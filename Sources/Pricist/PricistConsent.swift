import Foundation

/// Per-user consent state for GDPR / DMA compliance.
///
/// Pass to `Pricist.shared.setConsent(_:)` to inform the SDK of the user's
/// consent decisions. The four fields mirror Google Consent Mode v2 so values
/// map 1:1 to ad-network requirements when attribution is added later.
///
/// When `isUserSubjectToGDPR == true` and `hasConsentForDataUsage == false`,
/// the SDK stops dispatching new events and clears any pending queue. When
/// `isUserSubjectToGDPR == false`, the per-dimension fields are advisory only;
/// the SDK tracks normally. The current consent state is attached to every
/// event's `context` so the backend has it on record.
public struct PricistConsent {

    /// Whether the user is subject to GDPR (typically true for EEA users).
    /// When `false`, the SDK ignores the per-dimension flags and tracks
    /// normally.
    public var isUserSubjectToGDPR: Bool

    /// Whether the user granted consent for data usage (analytics,
    /// attribution). When `false` and `isUserSubjectToGDPR == true`, the SDK
    /// stops sending events and clears the local queue.
    public var hasConsentForDataUsage: Bool?

    /// Whether the user granted consent for personalized ads. Forwarded to ad
    /// networks (Google `ad_personalization`). Does not gate dispatch.
    public var hasConsentForAdsPersonalization: Bool?

    /// Whether the user granted consent for ad-related storage (cookies,
    /// IDFA-style identifiers). Forwarded to ad networks (Google `ad_storage`).
    /// Does not gate dispatch.
    public var hasConsentForAdStorage: Bool?

    public init(
        isUserSubjectToGDPR: Bool,
        hasConsentForDataUsage: Bool? = nil,
        hasConsentForAdsPersonalization: Bool? = nil,
        hasConsentForAdStorage: Bool? = nil
    ) {
        self.isUserSubjectToGDPR = isUserSubjectToGDPR
        self.hasConsentForDataUsage = hasConsentForDataUsage
        self.hasConsentForAdsPersonalization = hasConsentForAdsPersonalization
        self.hasConsentForAdStorage = hasConsentForAdStorage
    }

    /// True when the SDK must stop dispatching: GDPR applies and the user has
    /// affirmatively denied data-usage consent. A `nil` data-usage flag is
    /// treated as "not yet answered" and does not block dispatch (matches the
    /// SDK's "track-by-default unless told otherwise" model).
    var blocksDispatch: Bool {
        isUserSubjectToGDPR && hasConsentForDataUsage == false
    }

    /// Flattened representation attached to each event's `context.consent`.
    var contextDictionary: [String: Any] {
        var dict: [String: Any] = ["is_user_subject_to_gdpr": isUserSubjectToGDPR]
        if let v = hasConsentForDataUsage { dict["has_consent_for_data_usage"] = v }
        if let v = hasConsentForAdsPersonalization { dict["has_consent_for_ads_personalization"] = v }
        if let v = hasConsentForAdStorage { dict["has_consent_for_ad_storage"] = v }
        return dict
    }
}
