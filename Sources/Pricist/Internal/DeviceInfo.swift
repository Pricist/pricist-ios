import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Device information collector. Also owns the two stable per-install
/// identifiers Pricist keys events on: `deviceId` (IDFV when available) and
/// `anonymousId` (a generated UUID persisted across launches, used as the
/// identity fallback when no `userId` has been set).
struct DeviceInfo {

    private let anonymousIdKey = "com.pricist.anonymousId"
    private let deviceIdKey = "com.pricist.deviceId"

    /// Stable anonymous identifier for this install. Generated once and
    /// persisted; survives until the app is deleted. Used as `anonymousId`
    /// on every event and as the identity fallback before `setUserId`.
    var anonymousId: String {
        if let stored = UserDefaults.standard.string(forKey: anonymousIdKey) {
            return stored
        }
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: anonymousIdKey)
        return newId
    }

    /// Unique device identifier (IDFV when available, else a generated UUID).
    var deviceId: String {
        #if canImport(UIKit) && !os(watchOS)
        if let idfv = UIDevice.current.identifierForVendor?.uuidString {
            return idfv
        }
        #endif
        return getOrCreateDeviceId()
    }

    /// Operating system name.
    var osName: String {
        #if os(iOS)
        return "iOS"
        #elseif os(macOS)
        return "macOS"
        #elseif os(tvOS)
        return "tvOS"
        #elseif os(watchOS)
        return "watchOS"
        #else
        return "Unknown"
        #endif
    }

    /// Operating system version.
    var osVersion: String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }

    /// Device model.
    var deviceModel: String {
        #if canImport(UIKit) && !os(watchOS)
        return UIDevice.current.model
        #else
        return getDeviceModelIdentifier()
        #endif
    }

    /// Exact hardware model identifier (e.g. "iPhone16,2") via `hw.machine`.
    /// Unlike `UIDevice.current.model` (which is just "iPhone"), this is the
    /// precise hardware string the server can fingerprint against a web client.
    /// On the simulator this returns the simulated device identifier.
    var deviceModelIdentifier: String {
        #if targetEnvironment(simulator)
        if let simId = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"],
           !simId.isEmpty {
            return simId
        }
        #endif
        var size = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        guard size > 0 else { return "" }
        var machine = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.machine", &machine, &size, nil, 0)
        return String(cString: machine)
    }

    /// Physical screen width in pixels (points × scale). Matches the web's
    /// `screen.width * devicePixelRatio`. 0 where UIScreen is unavailable.
    var screenWidthPx: Int {
        #if canImport(UIKit) && !os(watchOS)
        let bounds = UIScreen.main.bounds
        let scale = UIScreen.main.scale
        return Int((bounds.width * scale).rounded())
        #else
        return 0
        #endif
    }

    /// Physical screen height in pixels (points × scale). Matches the web's
    /// `screen.height * devicePixelRatio`. 0 where UIScreen is unavailable.
    var screenHeightPx: Int {
        #if canImport(UIKit) && !os(watchOS)
        let bounds = UIScreen.main.bounds
        let scale = UIScreen.main.scale
        return Int((bounds.height * scale).rounded())
        #else
        return 0
        #endif
    }

    /// Screen scale (device pixel ratio). 0 where UIScreen is unavailable.
    var screenScale: Double {
        #if canImport(UIKit) && !os(watchOS)
        return Double(UIScreen.main.scale)
        #else
        return 0
        #endif
    }

    /// Comma-separated preferred languages (BCP-47), e.g. "en-US,fr-FR".
    var languages: String {
        Locale.preferredLanguages.joined(separator: ",")
    }

    /// App version (CFBundleShortVersionString).
    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }

    /// App build number (CFBundleVersion).
    var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
    }

    /// User locale.
    var locale: String {
        Locale.current.identifier
    }

    /// User timezone.
    var timezone: String {
        TimeZone.current.identifier
    }

    /// Best-effort ISO 3166-1 alpha-2 country, used to populate the event's
    /// top-level `country` field. Derived from the device region.
    var country: String? {
        if #available(iOS 16, macOS 13, tvOS 16, watchOS 9, *) {
            return Locale.current.region?.identifier
        }
        return (Locale.current as NSLocale).object(forKey: .countryCode) as? String
    }

    // MARK: - Private

    private func getOrCreateDeviceId() -> String {
        if let stored = UserDefaults.standard.string(forKey: deviceIdKey) {
            return stored
        }
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: deviceIdKey)
        return newId
    }

    private func getDeviceModelIdentifier() -> String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        return String(cString: model)
    }
}

// MARK: - Context

extension DeviceInfo {

    /// Device context attached to each event's `context` object. The backend
    /// stores `context` verbatim, so this is where ambient device signals
    /// (and, later, attribution identifiers) live.
    func contextDictionary() -> [String: Any] {
        [
            "app_build": appBuild,
            "os_name": osName,
            "os_version": osVersion,
            "device_model": deviceModel,
            "locale": locale,
            "timezone": timezone,
        ]
    }
}
