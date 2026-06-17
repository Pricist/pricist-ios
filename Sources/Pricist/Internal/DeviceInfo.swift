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
