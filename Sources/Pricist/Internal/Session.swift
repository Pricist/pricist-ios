import Foundation

/// Request body for `POST /api/session`. Keys are camelCase to match the
/// backend's session contract (the SDK's `JSONEncoder` applies no key strategy,
/// so the explicit `CodingKeys` below are the literal wire names).
///
/// `anonymousId` / `deviceId` come from `DeviceInfo`; the identifier fields
/// (`idfa`, `*Sha256`, `clickToken`) and `attStatus` come from the SDK's
/// in-memory identity state. The server derives client IP and user-agent, so
/// those are intentionally never sent.
struct SessionRequest: Encodable {
    let anonymousId: String
    let deviceId: String
    let platform: String
    let timestamp: String
    let isFirstSession: Bool
    let sessionId: String?
    let appVersion: String?
    let sdkVersion: String?
    /// Apple Advertising Identifier. The SDK never reads this itself — the host
    /// reads it after ATT consent and passes it via `setIDFA(_:)`.
    let idfa: String?
    /// Deep-link click token (`pricist_click`), claimed from an inbound URL.
    let clickToken: String?
    /// SHA256-hex of normalized email (lowercased, trimmed). Pre-hashed by the
    /// host — the SDK never sees raw PII.
    let emailSha256: String?
    /// SHA256-hex of normalized phone (E.164 format pre-hash).
    let phoneSha256: String?
    /// SHA256-hex of an external user identifier (CRM / auth user ID).
    let externalIdSha256: String?
    /// iOS ATT status: "authorized" | "denied" | "restricted" | "notDetermined".
    let attStatus: String?
    /// Ambient device context. Stored verbatim by the server.
    let context: [String: Any]?

    enum CodingKeys: String, CodingKey {
        case anonymousId
        case deviceId
        case platform
        case timestamp
        case isFirstSession
        case sessionId
        case appVersion
        case sdkVersion
        case idfa
        case clickToken
        case emailSha256
        case phoneSha256
        case externalIdSha256
        case attStatus
        case context
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(anonymousId, forKey: .anonymousId)
        try c.encode(deviceId, forKey: .deviceId)
        try c.encode(platform, forKey: .platform)
        try c.encode(timestamp, forKey: .timestamp)
        try c.encode(isFirstSession, forKey: .isFirstSession)
        try c.encodeIfPresent(sessionId, forKey: .sessionId)
        try c.encodeIfPresent(appVersion, forKey: .appVersion)
        try c.encodeIfPresent(sdkVersion, forKey: .sdkVersion)
        try c.encodeIfPresent(idfa, forKey: .idfa)
        try c.encodeIfPresent(clickToken, forKey: .clickToken)
        try c.encodeIfPresent(emailSha256, forKey: .emailSha256)
        try c.encodeIfPresent(phoneSha256, forKey: .phoneSha256)
        try c.encodeIfPresent(externalIdSha256, forKey: .externalIdSha256)
        try c.encodeIfPresent(attStatus, forKey: .attStatus)
        if let context = context {
            try c.encode(AnyCodable(context), forKey: .context)
        }
    }
}

/// Sanitized attribution result returned by `POST /api/session` and cached in
/// the Keychain. Keys are camelCase to match the server response.
public struct AttributionResult: Codable {
    /// Whether the install was attributed to a paid source.
    public let attributed: Bool
    /// How attribution was determined (e.g. `"deterministic"`, `"probabilistic"`, `"organic"`).
    public let method: String
    /// Ad network the install was attributed to, when known.
    public let adNetwork: String?
    /// Campaign identifier, when known.
    public let campaignId: String?
    /// Server confidence in the attribution, 0.0...1.0.
    public let confidence: Double
    /// Stable identifier for this attribution record, when present.
    public let attributionId: String?

    enum CodingKeys: String, CodingKey {
        case attributed
        case method
        case adNetwork
        case campaignId
        case confidence
        case attributionId
    }
}
