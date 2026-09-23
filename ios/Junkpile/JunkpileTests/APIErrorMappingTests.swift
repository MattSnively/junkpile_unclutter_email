import XCTest
@testable import Junkpile

/// The backend's error `code` is the contract the error screens branch on, so
/// a typo or a dropped case here silently sends users to the wrong recovery.
final class APIErrorMappingTests: XCTestCase {

    private func body(_ code: String?, error: String? = nil, retryAfter: Int? = nil) -> APIErrorBody {
        APIErrorBody(code: code, error: error, retryAfterSeconds: retryAfter)
    }

    // APIError is not Equatable (and making it so just for tests would widen
    // the app's API), so compare the case names with associated values.
    private func assertMaps(
        _ body: APIErrorBody?,
        status: Int,
        to expected: APIError,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let actual = APIError.from(body: body, statusCode: status)
        XCTAssertEqual(String(describing: actual), String(describing: expected), file: file, line: line)
    }

    func testKnownCodesMapToTypedErrors() {
        assertMaps(body("AUTH_REQUIRED"), status: 401, to: .authenticationRequired)
        assertMaps(body("AUTH_INVALID"), status: 401, to: .tokenExpired)
        assertMaps(body("OAUTH_TOKEN_EXPIRED"), status: 401, to: .gmailReauthRequired)
        assertMaps(body("OAUTH_SCOPE_INSUFFICIENT"), status: 403, to: .gmailReauthRequired)
        assertMaps(body("GMAIL_NOT_CONNECTED"), status: 400, to: .gmailNotConnected)
        assertMaps(body("EMAIL_FETCH_FAILED"), status: 502, to: .emailFetchFailed)
        assertMaps(body("SERVER_NOT_CONFIGURED"), status: 500, to: .gmailNotConfigured)
        assertMaps(body("VALIDATION_ERROR", error: "bad id"), status: 400, to: .serverError("bad id"))
    }

    func testRateLimitCarriesServerRetryAfter() {
        assertMaps(body("RATE_LIMITED", retryAfter: 30), status: 429, to: .rateLimited(retryAfterSeconds: 30))
    }

    func testRateLimitWithoutRetryAfterUsesDefault() {
        assertMaps(
            body("RATE_LIMITED"),
            status: 429,
            to: .rateLimited(retryAfterSeconds: APIError.defaultRetryAfterSeconds)
        )
    }

    func testCodeTakesPrecedenceOverStatus() {
        assertMaps(body("GMAIL_NOT_CONNECTED"), status: 401, to: .gmailNotConnected)
    }

    // Older server builds and proxy error pages send no code at all.
    func testMissingOrUnknownCodeFallsBackToStatus() {
        assertMaps(nil, status: 401, to: .authenticationRequired)
        assertMaps(body("SOMETHING_NEW"), status: 403, to: .tokenExpired)
        assertMaps(nil, status: 429, to: .rateLimited(retryAfterSeconds: APIError.defaultRetryAfterSeconds))
        assertMaps(nil, status: 500, to: .serverError("HTTP 500"))
    }
}
