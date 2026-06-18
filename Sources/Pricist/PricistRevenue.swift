import Foundation

/// Revenue information for purchase / subscription events.
public struct PricistRevenue {

    /// Revenue amount.
    public let amount: Decimal

    /// ISO 4217 currency code (e.g., "USD", "EUR").
    public let currency: String

    /// Create revenue with amount and currency.
    /// - Parameters:
    ///   - amount: Revenue amount.
    ///   - currency: ISO 4217 currency code.
    public init(amount: Decimal, currency: String) {
        self.amount = amount
        self.currency = currency.uppercased()
    }

    /// Create revenue from a Double with currency.
    /// - Parameters:
    ///   - amount: Revenue amount as Double.
    ///   - currency: ISO 4217 currency code.
    public init(amount: Double, currency: String) {
        self.amount = Decimal(amount)
        self.currency = currency.uppercased()
    }

    /// Amount formatted to 6 decimal places, matching the precision the
    /// Pricist backend stores (`revenue_amount` / `revenue_usd` are decimal
    /// strings). No grouping separator so the value parses as a plain number.
    internal func amountString() -> String {
        let formatter = NumberFormatter()
        // Pin to en_US_POSIX so the decimal separator is always '.' and no
        // grouping is applied, regardless of the device's current locale.
        // Without this, a device set to e.g. German would emit "29,99".
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 6
        formatter.groupingSeparator = ""
        formatter.decimalSeparator = "."
        formatter.roundingMode = .halfUp
        return formatter.string(from: amount as NSDecimalNumber) ?? "0.00"
    }
}

// MARK: - Convenience Initializers

public extension PricistRevenue {

    /// Create USD revenue.
    static func usd(_ amount: Decimal) -> PricistRevenue {
        PricistRevenue(amount: amount, currency: "USD")
    }

    /// Create USD revenue from Double.
    static func usd(_ amount: Double) -> PricistRevenue {
        PricistRevenue(amount: amount, currency: "USD")
    }

    /// Create EUR revenue.
    static func eur(_ amount: Decimal) -> PricistRevenue {
        PricistRevenue(amount: amount, currency: "EUR")
    }

    /// Create EUR revenue from Double.
    static func eur(_ amount: Double) -> PricistRevenue {
        PricistRevenue(amount: amount, currency: "EUR")
    }

    /// Create GBP revenue.
    static func gbp(_ amount: Decimal) -> PricistRevenue {
        PricistRevenue(amount: amount, currency: "GBP")
    }

    /// Create GBP revenue from Double.
    static func gbp(_ amount: Double) -> PricistRevenue {
        PricistRevenue(amount: amount, currency: "GBP")
    }
}
