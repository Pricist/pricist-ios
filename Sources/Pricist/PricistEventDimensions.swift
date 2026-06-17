import Foundation

/// First-class subscription / paywall dimensions for an event. These map to
/// dedicated columns in Pricist (not the generic `properties` bag), so the
/// dashboard can group, filter, and build funnels on them directly.
///
/// All fields are optional — set only the ones relevant to the event. Pass an
/// instance to any `track…` method via the `dimensions:` argument.
public struct PricistEventDimensions {

    /// Store product identifier (e.g. App Store product ID).
    public var productId: String?

    /// Offering / package group the product belongs to.
    public var offeringId: String?

    /// Paywall the event was triggered from.
    public var paywallId: String?

    /// Experiment this user is enrolled in.
    public var experimentId: String?

    /// Variant of the experiment shown to this user.
    public var variantId: String?

    /// Entitlement granted / referenced by the event.
    public var entitlementId: String?

    /// Where in the app the event occurred (e.g. "onboarding", "settings").
    public var placement: String?

    public init(
        productId: String? = nil,
        offeringId: String? = nil,
        paywallId: String? = nil,
        experimentId: String? = nil,
        variantId: String? = nil,
        entitlementId: String? = nil,
        placement: String? = nil
    ) {
        self.productId = productId
        self.offeringId = offeringId
        self.paywallId = paywallId
        self.experimentId = experimentId
        self.variantId = variantId
        self.entitlementId = entitlementId
        self.placement = placement
    }
}
