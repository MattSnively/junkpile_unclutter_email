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

    // Results lists put what the user may need to act on first
    func testResultsSortFollowUpsFirst() {
        let order: [UnsubscribeOutcome] = [.confirmed, .pending, .queued, .attempted, .failed]
        XCTAssertEqual(order.sorted { $0.resultsSortOrder < $1.resultsSortOrder },
                       [.failed, .attempted, .queued, .pending, .confirmed])
    }

    func testExplanationNamesTheMethodThatWorked() {
        let decision = Decision(emailId: "1", emailSender: "s", emailSubject: "x", action: .unsubscribe)
        decision.unsubscribeOutcome = .confirmed

        decision.unsubscribeMethod = "mailto"
        XCTAssertEqual(decision.outcomeExplanation, "Unsubscribed by email from your account")
        decision.unsubscribeMethod = "rfc8058"
        XCTAssertEqual(decision.outcomeExplanation, "Unsubscribed with the sender's one-click link")
    }

    func testFailuresTellTheUserWhatToDoNext() {
        let decision = Decision(emailId: "1", emailSender: "s", emailSubject: "x", action: .unsubscribe)

        decision.unsubscribeOutcome = .failed
        XCTAssertTrue(decision.outcomeExplanation.contains("Try the unsubscribe link"))
        decision.unsubscribeOutcome = .attempted
        XCTAssertTrue(decision.outcomeExplanation.contains("unsubscribe on their site"))
    }
}
