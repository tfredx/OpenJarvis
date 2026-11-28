import XCTest
@testable import JarvisCore

private struct GrantCalendarRead: ToolAuthorization, Sendable {
    func permits(_ action: String) -> Bool { action == NativeDeviceCapabilityID.calendarRead.rawValue }
}

private actor RecordingNativeCapability: NativeDeviceCapability {
    nonisolated let capabilityID: NativeDeviceCapabilityID
    private let output: String
    private var requests: [NativeDeviceCapabilityRequest] = []

    init(_ capabilityID: NativeDeviceCapabilityID, output: String = "Synthetic calendar result") {
        self.capabilityID = capabilityID; self.output = output
    }
    func execute(_ request: NativeDeviceCapabilityRequest) async throws -> NativeDeviceCapabilityResult {
        requests.append(request)
        return NativeDeviceCapabilityResult(content: output)
    }
    func recordedRequests() -> [NativeDeviceCapabilityRequest] { requests }
}

private actor RecordingCapabilityApproval: NativeDeviceCapabilityApproval {
    private var allowed: Bool
    private var requests: [NativeDeviceCapabilityRequest] = []
    init(allowed: Bool) { self.allowed = allowed }
    func approve(_ request: NativeDeviceCapabilityRequest) async -> Bool {
        requests.append(request)
        return allowed
    }
    func setAllowed(_ allowed: Bool) { self.allowed = allowed }
    func recordedRequests() -> [NativeDeviceCapabilityRequest] { requests }
}

private struct CancellingApproval: NativeDeviceCapabilityApproval {
    func approve(_ request: NativeDeviceCapabilityRequest) async -> Bool {
        withUnsafeCurrentTask { $0?.cancel() }
        return true
    }
}

@MainActor final class NativeDeviceCapabilitiesTests: XCTestCase {
    func testDeviceActionsAreDefaultDeniedEvenWhenAdapterIsRegistered() async throws {
        let capability = RecordingNativeCapability(.calendarRead)
        let approval = RecordingCapabilityApproval(allowed: true)
        let dispatcher = try NativeDeviceCapabilityDispatcher(capabilities: [capability], approval: approval)

        do {
            _ = try await dispatcher.invoke(capabilityID: NativeDeviceCapabilityID.calendarRead.rawValue, input: "next week")
            XCTFail("Local tool policy must default-deny new device capabilities")
        } catch { XCTAssertEqual(error as? NativeDeviceCapabilityError, .denied) }
        let capabilityRequests = await capability.recordedRequests()
        let approvalRequests = await approval.recordedRequests()
        XCTAssertTrue(capabilityRequests.isEmpty)
        XCTAssertTrue(approvalRequests.isEmpty)
        for id in NativeDeviceCapabilityID.allCases {
            XCTAssertFalse(LocalToolAuthorization().permits(id.rawValue))
        }
    }

    func testUnknownAndUnregisteredCapabilitiesFailBeforeApproval() async throws {
        let approval = RecordingCapabilityApproval(allowed: true)
        let noAdapters = try NativeDeviceCapabilityDispatcher(authorization: GrantCalendarRead(), approval: approval)
        do {
            _ = try await noAdapters.invoke(capabilityID: NativeDeviceCapabilityID.calendarRead.rawValue, input: "")
            XCTFail("Unregistered native capability must not execute")
        } catch { XCTAssertEqual(error as? NativeDeviceCapabilityError, .unavailable) }
        do {
            _ = try await noAdapters.invoke(capabilityID: "device.calendar.read;file.read", input: "")
            XCTFail("Unknown model supplied action must fail closed")
        } catch { XCTAssertEqual(error as? NativeDeviceCapabilityError, .unsupported) }
        let approvalRequests = await approval.recordedRequests()
        XCTAssertTrue(approvalRequests.isEmpty)
    }

    func testHumanApprovalIsRequiredForEveryInvocation() async throws {
        let capability = RecordingNativeCapability(.calendarRead)
        let approval = RecordingCapabilityApproval(allowed: false)
        let dispatcher = try NativeDeviceCapabilityDispatcher(
            capabilities: [capability], authorization: GrantCalendarRead(), approval: approval
        )
        let input = "next week"
        do {
            _ = try await dispatcher.invoke(capabilityID: NativeDeviceCapabilityID.calendarRead.rawValue, input: input)
            XCTFail("Declined request must not execute")
        } catch { XCTAssertEqual(error as? NativeDeviceCapabilityError, .approvalDeclined) }
        let declinedRequests = await capability.recordedRequests()
        XCTAssertTrue(declinedRequests.isEmpty)

        await approval.setAllowed(true)
        let first = try await dispatcher.invoke(capabilityID: NativeDeviceCapabilityID.calendarRead.rawValue, input: input)
        let second = try await dispatcher.invoke(capabilityID: NativeDeviceCapabilityID.calendarRead.rawValue, input: input)
        XCTAssertEqual(first.content, "Synthetic calendar result")
        XCTAssertEqual(second, first)
        let approvalRequests = await approval.recordedRequests()
        let capabilityRequests = await capability.recordedRequests()
        XCTAssertEqual(approvalRequests.count, 3)
        XCTAssertEqual(capabilityRequests.count, 2)
        XCTAssertTrue(capabilityRequests.allSatisfy { $0.input == input })
    }

    func testMalformedOrOversizedInputAndDuplicateRegistrationAreRejected() async throws {
        let capability = RecordingNativeCapability(.calendarRead)
        let approval = RecordingCapabilityApproval(allowed: true)
        let dispatcher = try NativeDeviceCapabilityDispatcher(
            capabilities: [capability], authorization: GrantCalendarRead(), approval: approval
        )
        for input in [String(repeating: "x", count: 2001), "bad\u{0000}input"] {
            do {
                _ = try await dispatcher.invoke(capabilityID: NativeDeviceCapabilityID.calendarRead.rawValue, input: input)
                XCTFail("Malformed or oversized input must fail before approval")
            } catch { XCTAssertEqual(error as? NativeDeviceCapabilityError, .invalidInput) }
        }
        let approvalRequests = await approval.recordedRequests()
        XCTAssertTrue(approvalRequests.isEmpty)
        XCTAssertThrowsError(try NativeDeviceCapabilityDispatcher(capabilities: [capability, capability])) {
            XCTAssertEqual($0 as? NativeDeviceCapabilityError, .duplicateRegistration)
        }
    }

    func testOversizedNativeOutputIsNotReturnedToAgent() async throws {
        let capability = RecordingNativeCapability(.calendarRead, output: String(repeating: "x", count: 16001))
        let dispatcher = try NativeDeviceCapabilityDispatcher(
            capabilities: [capability], authorization: GrantCalendarRead(),
            approval: RecordingCapabilityApproval(allowed: true)
        )
        do {
            _ = try await dispatcher.invoke(capabilityID: NativeDeviceCapabilityID.calendarRead.rawValue, input: "")
            XCTFail("Oversized native output must be rejected")
        } catch { XCTAssertEqual(error as? NativeDeviceCapabilityError, .invalidResult) }
    }

    func testCancellationDuringApprovalPreventsNativeExecution() async throws {
        let calendar = RecordingNativeCapability(.calendarRead)
        let dispatcher = try NativeDeviceCapabilityDispatcher(
            capabilities: [calendar], authorization: GrantCalendarRead(), approval: CancellingApproval()
        )
        let invocation = Task {
            try await dispatcher.invoke(capabilityID: NativeDeviceCapabilityID.calendarRead.rawValue, input: "synthetic")
        }
        do {
            _ = try await invocation.value
            XCTFail("Cancellation must prevent execution after approval")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
        let requests = await calendar.recordedRequests()
        XCTAssertTrue(requests.isEmpty)
    }

    func testCalendarWindowAcceptsOnlyBoundedUTCIntervals() throws {
        let valid = #"{"start":"2026-11-27T00:00:00Z","end":"2026-12-04T00:00:00Z"}"#
        let window = try CalendarReadWindow(input: valid)
        XCTAssertEqual(window.end.timeIntervalSince(window.start), 604800)
        for invalid in [
            valid.replacingOccurrences(of: "12-04", with: "12-05"),
            valid.replacingOccurrences(of: "12-04", with: "11-27"),
            valid.replacingOccurrences(of: "12-04", with: "11-26"),
            valid.replacingOccurrences(of: "Z", with: "-05:00"),
            valid.dropLast() + #", "calendar":"untrusted"}"#,
            "{}"
        ] {
            XCTAssertThrowsError(try CalendarReadWindow(input: invalid)) {
                XCTAssertEqual($0 as? NativeDeviceCapabilityError, .invalidInput)
            }
        }
    }
}
