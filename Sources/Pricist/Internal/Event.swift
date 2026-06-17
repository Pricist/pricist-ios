import Foundation

/// A single Pricist event. This is both the on-the-wire request body for
/// `POST /api/track` and the unit persisted in the local queue, so identity
/// and all dimensions are snapshotted at capture time — a replayed event
/// keeps the identity/context it was tracked with.
///
/// Keys are camelCase to match the backend's `TrackEventInput`
/// (`normalizeTrackEvent`). `eventId` MUST be a UUID and `timestamp` a valid
/// date — both are validated server-side and used for idempotent dedup, so a
/// 503-retry of the same event is safe.
struct PricistEvent {
    let eventId: String
    let eventName: String
    let timestamp: String
    let anonymousId: String
    let userId: String?
    let deviceId: String
    let appVersion: String
    let sdkVersion: String
    let sessionId: String?
    let environment: String
    let country: String?
    let context: [String: Any]
    let properties: [String: Any]

    // Subscription / paywall dimensions (first-class columns in Pricist).
    let productId: String?
    let offeringId: String?
    let paywallId: String?
    let experimentId: String?
    let variantId: String?
    let entitlementId: String?
    let placement: String?

    // Revenue (decimal strings; the backend re-parses to fixed precision).
    let revenueAmount: String?
    let revenueCurrency: String?
    let revenueUsd: String?
    let revenuecatUserId: String?
}

extension PricistEvent: Codable {
    enum CodingKeys: String, CodingKey {
        case eventId, eventName, timestamp, anonymousId, userId, deviceId
        case appVersion, sdkVersion, sessionId, environment, country
        case context, properties
        case productId, offeringId, paywallId, experimentId, variantId
        case entitlementId, placement
        case revenueAmount, revenueCurrency, revenueUsd, revenuecatUserId
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(eventId, forKey: .eventId)
        try c.encode(eventName, forKey: .eventName)
        try c.encode(timestamp, forKey: .timestamp)
        try c.encode(anonymousId, forKey: .anonymousId)
        try c.encodeIfPresent(nonEmpty(userId), forKey: .userId)
        try c.encode(deviceId, forKey: .deviceId)
        try c.encode(appVersion, forKey: .appVersion)
        try c.encode(sdkVersion, forKey: .sdkVersion)
        try c.encodeIfPresent(nonEmpty(sessionId), forKey: .sessionId)
        try c.encode(environment, forKey: .environment)
        try c.encodeIfPresent(nonEmpty(country), forKey: .country)
        try c.encode(AnyCodable(context), forKey: .context)
        try c.encode(AnyCodable(properties), forKey: .properties)
        try c.encodeIfPresent(nonEmpty(productId), forKey: .productId)
        try c.encodeIfPresent(nonEmpty(offeringId), forKey: .offeringId)
        try c.encodeIfPresent(nonEmpty(paywallId), forKey: .paywallId)
        try c.encodeIfPresent(nonEmpty(experimentId), forKey: .experimentId)
        try c.encodeIfPresent(nonEmpty(variantId), forKey: .variantId)
        try c.encodeIfPresent(nonEmpty(entitlementId), forKey: .entitlementId)
        try c.encodeIfPresent(nonEmpty(placement), forKey: .placement)
        try c.encodeIfPresent(nonEmpty(revenueAmount), forKey: .revenueAmount)
        try c.encodeIfPresent(nonEmpty(revenueCurrency), forKey: .revenueCurrency)
        try c.encodeIfPresent(nonEmpty(revenueUsd), forKey: .revenueUsd)
        try c.encodeIfPresent(nonEmpty(revenuecatUserId), forKey: .revenuecatUserId)
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        eventId = try c.decode(String.self, forKey: .eventId)
        eventName = try c.decode(String.self, forKey: .eventName)
        timestamp = try c.decode(String.self, forKey: .timestamp)
        anonymousId = try c.decode(String.self, forKey: .anonymousId)
        userId = try c.decodeIfPresent(String.self, forKey: .userId)
        deviceId = try c.decode(String.self, forKey: .deviceId)
        appVersion = try c.decode(String.self, forKey: .appVersion)
        sdkVersion = try c.decode(String.self, forKey: .sdkVersion)
        sessionId = try c.decodeIfPresent(String.self, forKey: .sessionId)
        environment = try c.decode(String.self, forKey: .environment)
        country = try c.decodeIfPresent(String.self, forKey: .country)
        context = (try c.decodeIfPresent(AnyCodable.self, forKey: .context))?.value as? [String: Any] ?? [:]
        properties = (try c.decodeIfPresent(AnyCodable.self, forKey: .properties))?.value as? [String: Any] ?? [:]
        productId = try c.decodeIfPresent(String.self, forKey: .productId)
        offeringId = try c.decodeIfPresent(String.self, forKey: .offeringId)
        paywallId = try c.decodeIfPresent(String.self, forKey: .paywallId)
        experimentId = try c.decodeIfPresent(String.self, forKey: .experimentId)
        variantId = try c.decodeIfPresent(String.self, forKey: .variantId)
        entitlementId = try c.decodeIfPresent(String.self, forKey: .entitlementId)
        placement = try c.decodeIfPresent(String.self, forKey: .placement)
        revenueAmount = try c.decodeIfPresent(String.self, forKey: .revenueAmount)
        revenueCurrency = try c.decodeIfPresent(String.self, forKey: .revenueCurrency)
        revenueUsd = try c.decodeIfPresent(String.self, forKey: .revenueUsd)
        revenuecatUserId = try c.decodeIfPresent(String.self, forKey: .revenuecatUserId)
    }
}

private func nonEmpty(_ value: String?) -> String? {
    guard let value = value, !value.isEmpty else { return nil }
    return value
}

/// Wrapper for encoding/decoding heterogeneous JSON (`context`, `properties`).
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}
