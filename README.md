# Pricist iOS SDK

The Pricist SDK for iOS, macOS, tvOS, and watchOS. Send subscription, paywall,
and revenue events to Pricist with a stable identity, queued and retried
offline. The event taxonomy mirrors the Meta/TikTok standard events, so
attribution can be layered on later without changing your call sites.

## Installation

### Swift Package Manager

In Xcode: **File → Add Package Dependencies…** and enter
`https://github.com/Pricist/pricist-ios`, or add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Pricist/pricist-ios", from: "0.1.0")
]
```

Then add `Pricist` to your target dependencies:

```swift
.target(name: "MyApp", dependencies: ["Pricist"])
```

> The SDK product/module is `Pricist`.

## Quick Start

```swift
import Pricist

// In your App init or AppDelegate
let config = PricistConfiguration(sdkKey: "pk_live_…")  // from Settings → SDK key
Pricist.shared.initialize(with: config)

// Track events anywhere
Pricist.shared.trackPurchase(value: 29.99, currency: "USD")
Pricist.shared.flush()  // optional; the SDK also auto-flushes
```

### SwiftUI

```swift
@main
struct MyApp: App {
    init() {
        Pricist.shared.initialize(with: PricistConfiguration(sdkKey: "pk_live_…"))
    }
    var body: some Scene { WindowGroup { ContentView() } }
}
```

On the first launch the SDK automatically fires an `Install` event, and an
`ActivateApp` event on every cold start.

## Configuration

```swift
let config = PricistConfiguration(sdkKey: "pk_live_…")
    .with(environment: "sandbox")        // "production" (default) or "sandbox"
    .with(logLevel: .debug)              // .none, .error, .warning, .info, .debug, .verbose
    .with(flushInterval: 30.0)           // auto-flush seconds (min 1.0, default 30.0)
    .with(maxBatchSize: 100)             // events drained per flush cycle (1–500)
    .with(host: "http://localhost:3000") // override API host for local dev
    .with(autoStart: false)              // defer start() until you have consent
    .with(waitForATTAuthorization: true) // defer first flush until ATT is answered
```

### API host

By default the SDK calls `https://api.pricist.com` and appends `/api/track`
and `/api/sdk/config`. Pass `host` to point at a different origin — typically a
webapp running on your dev machine. From the iOS simulator, `localhost` is the
host machine:

```swift
let config = PricistConfiguration(sdkKey: "pk_test_…")
    .with(host: "http://localhost:3000")
```

Pass the **host root only** (no path, no trailing slash).

## Event Tracking

### Standard events (recommended)

Typed methods cover the full Meta/TikTok standard-event taxonomy. Revenue
events require `value` and `currency`:

```swift
// Subscription lifecycle
Pricist.shared.trackStartTrial(value: 0, currency: "USD")
Pricist.shared.trackSubscribe(value: 9.99, currency: "USD")
Pricist.shared.trackPurchase(value: 29.99, currency: "USD")

// Engagement / commerce / lead-gen / app events
Pricist.shared.trackViewContent()
Pricist.shared.trackAddToCart()
Pricist.shared.trackCompleteRegistration()
Pricist.shared.trackCompleteTutorial()
```

### Subscription dimensions

Attach first-class dimensions (stored as dedicated columns, not buried in
`properties`) so the dashboard can group and build funnels on them:

```swift
let dims = PricistEventDimensions(
    productId: "com.app.premium.annual",
    offeringId: "default",
    paywallId: "onboarding_v2",
    experimentId: "exp_ltv_max",
    variantId: "variant_a",
    entitlementId: "premium",
    placement: "onboarding"
)

Pricist.shared.trackPurchase(value: 29.99, currency: "USD", dimensions: dims)
```

### Custom events + properties

```swift
// Simple
Pricist.shared.trackEvent("onboarding_complete")

// With properties (the `properties` bag)
var params = PricistEventParameters()
params.set("step", value: 3)
params.set("variant", value: "B")
Pricist.shared.trackEvent("paywall_viewed", parameters: params)

// Dictionary literal
Pricist.shared.trackEvent("paywall_viewed", parameters: ["step": 3, "variant": "B"])

// With revenue + properties + dimensions
Pricist.shared.trackEvent(
    "tip_sent",
    revenue: .usd(4.99),
    parameters: ["recipient": "user_456"],
    dimensions: PricistEventDimensions(placement: "creator_profile")
)
```

## Identity

```swift
Pricist.shared.setUserId("user_123")            // attached to subsequent events
Pricist.shared.setUserProperties(["plan": "pro"]) // merged into context
Pricist.shared.clearUserId()                     // on logout
```

Until `setUserId` is called, events carry a stable per-install `anonymousId`.
The backend resolves identity as `userId` if present, else `anonymousId`.

## Remote Config (Feature Flags)

Read the project's feature flags at runtime (fetched on `start()`, cached for
5 minutes, served from cache offline):

```swift
let headline: String = Pricist.shared.getConfig("paywall_header", default: "Go Premium")
let showBanner: Bool = Pricist.shared.getConfig("show_banner", default: false)

Pricist.shared.onConfigLoaded { config in
    // config is [String: Any] with typed values (string/number/bool/json)
}
```

## Consent & ATT

```swift
// GDPR / DMA — when GDPR applies and data-usage consent is denied, the SDK
// stops dispatching and purges the queue. Otherwise consent rides on events.
Pricist.shared.setConsent(PricistConsent(
    isUserSubjectToGDPR: true,
    hasConsentForDataUsage: true
))

// App Tracking Transparency — requires NSUserTrackingUsageDescription in Info.plist
Pricist.shared.requestTrackingAuthorization { status in /* … */ }
```

When you set `waitForATTAuthorization: true`, `start()` buffers events until the
user answers the prompt, then flushes. The live ATT status is attached to every
event's `context`.

### Attribution-ready

The standard-event names match Meta/TikTok verbatim, and identifiers you supply
(`setIDFA`, `setHashedEmail`, `setHashedPhone`, `setHashedExternalId`) plus ATT
and consent state are attached to each event's `context`. When the attribution
layer is added server-side, it can consume these from the event stream without
an SDK change.

## SDK Control

```swift
Pricist.shared.setEnabled(false)  // disable all tracking
Pricist.shared.flush()            // force-send queued events
```

## Validation

**Event names**: non-empty, ≤100 chars, matching `^[a-zA-Z][a-zA-Z0-9_]*$`
(start with a letter; letters, numbers, underscores). Invalid names are logged
and dropped.

**Currency**: 3-letter ISO 4217, auto-uppercased.

Errors are logged (prefix `[Pricist]`), never thrown. Set `logLevel: .debug` to
see them.

## How events are delivered

- Each `track…` call snapshots identity + dimensions and enqueues one event.
- The queue persists to `UserDefaults` and survives app restarts.
- Flushes POST one event per request to `/api/track`; `eventId` (a UUID) +
  `timestamp` make ingest idempotent, so retries are safe.
- Successfully-sent events are removed; retryable failures (network/5xx/429)
  are kept and retried; permanent failures (4xx/auth) are dropped so the queue
  can't wedge.

## Requirements

- iOS 14.0+ / macOS 12.0+ / tvOS 14.0+ / watchOS 7.0+
- Swift 5.9+, Xcode 15+

## License

MIT
