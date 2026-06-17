import Foundation

// MARK: - ISO8601DateFormatter Extension

extension ISO8601DateFormatter {

    /// Pricist standard date formatter with milliseconds. The backend
    /// (`normalizeTrackEvent`) accepts any value `Date(...)` can parse and
    /// re-serializes to ISO 8601, but the SDK always sends fractional-second
    /// UTC so event ordering is stable.
    static let pricist: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds
        ]
        return formatter
    }()
}
