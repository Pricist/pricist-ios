import Foundation
#if canImport(UIKit) && !os(watchOS)
import UIKit
#endif

/// Callback type for remote-config loaded events.
public typealias ConfigLoadedCallback = ([String: Any]) -> Void

/// Main entry point for the Pricist SDK.
///
/// Send subscription / paywall / revenue events to Pricist with a stable
/// identity, queued and retried offline. The event taxonomy mirrors the
/// Meta/TikTok standard events so attribution can be layered on later without
/// changing call sites.
public final class Pricist {

    /// Shared singleton instance.
    public static let shared = Pricist()

    /// SDK version, sent on every event as `sdkVersion`.
    public static let sdkVersion = "0.1.0"

    private var configuration: PricistConfiguration?
    private var isEnabled = true
    private var isStarted = false
    private let eventQueue: EventQueue
    private let networkClient: NetworkClient
    private let deviceInfo: DeviceInfo

    /// Per-launch session identifier, attached to every event tracked during
    /// this process lifetime.
    private var sessionId: String?

    private var flushTimer: DispatchSourceTimer?
    private var lifecycleObservers: [NSObjectProtocol] = []

    // MARK: - Mutable identity / config state
    //
    // Guarded by `stateLock`; snapshotted under lock when building an event.
    private let stateLock = NSLock()
    private var userId: String?
    private var userProperties: [String: Any]?
    private var remoteConfig: [String: Any]?

    // Attribution signals — stored in memory and attached to each event's
    // `context.attribution` so the attribution layer (added later) can consume
    // them from the event stream. IDFA is never persisted (ATT can be revoked).
    private var idfa: String?
    private var hashedEmail: String?
    private var hashedPhone: String?
    private var hashedExternalId: String?

    // Consent: nil until the host calls setConsent. When nil, the SDK tracks
    // normally (opt-in / track-by-default model).
    private var consent: PricistConsent?

    private var configCallbacks: [ConfigLoadedCallback] = []

    // MARK: - ATT wait state
    private var isWaitingForATT = false
    private var attWaitObserver: NSObjectProtocol?

    private static let userIdKey = "com.pricist.userId"
    private static let installedKey = "com.pricist.installed"
    private static let configKey = "com.pricist.config"
    private static let configTimestampKey = "com.pricist.config.ts"
    private static let configCacheTTL: TimeInterval = 300 // 5 minutes

    private init() {
        self.eventQueue = EventQueue()
        self.networkClient = NetworkClient()
        self.deviceInfo = DeviceInfo()
    }

    // MARK: - Initialization

    /// Initialize the SDK with configuration.
    ///
    /// When `configuration.autoStart` is `true` (the default), this also calls
    /// `start()` to begin the flush timer, lifecycle observers, remote-config
    /// fetch, and the automatic Install / app-open events.
    ///
    /// When `autoStart` is `false`, this only wires up internal state (no
    /// network activity). Call `start()` once you have any required consent.
    public func initialize(with configuration: PricistConfiguration) {
        guard self.configuration == nil else {
            Logger.warning("Pricist already initialized")
            return
        }

        self.configuration = configuration
        Logger.logLevel = configuration.logLevel
        Logger.info("Pricist initialized (env=\(configuration.environment))")

        restoreUserId()
        loadCachedConfig()

        if configuration.autoStart {
            start()
        } else {
            Logger.info("autoStart disabled — call Pricist.shared.start() when ready")
        }
    }

    /// Start the SDK's active components: flush timer, lifecycle observers,
    /// remote-config fetch, and the automatic Install / app-open events.
    ///
    /// Called automatically by `initialize(with:)` when `autoStart` is `true`.
    public func start() {
        guard let configuration = configuration else {
            Logger.error("Pricist not initialized. Call initialize(with:) first.")
            return
        }
        guard !isStarted else {
            Logger.warning("Pricist already started")
            return
        }
        guard !isWaitingForATT else {
            Logger.warning("Pricist already waiting for ATT — call requestTrackingAuthorization to advance")
            return
        }

        if configuration.waitForATTAuthorization && !isATTDetermined() {
            Logger.info("Waiting for ATT authorization before starting")
            beginATTWait()
            return
        }

        actuallyStart()
    }

    private func actuallyStart() {
        guard let configuration = configuration else { return }
        isStarted = true
        sessionId = UUID().uuidString

        fetchRemoteConfig()
        startFlushTimer(interval: configuration.flushInterval)
        registerLifecycleObservers()

        let defaults = UserDefaults.standard
        let isFirstLaunch = !defaults.bool(forKey: Self.installedKey)
        if isFirstLaunch {
            defaults.set(true, forKey: Self.installedKey)
            trackInstall()
            var launchParams = PricistEventParameters()
            launchParams.set("is_first_session", value: true)
            trackActivateApp(parameters: launchParams)
        } else {
            trackActivateApp()
        }
    }

    // MARK: - ATT wait

    private func beginATTWait() {
        isWaitingForATT = true
        #if canImport(UIKit) && !os(watchOS)
        attWaitObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleATTDetermined()
        }
        #endif
    }

    /// Called when ATT may have transitioned out of `.notDetermined`. If we
    /// were waiting and the status is now resolved, tear down the wait observer
    /// and run the deferred `actuallyStart()`.
    func handleATTDetermined() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            guard self.isWaitingForATT else { return }
            guard self.isATTDetermined() else { return }

            self.isWaitingForATT = false
            if let observer = self.attWaitObserver {
                NotificationCenter.default.removeObserver(observer)
                self.attWaitObserver = nil
            }
            self.actuallyStart()
        }
    }

    // MARK: - Event Tracking

    /// Track a custom event.
    public func trackEvent(_ name: String) {
        trackEvent(name, revenue: nil, parameters: nil, dimensions: nil)
    }

    /// Track an event with parameters.
    public func trackEvent(_ name: String, parameters: PricistEventParameters) {
        trackEvent(name, revenue: nil, parameters: parameters, dimensions: nil)
    }

    /// Track a revenue event.
    public func trackEvent(_ name: String, revenue: PricistRevenue) {
        trackEvent(name, revenue: revenue, parameters: nil, dimensions: nil)
    }

    /// Track an event with the full set of optional payload pieces.
    /// - Parameters:
    ///   - name: Event name. Validated `^[a-zA-Z][a-zA-Z0-9_]*$`, ≤100 chars.
    ///   - revenue: Optional revenue (amount + currency).
    ///   - parameters: Optional custom properties (the `properties` bag).
    ///   - dimensions: Optional subscription / paywall dimensions.
    public func trackEvent(
        _ name: String,
        revenue: PricistRevenue? = nil,
        parameters: PricistEventParameters? = nil,
        dimensions: PricistEventDimensions? = nil
    ) {
        guard isEnabled else {
            Logger.debug("Tracking disabled, ignoring event: \(name)")
            return
        }
        guard let configuration = configuration else {
            Logger.error("Pricist not initialized. Call initialize(with:) first.")
            return
        }
        guard isStarted || isWaitingForATT else {
            Logger.debug("Pricist not started, ignoring event: \(name)")
            return
        }

        let snapshot = stateSnapshot()
        if let consent = snapshot.consent, consent.blocksDispatch {
            Logger.debug("Consent blocks dispatch, dropping event: \(name)")
            return
        }

        guard let validatedName = validateEventName(name) else {
            Logger.error("Invalid event name: \(name)")
            return
        }

        let event = makeEvent(
            name: validatedName,
            revenue: revenue,
            parameters: parameters,
            dimensions: dimensions,
            configuration: configuration,
            snapshot: snapshot
        )

        let queueSize = eventQueue.enqueue(event)
        Logger.debug("Event queued: \(validatedName) (queue=\(queueSize))")

        if queueSize >= configuration.maxBatchSize {
            flush()
        }
    }

    private func makeEvent(
        name: String,
        revenue: PricistRevenue?,
        parameters: PricistEventParameters?,
        dimensions: PricistEventDimensions?,
        configuration: PricistConfiguration,
        snapshot: StateSnapshot
    ) -> PricistEvent {
        var context = deviceInfo.contextDictionary()
        if let att = currentATTStatusString() { context["att_status"] = att }
        if let consent = snapshot.consent { context["consent"] = consent.contextDictionary }
        if let props = snapshot.userProperties { context["user_properties"] = props }

        var attribution: [String: Any] = [:]
        if let v = snapshot.idfa { attribution["idfa"] = v }
        if let v = snapshot.hashedEmail { attribution["email_sha256"] = v }
        if let v = snapshot.hashedPhone { attribution["phone_sha256"] = v }
        if let v = snapshot.hashedExternalId { attribution["external_id_sha256"] = v }
        if !attribution.isEmpty { context["attribution"] = attribution }

        let revenueAmount = revenue?.amountString()
        let revenueCurrency = revenue?.currency
        // No FX in the SDK: only fill revenueUsd when the charge is already USD.
        let revenueUsd = (revenue?.currency == "USD") ? revenue?.amountString() : nil

        return PricistEvent(
            eventId: UUID().uuidString,
            eventName: name,
            timestamp: ISO8601DateFormatter.pricist.string(from: Date()),
            anonymousId: deviceInfo.anonymousId,
            userId: snapshot.userId,
            deviceId: deviceInfo.deviceId,
            appVersion: deviceInfo.appVersion,
            sdkVersion: Self.sdkVersion,
            sessionId: sessionId,
            environment: configuration.environment,
            country: deviceInfo.country,
            context: context,
            properties: parameters?.dictionary ?? [:],
            productId: dimensions?.productId,
            offeringId: dimensions?.offeringId,
            paywallId: dimensions?.paywallId,
            experimentId: dimensions?.experimentId,
            variantId: dimensions?.variantId,
            entitlementId: dimensions?.entitlementId,
            placement: dimensions?.placement,
            revenueAmount: revenueAmount,
            revenueCurrency: revenueCurrency,
            revenueUsd: revenueUsd,
            revenuecatUserId: nil
        )
    }

    // MARK: - Control

    /// Force-send queued events immediately.
    public func flush() {
        guard let config = configuration else { return }
        guard isStarted else {
            Logger.debug("flush() called before start; skipping")
            return
        }
        if let consent = stateSnapshot().consent, consent.blocksDispatch {
            Logger.debug("Consent blocks dispatch, skipping flush")
            return
        }
        eventQueue.flush(using: networkClient, configuration: config)
    }

    /// Enable or disable tracking.
    public func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        Logger.info("Tracking \(enabled ? "enabled" : "disabled")")
    }

    // MARK: - User Identification

    /// Set the user ID for identified users. Attached to all subsequent events
    /// as `userId` (and used as the event identity over `anonymousId`).
    public func setUserId(_ userId: String) {
        guard !userId.isEmpty else {
            Logger.error("setUserId: userId cannot be empty")
            return
        }
        withState { self.userId = userId }
        UserDefaults.standard.set(userId, forKey: Self.userIdKey)
        Logger.info("User ID set")
    }

    /// Merge user properties for the current user. Attached to subsequent
    /// events under `context.user_properties`.
    public func setUserProperties(_ properties: [String: Any]) {
        withState {
            if var existing = self.userProperties {
                for (key, value) in properties { existing[key] = value }
                self.userProperties = existing
            } else {
                self.userProperties = properties
            }
        }
        Logger.debug("User properties updated")
    }

    /// Clear the current user ID and properties (e.g., on logout).
    public func clearUserId() {
        withState {
            self.userId = nil
            self.userProperties = nil
        }
        UserDefaults.standard.removeObject(forKey: Self.userIdKey)
        Logger.info("User ID cleared")
    }

    private func restoreUserId() {
        if let stored = UserDefaults.standard.string(forKey: Self.userIdKey) {
            withState { self.userId = stored }
            Logger.debug("Restored user ID")
        }
    }

    // MARK: - Attribution identifiers (captured for the future attribution layer)

    /// Set the device IDFA (read by the host after ATT consent). Pass `nil` to
    /// clear. Attached to subsequent events under `context.attribution.idfa`.
    public func setIDFA(_ idfa: String?) {
        withState { self.idfa = idfa }
        Logger.debug("IDFA \(idfa == nil ? "cleared" : "set")")
    }

    /// Set the SHA256-hex hash of the user's normalized email. The SDK never
    /// sees the raw value.
    public func setHashedEmail(_ sha256: String?) {
        withState { self.hashedEmail = sha256 }
    }

    /// Set the SHA256-hex hash of the user's normalized phone (E.164).
    public func setHashedPhone(_ sha256: String?) {
        withState { self.hashedPhone = sha256 }
    }

    /// Set the SHA256-hex hash of an external user identifier (CRM / auth ID).
    public func setHashedExternalId(_ sha256: String?) {
        withState { self.hashedExternalId = sha256 }
    }

    // MARK: - Consent

    /// Record the user's GDPR / DMA consent decision. When consent blocks
    /// dispatch (GDPR applies and data-usage consent is denied), the SDK stops
    /// sending events and purges the local queue. Otherwise the consent state
    /// is attached to every event's `context.consent`.
    public func setConsent(_ consent: PricistConsent) {
        withState { self.consent = consent }
        Logger.info("Consent updated (gdpr=\(consent.isUserSubjectToGDPR))")
        if consent.blocksDispatch {
            eventQueue.clear()
            Logger.info("Consent blocks dispatch — local event queue purged")
        }
    }

    // MARK: - Remote Config

    /// Get a single remote-config value by key.
    public func getConfig(_ key: String) -> Any? {
        stateLock.lock(); defer { stateLock.unlock() }
        return remoteConfig?[key]
    }

    /// Get a single remote-config value with a default.
    public func getConfig<T>(_ key: String, default defaultValue: T) -> T {
        stateLock.lock(); defer { stateLock.unlock() }
        return (remoteConfig?[key] as? T) ?? defaultValue
    }

    /// Get all remote-config values.
    public func getAllConfig() -> [String: Any] {
        stateLock.lock(); defer { stateLock.unlock() }
        return remoteConfig ?? [:]
    }

    /// Register a callback that fires when remote config is loaded. If config
    /// has already loaded, the callback fires immediately.
    public func onConfigLoaded(_ callback: @escaping ConfigLoadedCallback) {
        let current = getAllConfig()
        configCallbacks.append(callback)
        if !current.isEmpty {
            callback(current)
        }
    }

    private func fetchRemoteConfig() {
        guard let config = configuration else { return }
        networkClient.fetchConfig(configuration: config) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let configData):
                self.withState { self.remoteConfig = configData }
                self.saveCachedConfig(configData)
                Logger.debug("Remote config loaded (\(configData.count) keys)")
                self.notifyConfigCallbacks(configData)
            case .failure(let error):
                Logger.error("Failed to fetch remote config: \(error)")
            }
        }
    }

    private func loadCachedConfig() {
        let defaults = UserDefaults.standard
        guard let ts = defaults.object(forKey: Self.configTimestampKey) as? Date else { return }
        guard Date().timeIntervalSince(ts) < Self.configCacheTTL else { return }
        guard let data = defaults.data(forKey: Self.configKey),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        withState { self.remoteConfig = json }
        Logger.debug("Loaded cached remote config")
    }

    private func saveCachedConfig(_ config: [String: Any]) {
        let defaults = UserDefaults.standard
        if let data = try? JSONSerialization.data(withJSONObject: config) {
            defaults.set(data, forKey: Self.configKey)
            defaults.set(Date(), forKey: Self.configTimestampKey)
        }
    }

    private func notifyConfigCallbacks(_ config: [String: Any]) {
        for callback in configCallbacks {
            callback(config)
        }
    }

    // MARK: - Flush Timer

    private func startFlushTimer(interval: TimeInterval) {
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
        timer.schedule(deadline: .now() + interval, repeating: interval)
        timer.setEventHandler { [weak self] in
            self?.flush()
        }
        flushTimer = timer
        timer.resume()
    }

    // MARK: - Lifecycle Observers

    private func registerLifecycleObservers() {
        #if canImport(UIKit) && !os(watchOS)
        let center = NotificationCenter.default

        let backgroundToken = center.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil, queue: nil
        ) { [weak self] _ in
            self?.flushOnBackground()
        }

        let foregroundToken = center.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil, queue: nil
        ) { [weak self] _ in
            self?.flush()
        }

        let terminateToken = center.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil, queue: nil
        ) { [weak self] _ in
            self?.flush()
        }

        lifecycleObservers = [backgroundToken, foregroundToken, terminateToken]
        #endif
    }

    #if canImport(UIKit) && !os(watchOS)
    private func flushOnBackground() {
        let app = UIApplication.shared
        var taskId: UIBackgroundTaskIdentifier = .invalid
        taskId = app.beginBackgroundTask(withName: "com.pricist.flush") {
            if taskId != .invalid {
                app.endBackgroundTask(taskId)
                taskId = .invalid
            }
        }

        flush()

        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 5) {
            if taskId != .invalid {
                app.endBackgroundTask(taskId)
                taskId = .invalid
            }
        }
    }
    #endif

    // MARK: - Validation

    private func validateEventName(_ name: String) -> String? {
        guard !name.isEmpty else { return nil }
        guard name.count <= 100 else { return nil }
        let pattern = "^[a-zA-Z][a-zA-Z0-9_]*$"
        guard name.range(of: pattern, options: .regularExpression) != nil else { return nil }
        return name
    }

    // MARK: - State snapshot

    private struct StateSnapshot {
        let userId: String?
        let userProperties: [String: Any]?
        let consent: PricistConsent?
        let idfa: String?
        let hashedEmail: String?
        let hashedPhone: String?
        let hashedExternalId: String?
    }

    private func stateSnapshot() -> StateSnapshot {
        stateLock.lock(); defer { stateLock.unlock() }
        return StateSnapshot(
            userId: userId,
            userProperties: userProperties,
            consent: consent,
            idfa: idfa,
            hashedEmail: hashedEmail,
            hashedPhone: hashedPhone,
            hashedExternalId: hashedExternalId
        )
    }

    private func withState(_ mutation: () -> Void) {
        stateLock.lock(); defer { stateLock.unlock() }
        mutation()
    }
}
