import XCTest
@testable import Junkpile

final class UnsubscribeOutcomeTests: XCTestCase {

    private func result(success: Bool, attempted: [String]?) -> UnsubscribeResult {
        UnsubscribeResult(success: success, method: nil, attempted: attempted, error: nil)
    }

    // Older servers omit the field; that must not read as a success.
    func testMissingResultIsFailed() {
        XCTAssertEqual(UnsubscribeOutcome.from(nil), .failed)
    }

    func testSuccessIsConfirmed() {
        XCTAssertEqual(UnsubscribeOutcome.from(result(success: true, attempted: ["rfc8058"])), .confirmed)
    }

    func testUnverifiedAttemptsAreAttempted() {
        XCTAssertEqual(UnsubscribeOutcome.from(result(success: false, attempted: ["http-header", "mailto"])), .attempted)
    }

    func testNothingToTryIsFailed() {
        XCTAssertEqual(UnsubscribeOutcome.from(result(success: false, attempted: [])), .failed)
        XCTAssertEqual(UnsubscribeOutcome.from(result(success: false, attempted: nil)), .failed)
    }
}
