import Foundation

/// Configuration options for the Pricist SDK.
public struct PricistConfiguration {

    /// Publishable SDK key for the project. This is the key shown in the
    /// Pricist dashboard under Settings → "SDK key" and is sent on every
    /// request as the `x-pricist-sdk-key` header. It is safe to ship in a
    /// mobile binary (publishable, not secret).
    public let sdkKey: String

    /// Which data environment events belong to: `"production"` or
    /// `"sandbox"`. Defaults to `"production"`. Use `"sandbox"` for debug /
    /// TestFlight builds so test traffic doesn't pollute production metrics.
    public var environment: String

    /// Log level for debugging.
    public var logLevel: LogLevel

    /// Interval between automatic event-queue flushes (in seconds).
    public var flushInterval: TimeInterval

    /// Maximum number of events drained from the local queue per flush
    /// cycle. Pricist's ingest endpoint accepts one event per request, so
    /// the SDK sends a flush batch sequentially; this bounds how many it
    /// sends in a single cycle.
    public var maxBatchSize: Int

    /// Optional override for the API host root. When `nil`, the SDK uses
    /// the production endpoint (`https://api.pricist.dev`). The SDK appends
    /// the path itself (`/api/track`, `/api/sdk/config`), so pass the host
    /// root only — e.g. `http://localhost:3000` from the iOS simulator
    /// pointing at a webapp running on the host machine. Trailing slashes
    /// are stripped.
    public var host: String?

    /// Whether the SDK starts its active components (flush timer, lifecycle
    /// observers, automatic Install/app_open events, remote config fetch)
    /// immediately when `initialize(with:)` is called.
    ///
    /// Defaults to `true`. Set to `false` when you need to defer the SDK's
    /// network and event activity until you have obtained user consent
    /// (e.g., ATT, GDPR). When `false`, you must call
    /// `Pricist.shared.start()` after consent is granted.
    public var autoStart: Bool

    /// Whether the SDK should defer its first event flush until the user has
    /// responded to the iOS App Tracking Transparency prompt.
    ///
    /// Defaults to `false` (no waiting — the SDK starts immediately and reads
    /// the live ATT status into each event's context). When `true`, `start()`
    /// enters a waiting state until ATT is determined; events tracked while
    /// waiting are buffered and flushed once the user responds.
    ///
    /// No-op on platforms without `AppTrackingTransparency` (watchOS).
    public var waitForATTAuthorization: Bool

    /// Log level options.
    public enum LogLevel: Int, Comparable {
        case none = 0
        case error = 1
        case warning = 2
        case info = 3
        case debug = 4
        case verbose = 5

        public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    /// Initialize configuration with the project's publishable SDK key.
    /// - Parameter sdkKey: Publishable SDK key from the Pricist dashboard.
    public init(sdkKey: String) {
        self.sdkKey = sdkKey
        self.environment = "production"
        self.logLevel = .none
        self.flushInterval = 30.0
        self.maxBatchSize = 100
        self.host = nil
        self.autoStart = true
        self.waitForATTAuthorization = false
    }
}

// MARK: - Builder Pattern

public extension PricistConfiguration {

    /// Set the data environment (`"production"` or `"sandbox"`).
    func with(environment: String) -> PricistConfiguration {
        var config = self
        let trimmed = environment.trimmingCharacters(in: .whitespacesAndNewlines)
        config.environment = trimmed.isEmpty ? "production" : trimmed
        return config
    }

    /// Set log level.
    func with(logLevel: LogLevel) -> PricistConfiguration {
        var config = self
        config.logLevel = logLevel
        return config
    }

    /// Set flush interval (clamped to a 1s minimum).
    func with(flushInterval: TimeInterval) -> PricistConfiguration {
        var config = self
        config.flushInterval = max(1.0, flushInterval)
        return config
    }

    /// Set max flush batch size (clamped to 1...500).
    func with(maxBatchSize: Int) -> PricistConfiguration {
        var config = self
        config.maxBatchSize = min(500, max(1, maxBatchSize))
        return config
    }

    /// Override the API host root. Pass the host without a path
    /// (e.g. `http://localhost:3000` from the iOS simulator pointing at a
    /// webapp on the host machine). Trailing slashes are trimmed.
    func with(host: String?) -> PricistConfiguration {
        var config = self
        if let url = host {
            var trimmed = url
            while trimmed.hasSuffix("/") {
                trimmed.removeLast()
            }
            config.host = trimmed.isEmpty ? nil : trimmed
        } else {
            config.host = nil
        }
        return config
    }

    /// Configure whether the SDK starts automatically on `initialize(with:)`.
    /// Pass `false` to defer all network activity and event tracking until
    /// `Pricist.shared.start()` is called.
    func with(autoStart: Bool) -> PricistConfiguration {
        var config = self
        config.autoStart = autoStart
        return config
    }

    /// Defer the first event flush until the user has responded to the iOS
    /// ATT prompt. The host must eventually call
    /// `Pricist.shared.requestTrackingAuthorization { ... }` (or the
    /// underlying `ATTrackingManager` API) or the SDK waits indefinitely.
    func with(waitForATTAuthorization: Bool) -> PricistConfiguration {
        var config = self
        config.waitForATTAuthorization = waitForATTAuthorization
        return config
    }
}
