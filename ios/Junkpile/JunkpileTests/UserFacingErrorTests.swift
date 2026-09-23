import XCTest
@testable import Junkpile

/// The error screen's button runs `action`, so a wrong mapping here strands the
/// user (e.g. "Try Again" forever on an expired Gmail grant).
final class UserFacingErrorTests: XCTestCase {

    func testEachErrorRoutesToItsRecoveryAction() {
        let expectations: [(APIError, RecoveryAction)] = [
            (.networkError("offline"), .retry),
            (.authenticationRequired, .signIn),
            (.tokenExpired, .signIn),
            (.invalidResponse, .retry),
            (.serverError("boom"), .retry),
            (.noEmailsFound, .showStats),
            (.gmailNotConfigured, .goHome),
            (.gmailNotConnected, .connectGmail),
            (.gmailReauthRequired, .connectGmail),
            (.rateLimited(retryAfterSeconds: 10), .retry),
            (.emailFetchFailed, .retry),
        ]

        for (error, action) in expectations {
            XCTAssertEqual(UserFacingError.from(error).action, action, "\(error)")
        }
    }

    func testRateLimitHoldsRetryForServerCountdown() {
        XCTAssertEqual(UserFacingError.from(.rateLimited(retryAfterSeconds: 42)).retryAfterSeconds, 42)
    }

    func testServerErrorBacksOffBeforeRetry() {
        XCTAssertNotNil(UserFacingError.from(.serverError("boom")).retryAfterSeconds)
    }

    func testImmediatelyRetryableErrorsDoNotDelay() {
        XCTAssertNil(UserFacingError.from(.networkError("offline")).retryAfterSeconds)
        XCTAssertNil(UserFacingError.from(.emailFetchFailed).retryAfterSeconds)
    }
}
