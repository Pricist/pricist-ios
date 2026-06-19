import Foundation

/// The result of an experiment decision (`POST /api/decision`).
///
/// `payload` is the assigned variant's value — e.g. `["price": 39.99]` for a
/// price experiment or `["copy": "…"]` for a copy experiment. When `assigned`
/// is `false` the experiment isn't running or the user isn't eligible; use your
/// own default value.
///
/// After a `decide(...)` call, the SDK auto-attaches this experiment's
/// `experimentId` / `variantId` (and branch + collected variables) to
/// subsequent events, so results flow without extra wiring.
public struct PricistDecision {
    /// Whether the user was assigned to a running, eligible experiment.
    public let assigned: Bool
    public let experimentId: String?
    public let variantId: String?
    /// The branch this user was routed into (e.g. an `experience_level` value),
    /// or `nil` for an unbranched experiment.
    public let branch: String?
    /// The assigned variant's value.
    public let payload: [String: Any]
    /// Collect/branch variables echoed back; attached to subsequent events.
    public let variables: [String: Any]

    /// A non-assignment result — callers should fall back to their default.
    public static let notAssigned = PricistDecision(
        assigned: false, experimentId: nil, variantId: nil, branch: nil, payload: [:], variables: [:]
    )

    // MARK: - Typed payload accessors

    public func double(_ key: String, default fallback: Double) -> Double {
        if let n = payload[key] as? Double { return n }
        if let n = payload[key] as? Int { return Double(n) }
        if let s = payload[key] as? String, let n = Double(s) { return n }
        return fallback
    }

    public func int(_ key: String, default fallback: Int) -> Int {
        if let n = payload[key] as? Int { return n }
        if let n = payload[key] as? Double { return Int(n) }
        if let s = payload[key] as? String, let n = Int(s) { return n }
        return fallback
    }

    public func string(_ key: String, default fallback: String) -> String {
        payload[key] as? String ?? fallback
    }

    public func bool(_ key: String, default fallback: Bool) -> Bool {
        payload[key] as? Bool ?? fallback
    }

    /// Convenience for price experiments (`payload["price"]`).
    public var price: Double? {
        if let n = payload["price"] as? Double { return n }
        if let n = payload["price"] as? Int { return Double(n) }
        return nil
    }

    /// Convenience for copy experiments (`payload["copy"]`).
    public var copy: String? { payload["copy"] as? String }
}
