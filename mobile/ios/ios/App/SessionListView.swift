import SwiftUI
import JarvisCore

struct SessionListView: View {
    @ObservedObject var model: AppState
    @State private var editing: SessionSummary?
    @State private var title = ""
    @State private var showTitle = false
    @State private var deleting: SessionSummary?
    @State private var showDelete = false

    var body: some View {
        NavigationStack {
            List {
                if !model.ready {
                    Text("Session storage is unavailable. Reopen the app to attempt recovery; existing data has not been reset.")
                } else if !model.canChangeSessions {
                    Text("Resolve or discard the current task in Chat before changing conversations.").foregroundStyle(.secondary)
                }
                Section("Conversations") {
                    ForEach(model.sessions) { item in
                        HStack {
                            Button {
                                model.selectSession(item.id)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(item.title).foregroundStyle(.primary)
                                        Text(item.createdAt, style: .date).font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if model.activeID == item.id {
                                        Image(systemName: "checkmark.circle.fill").accessibilityLabel("Selected")
                                    }
                                }
                            }.buttonStyle(.plain).disabled(!model.canChangeSessions)
                            Menu {
                                Button("Rename", systemImage: "pencil") {
                                    editing = item; title = item.title; showTitle = true
                                }
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    deleting = item; showDelete = true
                                }
                            } label: { Image(systemName: "ellipsis.circle").accessibilityLabel("Manage \(item.title)") }
                            .disabled(!model.canChangeSessions)
                        }
                    }
                }
                Section {
                    Text("Conversation histories, task approvals and memories stay separate. Switching discards unsent draft text.").font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Sessions")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editing = nil; title = ""; showTitle = true
                    } label: { Label("New conversation", systemImage: "plus") }
                    .disabled(!model.canChangeSessions)
                }
            }
            .alert(editing == nil ? "New conversation" : "Rename conversation", isPresented: $showTitle) {
                TextField("Conversation name", text: $title)
                Button("Save") {
                    if let editing { model.renameSession(editing.id, title: title) }
                    else { model.createSession(title: title) }
                    title = ""; editing = nil
                }.disabled(!(1...80).contains(title.trimmingCharacters(in: .whitespacesAndNewlines).count))
                Button("Cancel", role: .cancel) { title = ""; editing = nil }
            }
            .confirmationDialog("Delete conversation and its memory?", isPresented: $showDelete, titleVisibility: .visible, presenting: deleting) { item in
                Button("Delete", role: .destructive) { model.deleteSession(item.id); deleting = nil }
                Button("Cancel", role: .cancel) { deleting = nil }
            } message: { item in
                Text("Delete \(item.title) from this device? This also removes its saved memories and task history.")
            }
        }
    }
}
