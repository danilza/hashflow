import Foundation
import Supabase
import PostgREST

struct SupabaseProfileRecord: Codable, Identifiable {
    let id: UUID
    let username: String
    let isEmailVerified: Bool
    let walletAddress: String?
    let exclusivityMode: String?
}

private struct SupabaseProfileRow: Codable {
    let id: UUID
    let username: String?
    let isEmailVerified: Bool?
    let walletAddress: String?
    let exclusivityMode: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case username
        case isEmailVerified = "is_email_verified"
        case walletAddress = "wallet_address"
        case exclusivityMode = "exclusivity_mode"
    }
}

struct LeaderboardEntry: Identifiable {
    let playerID: UUID
    let username: String
    let uniqueSolutions: Int
    let uniqueLevelsCompleted: Int
    let totalPipelineLength: Int
    let respect: Int?
    let updatedAt: Date?

    var id: UUID { playerID }
}

struct CreditRefillStatus {
    let lastRefillDate: Date?
    let nextRefillAt: Date?
}

struct RunResourceConsumption: Decodable {
    let success: Bool
    let remainingMoves: Int
    let remainingCredits: Int

    private enum CodingKeys: String, CodingKey {
        case success
        case remainingMoves = "remaining_moves"
        case remainingCredits = "remaining_credits"
    }
}

struct PlayerEconomySnapshot: Decodable {
    let dailyMovesLeft: Int
    let creditBalance: Int

    private enum CodingKeys: String, CodingKey {
        case dailyMovesLeft = "daily_moves_left"
        case creditBalance = "credit_balance"
    }
}

struct SolutionNFT: Identifiable, Hashable {
    let pipelineHash: String
    let levelID: Int
    let pipelineLength: Int
    let metadataURI: String?
    let nftAddress: String?
    let mintTxHash: String?
    let mintedAt: Date?
    let chainOwnerAddress: String?
    let chainMetadataName: String?
    let chainMetadataImage: String?
    let isOwnedByCurrentPlayer: Bool?

    var id: String { pipelineHash }

    func withChainOverlay(
        ownerAddress: String?,
        metadataName: String?,
        metadataImage: String?,
        ownedByCurrentPlayer: Bool?
    ) -> SolutionNFT {
        SolutionNFT(
            pipelineHash: pipelineHash,
            levelID: levelID,
            pipelineLength: pipelineLength,
            metadataURI: metadataURI,
            nftAddress: nftAddress,
            mintTxHash: mintTxHash,
            mintedAt: mintedAt,
            chainOwnerAddress: ownerAddress,
            chainMetadataName: metadataName,
            chainMetadataImage: metadataImage,
            isOwnedByCurrentPlayer: ownedByCurrentPlayer
        )
    }
}

struct PlayerProgressSnapshot {
    let completedLevelIDs: [Int]
    let highestUnlockedLevelID: Int
    let updatedAt: Date?
}


actor SupabaseService {
    static let shared = SupabaseService()

    nonisolated let client: SupabaseClient
    private let decoder: JSONDecoder
    private let supabaseKey: String
    private let supabaseURLString: String

    init() {
        let env = ProcessInfo.processInfo.environment
        let isUITest = env["UITEST_MODE"] == "1"
        let defaultURL = "https://mspqeumqitcomagyorvw.supabase.co"
        let defaultKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1zcHFldW1xaXRjb21hZ3lvcnZ3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ4NTA4NjEsImV4cCI6MjA4MDQyNjg2MX0.jF1sgazizAVPFwEmyJs_Dd_Wx31Mromg5iEVIcnB1xs"
        if isUITest {
            let overrideURL = env["UITEST_SUPABASE_URL"] ?? ""
            let overrideKey = env["UITEST_SUPABASE_ANON_KEY"] ?? ""
            supabaseURLString = overrideURL.isEmpty ? defaultURL : overrideURL
            supabaseKey = overrideKey.isEmpty ? defaultKey : overrideKey
            print("SupabaseService UITEST_MODE url:", supabaseURLString)
        } else {
            supabaseURLString = defaultURL
            supabaseKey = defaultKey
        }
        client = SupabaseClient(
            supabaseURL: URL(string: supabaseURLString)!,
            supabaseKey: supabaseKey,
            options: SupabaseClientOptions(
                auth: .init(
                    emitLocalSessionAsInitialSession: true
                )
            )
        )
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func bootstrapCurrentProfile() async throws -> SupabaseProfileRecord? {
        guard let session = try? await client.auth.session else { return nil }
        return try await fetchOrCreateProfile(
            for: session.user,
            requiresEmailVerification: shouldEnforceEmailVerification(for: session.user)
        )
    }

    func profile(from session: Session) async throws -> SupabaseProfileRecord {
        try await fetchOrCreateProfile(
            for: session.user,
            requiresEmailVerification: shouldEnforceEmailVerification(for: session.user)
        )
    }

    func signIn(
        email: String,
        password: String,
        preferredUsername: String? = nil,
        requiresEmailVerification: Bool = true
    ) async throws -> SupabaseProfileRecord {
        let session = try await client.auth.signIn(email: email, password: password)
        return try await fetchOrCreateProfile(
            for: session.user,
            preferredUsername: preferredUsername,
            requiresEmailVerification: requiresEmailVerification
        )
    }

    func signInAnonymously() async throws -> SupabaseProfileRecord {
        let session = try await client.auth.signInAnonymously()
        return try await fetchOrCreateProfile(
            for: session.user,
            requiresEmailVerification: false
        )
    }

    func signUp(email: String, password: String, username: String) async throws {
        print("SUPABASE SIGNUP REQUEST email:", email)
        let response = try await client.auth.signUp(email: email, password: password)
        print("SUPABASE SIGNUP RESPONSE:", response)
        let otp = String(format: "%06d", Int.random(in: 0...999_999))
        let expiresAt = Date().addingTimeInterval(600)
        _ = try? await client
            .from("email_otp")
            .delete()
            .eq("email", value: email)
            .execute()
        let otpPayload = EmailOtpInsert(email: email, otp: otp, expiresAt: expiresAt.iso8601String)
        try await client.from("email_otp").insert(otpPayload).execute()
        print("OTP stored for:", email, "otp:", otp, "expires:", expiresAt)
        do {
            try await sendOtpEmail(email: email, otp: otp)
        } catch {
            print("Failed to send OTP email:", error)
            throw SupabaseServiceError.emailSendFailed
        }
        if response.session != nil {
            do {
                try await client.auth.signOut()
                print("Signed out immediately after signUp to wait for OTP.")
            } catch {
                print("Failed to sign out post-signUp:", error.localizedDescription)
            }
        }
    }

    func updateUsername(to newUsername: String) async throws -> SupabaseProfileRecord {
        let user = try await activeUser()
        let response = try await client
            .from("profiles")
            .update(UsernameUpdate(username: newUsername))
            .eq("id", value: user.id)
            .select()
            .single()
            .execute()
        let row = try decoder.decode(SupabaseProfileRow.self, from: response.data)
        let username = row.username ?? newUsername
        print("Updated Supabase username to", username, "for user", row.id)
        let requiresVerification = shouldEnforceEmailVerification(for: user)
        let verified = user.emailConfirmedAt != nil
        let effectiveVerified = verified || !requiresVerification
        guard effectiveVerified else { throw SupabaseServiceError.emailNotVerified }
        return SupabaseProfileRecord(id: row.id, username: username, isEmailVerified: effectiveVerified, walletAddress: row.walletAddress, exclusivityMode: row.exclusivityMode)
    }

    func updateWalletAddress(to newAddress: String?) async throws -> SupabaseProfileRecord {
        struct WalletAddressUpdate: Encodable {
            let wallet_address: String?
        }
        let user = try await activeUser()
        let normalized = SupabaseService.normalizeWalletAddress(newAddress)
        let rawTrimmed = newAddress?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !rawTrimmed.isEmpty && normalized == nil {
            throw SupabaseServiceError.invalidWalletAddress
        }
        let response = try await client
            .from("profiles")
            .update(WalletAddressUpdate(wallet_address: normalized))
            .eq("id", value: user.id)
            .select()
            .single()
            .execute()
        let row = try decoder.decode(SupabaseProfileRow.self, from: response.data)
        let username = row.username ?? "Player"
        let requiresVerification = shouldEnforceEmailVerification(for: user)
        let verified = user.emailConfirmedAt != nil
        let effectiveVerified = verified || !requiresVerification
        guard effectiveVerified else { throw SupabaseServiceError.emailNotVerified }
        return SupabaseProfileRecord(id: row.id, username: username, isEmailVerified: effectiveVerified, walletAddress: row.walletAddress, exclusivityMode: row.exclusivityMode)
    }

    func setExclusivityMode(to newMode: String) async throws -> SupabaseProfileRecord {
        throw SupabaseServiceError.operationUnavailable
    }

    func fetchExclusivityMode() async throws -> String {
        return "open"
    }

    func fetchLeaderboardByUniqueSolutions(limit: Int = 20) async throws -> [LeaderboardEntry] {
        print("🚀 Fetching leaderboard from Supabase...")
        let query = client
            .from("player_reputation")
            .select("""
                player_id,
                unique_solutions,
                respect,
                updated_at,
                profiles!inner(username)
            """)
            .order("unique_solutions", ascending: false)
            .limit(limit)
        print("🔍 Querying player_reputation via Supabase client: \(query)")
        print("📝 Supabase request: player_reputation ordered by unique_solutions desc limit \(limit)")
        let response = try await query.execute()
        print("📡 Supabase status: \(response.response.statusCode)")
        if let rawJSON = String(data: response.data, encoding: .utf8) {
            print("📥 Leaderboard raw JSON:\n\(rawJSON)")
        } else {
            print("📥 Leaderboard raw JSON: <nil data>")
        }
        let rows = try decoder.decode([LeaderboardRow].self, from: response.data)
        print("📊 Decoded leaderboard rows: \(rows.count)")
        return rows.map { row in
            let parsedDate = row.updatedAtString.flatMap {
                ISO8601DateFormatter.supabaseFractional.date(from: $0)
            }
            return LeaderboardEntry(
                playerID: row.playerID,
                username: row.username,
                uniqueSolutions: row.uniqueSolutions,
                uniqueLevelsCompleted: row.uniqueLevelsCompleted ?? 0,
                totalPipelineLength: row.totalPipelineLength ?? 0,
                respect: row.respect,
                updatedAt: parsedDate
            )
        }
    }

    func getLevelUniqueSolutionCounts() async throws -> [Int: Int] {
        let response = try await client
            .from("level_unique_solution_counts")
            .select("level_id, unique_solutions")
            .execute()
        let rows = try decoder.decode([LevelUniqueSolutionRow].self, from: response.data)
        var mapping: [Int: Int] = [:]
        for row in rows {
            mapping[row.levelID] = Int(row.uniqueSolutions)
        }
        return mapping
    }

    func getPlayerLevelStats(playerId: UUID) async throws -> [PlayerLevelStat] {
        struct Params: Encodable { let p_player_id: UUID }
        let response = try await client
            .rpc("get_player_level_stats", params: Params(p_player_id: playerId))
            .execute()
        let rows = try decoder.decode([PlayerLevelStatRow].self, from: response.data)
        return rows.map { row in
            PlayerLevelStat(
                levelID: Int(row.levelID),
                myUniqueSolutions: row.myUniqueSolutions,
                allUniqueSolutions: row.allUniqueSolutions,
                playerSharePercent: row.playerSharePercent,
                avgPipelineLength: row.avgPipelineLength
            )
        }
    }

    func getPlayerNFTs() async throws -> [SolutionNFT] {
        let response = try await client
            .rpc("get_player_solution_nfts", params: EmptyCodable())
            .execute()
        let rows = try decoder.decode([SolutionNFTRow].self, from: response.data)
        return rows.map {
            SolutionNFT(
                pipelineHash: $0.pipelineHash,
                levelID: $0.levelID,
                pipelineLength: $0.pipelineLength,
                metadataURI: $0.metadataURI,
                nftAddress: $0.nftAddress,
                mintTxHash: $0.mintTxHash,
                mintedAt: $0.mintedAt,
                chainOwnerAddress: nil,
                chainMetadataName: nil,
                chainMetadataImage: nil,
                isOwnedByCurrentPlayer: nil
            )
        }
    }

    func fetchPlayerProgress() async throws -> PlayerProgressSnapshot? {
        let user = try await activeUser()
        let response = try await client
            .from("player_progress")
            .select("player_id, completed_levels, highest_unlocked_level_id, updated_at")
            .eq("player_id", value: user.id)
            .limit(1)
            .execute()
        let rows = try decoder.decode([PlayerProgressRow].self, from: response.data)
        guard let row = rows.first else { return nil }
        return PlayerProgressSnapshot(
            completedLevelIDs: row.completedLevels,
            highestUnlockedLevelID: row.highestUnlockedLevelID,
            updatedAt: row.updatedAt
        )
    }

    func upsertPlayerProgressSnapshot(completedLevelIDs: [Int], highestUnlockedLevelID: Int) async throws {
        struct Params: Encodable {
            let p_player_id: UUID
            let p_completed_levels: [Int]
            let p_highest_unlocked_level_id: Int
        }
        let user = try await activeUser()
        let params = Params(
            p_player_id: user.id,
            p_completed_levels: completedLevelIDs,
            p_highest_unlocked_level_id: highestUnlockedLevelID
        )
        _ = try await client
            .rpc("set_player_progress", params: params)
            .execute()
    }

    private func fetchOrCreateProfile(
        for user: User,
        preferredUsername: String? = nil,
        requiresEmailVerification: Bool = true
    ) async throws -> SupabaseProfileRecord {
        do {
            let row = try await loadProfileRow(for: user, desiredUsername: preferredUsername)
            let username = try await ensureUsername(for: row, preferred: preferredUsername)
            let verified = user.emailConfirmedAt != nil
            let effectiveVerified = verified || !requiresEmailVerification
            guard effectiveVerified else { throw SupabaseServiceError.emailNotVerified }
            print("Fetched Supabase profile for user:", user.id, "username:", username)
            return SupabaseProfileRecord(id: row.id, username: username, isEmailVerified: effectiveVerified, walletAddress: row.walletAddress, exclusivityMode: row.exclusivityMode)
        } catch {
            print("Supabase profile lookup failed. Error:", error)
            throw error
        }
    }

    private func loadProfileRow(for user: User, desiredUsername: String? = nil) async throws -> SupabaseProfileRow {
        do {
            let response = try await client
                .rpc("bootstrap_profile_v1", params: EmptyCodable())
                .single()
                .execute()
            let row = try decoder.decode(SupabaseProfileRow.self, from: response.data)
            return try await finalizeProfileRow(row, desiredUsername: desiredUsername, user: user)
        } catch {
            if let postgrestError = error as? PostgrestError, postgrestError.code == "PGRST202" {
                let row = try await loadProfileRowFallback(for: user)
                return try await finalizeProfileRow(row, desiredUsername: desiredUsername, user: user)
            }
            throw error
        }
    }

    private func loadProfileRowFallback(for user: User) async throws -> SupabaseProfileRow {
        for attempt in 0..<3 {
            if let row = try await fetchProfileRow(for: user.id) {
                return row
            }
            try await createProfileRow(for: user.id)
            if let row = try await fetchProfileRow(for: user.id) {
                return row
            }
            if attempt < 2 {
                try await Task.sleep(nanoseconds: 250_000_000)
            }
        }
        throw SupabaseServiceError.missingUser
    }

    private func fetchProfileRow(for userID: UUID) async throws -> SupabaseProfileRow? {
        let response = try await client
            .from("profiles")
            .select()
            .eq("id", value: userID)
            .limit(1)
            .execute()
        let rows = try decoder.decode([SupabaseProfileRow].self, from: response.data)
        return rows.first
    }

    private func createProfileRow(for userID: UUID) async throws {
        _ = try await client
            .from("profiles")
            .insert(ProfileInsert(id: userID))
            .execute()
    }

    private func finalizeProfileRow(
        _ row: SupabaseProfileRow,
        desiredUsername: String?,
        user: User
    ) async throws -> SupabaseProfileRow {
        if (row.username == nil || row.username?.isEmpty == true),
           let desired = desiredUsername, !desired.isEmpty {
            try await client
                .from("profiles")
                .update(UsernameUpdate(username: desired))
                .eq("id", value: user.id)
                .execute()
            return SupabaseProfileRow(
                id: row.id,
                username: desired,
                isEmailVerified: row.isEmailVerified,
                walletAddress: row.walletAddress,
                exclusivityMode: row.exclusivityMode
            )
        }
        return row
    }

    private func ensureUsername(for row: SupabaseProfileRow, preferred: String?) async throws -> String {
        let trimmedPreferred = preferred?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let existing = row.username, !existing.isEmpty {
            if let desired = trimmedPreferred,
               !desired.isEmpty,
               existing.compare(desired, options: .caseInsensitive) != .orderedSame {
                try await client
                    .from("profiles")
                    .update(UsernameUpdate(username: desired))
                    .eq("id", value: row.id)
                    .execute()
                return desired
            }
            return existing
        }
        let username = try await pickAvailableUsername(preferred: trimmedPreferred)
        print("Assigning fallback username", username, "to profile", row.id)
        try await client
            .from("profiles")
            .update(UsernameUpdate(username: username))
            .eq("id", value: row.id)
            .execute()
        return username
    }

    private func pickAvailableUsername(preferred: String?) async throws -> String {
        if let preferred = preferred, !preferred.isEmpty {
            if try await isUsernameAvailable(preferred) {
                return preferred
            }
        }
        var attempt = 0
        while attempt < 5 {
            let candidate = "Player\(Int.random(in: 1000...9999))"
            if try await isUsernameAvailable(candidate) {
                return candidate
            }
            attempt += 1
        }
        return "Player\(UUID().uuidString.prefix(6))"
    }

    func isUsernameAvailable(_ username: String) async throws -> Bool {
        let response = try await client
            .from("profiles")
            .select("id")
            .eq("username", value: username)
            .limit(1)
            .execute()
        if let json = String(data: response.data, encoding: .utf8) {
            print("Username check JSON:", json)
        }
        let rows = try decoder.decode([SupabaseProfileRow].self, from: response.data)
        return rows.isEmpty
    }

    private func activeUser() async throws -> User {
        do {
            let session = try await client.auth.session
            return session.user
        } catch {
            throw SupabaseServiceError.notAuthenticated
        }
    }

    func verifyEmailOtp(email: String, otp: String, password: String, preferredUsername: String?) async throws -> SupabaseProfileRecord {
        struct VerifyOtpParams: Encodable {
            let p_email: String
            let p_code: String
        }
        _ = try await client
            .rpc("verify_otp", params: VerifyOtpParams(p_email: email, p_code: otp))
            .execute()

        _ = try await client
            .rpc("confirm_email", params: ["p_email": email])
            .execute()

        let profile = try await signIn(email: email, password: password, preferredUsername: preferredUsername)
        return profile
    }

    func deleteAccountData() async throws {
        let user = try await activeUser()
        try await client
            .from("profiles")
            .delete()
            .eq("id", value: user.id)
            .execute()
        try await client.auth.signOut()
    }

    func signInWithGoogle() async throws {
        try await client.auth.signInWithOAuth(
            provider: .google,
            redirectTo: URL(string: "hashflow://login-callback")
        )
    }

    private func shouldEnforceEmailVerification(for user: User) -> Bool {
        if let provider = user.identities?.first?.provider.lowercased() {
            return provider == "email"
        }
        return false
    }

    func handleDeepLink(_ url: URL) async throws {
        print("SupabaseService.handleDeepLink url =", url.absoluteString)
        do {
            let session = try await client.auth.session(from: url)
            print("session(from:) completed, user id:", session.user.id)
        } catch {
            print("session(from:) error:", error)
            throw error
        }
    }

    func debugOtpRows(for email: String) async {
        do {
            let response = try await client
                .from("email_otp")
                .select()
                .eq("email", value: email)
                .execute()
            if let raw = String(data: response.data, encoding: .utf8) {
                print("OTP debug rows for", email, ":", raw)
            }
        } catch {
            print("OTP debug fetch failed:", error.localizedDescription)
        }
    }

    private func sendOtpEmail(email: String, otp: String) async throws {
        struct Payload: Encodable {
            let email: String
            let otp: String
        }
        let payload = Payload(email: email, otp: otp)
        guard let url = URL(string: "https://mspqeumqitcomagyorvw.supabase.co/functions/v1/send_otp") else {
            throw SupabaseServiceError.emailSendFailed
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(payload)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            if let raw = String(data: data, encoding: .utf8) {
                print("send_otp error response:", raw)
            }
            throw SupabaseServiceError.emailSendFailed
        }
        print("OTP email requested via send_otp for:", email)
    }
}
enum SupabaseServiceError: LocalizedError {
    case notAuthenticated
    case missingUser
    case invalidOtp
    case emailSendFailed
    case emailNotVerified
    case invalidWalletAddress
    case operationUnavailable

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Не выполнен вход в Supabase."
        case .missingUser:
            return "Не удалось получить информацию о пользователе."
        case .invalidOtp:
            return "Неверный или устаревший код подтверждения."
        case .emailSendFailed:
            return "Не удалось отправить код подтверждения."
        case .emailNotVerified:
            return "Email ещё не подтверждён. Заверши ввод OTP."
        case .invalidWalletAddress:
            return "TON-адрес некорректен. Проверь длину и допустимые символы."
        case .operationUnavailable:
            return "Операция недоступна на текущем этапе."
        }
    }
}

private struct UsernameUpdate: Encodable {
    let username: String
}

private struct ProfileInsert: Encodable {
    let id: UUID
}

private struct EmailOtpInsert: Encodable {
    let email: String
    let otp: String
    let expiresAt: String

    private enum CodingKeys: String, CodingKey {
        case email
        case otp
        case expiresAt = "expires_at"
    }
}

private struct EmailOtpRow: Decodable {
    let email: String
    let otp: String
    let expiresAt: Date

    private enum CodingKeys: String, CodingKey {
        case email
        case otp
        case expiresAt = "expires_at"
    }
}

private struct LevelUniqueSolutionRow: Decodable {
    let levelID: Int
    let uniqueSolutions: Int

    private enum CodingKeys: String, CodingKey {
        case levelID = "level_id"
        case uniqueSolutions = "unique_solutions"
    }
}

struct PlayerLevelStat {
    let levelID: Int
    let myUniqueSolutions: Int
    let allUniqueSolutions: Int
    let playerSharePercent: Double?
    let avgPipelineLength: Double?
}

private struct PlayerLevelStatRow: Decodable {
    let levelID: Int
    let myUniqueSolutions: Int
    let allUniqueSolutions: Int
    let playerSharePercent: Double?
    let avgPipelineLength: Double?

    private enum CodingKeys: String, CodingKey {
        case levelID = "level_id"
        case myUniqueSolutions = "my_unique_solutions"
        case allUniqueSolutions = "all_unique_solutions"
        case playerSharePercent = "player_share_percent"
        case avgPipelineLength = "avg_pipeline_length"
    }
}

private extension ISO8601DateFormatter {
    static let supabaseFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

private extension DateFormatter {
    static let supabaseDateOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

extension SupabaseService {
    func currentUser() async throws -> User {
        try await activeUser()
    }

    func recordUniqueSolution(
        playerId: UUID,
        levelId: Int,
        pipelineHash: String,
        pipelineRaw: String,
        pipelineLength: Int
    ) async throws -> Bool {
        struct RecordUniqueSolutionParams: Encodable {
            let p_player_id: UUID
            let p_level_id: Int64
            let p_pipeline_hash: String
            let p_pipeline_raw: String
            let p_pipeline_length: Int32
        }
        let params = RecordUniqueSolutionParams(
            p_player_id: playerId,
            p_level_id: Int64(levelId),
            p_pipeline_hash: pipelineHash,
            p_pipeline_raw: pipelineRaw,
            p_pipeline_length: Int32(pipelineLength)
        )
        print("🚀 recordUniqueSolution called: player=\(playerId), level=\(levelId), hash=\(pipelineHash)")
        let response = try await client
            .rpc("record_unique_solution_v1", params: params)
            .single()
            .execute()
        let inserted = try decoder.decode(Bool.self, from: response.data)
        if inserted {
            print("🔥 Unique solution recorded")
        } else {
            print("🤷 Already exists, ignoring")
        }
        return inserted
    }
}

extension SupabaseService {
    func pipelineHashExists(_ pipelineHash: String) async throws -> Bool {
        struct Row: Decodable { let pipeline_hash: String }
        let response = try await client
            .from("unique_pipelines")
            .select("pipeline_hash")
            .eq("pipeline_hash", value: pipelineHash)
            .limit(1)
            .execute()
        let rows = try decoder.decode([Row].self, from: response.data)
        return !rows.isEmpty
    }
}

extension SupabaseService {
    func fetchPlayerEconomy() async throws -> PlayerEconomySnapshot {
        let user = try await activeUser()
        let response = try await client
            .from("player_economy")
            .select("daily_moves_left, credit_balance")
            .eq("player_id", value: user.id)
            .limit(1)
            .execute()
        let rows = try decoder.decode([PlayerEconomySnapshot].self, from: response.data)
        if let row = rows.first {
            return row
        }
        return PlayerEconomySnapshot(dailyMovesLeft: 50, creditBalance: 0)
    }

    func fetchCreditBalance() async throws -> Int {
        let economy = try await fetchPlayerEconomy()
        return economy.creditBalance
    }

    func fetchWithdrawableBalance() async throws -> Int {
        return 0
    }

    func fetchMovesBalance() async throws -> Int {
        let economy = try await fetchPlayerEconomy()
        return economy.dailyMovesLeft
    }

    func fetchCreditRefillStatus() async throws -> CreditRefillStatus? {
        struct Params: Encodable { let p_player_id: UUID }
        struct Row: Decodable {
            let lastRefillDate: String?
            let nextRefillAtString: String?

            private enum CodingKeys: String, CodingKey {
                case lastRefillDate = "last_refill_date"
                case nextRefillAtString = "next_refill_at"
            }

            var lastRefillDateValue: Date? {
                guard let lastRefillDate else { return nil }
                return DateFormatter.supabaseDateOnly.date(from: lastRefillDate)
            }

            var nextRefillAt: Date? {
                guard let nextRefillAtString else { return nil }
                return ISO8601DateFormatter.supabaseFractional.date(from: nextRefillAtString)
            }
        }
        let user = try await activeUser()
        let response = try await client
            .rpc("get_credit_refill_status", params: Params(p_player_id: user.id))
            .single()
            .execute()
        let row = try decoder.decode(Row.self, from: response.data)
        return CreditRefillStatus(
            lastRefillDate: row.lastRefillDateValue,
            nextRefillAt: row.nextRefillAt
        )
    }

    func isFreeRunActive() async throws -> Bool {
        struct Params: Encodable { let p_player_id: UUID }
        let user = try await activeUser()
        let response = try await client
            .rpc("free_run_active", params: Params(p_player_id: user.id))
            .single()
            .execute()
        return try decoder.decode(Bool.self, from: response.data)
    }

    func fetchFreeRunRemainingHours() async throws -> Int? {
        struct Params: Encodable { let p_player_id: UUID }
        let user = try await activeUser()
        let response = try await client
            .rpc("free_run_remaining_hours", params: Params(p_player_id: user.id))
            .single()
            .execute()
        return try decoder.decode(Int?.self, from: response.data)
    }

    func calculateRunCost(levelId: Int, nodes: Int, pipelineHash: String, lastPipelineHash: String?, levelTier: String) async throws -> Int {
        struct Params: Encodable {
            let p_player_id: UUID
            let p_level_id: Int64
            let p_nodes_count: Int
            let p_pipeline_hash: String
            let p_last_pipeline_hash: String?
            let p_level_tier: String
        }
        let user = try await activeUser()
        let params = Params(
            p_player_id: user.id,
            p_level_id: Int64(levelId),
            p_nodes_count: nodes,
            p_pipeline_hash: pipelineHash,
            p_last_pipeline_hash: lastPipelineHash,
            p_level_tier: levelTier
        )
        let response = try await client
            .rpc("calculate_run_cost_v1", params: params)
            .single()
            .execute()
        return try decoder.decode(Int.self, from: response.data)
    }

    func consumeRunResources(cost: Int) async throws -> RunResourceConsumption {
        struct Params: Encodable {
            let p_player_id: UUID
            let p_cost: Int
        }
        let user = try await activeUser()
        let params = Params(p_player_id: user.id, p_cost: cost)
        let response = try await client
            .rpc("consume_run_resources_v1", params: params)
            .single()
            .execute()
        return try decoder.decode(RunResourceConsumption.self, from: response.data)
    }

    func consumeCredits(amount: Int, source: String) async throws -> Int {
        let result = try await consumeRunResources(cost: amount)
        return result.remainingCredits
    }

    func mintPipelineNFT(levelId: Int, pipelineHash: String, cost: Int?) async throws {
        throw SupabaseServiceError.operationUnavailable
    }

    func purchaseSolution(pipelineHash: String, price: Int, platformCut: Int = 0) async throws {
        struct Params: Encodable {
            let p_pipeline_hash: String
            let p_price: Int
        }
        let params = Params(
            p_pipeline_hash: pipelineHash,
            p_price: price
        )
        _ = try await client.rpc("purchase_pipeline_v1", params: params).single().execute()
    }

    func setSolutionPrice(pipelineHash: String, price: Int?, forSale: Bool) async throws -> Bool {
        throw SupabaseServiceError.operationUnavailable
    }

    func fetchMarketSolutions(limit: Int = 50) async throws -> [UniquePipelineItem] {
        return []
    }

    func fetchMyUniqueSolutions(pendingOnly: Bool = true) async throws -> [UniquePipelineItem] {
        let user = try await activeUser()
        var query = client
            .from("unique_pipelines")
            .select("""
                pipeline_hash,
                level_id,
                pipeline_length,
                nft_status,
                nft_address,
                owner_id,
                created_at
            """)
            .eq("owner_id", value: user.id)
        if pendingOnly {
            query = query.eq("nft_status", value: "pending")
        }
        let response = try await query
            .order("created_at", ascending: false)
            .execute()
        return try decoder.decode([UniquePipelineItem].self, from: response.data)
    }

    func fetchMyMintedSolutions() async throws -> [UniquePipelineItem] {
        let user = try await activeUser()
        let response = try await client
            .from("unique_pipelines")
            .select("""
                pipeline_hash,
                level_id,
                pipeline_length,
                nft_status,
                nft_address,
                owner_id,
                created_at
            """)
            .eq("owner_id", value: user.id)
            .eq("nft_status", value: "minted")
            .order("created_at", ascending: false)
            .execute()
        return try decoder.decode([UniquePipelineItem].self, from: response.data)
    }

    func fetchOtherMintableSolutions(limit: Int = 20) async throws -> [UniquePipelineItem] {
        return []
    }
}

private struct LeaderboardRow: Decodable {
    let playerID: UUID
    let uniqueSolutions: Int
    let uniqueLevelsCompleted: Int?
    let totalPipelineLength: Int?
    let respect: Int?
    let updatedAtString: String?
    let profiles: ProfileRef?

    var username: String { profiles?.username ?? "Player" }

    private enum CodingKeys: String, CodingKey {
        case playerID = "player_id"
        case uniqueSolutions = "unique_solutions"
        case uniqueLevelsCompleted = "unique_levels_completed"
        case totalPipelineLength = "total_pipeline_length"
        case respect
        case updatedAtString = "updated_at"
        case profiles
    }

    struct ProfileRef: Decodable {
        let username: String
    }
}

private struct PlayerProgressRow: Decodable {
    let playerID: UUID
    let completedLevels: [Int]
    let highestUnlockedLevelID: Int
    let updatedAtString: String?

    var updatedAt: Date? {
        guard let updatedAtString else { return nil }
        return ISO8601DateFormatter.supabaseFractional.date(from: updatedAtString)
    }

    private enum CodingKeys: String, CodingKey {
        case playerID = "player_id"
        case completedLevels = "completed_levels"
        case highestUnlockedLevelID = "highest_unlocked_level_id"
        case updatedAtString = "updated_at"
    }
}

private struct SolutionNFTRow: Decodable {
    let pipelineHash: String
    let levelID: Int
    let pipelineLength: Int
    let metadataURI: String?
    let nftAddress: String?
    let mintTxHash: String?
    let mintedAtString: String?

    var mintedAt: Date? {
        guard let mintedAtString else { return nil }
        return ISO8601DateFormatter.supabaseFractional.date(from: mintedAtString)
    }

    private enum CodingKeys: String, CodingKey {
        case pipelineHash = "pipeline_hash"
        case levelID = "level_id"
        case pipelineLength = "pipeline_length"
        case metadataURI = "metadata_uri"
        case nftAddress = "nft_address"
        case mintTxHash = "mint_tx_hash"
        case mintedAtString = "minted_at"
    }
}

private struct ExclusivityModeRow: Decodable {
    let exclusivityMode: String?

    private enum CodingKeys: String, CodingKey {
        case exclusivityMode = "exclusivity_mode"
    }
}

struct UniquePipelineItem: Decodable, Identifiable, Hashable {
    let pipelineHash: String
    let levelID: Int
    let pipelineLength: Int
    let nftStatus: String?
    let nftAddress: String?
    let ownerID: UUID
    let createdAtString: String?
    let exclusiveUntilString: String?
    let exclusiveOverride: Bool
    let salePrice: Int?
    let forSale: Bool

    var id: String { pipelineHash }

    var createdAt: Date? {
        guard let createdAtString else { return nil }
        return ISO8601DateFormatter.supabaseFractional.date(from: createdAtString)
    }

    var exclusiveUntil: Date? {
        guard let exclusiveUntilString else { return nil }
        return ISO8601DateFormatter.supabaseFractional.date(from: exclusiveUntilString)
    }

    private enum CodingKeys: String, CodingKey {
        case pipelineHash = "pipeline_hash"
        case levelID = "level_id"
        case pipelineLength = "pipeline_length"
        case nftStatus = "nft_status"
        case nftAddress = "nft_address"
        case ownerID = "owner_id"
        case createdAtString = "created_at"
        case exclusiveUntilString = "exclusive_until"
        case exclusiveOverride = "exclusive_override"
        case salePrice = "sale_price"
        case forSale = "for_sale"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        pipelineHash = try container.decode(String.self, forKey: .pipelineHash)
        levelID = try container.decode(Int.self, forKey: .levelID)
        pipelineLength = try container.decode(Int.self, forKey: .pipelineLength)
        nftStatus = try container.decodeIfPresent(String.self, forKey: .nftStatus)
        nftAddress = try container.decodeIfPresent(String.self, forKey: .nftAddress)
        ownerID = try container.decode(UUID.self, forKey: .ownerID)
        createdAtString = try container.decodeIfPresent(String.self, forKey: .createdAtString)
        exclusiveUntilString = try container.decodeIfPresent(String.self, forKey: .exclusiveUntilString)
        exclusiveOverride = try container.decodeIfPresent(Bool.self, forKey: .exclusiveOverride) ?? false
        salePrice = try container.decodeIfPresent(Int.self, forKey: .salePrice)
        forSale = try container.decodeIfPresent(Bool.self, forKey: .forSale) ?? false
    }
}
private struct EmptyCodable: Encodable {}

private extension SupabaseService {
    func forceMarkMintedForUITests(pipelineHash: String) async {
        guard ProcessInfo.processInfo.environment["UITEST_MODE"] == "1" else { return }
        guard let serviceKey = ProcessInfo.processInfo.environment["UITEST_SERVICE_KEY"],
              !serviceKey.isEmpty else { return }
        let baseURL = ProcessInfo.processInfo.environment["UITEST_SUPABASE_URL"] ?? supabaseURLString
        guard let url = URL(string: "\(baseURL)/rest/v1/unique_pipelines?pipeline_hash=eq.\(pipelineHash)") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(serviceKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(serviceKey)", forHTTPHeaderField: "Authorization")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        let payload: [String: Any] = [
            "nft_status": "minted",
            "exclusive_override": true,
            "minted_at": ISO8601DateFormatter().string(from: Date())
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload, options: [])
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse {
                if http.statusCode >= 300 {
                    print("forceMarkMintedForUITests failed status:", http.statusCode, "hash:", pipelineHash)
                } else {
                    print("forceMarkMintedForUITests updated hash:", pipelineHash, "status:", http.statusCode)
                }
            }
        } catch {
            print("forceMarkMintedForUITests error:", error)
        }
    }
}

extension SupabaseService {
    nonisolated static func normalizeWalletAddress(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let cleaned = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
        guard !cleaned.isEmpty else { return nil }
        let pattern = "^[A-Za-z0-9_-]{48}$"
        guard cleaned.range(of: pattern, options: .regularExpression) != nil else { return nil }
        return cleaned
    }
}
