import SwiftUI
import FoundationModels
import JarvisCore
import AppIntents
import AVFoundation
import UIKit

struct AppleEngine: Intelligence {
    func decide(prompt: String) async throws -> Decision {
        var text = try await generate(
            prompt: prompt,
            instructions: "You are a careful local assistant. Follow the requested JSON schema; output JSON only."
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("```"), let first = text.firstIndex(of: "\n"),
           let last = text.range(of: "```", options: .backwards), last.lowerBound > first {
            text = String(text[text.index(after: first)..<last.lowerBound])
        }
        do { return try JSONDecoder().decode(Decision.self, from: Data(text.utf8)) }
        catch { throw InferenceFailure.malformedDecision }
    }

    func directReply(prompt: String) async throws -> String {
        try await generate(prompt: prompt, instructions: "Answer the user's request directly in plain text.")
    }

    private func generate(prompt: String, instructions: String) async throws -> String {
        try Task.checkCancellation()
        guard SystemLanguageModel.default.isAvailable else { throw InferenceFailure.modelUnavailable }
        let session = LanguageModelSession(instructions: instructions)
        do { return try await session.respond(to: prompt).content }
        catch is CancellationError { throw CancellationError() }
        catch {
            try Task.checkCancellation()
            throw InferenceFailure.generation
        }
    }
}

@MainActor final class AppState: ObservableObject {
    @Published private(set) var snapshot = Snapshot()
    @Published private(set) var error = ""
    @Published private(set) var busy = false
    @Published private(set) var ready = false
    @Published private(set) var sessions: [SessionSummary] = []
    @Published private(set) var activeID: UUID?
    @Published private(set) var diagnosticReport = ""
    @Published private(set) var diagnosticsRunning = false
    @Published var input = ""
    private var coordinator: SessionCoordinator?
    private var task: Task<Void, Never>?
    private let speaker = AVSpeechSynthesizer()
    private var applicationSupportRoot: URL?
    static let shared = AppState()

    var canChangeSessions: Bool {
        !busy && !diagnosticsRunning && ready && coordinator?.canChangeSessions == true
    }
    var activeTitle: String { sessions.first { $0.id == activeID }?.title ?? "Jarvis" }

    private init() {
        do {
            let root = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("Jarvis", isDirectory: true)
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            var directory = root; var values = URLResourceValues(); values.isExcludedFromBackup = true
            try directory.setResourceValues(values)
            try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: root.path)
            applicationSupportRoot = root
            coordinator = try SessionCoordinator(root: root, engine: AppleEngine(), bridge: makeConversationBridge(), authorization: makeToolAuthorization())
            refresh()
        } catch { self.error = error.localizedDescription }
    }
    private func refresh() {
        guard let coordinator, coordinator.isReady else {
            ready = false; snapshot = Snapshot(); sessions = []; activeID = nil; input = ""
            speaker.stopSpeaking(at: .immediate)
            return
        }
        if activeID != coordinator.activeID {
            input = ""; speaker.stopSpeaking(at: .immediate)
        }
        snapshot = coordinator.snapshot; sessions = coordinator.sessions; activeID = coordinator.activeID; ready = true
    }
    func prefill(_ request: String) -> Bool {
        guard canChangeSessions else { return false }
        input = request
        return true
    }
    func submit() {
        guard canChangeSessions else { return }
        let request = input
        guard !request.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        input = ""
        perform { try await $0.submit(request) }
    }
    func resume() { perform { try await $0.resume() } }
    func approval(_ allow: Bool) { perform { try await $0.approve(allow) } }
    func cancel() { if busy { task?.cancel() } else { perform { try await $0.discard() } } }
    func eraseAll() { change { try $0.eraseAll() } }
    func delete(_ id: UUID) { perform { try await $0.deleteMemory(id) } }
    func createSession(title: String) { change { try $0.create(title: title) } }
    func selectSession(_ id: UUID) { change { try $0.select(id) } }
    func renameSession(_ id: UUID, title: String) { change { try $0.rename(id, title: title) } }
    func deleteSession(_ id: UUID) { change { try $0.delete(id) } }
    func speak(_ text: String) { speaker.stopSpeaking(at: .immediate); let utterance = AVSpeechUtterance(string: text); utterance.rate = AVSpeechUtteranceDefaultSpeechRate; speaker.speak(utterance) }

    func runDiagnostics() async {
        guard !diagnosticsRunning, canChangeSessions, let applicationSupportRoot else { return }
        diagnosticReport = ""
        diagnosticsRunning = true
        defer { diagnosticsRunning = false }
        do {
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
            let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
            let environment = InferenceDiagnosticEnvironment(
                device: UIDevice.current.model,
                operatingSystem: ProcessInfo.processInfo.operatingSystemVersionString,
                appVersion: version,
                build: build
            )
            let report = try await PhysicalInferenceDiagnostics.run(
                engine: AppleEngine(), root: applicationSupportRoot,
                environment: environment, bridge: makeConversationBridge(),
                authorization: makeToolAuthorization(),
                directReply: { try await AppleEngine().directReply(prompt: $0) }
            )
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            diagnosticReport = String(decoding: try encoder.encode(report), as: UTF8.self)
        } catch {
            diagnosticReport = "Diagnostics could not complete. No conversation content was included."
        }
    }

    private func change(_ work: (SessionCoordinator) throws -> Void) {
        guard canChangeSessions, let coordinator else { return }
        error = ""
        do { try work(coordinator) } catch { self.error = error.localizedDescription }
        refresh()
    }
    private func perform(_ work: @escaping @MainActor (SessionCoordinator) async throws -> Void) {
        guard !busy, !diagnosticsRunning, ready, let coordinator else { return }
        busy = true; error = ""
        task = Task {
            defer { refresh(); busy = false; task = nil }
            do { try await work(coordinator) } catch { self.error = error.localizedDescription }
        }
    }
}

struct AskJarvisIntent: AppIntent {
    static let title: LocalizedStringResource = "Ask Jarvis"
    static let description = IntentDescription("Open Jarvis with a request ready to review and run locally.")
    static let openAppWhenRun = true
    @Parameter(title: "Request") var request: String
    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        guard AppState.shared.prefill(request) else {
            return .result(dialog: "Resolve the current Jarvis task before adding another request.")
        }
        return .result(dialog: "Your request is ready in the selected Jarvis conversation.")
    }
}
struct JarvisShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: AskJarvisIntent(), phrases: ["Ask \(.applicationName)", "Open \(.applicationName)"], shortTitle: "Ask Jarvis", systemImageName: "sparkles")
    }
}
@main struct OpenJarvisApp: App {
    @StateObject private var model = AppState.shared
    var body: some Scene { WindowGroup { RootView(model: model) } }
}
struct RootView: View {
    @ObservedObject var model: AppState
    @State private var confirmErase = false
    var body: some View {
        TabView {
            NavigationStack {
                VStack(spacing: 12) {
                    HStack { Circle().fill(SystemLanguageModel.default.isAvailable ? Color.green : Color.orange).frame(width: 8, height: 8); Text(SystemLanguageModel.default.isAvailable ? "On-device model ready" : "On-device model unavailable"); Spacer(); Text(model.snapshot.status.rawValue.capitalized) }.font(.caption).foregroundStyle(.secondary)
                    ScrollViewReader { proxy in
                        ScrollView { LazyVStack(alignment: .leading, spacing: 14) {
                            if model.snapshot.messages.isEmpty { VStack(spacing: 14) { Image(systemName: "waveform.circle").font(.system(size: 72)).foregroundStyle(.cyan); Text("How can I assist?").font(.title2.bold()); Text("Private by default. Your requests stay on this device.").font(.subheadline).foregroundStyle(.secondary) }.frame(maxWidth: .infinity).padding(.vertical, 60) }
                            ForEach(model.snapshot.messages) { message in
                                VStack(alignment: .leading, spacing: 5) { HStack { Text(message.role.capitalized).font(.caption.bold()).foregroundStyle(.secondary); Spacer(); if message.role == "assistant" { Button { model.speak(message.text) } label: { Image(systemName: "speaker.wave.2") }.accessibilityLabel("Read answer aloud") } }; Text(message.text).textSelection(.enabled) }.padding(12).frame(maxWidth: .infinity, alignment: .leading).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14)).id(message.id)
                            }
                        }}.onChange(of: model.snapshot.messages.count) { _, _ in if let id = model.snapshot.messages.last?.id { proxy.scrollTo(id, anchor: .bottom) } }
                    }
                    if let pending = model.snapshot.pending { VStack(alignment: .leading) { Text("Approve memory write?").font(.headline); Text(pending.value); HStack { Button("Deny", role: .cancel) { model.approval(false) }; Spacer(); Button("Approve") { model.approval(true) }.buttonStyle(.borderedProminent) } }.padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12)).disabled(model.busy) }
                    if model.busy { HStack { ProgressView(); Text("Working locally"); Spacer(); Button("Cancel") { model.cancel() } } }
                    else if model.snapshot.status == .running { HStack { Button("Resume interrupted task") { model.resume() }; Spacer(); Button("Discard", role: .destructive) { model.cancel() } } }
                    HStack(alignment: .bottom) { TextField("Ask Jarvis…", text: $model.input, axis: .vertical).lineLimit(1...5).textFieldStyle(.roundedBorder); Button { model.submit() } label: { Image(systemName: "arrow.up.circle.fill").font(.system(size: 34)) }.accessibilityLabel("Send") }.disabled(!model.canChangeSessions)
                }.padding().navigationTitle(model.activeTitle)
            }.tabItem { Label("Chat", systemImage: "bubble.left.and.bubble.right") }
            SessionListView(model: model).tabItem { Label("Sessions", systemImage: "rectangle.stack") }
            NavigationStack { List { Section("Task state") { LabeledContent("Status", value: model.snapshot.status.rawValue); LabeledContent("Model decisions", value: String(model.snapshot.steps)); LabeledContent("Pending approval", value: model.snapshot.pending == nil ? "No" : "Yes") }; Section("Execution") { Text("Foreground execution and manual checkpoint recovery. Continuous background scheduling is not enabled in this release.") } }.navigationTitle("Activity") }.tabItem { Label("Activity", systemImage: "waveform.path") }
            NavigationStack { List { if model.snapshot.notes.isEmpty { Text("Approved memories in this conversation appear here.").foregroundStyle(.secondary) }; ForEach(model.snapshot.notes) { note in HStack { Text(note.text); Spacer(); Button(role: .destructive) { model.delete(note.id) } label: { Image(systemName: "trash") }.disabled(model.busy || model.snapshot.status == .running || model.snapshot.status == .approval) } } }.navigationTitle("Memory · " + model.activeTitle) }.tabItem { Label("Memory", systemImage: "brain") }
            NavigationStack { List { Section("Intelligence") { LabeledContent("Provider", value: "Apple on-device"); LabeledContent("Cloud fallback", value: "Off") }; Section("Build") { LabeledContent("Version", value: "0.3.2"); LabeledContent("Conversation bridge", value: conversationBridgeLabel); Text("Experimental mobile prototype. Agent orchestration remains Swift.") }; Section("Device diagnostics") { Text("Runs synthetic prompts with synthetic memory in an isolated temporary session. The shareable report contains timing, state and context-selection checks, not prompts, answers or personal conversation data.").font(.footnote).foregroundStyle(.secondary); Button(model.diagnosticsRunning ? "Running diagnostics…" : "Run local inference diagnostics") { Task { await model.runDiagnostics() } }.disabled(model.diagnosticsRunning || !model.canChangeSessions); if !model.diagnosticReport.isEmpty { ShareLink(item: model.diagnosticReport) { Label("Share diagnostics report", systemImage: "square.and.arrow.up") }; Text("This records a device run only when you start it. No on-device results are assumed.").font(.caption).foregroundStyle(.secondary) } }; Section("Privacy") { Text("Each conversation has its own history, approved memories and task state. Data is stored locally and excluded from backup. Deleting a memory does not erase earlier conversation messages."); Button("Erase all local conversations and memory", role: .destructive) { confirmErase = true }.disabled(!model.canChangeSessions) } }.navigationTitle("Settings") }.tabItem { Label("Settings", systemImage: "gearshape") }
        }.tint(.cyan).safeAreaInset(edge: .top) {
            if !model.error.isEmpty { Text(model.error).font(.footnote).foregroundStyle(.red).padding(8).frame(maxWidth: .infinity).background(.regularMaterial) }
        }.confirmationDialog("Erase all local data?", isPresented: $confirmErase, titleVisibility: .visible) { Button("Erase all", role: .destructive) { model.eraseAll() }; Button("Cancel", role: .cancel) {} }
    }
}
