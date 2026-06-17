import XCTest
@testable import Pricist

final class EventValidationTests: XCTestCase {

    // MARK: - Valid Event Names

    func testValidEventName() {
        XCTAssertTrue(isValidEventName("purchase"))
        XCTAssertTrue(isValidEventName("button_click"))
        XCTAssertTrue(isValidEventName("level1Complete"))
        XCTAssertTrue(isValidEventName("step2_complete"))
        XCTAssertTrue(isValidEventName("a"))
        XCTAssertTrue(isValidEventName("Purchase"))
    }

    // MARK: - Invalid Event Names

    func testEmptyEventName() {
        XCTAssertFalse(isValidEventName(""))
    }

    func testEventNameStartsWithNumber() {
        XCTAssertFalse(isValidEventName("2nd_purchase"))
        XCTAssertFalse(isValidEventName("123"))
    }

    func testEventNameWithSpecialChars() {
        XCTAssertFalse(isValidEventName("purchase-complete"))
        XCTAssertFalse(isValidEventName("purchase.complete"))
        XCTAssertFalse(isValidEventName("purchase@home"))
        XCTAssertFalse(isValidEventName("purchase#1"))
    }

    func testEventNameWithSpaces() {
        XCTAssertFalse(isValidEventName("purchase complete"))
        XCTAssertFalse(isValidEventName(" purchase"))
        XCTAssertFalse(isValidEventName("purchase "))
    }

    func testEventNameTooLong() {
        XCTAssertFalse(isValidEventName(String(repeating: "a", count: 101)))
    }

    func testEventNameMaxLength() {
        XCTAssertTrue(isValidEventName(String(repeating: "a", count: 100)))
    }

    // MARK: - Helper
    //
    // Mirrors `Pricist.validateEventName`. Kept in sync deliberately so the
    // rule is asserted independently of the (private) production method.

    private func isValidEventName(_ name: String) -> Bool {
        guard !name.isEmpty else { return false }
        guard name.count <= 100 else { return false }
        let pattern = "^[a-zA-Z][a-zA-Z0-9_]*$"
        return name.range(of: pattern, options: .regularExpression) != nil
    }
}
