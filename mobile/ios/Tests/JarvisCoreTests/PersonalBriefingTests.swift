import Foundation
import XCTest
@testable import JarvisCore

private actor BriefingTrace {
    var executions: [NativeDeviceCapabilityRequest] = []
    var approvals: [NativeDeviceCapabilityRequest] = []

    func execute(_ request: NativeDeviceCapabilityRequest) { executions.append(request) }
    func approve(_ request: NativeDeviceCapabilityRequest) { approvals.append(request) }
}

private struct BriefingAccess: ToolAuthorization {
    func permits(_ action: String) -> Bool {
        [.calendarRead, .reminderRead, .reminderCreate]
            .contains { (id: NativeDeviceCapabilityID) in id.rawValue == action }
    }
}

private struct BriefingApproval: NativeDeviceCapabilityApproval {
    let trace: BriefingTrace
    let permitWrite: Bool

    func approve(_ request: NativeDeviceCapabilityRequest) async -> Bool {
        await trace.approve(request)
        return permitWrite || request.capability != .reminderCreate
    }
}

private struct BriefingAdapter: NativeDeviceCapability {
    let capabilityID: NativeDeviceCapabilityID
    let trace: BriefingTrace
    let response: String?

    func execute(_ request: NativeDeviceCapabilityRequest) async throws -> NativeDeviceCapabilityResult {
        await trace.execute(request)
        guard let response else { throw NativeDeviceCapabilityError.unavailable }
        return .init(content: response)
    }
}

@MainActor final class PersonalBriefingTests: XCTestCase {
    private let window = #"{"start":"2030-01-01T00:00:00Z","end":"2030-01-02T00:00:00Z"}"#
    private let eventPage = """
    {"events":[
      {"title":"One","start":"2030-01-01T12:00:00Z","end":"2030-01-01T13:00:00Z","allDay":false},
      {"title":"Two","start":"2030-01-01T12:30:00Z","end":"2030-01-01T14:00:00Z","allDay":false}
    ],"truncated":false}
    """

    private func makeDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        return url
    }

    private func dispatcher(trace: BriefingTrace, permitWrite: Bool = true,
                            receipt: String? = "synthetic-receipt") throws -> NativeDeviceCapabilityDispatcher {
        try .init(capabilities: [
            BriefingAdapter(capabilityID: .calendarRead, trace: trace, response: eventPage),
            BriefingAdapter(capabilityID: .reminderRead, trace: trace,
                response: #"{"reminders":[{"title":"Synthetic","dueAt":"2030-01-01T18:00:00Z"}],"truncated":false}"#),
            BriefingAdapter(capabilityID: .reminderCreate, trace: trace, response: receipt)
        ], authorization: BriefingAccess(), approval: BriefingApproval(trace: trace, permitWrite: permitWrite))
    }

    private func draft() throws -> BriefingReminder {
        try .init(title: "Synthetic reminder", dueAt: Date(timeIntervalSince1970: 1_893_470_400))
    }

    func testBriefingRunsInOrderAndSameTaskCannotReplayCompletedWrite() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let trace = BriefingTrace(), id = UUID()
        let dispatcher = try dispatcher(trace: trace)
        let task = PersonalBriefing(id: id, checkpointDirectory: directory, dispatcher: dispatcher)
        let analysis = try await task.prepare(windowInput: window, reminder: draft())
        XCTAssertEqual(analysis.events.count, 2)
        XCTAssertEqual(analysis.reminders.count, 1)
        XCTAssertEqual(analysis.overlappingEventPairs, 1)
        XCTAssertFalse(analysis.isPartial)

        let receipt = try await task.createPreparedReminder()
        XCTAssertEqual(receipt.content, "synthetic-receipt")
        let reopened = PersonalBriefing(id: id, checkpointDirectory: directory, dispatcher: dispatcher)
        let state = try await reopened.writeState()
        XCTAssertEqual(state, .completed)
        do {
            _ = try await reopened.createPreparedReminder()
            XCTFail("A reopened task must reject a second write")
        } catch { XCTAssertEqual(error as? BriefingError, .writeAlreadyAttempted) }

        let approvals = await trace.approvals
        let executions = await trace.executions
        XCTAssertEqual(executions.map(\.capability), [.calendarRead, .reminderRead, .reminderCreate])
        XCTAssertEqual(approvals, executions)
    }

    func testDeclinedWriteDoesNotReachProviderOrConsumeCheckpoint() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let trace = BriefingTrace()
        let task = PersonalBriefing(id: UUID(), checkpointDirectory: directory,
                                   dispatcher: try dispatcher(trace: trace, permitWrite: false))
        _ = try await task.prepare(windowInput: window, reminder: draft())
        do {
            _ = try await task.createPreparedReminder()
            XCTFail("Declined write must fail")
        } catch { XCTAssertEqual(error as? NativeDeviceCapabilityError, .approvalDeclined) }
        let state = try await task.writeState()
        let executions = await trace.executions
        XCTAssertEqual(state, .ready)
        XCTAssertEqual(executions.map(\.capability), [.calendarRead, .reminderRead])
    }

    func testUncertainWriteRequiresReconciliationAfterReopen() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let trace = BriefingTrace(), id = UUID()
        let dispatcher = try dispatcher(trace: trace, receipt: nil)
        let task = PersonalBriefing(id: id, checkpointDirectory: directory, dispatcher: dispatcher)
        _ = try await task.prepare(windowInput: window, reminder: draft())
        do {
            _ = try await task.createPreparedReminder()
            XCTFail("Synthetic failure must propagate")
        } catch { XCTAssertEqual(error as? NativeDeviceCapabilityError, .unavailable) }
        let reopened = PersonalBriefing(id: id, checkpointDirectory: directory, dispatcher: dispatcher)
        let state = try await reopened.writeState()
        XCTAssertEqual(state, .requiresReconciliation)
    }
}
