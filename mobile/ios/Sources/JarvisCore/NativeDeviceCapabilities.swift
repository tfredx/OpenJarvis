import Foundation

/// Fixed identifiers for future native adapters. The model cannot register or
/// construct a new capability by supplying a resource string.
public enum NativeDeviceCapabilityID: String, Codable, CaseIterable, Sendable, Equatable {
    case calendarRead = "device.calendar.read"
    case reminderCreate = "device.reminder.create"
    case contactsRead = "device.contacts.read"
    case photosRead = "device.photos.read"
    case locationRead = "device.location.read"
}

public struct NativeDeviceCapabilityRequest: Sendable, Equatable {
    public let capability: NativeDeviceCapabilityID
    public let input: String
    public init(capability: NativeDeviceCapabilityID, input: String) {
        self.capability = capability; self.input = input
    }
}

public struct NativeDeviceCapabilityResult: Sendable, Equatable {
    public let content: String
    public init(content: String) { self.content = content }
}

/// A platform adapter implements one fixed capability and validates its own
/// structured input before calling a protected iOS framework API.
public protocol NativeDeviceCapability: Sendable {
    var capabilityID: NativeDeviceCapabilityID { get }
    func execute(_ request: NativeDeviceCapabilityRequest) async throws -> NativeDeviceCapabilityResult
}

/// The app must obtain a fresh human decision for every capability invocation.
/// OS permission prompts remain a separate requirement of each concrete adapter.
public protocol NativeDeviceCapabilityApproval: Sendable {
    func approve(_ request: NativeDeviceCapabilityRequest) async -> Bool
}

public struct DefaultDenyNativeDeviceCapabilityApproval: NativeDeviceCapabilityApproval {
    public init() {}
    public func approve(_ request: NativeDeviceCapabilityRequest) async -> Bool { false }
}

public enum NativeDeviceCapabilityError: Error, Equatable {
    case unsupported, unavailable, denied, approvalDeclined, invalidInput, invalidResult, duplicateRegistration
}

/// Permission-neutral dispatcher seam. With its defaults, no native adapter is
/// registered, local policy denies all device capability IDs, and approvals fail
/// closed. This type does not request iOS permissions or run in the background.
public struct NativeDeviceCapabilityDispatcher: Sendable {
    private let capabilities: [NativeDeviceCapabilityID: any NativeDeviceCapability]
    private let authorization: any ToolAuthorization
    private let approval: any NativeDeviceCapabilityApproval

    public init(capabilities: [any NativeDeviceCapability] = [],
                authorization: any ToolAuthorization = LocalToolAuthorization(),
                approval: any NativeDeviceCapabilityApproval = DefaultDenyNativeDeviceCapabilityApproval()) throws {
        var registry: [NativeDeviceCapabilityID: any NativeDeviceCapability] = [:]
        for capability in capabilities {
            guard registry[capability.capabilityID] == nil else {
                throw NativeDeviceCapabilityError.duplicateRegistration
            }
            registry[capability.capabilityID] = capability
        }
        self.capabilities = registry; self.authorization = authorization; self.approval = approval
    }

    public func invoke(capabilityID rawID: String, input: String) async throws -> NativeDeviceCapabilityResult {
        try Task.checkCancellation()
        guard let capabilityID = NativeDeviceCapabilityID(rawValue: rawID) else {
            throw NativeDeviceCapabilityError.unsupported
        }
        guard input.count <= 2000, !input.contains("\u{0000}") else {
            throw NativeDeviceCapabilityError.invalidInput
        }
        guard let capability = capabilities[capabilityID] else {
            throw NativeDeviceCapabilityError.unavailable
        }
        guard authorization.permits(capabilityID.rawValue) else {
            throw NativeDeviceCapabilityError.denied
        }

        let request = NativeDeviceCapabilityRequest(capability: capabilityID, input: input)
        let approved = await approval.approve(request)
        try Task.checkCancellation()
        guard approved else { throw NativeDeviceCapabilityError.approvalDeclined }
        guard authorization.permits(capabilityID.rawValue) else {
            throw NativeDeviceCapabilityError.denied
        }
        let result = try await capability.execute(request)
        guard result.content.count <= 16000 else { throw NativeDeviceCapabilityError.invalidResult }
        return result
    }
}
