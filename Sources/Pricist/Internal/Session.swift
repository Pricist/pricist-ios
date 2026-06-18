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
    /// SHA256-hex of normalized first name (lowercased, trimmed, punctuation &
    /// whitespace stripped pre-hash). Pre-hashed by the host.
    let firstNameSha256: String?
    /// SHA256-hex of normalized last name (lowercased, trimmed, punctuation &
    /// whitespace stripped pre-hash). Pre-hashed by the host.
    let lastNameSha256: String?
    /// SHA256-hex of normalized city (lowercased, spaces & punctuation removed
    /// pre-hash). Pre-hashed by the host.
    let citySha256: String?
    /// SHA256-hex of normalized 2-letter region/state code (lowercased, e.g.
    /// "ca" pre-hash). Pre-hashed by the host.
    let stateSha256: String?
    /// SHA256-hex of normalized zip/postal code (lowercased; US = first 5 digits
    /// pre-hash). Pre-hashed by the host.
    let zipSha256: String?
    /// SHA256-hex of date of birth in "YYYYMMDD" format pre-hash. Pre-hashed by
    /// the host.
    let dobSha256: String?
    /// SHA256-hex of gender as single char "m"/"f" (lowercased pre-hash).
    /// Pre-hashed by the host.
    let genderSha256: String?
    /// iOS ATT status: "authorized" | "denied" | "restricted" | "notDetermined".
    let attStatus: String?
    /// Physical screen width in pixels (points × scale), for fingerprint match.
    let screenWidth: Int?
    /// Physical screen height in pixels (points × scale), for fingerprint match.
    let screenHeight: Int?
    /// Screen scale (device pixel ratio).
    let screenScale: Double?
    /// Exact hardware model identifier (`hw.machine`), e.g. "iPhone16,2".
    let deviceModel: String?
    /// OS version string, e.g. "17.4.1".
    let osVersion: String?
    /// Device locale identifier, e.g. "en_US".
    let locale: String?
    /// Device timezone identifier, e.g. "America/New_York".
    let timezone: String?
    /// Comma-separated preferred languages, e.g. "en-US,fr-FR".
    let languages: String?
    /// App bundle identifier, e.g. "com.acme.app". For Meta CAPI `extinfo`.
    let bundleId: String?
    /// App build number (CFBundleVersion), e.g. "42".
    let appBuild: String?
    /// Cellular carrier name; best-effort (empty on modern iOS).
    let carrier: String?
    /// Logical CPU core count.
    let cpuCores: Int?
    /// Total disk capacity in GB (integer, decimal GB).
    let totalDiskGb: Int?
    /// Free (available) disk capacity in GB (integer, decimal GB).
    let freeDiskGb: Int?
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
        case firstNameSha256
        case lastNameSha256
        case citySha256
        case stateSha256
        case zipSha256
        case dobSha256
        case genderSha256
        case attStatus
        case screenWidth
        case screenHeight
        case screenScale
        case deviceModel
        case osVersion
        case locale
        case timezone
        case languages
        case bundleId
        case appBuild
        case carrier
        case cpuCores
        case totalDiskGb
        case freeDiskGb
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
        try c.encodeIfPresent(firstNameSha256, forKey: .firstNameSha256)
        try c.encodeIfPresent(lastNameSha256, forKey: .lastNameSha256)
        try c.encodeIfPresent(citySha256, forKey: .citySha256)
        try c.encodeIfPresent(stateSha256, forKey: .stateSha256)
        try c.encodeIfPresent(zipSha256, forKey: .zipSha256)
        try c.encodeIfPresent(dobSha256, forKey: .dobSha256)
        try c.encodeIfPresent(genderSha256, forKey: .genderSha256)
        try c.encodeIfPresent(attStatus, forKey: .attStatus)
        try c.encodeIfPresent(screenWidth, forKey: .screenWidth)
        try c.encodeIfPresent(screenHeight, forKey: .screenHeight)
        try c.encodeIfPresent(screenScale, forKey: .screenScale)
        try c.encodeIfPresent(deviceModel, forKey: .deviceModel)
        try c.encodeIfPresent(osVersion, forKey: .osVersion)
        try c.encodeIfPresent(locale, forKey: .locale)
        try c.encodeIfPresent(timezone, forKey: .timezone)
        try c.encodeIfPresent(languages, forKey: .languages)
        try c.encodeIfPresent(bundleId, forKey: .bundleId)
        try c.encodeIfPresent(appBuild, forKey: .appBuild)
        try c.encodeIfPresent(carrier, forKey: .carrier)
        try c.encodeIfPresent(cpuCores, forKey: .cpuCores)
        try c.encodeIfPresent(totalDiskGb, forKey: .totalDiskGb)
        try c.encodeIfPresent(freeDiskGb, forKey: .freeDiskGb)
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
