import Foundation

// MARK: - Standard Events

public extension Pricist {

    /// Standard event names for common actions. Names mirror Meta/TikTok
    /// Standard Events verbatim so the attribution / postback layer (added
    /// later) needs no translation. `Install` and `ActivateApp` are mobile
    /// lifecycle events fired automatically by `initialize(with:)`.
    enum StandardEvent {
        public static let install = "Install"
        public static let activateApp = "ActivateApp"
        public static let pageView = "PageView"
        public static let viewContent = "ViewContent"
        public static let search = "Search"
        public static let addToCart = "AddToCart"
        public static let addToWishlist = "AddToWishlist"
        public static let initiateCheckout = "InitiateCheckout"
        public static let addPaymentInfo = "AddPaymentInfo"
        public static let purchase = "Purchase"
        public static let lead = "Lead"
        public static let completeRegistration = "CompleteRegistration"
        public static let contact = "Contact"
        public static let schedule = "Schedule"
        public static let findLocation = "FindLocation"
        public static let customizeProduct = "CustomizeProduct"
        public static let donate = "Donate"
        public static let submitApplication = "SubmitApplication"
        public static let applicationApproval = "ApplicationApproval"
        public static let download = "Download"
        public static let submitForm = "SubmitForm"
        public static let startTrial = "StartTrial"
        public static let subscribe = "Subscribe"
        public static let achieveLevel = "AchieveLevel"
        public static let unlockAchievement = "UnlockAchievement"
        public static let spentCredits = "SpentCredits"
        public static let rate = "Rate"
        public static let completeTutorial = "CompleteTutorial"
        public static let inAppAdClick = "InAppAdClick"
        public static let inAppAdImpression = "InAppAdImpression"
    }

    // MARK: - Typed Standard Event Methods

    /// Meta only — fires on every page load.
    func trackPageView(parameters: PricistEventParameters? = nil, dimensions: PricistEventDimensions? = nil) {
        trackEvent(StandardEvent.pageView, revenue: nil, parameters: parameters, dimensions: dimensions)
    }

    /// Meta + TikTok — visit to a product, landing, or content page.
    func trackViewContent(parameters: PricistEventParameters? = nil, dimensions: PricistEventDimensions? = nil) {
        trackEvent(StandardEvent.viewContent, revenue: nil, parameters: parameters, dimensions: dimensions)
    }

    /// Meta + TikTok — search performed.
    func trackSearch(parameters: PricistEventParameters? = nil, dimensions: PricistEventDimensions? = nil) {
        trackEvent(StandardEvent.search, revenue: nil, parameters: parameters, dimensions: dimensions)
    }

    /// Meta + TikTok — item added to cart.
    func trackAddToCart(parameters: PricistEventParameters? = nil, dimensions: PricistEventDimensions? = nil) {
        trackEvent(StandardEvent.addToCart, revenue: nil, parameters: parameters, dimensions: dimensions)
    }

    /// Meta + TikTok — item added to wishlist.
    func trackAddToWishlist(parameters: PricistEventParameters? = nil, dimensions: PricistEventDimensions? = nil) {
        trackEvent(StandardEvent.addToWishlist, revenue: nil, parameters: parameters, dimensions: dimensions)
    }

    /// Meta + TikTok — start of checkout process.
    func trackInitiateCheckout(parameters: PricistEventParameters? = nil, dimensions: PricistEventDimensions? = nil) {
        trackEvent(StandardEvent.initiateCheckout, revenue: nil, parameters: parameters, dimensions: dimensions)
    }

    /// Meta + TikTok — payment info entered during checkout.
    func trackAddPaymentInfo(parameters: PricistEventParameters? = nil, dimensions: PricistEventDimensions? = nil) {
        trackEvent(StandardEvent.addPaymentInfo, revenue: nil, parameters: parameters, dimensions: dimensions)
    }

    /// Meta + TikTok — purchase completed; value and currency are required.
    func trackPurchase(value: Double, currency: String, parameters: PricistEventParameters? = nil, dimensions: PricistEventDimensions? = nil) {
        trackEvent(StandardEvent.purchase, revenue: PricistRevenue(amount: value, currency: currency), parameters: parameters, dimensions: dimensions)
    }

    /// Meta + TikTok — user submits contact information.
    func trackLead(parameters: PricistEventParameters? = nil, dimensions: PricistEventDimensions? = nil) {
        trackEvent(StandardEvent.lead, revenue: nil, parameters: parameters, dimensions: dimensions)
    }

    /// Meta + TikTok — user completes a registration / sign-up flow.
    func trackCompleteRegistration(parameters: PricistEventParameters? = nil, dimensions: PricistEventDimensions? = nil) {
        trackEvent(StandardEvent.completeRegistration, revenue: nil, parameters: parameters, dimensions: dimensions)
    }

    /// Meta + TikTok — any contact initiated between user and business.
    func trackContact(parameters: PricistEventParameters? = nil, dimensions: PricistEventDimensions? = nil) {
        trackEvent(StandardEvent.contact, revenue: nil, parameters: parameters, dimensions: dimensions)
    }

    /// Meta + TikTok — user books an appointment or reservation.
    func trackSchedule(parameters: PricistEventParameters? = nil, dimensions: PricistEventDimensions? = nil) {
        trackEvent(StandardEvent.schedule, revenue: nil, parameters: parameters, dimensions: dimensions)
    }

    /// Meta + TikTok — user searches for a physical business location.
    func trackFindLocation(parameters: PricistEventParameters? = nil, dimensions: PricistEventDimensions? = nil) {
        trackEvent(StandardEvent.findLocation, revenue: nil, parameters: parameters, dimensions: dimensions)
    }

    /// Meta + TikTok — user customizes a product.
    func trackCustomizeProduct(parameters: PricistEventParameters? = nil, dimensions: PricistEventDimensions? = nil) {
        trackEvent(StandardEvent.customizeProduct, revenue: nil, parameters: parameters, dimensions: dimensions)
    }

    /// Meta only — donation completed; value and currency are required.
    func trackDonate(value: Double, currency: String, parameters: PricistEventParameters? = nil, dimensions: PricistEventDimensions? = nil) {
        trackEvent(StandardEvent.donate, revenue: PricistRevenue(amount: value, currency: currency), parameters: parameters, dimensions: dimensions)
    }

    /// Meta + TikTok — user submits an application.
    func trackSubmitApplication(parameters: PricistEventParameters? = nil, dimensions: PricistEventDimensions? = nil) {
        trackEvent(StandardEvent.submitApplication, revenue: nil, parameters: parameters, dimensions: dimensions)
    }

    /// TikTok only — application previously submitted is approved.
    func trackApplicationApproval(parameters: PricistEventParameters? = nil, dimensions: PricistEventDimensions? = nil) {
        trackEvent(StandardEvent.applicationApproval, revenue: nil, parameters: parameters, dimensions: dimensions)
    }

    /// TikTok only — user downloads a file or asset.
    func trackDownload(parameters: PricistEventParameters? = nil, dimensions: PricistEventDimensions? = nil) {
        trackEvent(StandardEvent.download, revenue: nil, parameters: parameters, dimensions: dimensions)
    }

    /// TikTok legacy — use `trackLead()` for new implementations.
    func trackSubmitForm(parameters: PricistEventParameters? = nil, dimensions: PricistEventDimensions? = nil) {
        trackEvent(StandardEvent.submitForm, revenue: nil, parameters: parameters, dimensions: dimensions)
    }

    /// Meta + TikTok — user begins a free trial; value and currency are required.
    func trackStartTrial(value: Double, currency: String, parameters: PricistEventParameters? = nil, dimensions: PricistEventDimensions? = nil) {
        trackEvent(StandardEvent.startTrial, revenue: PricistRevenue(amount: value, currency: currency), parameters: parameters, dimensions: dimensions)
    }

    /// Meta + TikTok — user starts a paid subscription; value and currency are required.
    func trackSubscribe(value: Double, currency: String, parameters: PricistEventParameters? = nil, dimensions: PricistEventDimensions? = nil) {
        trackEvent(StandardEvent.subscribe, revenue: PricistRevenue(amount: value, currency: currency), parameters: parameters, dimensions: dimensions)
    }

    /// Meta only — user reaches a level in your app or game.
    func trackAchieveLevel(parameters: PricistEventParameters? = nil, dimensions: PricistEventDimensions? = nil) {
        trackEvent(StandardEvent.achieveLevel, revenue: nil, parameters: parameters, dimensions: dimensions)
    }

    /// Meta only — user completes a rewarded action or milestone.
    func trackUnlockAchievement(parameters: PricistEventParameters? = nil, dimensions: PricistEventDimensions? = nil) {
        trackEvent(StandardEvent.unlockAchievement, revenue: nil, parameters: parameters, dimensions: dimensions)
    }

    /// Meta only — user spends in-app credits / virtual currency; value is
    /// required. Value is passed as a parameter (not revenue) because virtual
    /// currency has no ISO 4217 code.
    func trackSpentCredits(value: Double, parameters: PricistEventParameters? = nil, dimensions: PricistEventDimensions? = nil) {
        var params = parameters ?? PricistEventParameters()
        params.set("value", value: value)
        trackEvent(StandardEvent.spentCredits, revenue: nil, parameters: params, dimensions: dimensions)
    }

    /// Meta only — user submits a rating.
    func trackRate(parameters: PricistEventParameters? = nil, dimensions: PricistEventDimensions? = nil) {
        trackEvent(StandardEvent.rate, revenue: nil, parameters: parameters, dimensions: dimensions)
    }

    /// Meta only — user completes an in-app tutorial.
    func trackCompleteTutorial(parameters: PricistEventParameters? = nil, dimensions: PricistEventDimensions? = nil) {
        trackEvent(StandardEvent.completeTutorial, revenue: nil, parameters: parameters, dimensions: dimensions)
    }

    /// First-launch install event. Fired automatically by `initialize(with:)`
    /// on the device's first ever launch.
    func trackInstall(parameters: PricistEventParameters? = nil, dimensions: PricistEventDimensions? = nil) {
        trackEvent(StandardEvent.install, revenue: nil, parameters: parameters, dimensions: dimensions)
    }

    /// App launch / activate. Fired automatically by `initialize(with:)` on
    /// every cold start.
    func trackActivateApp(parameters: PricistEventParameters? = nil, dimensions: PricistEventDimensions? = nil) {
        trackEvent(StandardEvent.activateApp, revenue: nil, parameters: parameters, dimensions: dimensions)
    }

    /// Meta only — in-app ad clicked by user.
    func trackInAppAdClick(parameters: PricistEventParameters? = nil, dimensions: PricistEventDimensions? = nil) {
        trackEvent(StandardEvent.inAppAdClick, revenue: nil, parameters: parameters, dimensions: dimensions)
    }

    /// Meta only — in-app ad appeared on-screen.
    func trackInAppAdImpression(parameters: PricistEventParameters? = nil, dimensions: PricistEventDimensions? = nil) {
        trackEvent(StandardEvent.inAppAdImpression, revenue: nil, parameters: parameters, dimensions: dimensions)
    }
}
