import XCTest
@testable import Pricist

final class PricistTests: XCTestCase {

    // MARK: - Configuration

    func testConfigurationDefaults() {
        let config = PricistConfiguration(sdkKey: "pk_test_key")

        XCTAssertEqual(config.sdkKey, "pk_test_key")
        XCTAssertEqual(config.environment, "production")
        XCTAssertEqual(config.logLevel, .none)
        XCTAssertEqual(config.flushInterval, 30.0)
        XCTAssertEqual(config.maxBatchSize, 100)
        XCTAssertNil(config.host)
        XCTAssertTrue(config.autoStart)
    }

    func testHostDefaultsToProduction() {
        let config = PricistConfiguration(sdkKey: "pk_test_key")

        XCTAssertNil(config.host)
        XCTAssertEqual(pricistDefaultBaseURL, "https://api.pricist.dev")
        XCTAssertEqual(pricistResolveBaseURL(config), "https://api.pricist.dev")
    }

    func testHostOverride() {
        let config = PricistConfiguration(sdkKey: "pk_test_key")
            .with(host: "http://localhost:3000")

        XCTAssertEqual(config.host, "http://localhost:3000")
        XCTAssertEqual(pricistResolveBaseURL(config), "http://localhost:3000")
    }

    func testHostTrailingSlashTrimmed() {
        let config = PricistConfiguration(sdkKey: "pk_test_key")
            .with(host: "http://localhost:3000/")

        XCTAssertEqual(config.host, "http://localhost:3000")
        XCTAssertEqual(pricistResolveBaseURL(config), "http://localhost:3000")
    }

    func testEnvironmentOverride() {
        let config = PricistConfiguration(sdkKey: "pk_test_key")
            .with(environment: "sandbox")

        XCTAssertEqual(config.environment, "sandbox")
    }

    func testBuilderAndClamping() {
        let config = PricistConfiguration(sdkKey: "pk_test_key")
            .with(logLevel: .debug)
            .with(flushInterval: 0.5)   // below min
            .with(maxBatchSize: 9000)   // above max

        XCTAssertEqual(config.logLevel, .debug)
        XCTAssertEqual(config.flushInterval, 1.0)
        XCTAssertEqual(config.maxBatchSize, 500)
    }

    // MARK: - Revenue

    func testRevenueUSD() {
        let revenue = PricistRevenue.usd(29.99)
        XCTAssertEqual(revenue.amount, Decimal(29.99))
        XCTAssertEqual(revenue.currency, "USD")
    }

    func testRevenueCurrencyNormalization() {
        let revenue = PricistRevenue(amount: 10.0, currency: "eur")
        XCTAssertEqual(revenue.currency, "EUR")
    }

    func testRevenueFormatting() {
        XCTAssertEqual(PricistRevenue.usd(100.0).amountString(), "100.00")
        XCTAssertEqual(PricistRevenue.usd(9.9).amountString(), "9.90")
    }

    /// Large amounts must not pick up a grouping separator.
    func testRevenueNoGroupingSeparator() {
        XCTAssertEqual(PricistRevenue.usd(1234567.89).amountString(), "1234567.89")
    }

    /// The decimal separator must always be '.' regardless of host locale.
    /// Previously the formatter used the current locale, so a German device
    /// would emit "29,99" and the backend's numeric parse would break.
    func testRevenueDecimalSeparatorIsAlwaysDot() {
        let amount = PricistRevenue.eur(29.99).amountString()
        XCTAssertEqual(amount, "29.99")
        XCTAssertFalse(amount.contains(","))
    }

    /// Sub-cent precision is preserved up to 6 fraction digits.
    func testRevenuePreservesPrecision() {
        XCTAssertEqual(PricistRevenue.usd(Decimal(string: "0.123456")!).amountString(), "0.123456")
        XCTAssertEqual(PricistRevenue.usd(Decimal(0)).amountString(), "0.00")
    }

    // MARK: - Device identifiers

    /// anonymousId / deviceId must be stable across repeated accesses and
    /// across separate DeviceInfo instances (they back the persisted identity).
    func testDeviceIdentifiersAreStable() {
        let info = DeviceInfo()
        let anon1 = info.anonymousId
        let anon2 = info.anonymousId
        XCTAssertEqual(anon1, anon2)
        XCTAssertFalse(anon1.isEmpty)

        // A fresh instance reads the same persisted value.
        XCTAssertEqual(DeviceInfo().anonymousId, anon1)
    }

    /// Concurrent first-access must not generate two different anonymousIds.
    /// (Guards the read-or-create race fixed by DeviceInfo.idLock.)
    func testAnonymousIdConcurrentAccessIsConsistent() {
        // Clear any previously persisted value so this exercises generation.
        UserDefaults.standard.removeObject(forKey: "com.pricist.anonymousId")

        let info = DeviceInfo()
        let results = NSMutableSet()
        let resultsLock = NSLock()
        let group = DispatchGroup()
        for _ in 0..<50 {
            group.enter()
            DispatchQueue.global().async {
                let id = info.anonymousId
                resultsLock.lock(); results.add(id); resultsLock.unlock()
                group.leave()
            }
        }
        group.wait()
        XCTAssertEqual(results.count, 1, "concurrent access produced multiple anonymousIds")
    }

    // MARK: - Event Parameters

    func testEventParametersEmpty() {
        XCTAssertNil(PricistEventParameters().dictionary)
    }

    func testEventParametersWithValues() {
        var params = PricistEventParameters()
        params.set("string_key", value: "hello")
        params.set("int_key", value: 42)
        params.set("double_key", value: 3.14)
        params.set("bool_key", value: true)

        let dict = params.dictionary
        XCTAssertEqual(dict?["string_key"] as? String, "hello")
        XCTAssertEqual(dict?["int_key"] as? Int, 42)
        XCTAssertEqual(dict?["double_key"] as? Double, 3.14)
        XCTAssertEqual(dict?["bool_key"] as? Bool, true)
    }

    func testEventParametersLiteral() {
        let params: PricistEventParameters = ["item_id": "sku_123", "quantity": 2]
        XCTAssertEqual(params.dictionary?["item_id"] as? String, "sku_123")
        XCTAssertEqual(params.dictionary?["quantity"] as? Int, 2)
    }

    // MARK: - Wire format

    /// The event must serialize to the camelCase keys the backend's
    /// `normalizeTrackEvent` reads, with subscription dimensions and revenue
    /// present as top-level fields.
    func testEventEncodesToCamelCaseContract() throws {
        let event = PricistEvent(
            eventId: "11111111-1111-4111-8111-111111111111",
            eventName: "Purchase",
            timestamp: "2026-06-17T12:00:00.000Z",
            anonymousId: "anon-1",
            userId: "user-1",
            deviceId: "device-1",
            appVersion: "1.2.3",
            sdkVersion: "0.1.0",
            sessionId: "session-1",
            environment: "production",
            country: "US",
            context: ["os_name": "iOS"],
            properties: ["plan": "annual"],
            productId: "com.app.premium.annual",
            offeringId: "default",
            paywallId: "pw_1",
            experimentId: "exp_1",
            variantId: "var_a",
            entitlementId: "premium",
            placement: "onboarding",
            revenueAmount: "29.99",
            revenueCurrency: "USD",
            revenueUsd: "29.99",
            revenuecatUserId: nil
        )

        let data = try JSONEncoder().encode(event)
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(json["eventId"] as? String, "11111111-1111-4111-8111-111111111111")
        XCTAssertEqual(json["eventName"] as? String, "Purchase")
        XCTAssertEqual(json["anonymousId"] as? String, "anon-1")
        XCTAssertEqual(json["userId"] as? String, "user-1")
        XCTAssertEqual(json["appVersion"] as? String, "1.2.3")
        XCTAssertEqual(json["productId"] as? String, "com.app.premium.annual")
        XCTAssertEqual(json["paywallId"] as? String, "pw_1")
        XCTAssertEqual(json["revenueAmount"] as? String, "29.99")
        XCTAssertEqual(json["revenueCurrency"] as? String, "USD")
        XCTAssertEqual((json["properties"] as? [String: Any])?["plan"] as? String, "annual")
        XCTAssertEqual((json["context"] as? [String: Any])?["os_name"] as? String, "iOS")
        // nil optionals are omitted, not sent as null.
        XCTAssertNil(json["revenuecatUserId"])
    }

    /// Empty optional strings are omitted so the backend doesn't store blanks.
    func testEventOmitsEmptyOptionalFields() throws {
        let event = PricistEvent(
            eventId: "22222222-2222-4222-8222-222222222222",
            eventName: "app_open",
            timestamp: "2026-06-17T12:00:00.000Z",
            anonymousId: "anon-2",
            userId: nil,
            deviceId: "device-2",
            appVersion: "1.0.0",
            sdkVersion: "0.1.0",
            sessionId: nil,
            environment: "production",
            country: nil,
            context: [:],
            properties: [:],
            productId: nil, offeringId: nil, paywallId: nil, experimentId: nil,
            variantId: nil, entitlementId: nil, placement: nil,
            revenueAmount: nil, revenueCurrency: nil, revenueUsd: nil, revenuecatUserId: nil
        )

        let data = try JSONEncoder().encode(event)
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertNil(json["userId"])
        XCTAssertNil(json["sessionId"])
        XCTAssertNil(json["productId"])
        XCTAssertEqual(json["eventName"] as? String, "app_open")
        XCTAssertNotNil(json["context"])
        XCTAssertNotNil(json["properties"])
    }

    /// The persisted queue round-trips an event through Codable unchanged.
    func testEventCodableRoundTrip() throws {
        let event = PricistEvent(
            eventId: "33333333-3333-4333-8333-333333333333",
            eventName: "Subscribe",
            timestamp: "2026-06-17T12:00:00.000Z",
            anonymousId: "anon-3",
            userId: "user-3",
            deviceId: "device-3",
            appVersion: "2.0.0",
            sdkVersion: "0.1.0",
            sessionId: "session-3",
            environment: "sandbox",
            country: "GB",
            context: ["att_status": "authorized"],
            properties: ["count": 3],
            productId: "p1", offeringId: nil, paywallId: nil, experimentId: nil,
            variantId: nil, entitlementId: nil, placement: nil,
            revenueAmount: "9.99", revenueCurrency: "GBP", revenueUsd: nil, revenuecatUserId: nil
        )

        let data = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(PricistEvent.self, from: data)

        XCTAssertEqual(decoded.eventId, event.eventId)
        XCTAssertEqual(decoded.eventName, "Subscribe")
        XCTAssertEqual(decoded.environment, "sandbox")
        XCTAssertEqual(decoded.revenueCurrency, "GBP")
        XCTAssertEqual(decoded.context["att_status"] as? String, "authorized")
        XCTAssertEqual(decoded.properties["count"] as? Int, 3)
    }
}
