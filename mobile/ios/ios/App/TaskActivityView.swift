import JarvisCore
import SwiftUI

struct TaskActivityView: View {
    @ObservedObject var model: AppState

    private var latestTask: ArraySlice<Message> {
        let messages = model.snapshot.messages
        guard let start = messages.lastIndex(where: { $0.role == "user" }) else { return [] }
        return messages[start...]
    }

    private var status: String {
        if model.busy { return "Working locally" }
        switch model.snapshot.status {
        case .idle: return "No active task"
        case .running: return "Interrupted"
        case .approval: return "Awaiting approval"
        case .complete: return "Completed"
        case .failed: return "Failed"
        case .cancelled: return "Cancelled"
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section(model.activeTitle) {
                    LabeledContent("Status", value: status)
                    LabeledContent("Model decisions", value: String(model.snapshot.steps))
                    taskControls
                }
                if !latestTask.isEmpty {
                    Section("Latest task") {
                        ForEach(latestTask) { message in
                            DisclosureGroup {
                                Text(message.text).textSelection(.enabled)
                            } label: {
                                Text(eventLabel(message.role))
                            }
                        }
                    }
                }
            }
            .navigationTitle("Activity")
        }
    }

    @ViewBuilder private var taskControls: some View {
        if model.busy {
            Button("Cancel task") { model.cancel() }
        } else if model.ready && !model.diagnosticsRunning {
            if model.snapshot.status == .approval, let pending = model.snapshot.pending,
               pending.action == "save_memory" {
                DisclosureGroup("Proposed memory") {
                    Text(pending.value).textSelection(.enabled)
                }
                Button("Approve memory write") { model.approval(true) }
                Button("Decline memory write", role: .cancel) { model.approval(false) }
            } else if model.snapshot.status == .running {
                Button("Resume interrupted task") { model.resume() }
                Button("Discard interrupted task", role: .destructive) { model.cancel() }
            }
        }
    }

    private func eventLabel(_ role: String) -> LocalizedStringKey {
        switch role {
        case "user": "Request"
        case "tool": "Tool outcome"
        case "assistant": "Response"
        default: "Task notice"
        }
    }
}
