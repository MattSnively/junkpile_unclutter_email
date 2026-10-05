import XCTest
@testable import Junkpile

/// The server flags senders who kept emailing after an unsubscribe, or whose
/// unsubscribe never went through; the card warning depends on this decoding
/// correctly and saying when it happened.
final class RepeatSenderTests: XCTestCase {

    private func decodeEmail(_ json: String) throws -> Email {
        try JSONDecoder().decode(Email.self, from: Data(json.utf8))
    }

    private let baseFields = """
        "id": "m1", "sender": "Ranger Station", "subject": "New gear", "htmlBody": null,
        "snippet": "", "unsubscribeUrl": "https://example.com/u", "rawHeaders": null
        """

    func testRegularEmailHasNoWarning() throws {
        let email = try decodeEmail("{\(baseFields)}")
        XCTAssertNil(email.ignoredUnsubscribe)
    }

    func testFlaggedEmailDecodesTheServersTimestamp() throws {
        // JavaScript's toISOString includes milliseconds, which the default
        // ISO8601DateFormatter options reject
        let email = try decodeEmail("""
            {\(baseFields), "ignoredUnsubscribe": { "unsubscribedAt": "2026-09-24T14:32:41.000Z" }}
            """)

        let date = try XCTUnwrap(email.ignoredUnsubscribe?.unsubscribedDate)
        XCTAssertEqual(date.timeIntervalSince1970, 1_790_260_361, accuracy: 1)
    }

    func testWarningNamesWhenTheUserUnsubscribed() {
        let ignored = IgnoredUnsubscribe(unsubscribedAt: "2026-09-24T14:32:41.000Z")
        let expectedDate = ignored.unsubscribedDate!.formatted(date: .abbreviated, time: .omitted)

        XCTAssertTrue(ignored.message.hasPrefix("You unsubscribed on \(expectedDate)"))
        XCTAssertTrue(ignored.message.contains("may not be honoring your request"))
    }

    func testUnreadableDateStillWarns() {
        let ignored = IgnoredUnsubscribe(unsubscribedAt: "not a date")
        XCTAssertTrue(ignored.message.hasPrefix("You unsubscribed before"))
    }

    func testRegularEmailHasNoCardWarning() throws {
        let email = try decodeEmail("{\(baseFields)}")
        XCTAssertNil(email.senderWarning)
    }

    func testUnconfirmedUnsubscribeWarnsToTryAgain() throws {
        let email = try decodeEmail("""
            {\(baseFields), "unconfirmedUnsubscribe": { "attemptedAt": "2026-09-24T14:32:41.000Z" }}
            """)

        let warning = try XCTUnwrap(email.senderWarning)
        XCTAssertEqual(warning.title, "Unsubscribe didn't go through")
        XCTAssertTrue(warning.message.contains("Swipe left to try again"))
        XCTAssertNotNil(email.unconfirmedUnsubscribe?.attemptedDate)
    }

    func testIgnoredUnsubscribeWarnsStillEmailing() throws {
        let email = try decodeEmail("""
            {\(baseFields), "ignoredUnsubscribe": { "unsubscribedAt": "2026-09-24T14:32:41.000Z" }}
            """)
        XCTAssertEqual(email.senderWarning?.title, "Still emailing you")
    }
}
