import Foundation
#if canImport(Security)
import Security
#endif
#if canImport(UIKit) && !os(watchOS)
import UIKit
#endif

/// Callback type for attribution results. Fires with the server's sanitized
/// `AttributionResult`, or `nil` when attribution could not be resolved.
public typealias AttributionCallback = (AttributionResult?) -> Void

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
    // Deep-link click token (`pricist_click`) claimed from an inbound URL.
    private var clickToken: String?

    // Consent: nil until the host calls setConsent. When nil, the SDK tracks
    // normally (opt-in / track-by-default model).
    private var consent: PricistConsent?

    private var configCallbacks: [ConfigLoadedCallback] = []

    // MARK: - Attribution state
    private var attributionCallbacks: [AttributionCallback] = []
    private var cachedAttribution: AttributionResult?

    // MARK: - Session re-fire (identifier change debounce)
    //
    // Identifier setters mark the in-memory set dirty and schedule a debounced
    // re-POST of the session so the server learns upgraded identifiers without
    // waiting for the next launch. A 1s debounce coalesces bursts; an in-flight
    // guard prevents overlapping POSTs.
    private let sessionQueue = DispatchQueue(label: "com.pricist.session")
    private var isIdentifierDirty = false
    private var isReFireInFlight = false
    private var identifierDebounceTimer: DispatchSourceTimer?
    private static let identifierDebounceMs: Int = 1000

    // MARK: - ATT wait state
    private var isWaitingForATT = false
    private var attWaitObserver: NSObjectProtocol?

    private static let userIdKey = "com.pricist.userId"
    private static let installedKey = "com.pricist.installed"
    private static let configKey = "com.pricist.config"
    private static let configTimestampKey = "com.pricist.config.ts"
    private static let configCacheTTL: TimeInterval = 300 // 5 minutes
    private static let keychainService = "com.pricist.attribution"
    private static let keychainAccount = "attribution_result"

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

        startAttributionSession(isFirstSession: isFirstLaunch)
    }

    // MARK: - Attribution Session

    /// Fire the attribution session. If a cached result already exists in the
    /// Keychain, return it without POSTing (and notify any pending callbacks).
    /// Otherwise POST `/api/session`, cache the result, and fire callbacks.
    private func startAttributionSession(isFirstSession: Bool) {
        if let cached = loadAttribution() {
            withState { self.cachedAttribution = cached }
            Logger.debug("Loaded cached attribution — skipping session POST")
            notifyAttributionCallbacks(cached)
            return
        }
        postSession(isFirstSession: isFirstSession) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let attribution):
                self.saveAttribution(attribution)
                self.withState { self.cachedAttribution = attribution }
                Logger.info("Attribution received (attributed=\(attribution.attributed), method=\(attribution.method))")
                self.notifyAttributionCallbacks(attribution)
            case .failure(let error):
                Logger.error("Attribution session failed: \(error)")
                self.notifyAttributionCallbacks(nil)
            }
        }
    }

    /// Build and POST a `SessionRequest` from the current snapshot. Gated on
    /// consent (no POST when consent blocks dispatch).
    private func postSession(
        isFirstSession: Bool,
        completion: @escaping (Result<AttributionResult, NetworkError>) -> Void
    ) {
        guard let configuration = configuration else { return }
        let snapshot = stateSnapshot()
        if let consent = snapshot.consent, consent.blocksDispatch {
            Logger.debug("Consent blocks dispatch, skipping session POST")
            return
        }
        let request = buildSessionRequest(isFirstSession: isFirstSession, snapshot: snapshot)
        networkClient.sendSession(request, configuration: configuration, completion: completion)
    }

    /// Build a `SessionRequest` from the device info + current identity
    /// snapshot. Shared by the first-launch path and the re-fire path.
    private func buildSessionRequest(isFirstSession: Bool, snapshot: StateSnapshot) -> SessionRequest {
        var context = deviceInfo.contextDictionary()
        if let consent = snapshot.consent { context["consent"] = consent.contextDictionary }

        return SessionRequest(
            anonymousId: deviceInfo.anonymousId,
            deviceId: deviceInfo.deviceId,
            platform: "ios",
            timestamp: ISO8601DateFormatter.pricist.string(from: Date()),
            isFirstSession: isFirstSession,
            sessionId: sessionId,
            appVersion: deviceInfo.appVersion,
            sdkVersion: Self.sdkVersion,
            idfa: snapshot.idfa,
            clickToken: snapshot.clickToken,
            emailSha256: snapshot.hashedEmail,
            phoneSha256: snapshot.hashedPhone,
            externalIdSha256: snapshot.hashedExternalId,
            attStatus: currentATTStatusString(),
            screenWidth: deviceInfo.screenWidthPx,
            screenHeight: deviceInfo.screenHeightPx,
            screenScale: deviceInfo.screenScale,
            deviceModel: deviceInfo.deviceModelIdentifier,
            osVersion: deviceInfo.osVersion,
            locale: deviceInfo.locale,
            timezone: deviceInfo.timezone,
            languages: deviceInfo.languages,
            context: context
        )
    }

    // MARK: - Attribution callbacks

    /// Register a callback for the attribution result. If a result has already
    /// been resolved (cached), the callback fires immediately.
    public func onAttribution(_ callback: @escaping AttributionCallback) {
        let cached: AttributionResult? = {
            stateLock.lock(); defer { stateLock.unlock() }
            return cachedAttribution
        }() ?? loadAttribution()

        withState { self.attributionCallbacks.append(callback) }

        if let cached = cached {
            callback(cached)
        }
    }

    private func notifyAttributionCallbacks(_ result: AttributionResult?) {
        let callbacks: [AttributionCallback] = {
            stateLock.lock(); defer { stateLock.unlock() }
            return attributionCallbacks
        }()
        for callback in callbacks {
            callback(result)
        }
    }

    // MARK: - Deep-link click token

    /// Set the deep-link click token directly. Included in the next session
    /// POST as `clickToken` and triggers a debounced re-fire so the server can
    /// claim the click. Pass `nil` to clear.
    public func setClickToken(_ token: String?) {
        withState { self.clickToken = token }
        Logger.debug("Click token \(token == nil ? "cleared" : "set")")
        markIdentifierDirty()
    }

    /// Extract a `pricist_click` query parameter from an inbound deep-link URL
    /// and claim it via `setClickToken(_:)`. Call from your app's URL /
    /// universal-link handler. Returns `true` when a token was found.
    @discardableResult
    public func handleDeepLink(url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let token = components.queryItems?.first(where: { $0.name == "pricist_click" })?.value,
              !token.isEmpty else {
            return false
        }
        setClickToken(token)
        return true
    }

    // MARK: - Identifier debounce + re-fire

    /// Mark the identity set dirty and schedule a debounced session re-fire.
    /// No-op before `start()` (values ride the first-launch POST) and while a
    /// re-fire is already in flight (handled on completion).
    private func markIdentifierDirty() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.isIdentifierDirty = true
            guard self.isStarted else { return }
            guard !self.isReFireInFlight else { return }
            self.scheduleDebounceOnQueue()
        }
    }

    /// Cancel any pending debounce timer and start a fresh one. Must run on
    /// `sessionQueue`.
    private func scheduleDebounceOnQueue() {
        identifierDebounceTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: sessionQueue)
        timer.schedule(deadline: .now() + .milliseconds(Self.identifierDebounceMs))
        timer.setEventHandler { [weak self] in
            self?.identifierDebounceTimer = nil
            self?.triggerReFireOnQueue()
        }
        identifierDebounceTimer = timer
        timer.resume()
    }

    /// Send the re-fire if started + dirty. Must run on `sessionQueue`. Holds
    /// the in-flight guard for the POST duration; re-schedules if a setter
    /// fired during the window or the POST failed.
    private func triggerReFireOnQueue() {
        guard isStarted else { return }
        guard isIdentifierDirty else { return }
        guard let configuration = configuration else { return }

        let snapshot = stateSnapshot()
        if let consent = snapshot.consent, consent.blocksDispatch {
            Logger.debug("Consent blocks dispatch, skipping session re-fire")
            isIdentifierDirty = false
            return
        }

        isReFireInFlight = true
        isIdentifierDirty = false

        let request = buildSessionRequest(isFirstSession: false, snapshot: snapshot)
        networkClient.sendSession(request, configuration: configuration) { [weak self] result in
            guard let self = self else { return }
            self.sessionQueue.async {
                self.isReFireInFlight = false
                switch result {
                case .success(let attribution):
                    self.saveAttribution(attribution)
                    self.withState { self.cachedAttribution = attribution }
                    Logger.debug("Session re-fire succeeded")
                    self.notifyAttributionCallbacks(attribution)
                case .failure(let error):
                    self.isIdentifierDirty = true
                    Logger.warning("Session re-fire failed: \(error)")
                }
                if self.isIdentifierDirty {
                    self.scheduleDebounceOnQueue()
                }
            }
        }
    }

    // MARK: - Attribution Keychain cache

    private func loadAttribution() -> AttributionResult? {
        #if canImport(Security)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: Self.keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return try? JSONDecoder().decode(AttributionResult.self, from: data)
        #else
        return nil
        #endif
    }

    private func saveAttribution(_ attribution: AttributionResult) {
        #if canImport(Security)
        guard let data = try? JSONEncoder().encode(attribution) else {
            Logger.warning("Failed to encode attribution for Keychain")
            return
        }
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: Self.keychainAccount
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: Self.keychainAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status != errSecSuccess {
            Logger.warning("Failed to save attribution to Keychain: \(status)")
        }
        #endif
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
        markIdentifierDirty()
    }

    /// Set the SHA256-hex hash of the user's normalized email. The SDK never
    /// sees the raw value.
    public func setHashedEmail(_ sha256: String?) {
        withState { self.hashedEmail = sha256 }
        markIdentifierDirty()
    }

    /// Set the SHA256-hex hash of the user's normalized phone (E.164).
    public func setHashedPhone(_ sha256: String?) {
        withState { self.hashedPhone = sha256 }
        markIdentifierDirty()
    }

    /// Set the SHA256-hex hash of an external user identifier (CRM / auth ID).
    public func setHashedExternalId(_ sha256: String?) {
        withState { self.hashedExternalId = sha256 }
        markIdentifierDirty()
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
        } else {
            // Re-fire so the backend learns the new consent state without
            // waiting for a natural session boundary.
            markIdentifierDirty()
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
        let clickToken: String?
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
            hashedExternalId: hashedExternalId,
            clickToken: clickToken
        )
    }

    private func withState(_ mutation: () -> Void) {
        stateLock.lock(); defer { stateLock.unlock() }
        mutation()
    }
}
