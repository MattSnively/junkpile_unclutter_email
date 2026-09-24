import XCTest
import SwiftData
@testable import Junkpile

/// Stands in for the backend. An actor because the view model sends
/// confirmed unsubscribes concurrently.
private actor FakeDecisionSync: DecisionSyncing {
    private(set) var sentEmailIds: [String] = []
    /// Email IDs whose request asked for the message to be trashed
    private(set) var trashRequestedEmailIds: [String] = []
    private let unreachableEmailIds: Set<String>

    init(unreachableEmailIds: Set<String> = []) {
        self.unreachableEmailIds = unreachableEmailIds
    }

    func recordDecision(emailId: String, action: DecisionAction, trash: Bool) async throws -> DecisionAPIResponse {
        if unreachableEmailIds.contains(emailId) {
            throw APIError.networkError("offline")
        }
        sentEmailIds.append(emailId)
        if trash {
            trashRequestedEmailIds.append(emailId)
        }
        return DecisionAPIResponse(
            success: true,
            message: nil,
            error: nil,
            unsubscribeResult: UnsubscribeResult(success: true, method: "rfc8058", attempted: ["rfc8058"], error: nil),
            trashed: trash ? true : nil
        )
    }
}

/// The review step is what keeps an unsubscribe from being sent without the
/// user's say-so, so these pin down what is sent, withdrawn, and kept queued.
@MainActor
final class SwipeViewModelQueueTests: XCTestCase {

    // Held so the in-memory store outlives setUp
    private var container: ModelContainer!
    private var context: ModelContext { container.mainContext }

    override func setUp() {
        super.setUp()
        container = PersistenceController(inMemory: true).container
    }

    private func email(_ id: String) -> Email {
        Email(id: id, sender: "Sender \(id)", subject: "Subject \(id)", htmlBody: nil, snippet: nil, unsubscribeUrl: "https://example.com/\(id)", rawHeaders: nil)
    }

    private func makeViewModel(_ sync: FakeDecisionSync) -> SwipeViewModel {
        let viewModel = SwipeViewModel(decisionSync: sync)
        viewModel.configure(with: context)
        return viewModel
    }

    private func storedDecisions() -> [Decision] {
        (try? context.fetch(FetchDescriptor<Decision>())) ?? []
    }

    func testUnsubscribeSwipeIsQueuedNotSent() async {
        let sync = FakeDecisionSync()
        let viewModel = makeViewModel(sync)

        viewModel.recordDecision(email: email("a"), action: .unsubscribe)

        XCTAssertEqual(viewModel.queuedUnsubscribes.map(\.emailId), ["a"])
        XCTAssertEqual(viewModel.queuedUnsubscribes.first?.unsubscribeOutcome, .queued)
        let sent = await sync.sentEmailIds
        XCTAssertTrue(sent.isEmpty)
    }

    func testConfirmSendsCheckedAndWithdrawsUnchecked() async {
        let sync = FakeDecisionSync()
        let viewModel = makeViewModel(sync)
        for id in ["a", "b", "c"] {
            viewModel.recordDecision(email: email(id), action: .unsubscribe)
        }
        viewModel.toggleQueued(viewModel.queuedUnsubscribes[1])

        await viewModel.sendQueuedUnsubscribes()

        let sent = await sync.sentEmailIds
        XCTAssertEqual(Set(sent), ["a", "c"])
        XCTAssertTrue(viewModel.queuedUnsubscribes.isEmpty)
        // The unchecked swipe is gone, as if it never happened
        XCTAssertEqual(Set(storedDecisions().map(\.emailId)), ["a", "c"])
        XCTAssertTrue(storedDecisions().allSatisfy { $0.unsubscribeOutcome == .confirmed })
        XCTAssertEqual(viewModel.unsubscribeCount, 2)
    }

    func testUnreachableServerLeavesDecisionQueuedForRetry() async {
        let sync = FakeDecisionSync(unreachableEmailIds: ["b"])
        let viewModel = makeViewModel(sync)
        viewModel.recordDecision(email: email("a"), action: .unsubscribe)
        viewModel.recordDecision(email: email("b"), action: .unsubscribe)

        await viewModel.sendQueuedUnsubscribes()

        XCTAssertEqual(viewModel.queuedUnsubscribes.map(\.emailId), ["b"])
        XCTAssertEqual(viewModel.queuedUnsubscribes.first?.unsubscribeOutcome, .queued)
        XCTAssertEqual(viewModel.unsentAfterLastSend, 1)
        XCTAssertNil(viewModel.sendProgress)
    }

    func testQueueSurvivesRelaunch() {
        let first = makeViewModel(FakeDecisionSync())
        first.recordDecision(email: email("a"), action: .unsubscribe)
        first.recordDecision(email: email("k"), action: .keep)

        // A fresh view model on the same store stands in for a relaunch
        let relaunched = makeViewModel(FakeDecisionSync())

        XCTAssertEqual(relaunched.queuedUnsubscribes.map(\.emailId), ["a"])
    }

    // Deleting mail must be a deliberate choice
    func testTrashIsNotRequestedByDefault() async {
        let sync = FakeDecisionSync()
        let viewModel = makeViewModel(sync)
        viewModel.recordDecision(email: email("a"), action: .unsubscribe)

        await viewModel.sendQueuedUnsubscribes()

        let trashed = await sync.trashRequestedEmailIds
        XCTAssertTrue(trashed.isEmpty)
        XCTAssertNil(storedDecisions().first?.movedToTrash)
    }

    func testTrashAppliesOnlyToCheckedSendersWhenChosen() async {
        let sync = FakeDecisionSync()
        let viewModel = makeViewModel(sync)
        viewModel.recordDecision(email: email("a"), action: .unsubscribe)
        viewModel.recordDecision(email: email("b"), action: .unsubscribe)
        viewModel.toggleQueued(viewModel.queuedUnsubscribes[1])
        viewModel.alsoMoveToTrash = true

        await viewModel.sendQueuedUnsubscribes()

        let trashed = await sync.trashRequestedEmailIds
        XCTAssertEqual(trashed, ["a"])
        XCTAssertEqual(storedDecisions().first { $0.emailId == "a" }?.movedToTrash, true)
    }

    func testDiscardWithdrawsEverythingWithoutSending() async {
        let sync = FakeDecisionSync()
        let viewModel = makeViewModel(sync)
        viewModel.recordDecision(email: email("a"), action: .unsubscribe)
        viewModel.recordDecision(email: email("b"), action: .unsubscribe)

        viewModel.discardQueuedUnsubscribes()

        let sent = await sync.sentEmailIds
        XCTAssertTrue(sent.isEmpty)
        XCTAssertTrue(viewModel.queuedUnsubscribes.isEmpty)
        XCTAssertTrue(storedDecisions().isEmpty)
    }
}
