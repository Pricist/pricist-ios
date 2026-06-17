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
            attStatus: "authorized",
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
        XCTAssertEqual(json["attStatus"] as? String, "authorized")
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
            attStatus: nil,
            context: nil
        )

        let data = try JSONEncoder().encode(request)
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(json["anonymousId"] as? String, "anon-2")
        XCTAssertEqual(json["isFirstSession"] as? Bool, false)
        XCTAssertNil(json["sessionId"])
        XCTAssertNil(json["idfa"])
        XCTAssertNil(json["clickToken"])
        XCTAssertNil(json["attStatus"])
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
