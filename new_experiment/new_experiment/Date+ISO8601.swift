import Foundation

extension Date {
    var iso8601String: String {
        Date.iso8601Formatter.string(from: self)
    }

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
