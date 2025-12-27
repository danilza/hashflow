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
        var resolvedURL = env["UITEST_SUPABASE_URL"] ?? ""
        var resolvedAnonKey = env["UITEST_SUPABASE_ANON_KEY"] ?? ""
        var resolvedServiceKey = env["UITEST_SERVICE_KEY"] ?? ""
        let resolvedEmail = env["UITEST_EMAIL"]
        let resolvedPassword = env["UITEST_PASSWORD"]
        var resolvedWallet = env["UITEST_WALLET_ADDRESS"] ?? "EQTEST_WALLET_ADDRESS"

        if resolvedURL.isEmpty || resolvedAnonKey.isEmpty || resolvedServiceKey.isEmpty {
            if let filePayload = Self.loadSecretsFromBundle() {
                if resolvedURL.isEmpty { resolvedURL = filePayload.supabaseURL }
                if resolvedAnonKey.isEmpty { resolvedAnonKey = filePayload.anonKey }
                if resolvedServiceKey.isEmpty { resolvedServiceKey = filePayload.serviceKey }
                if resolvedWallet == "EQTEST_WALLET_ADDRESS", !filePayload.walletAddress.isEmpty {
                    resolvedWallet = filePayload.walletAddress
                }
            }
        }

        supabaseURL = resolvedURL
        anonKey = resolvedAnonKey
        serviceKey = resolvedServiceKey
        email = resolvedEmail
        password = resolvedPassword
        walletAddress = resolvedWallet
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

private final class BundleLocator {}

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
