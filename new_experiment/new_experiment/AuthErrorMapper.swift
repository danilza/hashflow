import Foundation

enum AuthErrorMapper {
    static func message(for error: Error) -> String {
        if let supabaseError = error as? SupabaseServiceError {
            return supabaseError.localizedDescription
        }
        let lower = error.localizedDescription.lowercased()
        if lower.contains("invalid login credentials") ||
            lower.contains("invalid login") ||
            lower.contains("invalid email or password") {
            return "Неверный логин/пароль."
        }
        if lower.contains("email not confirmed") ||
            lower.contains("email confirmation") {
            return "Почта не подтверждена — проверь inbox."
        }
        if lower.contains("row-level security") {
            return "Ошибка сервиса (RLS). Попробуй позже."
        }
        if lower.contains("insufficient credits") || lower.contains("insufficient") {
            return "Недостаточно кредитов."
        }
        return "Ошибка сервиса. \(error.localizedDescription)"
    }
}
