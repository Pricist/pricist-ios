import Foundation

/// Container for custom event parameters. These map to the event's
/// `properties` object on the wire — an arbitrary JSON bag the dashboard can
/// break down and filter on.
public struct PricistEventParameters {

    private var storage: [String: Any] = [:]

    /// Create empty parameters.
    public init() {}

    /// Set a string parameter.
    public mutating func set(_ key: String, value: String) {
        storage[key] = value
    }

    /// Set an integer parameter.
    public mutating func set(_ key: String, value: Int) {
        storage[key] = value
    }

    /// Set a double parameter.
    public mutating func set(_ key: String, value: Double) {
        storage[key] = value
    }

    /// Set a boolean parameter.
    public mutating func set(_ key: String, value: Bool) {
        storage[key] = value
    }

    /// The underlying dictionary, or nil when empty.
    internal var dictionary: [String: Any]? {
        storage.isEmpty ? nil : storage
    }
}

// MARK: - Convenience Initializers

public extension PricistEventParameters {

    /// Create parameters from a dictionary. Unsupported value types are
    /// skipped (only String/Int/Double/Bool are kept).
    init(_ dictionary: [String: Any]) {
        for (key, value) in dictionary {
            switch value {
            case let string as String:
                storage[key] = string
            case let bool as Bool:
                storage[key] = bool
            case let int as Int:
                storage[key] = int
            case let double as Double:
                storage[key] = double
            default:
                break
            }
        }
    }
}

// MARK: - ExpressibleByDictionaryLiteral

extension PricistEventParameters: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, Any)...) {
        self.init()
        for (key, value) in elements {
            switch value {
            case let string as String:
                storage[key] = string
            case let bool as Bool:
                storage[key] = bool
            case let int as Int:
                storage[key] = int
            case let double as Double:
                storage[key] = double
            default:
                break
            }
        }
    }
}
