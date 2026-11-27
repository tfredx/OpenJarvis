import SwiftUI
import FoundationModels
import JarvisCore
import AppIntents
import AVFoundation

struct AppleEngine: Intelligence {
    func decide(prompt: String) async throws -> Decision {
        guard SystemLanguageModel.default.isAvailable else { throw LocalError.unavailable }
        let session = LanguageModelSession(instructions: "You are a careful local assistant. Follow the requested JSON schema; output JSON only.")
        let response = try await session.respond(to: prompt)
        var text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("```"), let first = text.firstIndex(of: "\n"), let last = text.range(of: "```", options: .backwards), last.lowerBound > first { text = String(text[text.index(after: first)..<last.lowerBound]) }
        return try JSONDecoder().decode(Decision.self, from: Data(text.utf8))
    }
}
enum LocalError: LocalizedError { case unavailable; var errorDescription: String? { "Apple Intelligence is unavailable. Enable it in Settings and allow the model to finish downloading." } }

@MainActor final class AppState: ObservableObject {
    @Published var snapshot = Snapshot()
    @Published var error = ""
    @Published var busy = false
    @Published var input = ""
    private var agent: Agent?
    private var task: Task<Void, Never>?
    private let speaker = AVSpeechSynthesizer()
    static let shared = AppState()
    private init() {
        do {
            let root = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("Jarvis", isDirectory: true)
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            var directory = root; var values = URLResourceValues(); values.isExcludedFromBackup = true; try directory.setResourceValues(values)
            try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: root.path)
            agent = try Agent(engine: AppleEngine(), file: root.appendingPathComponent("state.json"), bridge: makeConversationBridge())
        } catch { self.error = error.localizedDescription }
    }
    func load() async { if let agent { snapshot = await agent.snapshot() } }
    func submit() { let request = input; guard !request.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }; input = ""; perform { try await $0.start(request) } }
    func resume() { perform { try await $0.resume() } }
    func approval(_ allow: Bool) { perform { try await $0.approve(allow) } }
    func cancel() { if busy { task?.cancel() } else { perform { try await $0.cancel() } } }
    func eraseAll() { perform { try await $0.eraseAll() } }
    func delete(_ id: UUID) { perform { try await $0.deleteMemory(id) } }
    func speak(_ text: String) { speaker.stopSpeaking(at: .immediate); let utterance = AVSpeechUtterance(string: text); utterance.rate = AVSpeechUtteranceDefaultSpeechRate; speaker.speak(utterance) }
    private func perform(_ work: @escaping @Sendable (Agent) async throws -> Snapshot) {
        guard !busy, let agent else { return }; busy = true; error = ""
        task = Task { defer { busy = false; task = nil }; do { snapshot = try await work(agent) } catch { self.error = error.localizedDescription; snapshot = await agent.snapshot() } }
    }
}

struct AskJarvisIntent: AppIntent {
    static let title: LocalizedStringResource = "Ask Jarvis"
    static let description = IntentDescription("Open Jarvis with a request ready to review and run locally.")
    static let openAppWhenRun = true
    @Parameter(title: "Request") var request: String
    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        AppState.shared.input = request
        return .result(dialog: "Your request is ready in Jarvis.")
    }
}
struct JarvisShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: AskJarvisIntent(), phrases: ["Ask \(.applicationName)", "Open \(.applicationName)"], shortTitle: "Ask Jarvis", systemImageName: "sparkles")
    }
}
@main struct OpenJarvisApp: App {
    @StateObject private var model = AppState.shared
    var body: some Scene { WindowGroup { RootView(model: model).task { await model.load() } } }
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
                    if !model.error.isEmpty { Text(model.error).font(.footnote).foregroundStyle(.red) }
                    if let pending = model.snapshot.pending { VStack(alignment: .leading) { Text("Approve memory write?").font(.headline); Text(pending.value); HStack { Button("Deny", role: .cancel) { model.approval(false) }; Spacer(); Button("Approve") { model.approval(true) }.buttonStyle(.borderedProminent) } }.padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12)).disabled(model.busy) }
                    if model.busy { HStack { ProgressView(); Text("Working locally"); Spacer(); Button("Cancel") { model.cancel() } } }
                    else if model.snapshot.status == .running { HStack { Button("Resume interrupted task") { model.resume() }; Spacer(); Button("Discard", role: .destructive) { model.cancel() } } }
                    HStack(alignment: .bottom) { TextField("Ask Jarvis…", text: $model.input, axis: .vertical).lineLimit(1...5).textFieldStyle(.roundedBorder); Button { model.submit() } label: { Image(systemName: "arrow.up.circle.fill").font(.system(size: 34)) }.accessibilityLabel("Send") }.disabled(model.busy || model.snapshot.status == .approval || model.snapshot.status == .running)
                }.padding().navigationTitle("Jarvis")
            }.tabItem { Label("Chat", systemImage: "bubble.left.and.bubble.right") }
            NavigationStack { List { Section("Task state") { LabeledContent("Status", value: model.snapshot.status.rawValue); LabeledContent("Model decisions", value: String(model.snapshot.steps)); LabeledContent("Pending approval", value: model.snapshot.pending == nil ? "No" : "Yes") }; Section("Execution") { Text("Foreground execution and manual checkpoint recovery. Continuous background scheduling is not enabled in this release.") } }.navigationTitle("Activity") }.tabItem { Label("Activity", systemImage: "waveform.path") }
            NavigationStack { List { if model.snapshot.notes.isEmpty { Text("Approved memories appear here.").foregroundStyle(.secondary) }; ForEach(model.snapshot.notes) { note in HStack { Text(note.text); Spacer(); Button(role: .destructive) { model.delete(note.id) } label: { Image(systemName: "trash") }.disabled(model.busy || model.snapshot.status == .running || model.snapshot.status == .approval) } } }.navigationTitle("Memory") }.tabItem { Label("Memory", systemImage: "brain") }
            NavigationStack { List { Section("Intelligence") { LabeledContent("Provider", value: "Apple on-device"); LabeledContent("Cloud fallback", value: "Off") }; Section("Build") { LabeledContent("Version", value: "0.2.0"); LabeledContent("Conversation bridge", value: conversationBridgeLabel); Text("Experimental mobile prototype. Agent orchestration remains Swift.") }; Section("Privacy") { Text("Conversation and approved memories are stored locally and excluded from backup. Deleting a memory does not erase earlier conversation messages."); Button("Erase all local conversations and memory", role: .destructive) { confirmErase = true }.disabled(model.busy) } }.navigationTitle("Settings") }.tabItem { Label("Settings", systemImage: "gearshape") }
        }.tint(.cyan).confirmationDialog("Erase all local data?", isPresented: $confirmErase, titleVisibility: .visible) { Button("Erase all", role: .destructive) { model.eraseAll() }; Button("Cancel", role: .cancel) {} }
    }
}
