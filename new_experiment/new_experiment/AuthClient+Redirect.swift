import Foundation
import Supabase

extension AuthClient {
    func handleRedirectURL(_ url: URL) async throws {
        _ = try await session(from: url)
    }
}
