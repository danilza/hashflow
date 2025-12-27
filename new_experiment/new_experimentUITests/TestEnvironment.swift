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
}
