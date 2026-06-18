import XCTest
@testable import Pricist

final class SessionTests: XCTestCase {

    // MARK: - SessionRequest encoding

    /// The session request must serialize to the camelCase keys the
    /// `/api/session` contract reads, with nil optionals omitted (not null).
    func testSessionRequestEncodesToCamelCaseContract() throws {
        let request = SessionRequest(
            anonymousId: "anon-1",
            deviceId: "device-1",
            platform: "ios",
            timestamp: "2026-06-17T12:00:00.000Z",
            isFirstSession: true,
            sessionId: "session-1",
            appVersion: "1.2.3",
            sdkVersion: "0.1.0",
            idfa: "AAAA-BBBB",
            clickToken: "click_123",
            emailSha256: "emailhash",
            phoneSha256: "phonehash",
            externalIdSha256: "extidhash",
            firstNameSha256: "firstnamehash",
            lastNameSha256: "lastnamehash",
            citySha256: "cityhash",
            stateSha256: "statehash",
            zipSha256: "ziphash",
            dobSha256: "dobhash",
            genderSha256: "genderhash",
            attStatus: "authorized",
            screenWidth: 1179,
            screenHeight: 2556,
            screenScale: 3.0,
            deviceModel: "iPhone16,2",
            osVersion: "17.4.1",
            locale: "en_US",
            timezone: "America/New_York",
            languages: "en-US,fr-FR",
            bundleId: "com.acme.app",
            appBuild: "42",
            carrier: "",
            cpuCores: 6,
            totalDiskGb: 256,
            freeDiskGb: 128,
            context: ["os_name": "iOS"]
        )

        let data = try JSONEncoder().encode(request)
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(json["anonymousId"] as? String, "anon-1")
        XCTAssertEqual(json["deviceId"] as? String, "device-1")
        XCTAssertEqual(json["platform"] as? String, "ios")
        XCTAssertEqual(json["timestamp"] as? String, "2026-06-17T12:00:00.000Z")
        XCTAssertEqual(json["isFirstSession"] as? Bool, true)
        XCTAssertEqual(json["sessionId"] as? String, "session-1")
        XCTAssertEqual(json["appVersion"] as? String, "1.2.3")
        XCTAssertEqual(json["sdkVersion"] as? String, "0.1.0")
        XCTAssertEqual(json["idfa"] as? String, "AAAA-BBBB")
        XCTAssertEqual(json["clickToken"] as? String, "click_123")
        XCTAssertEqual(json["emailSha256"] as? String, "emailhash")
        XCTAssertEqual(json["phoneSha256"] as? String, "phonehash")
        XCTAssertEqual(json["externalIdSha256"] as? String, "extidhash")
        XCTAssertEqual(json["firstNameSha256"] as? String, "firstnamehash")
        XCTAssertEqual(json["lastNameSha256"] as? String, "lastnamehash")
        XCTAssertEqual(json["citySha256"] as? String, "cityhash")
        XCTAssertEqual(json["stateSha256"] as? String, "statehash")
        XCTAssertEqual(json["zipSha256"] as? String, "ziphash")
        XCTAssertEqual(json["dobSha256"] as? String, "dobhash")
        XCTAssertEqual(json["genderSha256"] as? String, "genderhash")
        XCTAssertEqual(json["attStatus"] as? String, "authorized")
        XCTAssertEqual(json["screenWidth"] as? Int, 1179)
        XCTAssertEqual(json["screenHeight"] as? Int, 2556)
        XCTAssertEqual(json["screenScale"] as? Double, 3.0)
        XCTAssertEqual(json["deviceModel"] as? String, "iPhone16,2")
        XCTAssertEqual(json["osVersion"] as? String, "17.4.1")
        XCTAssertEqual(json["locale"] as? String, "en_US")
        XCTAssertEqual(json["timezone"] as? String, "America/New_York")
        XCTAssertEqual(json["languages"] as? String, "en-US,fr-FR")
        XCTAssertEqual(json["bundleId"] as? String, "com.acme.app")
        XCTAssertEqual(json["appBuild"] as? String, "42")
        XCTAssertEqual(json["carrier"] as? String, "")
        XCTAssertEqual(json["cpuCores"] as? Int, 6)
        XCTAssertEqual(json["totalDiskGb"] as? Int, 256)
        XCTAssertEqual(json["freeDiskGb"] as? Int, 128)
        XCTAssertEqual((json["context"] as? [String: Any])?["os_name"] as? String, "iOS")
    }

    /// nil optionals are omitted from the payload, not sent as null.
    func testSessionRequestOmitsNilOptionals() throws {
        let request = SessionRequest(
            anonymousId: "anon-2",
            deviceId: "device-2",
            platform: "ios",
            timestamp: "2026-06-17T12:00:00.000Z",
            isFirstSession: false,
            sessionId: nil,
            appVersion: nil,
            sdkVersion: nil,
            idfa: nil,
            clickToken: nil,
            emailSha256: nil,
            phoneSha256: nil,
            externalIdSha256: nil,
            firstNameSha256: nil,
            lastNameSha256: nil,
            citySha256: nil,
            stateSha256: nil,
            zipSha256: nil,
            dobSha256: nil,
            genderSha256: nil,
            attStatus: nil,
            screenWidth: nil,
            screenHeight: nil,
            screenScale: nil,
            deviceModel: nil,
            osVersion: nil,
            locale: nil,
            timezone: nil,
            languages: nil,
            bundleId: nil,
            appBuild: nil,
            carrier: nil,
            cpuCores: nil,
            totalDiskGb: nil,
            freeDiskGb: nil,
            context: nil
        )

        let data = try JSONEncoder().encode(request)
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(json["anonymousId"] as? String, "anon-2")
        XCTAssertEqual(json["isFirstSession"] as? Bool, false)
        XCTAssertNil(json["sessionId"])
        XCTAssertNil(json["idfa"])
        XCTAssertNil(json["clickToken"])
        XCTAssertNil(json["firstNameSha256"])
        XCTAssertNil(json["lastNameSha256"])
        XCTAssertNil(json["citySha256"])
        XCTAssertNil(json["stateSha256"])
        XCTAssertNil(json["zipSha256"])
        XCTAssertNil(json["dobSha256"])
        XCTAssertNil(json["genderSha256"])
        XCTAssertNil(json["attStatus"])
        XCTAssertNil(json["screenWidth"])
        XCTAssertNil(json["screenHeight"])
        XCTAssertNil(json["screenScale"])
        XCTAssertNil(json["deviceModel"])
        XCTAssertNil(json["osVersion"])
        XCTAssertNil(json["locale"])
        XCTAssertNil(json["timezone"])
        XCTAssertNil(json["languages"])
        XCTAssertNil(json["bundleId"])
        XCTAssertNil(json["appBuild"])
        XCTAssertNil(json["carrier"])
        XCTAssertNil(json["cpuCores"])
        XCTAssertNil(json["totalDiskGb"])
        XCTAssertNil(json["freeDiskGb"])
        XCTAssertNil(json["context"])
    }

    // MARK: - AttributionResult decoding

    /// The sanitized server response decodes into the public struct.
    func testAttributionResultDecodesSanitizedFields() throws {
        let json = """
        {
            "attributed": true,
            "method": "deterministic",
            "adNetwork": "meta",
            "campaignId": "camp_42",
            "confidence": 0.93,
            "attributionId": "attr_abc"
        }
        """.data(using: .utf8)!

        let result = try JSONDecoder().decode(AttributionResult.self, from: json)

        XCTAssertTrue(result.attributed)
        XCTAssertEqual(result.method, "deterministic")
        XCTAssertEqual(result.adNetwork, "meta")
        XCTAssertEqual(result.campaignId, "camp_42")
        XCTAssertEqual(result.confidence, 0.93, accuracy: 0.0001)
        XCTAssertEqual(result.attributionId, "attr_abc")
    }

    /// Optional fields are allowed to be absent (organic / unattributed).
    func testAttributionResultDecodesWithMissingOptionals() throws {
        let json = """
        {
            "attributed": false,
            "method": "organic",
            "confidence": 0.0
        }
        """.data(using: .utf8)!

        let result = try JSONDecoder().decode(AttributionResult.self, from: json)

        XCTAssertFalse(result.attributed)
        XCTAssertEqual(result.method, "organic")
        XCTAssertNil(result.adNetwork)
        XCTAssertNil(result.campaignId)
        XCTAssertNil(result.attributionId)
        XCTAssertEqual(result.confidence, 0.0)
    }

    /// AttributionResult round-trips through Codable (used for the Keychain cache).
    func testAttributionResultRoundTrips() throws {
        let original = AttributionResult(
            attributed: true,
            method: "probabilistic",
            adNetwork: "tiktok",
            campaignId: "camp_7",
            confidence: 0.5,
            attributionId: "attr_xyz"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AttributionResult.self, from: data)

        XCTAssertEqual(decoded.attributed, original.attributed)
        XCTAssertEqual(decoded.method, original.method)
        XCTAssertEqual(decoded.adNetwork, original.adNetwork)
        XCTAssertEqual(decoded.campaignId, original.campaignId)
        XCTAssertEqual(decoded.confidence, original.confidence)
        XCTAssertEqual(decoded.attributionId, original.attributionId)
    }
}
