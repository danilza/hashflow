import Foundation

struct TestUser {
    let id: String
    let email: String
    let password: String
}

struct EconomySnapshot {
    let dailyMovesLeft: Int
    let creditBalance: Int
}

final class TestUserFactory {
    private let baseURL: String
    private let anonKey: String
    private let serviceKey: String

    init(baseURL: String, anonKey: String, serviceKey: String) {
        self.baseURL = baseURL
        self.anonKey = anonKey
        self.serviceKey = serviceKey
    }

    func makeUser(prefix: String, wallet: String, dailyMoves: Int = 50, credits: Int = 0) async throws -> TestUser {
        let stamp = Int(Date().timeIntervalSince1970)
        let email = "\(prefix)+\(stamp)@example.com"
        let password = "TestPass123!"
        let userId = try await adminCreateUser(email: email, password: password)
        try await upsertProfile(userId: userId, username: prefix, wallet: wallet)
        try await upsertPlayerEconomy(userId: userId, dailyMovesLeft: dailyMoves, creditBalance: credits)
        return TestUser(id: userId, email: email, password: password)
    }

    func fetchLatestAuthUserID() async throws -> String? {
        guard let url = URL(string: "\(baseURL)/auth/v1/admin/users?page=1&per_page=1") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(serviceKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(serviceKey)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await dataWithStatusRetry(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 500
        guard status < 300 else {
            throw NSError(domain: "UITest", code: 12, userInfo: [NSLocalizedDescriptionKey: "Fetch latest auth user failed (status \(status))"])
        }
        let json = try JSONSerialization.jsonObject(with: data, options: [])
        if let dict = json as? [String: Any], let users = dict["users"] as? [[String: Any]] {
            return users.first?["id"] as? String
        }
        if let users = json as? [[String: Any]] {
            return users.first?["id"] as? String
        }
        return nil
    }

    func fetchPlayerEconomy(userId: String) async throws -> EconomySnapshot {
        let url = URL(string: "\(baseURL)/rest/v1/player_economy?player_id=eq.\(userId)&select=daily_moves_left,credit_balance")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(serviceKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(serviceKey)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await dataWithStatusRetry(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 500
        guard status < 300 else {
            throw NSError(domain: "UITest", code: 13, userInfo: [NSLocalizedDescriptionKey: "Fetch economy failed (status \(status))"])
        }
        let json = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]]
        guard let item = json?.first,
              let moves = item["daily_moves_left"] as? Int,
              let credits = item["credit_balance"] as? Int else {
            throw NSError(domain: "UITest", code: 13, userInfo: [NSLocalizedDescriptionKey: "Fetch economy missing fields"])
        }
        return EconomySnapshot(dailyMovesLeft: moves, creditBalance: credits)
    }

    func profileExists(userId: String) async throws -> Bool {
        let url = URL(string: "\(baseURL)/rest/v1/profiles?id=eq.\(userId)&select=id")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(serviceKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(serviceKey)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await dataWithStatusRetry(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 500
        guard status < 300 else {
            throw NSError(domain: "UITest", code: 13, userInfo: [NSLocalizedDescriptionKey: "Fetch profile failed (status \(status))"])
        }
        let json = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]]
        return !(json ?? []).isEmpty
    }

    func fetchAccessToken(email: String, password: String) async throws -> (accessToken: String, userId: String) {
        let url = URL(string: "\(baseURL)/auth/v1/token?grant_type=password")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "email": email,
            "password": password
        ], options: [])
        let (data, response) = try await dataWithStatusRetry(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 500
        guard status < 300 else {
            throw NSError(domain: "UITest", code: 14, userInfo: [NSLocalizedDescriptionKey: "Fetch access token failed (status \(status))"])
        }
        let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        guard let accessToken = json?["access_token"] as? String,
              let user = json?["user"] as? [String: Any],
              let userId = user["id"] as? String else {
            throw NSError(domain: "UITest", code: 14, userInfo: [NSLocalizedDescriptionKey: "Fetch access token missing fields"])
        }
        return (accessToken, userId)
    }

    func uniquePipelineCount(pipelineHash: String) async throws -> Int {
        let url = URL(string: "\(baseURL)/rest/v1/unique_pipelines?pipeline_hash=eq.\(pipelineHash)&select=pipeline_hash")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(serviceKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(serviceKey)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await dataWithStatusRetry(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 500
        guard status < 300 else {
            throw NSError(domain: "UITest", code: 18, userInfo: [NSLocalizedDescriptionKey: "Fetch unique pipeline failed (status \(status))"])
        }
        let json = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]]
        return json?.count ?? 0
    }

    private func adminCreateUser(email: String, password: String) async throws -> String {
        let url = URL(string: "\(baseURL)/auth/v1/admin/users")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(serviceKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(serviceKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "email": email,
            "password": password,
            "email_confirm": true
        ], options: [])
        let (data, response) = try await dataWithStatusRetry(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 500
        guard status < 300 else {
            throw NSError(domain: "UITest", code: 15, userInfo: [NSLocalizedDescriptionKey: "Admin create user failed (status \(status))"])
        }
        let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        guard let id = json?["id"] as? String else {
            throw NSError(domain: "UITest", code: 15, userInfo: [NSLocalizedDescriptionKey: "Admin create user missing id"])
        }
        return id
    }

    private func upsertProfile(userId: String, username: String, wallet: String) async throws {
        let url = URL(string: "\(baseURL)/rest/v1/profiles")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(serviceKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(serviceKey)", forHTTPHeaderField: "Authorization")
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONSerialization.data(withJSONObject: [[
            "id": userId,
            "username": username,
            "wallet_address": wallet
        ]], options: [])
        let (_, response) = try await dataWithStatusRetry(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 500
        guard status < 300 else {
            throw NSError(domain: "UITest", code: 16, userInfo: [NSLocalizedDescriptionKey: "Profile upsert failed (status \(status))"])
        }
    }

    private func upsertPlayerEconomy(userId: String, dailyMovesLeft: Int, creditBalance: Int) async throws {
        let url = URL(string: "\(baseURL)/rest/v1/player_economy")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(serviceKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(serviceKey)", forHTTPHeaderField: "Authorization")
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONSerialization.data(withJSONObject: [[
            "player_id": userId,
            "daily_moves_left": dailyMovesLeft,
            "credit_balance": creditBalance
        ]], options: [])
        let (_, response) = try await dataWithStatusRetry(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 500
        guard status < 300 else {
            throw NSError(domain: "UITest", code: 17, userInfo: [NSLocalizedDescriptionKey: "Player economy upsert failed (status \(status))"])
        }
    }

    private func dataWithStatusRetry(for request: URLRequest, retries: Int = 2) async throws -> (Data, URLResponse) {
        var lastError: Error?
        for attempt in 0...retries {
            do {
                return try await URLSession.shared.data(for: request)
            } catch {
                lastError = error
                if attempt == retries { break }
                try await Task.sleep(nanoseconds: 300_000_000)
            }
        }
        throw lastError ?? NSError(domain: "UITest", code: 18, userInfo: [NSLocalizedDescriptionKey: "Request failed"])
    }
}
