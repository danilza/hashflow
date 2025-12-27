import Foundation

struct TestEnvironment {
    let supabaseURL: String
    let anonKey: String
    let serviceKey: String
    let email: String?
    let password: String?
    let walletAddress: String

    init() {
        let env = ProcessInfo.processInfo.environment
        supabaseURL = env["UITEST_SUPABASE_URL"] ?? ""
        anonKey = env["UITEST_SUPABASE_ANON_KEY"] ?? ""
        serviceKey = env["UITEST_SERVICE_KEY"] ?? ""
        email = env["UITEST_EMAIL"]
        password = env["UITEST_PASSWORD"]
        walletAddress = env["UITEST_WALLET_ADDRESS"] ?? "EQTEST_WALLET_ADDRESS"

        if supabaseURL.isEmpty || anonKey.isEmpty || serviceKey.isEmpty {
            if let filePayload = Self.loadSecretsFromBundle() {
                supabaseURL = filePayload.supabaseURL.isEmpty ? supabaseURL : filePayload.supabaseURL
                anonKey = filePayload.anonKey.isEmpty ? anonKey : filePayload.anonKey
                serviceKey = filePayload.serviceKey.isEmpty ? serviceKey : filePayload.serviceKey
                if walletAddress == "EQTEST_WALLET_ADDRESS", !filePayload.walletAddress.isEmpty {
                    walletAddress = filePayload.walletAddress
                }
            }
        }
    }

    func validateOrThrow() throws {
        if supabaseURL.isEmpty || anonKey.isEmpty || serviceKey.isEmpty {
            throw NSError(
                domain: "UITest",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Missing UITEST_SUPABASE_URL / UITEST_SUPABASE_ANON_KEY / UITEST_SERVICE_KEY"]
            )
        }
    }

    func validateOrDescribeError() -> String? {
        if supabaseURL.isEmpty || anonKey.isEmpty || serviceKey.isEmpty {
            return "Missing UITEST_SUPABASE_URL / UITEST_SUPABASE_ANON_KEY / UITEST_SERVICE_KEY"
        }
        return nil
    }

    private static func loadSecretsFromBundle() -> FilePayload? {
        let bundle = Bundle(for: BundleLocator.self)
        guard let url = bundle.url(forResource: "UITestSecrets", withExtension: "json") else { return nil }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(FilePayload.self, from: data)
    }
}

private struct BundleLocator {}

private struct FilePayload: Decodable {
    let supabaseURL: String
    let anonKey: String
    let serviceKey: String
    let walletAddress: String

    private enum CodingKeys: String, CodingKey {
        case supabaseURL = "UITEST_SUPABASE_URL"
        case anonKey = "UITEST_SUPABASE_ANON_KEY"
        case serviceKey = "UITEST_SERVICE_KEY"
        case walletAddress = "UITEST_WALLET_ADDRESS"
    }
}
