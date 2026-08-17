import SwiftUI

struct SettingsView: View {
    @ObservedObject var preferences: Preferences

    @State private var token = Keychain.notionToken ?? ""
    @State private var destinations: [NotionDestination] = []
    @State private var status: Status = .idle

    private enum Status: Equatable {
        case idle
        case checking
        case failed(String)
        /// Distinct from "no databases" on purpose — an empty list means the
        /// integration hasn't been connected to anything yet, which is a
        /// different problem with a different fix.
        case notConnected
        case ok(Int)
    }

    var body: some View {
        TabView {
            writing.tabItem { Label("Writing", systemImage: "text.alignleft") }
            notion.tabItem { Label("Notion", systemImage: "arrow.up.to.line") }
        }
        .frame(width: 460)
        .padding(20)
    }

    // MARK: - Writing

    private var writing: some View {
        Form {
            Section {
                TextField("Words", value: $preferences.wordGoal, format: .number)
                    .frame(width: 90)
                Text("The count turns green when you get there. Set 0 to hide the target and just show the count.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Daily goal")
            }

            Section {
                Toggle("Check spelling", isOn: $preferences.spelling.checkSpelling)
                Toggle("Autocorrect", isOn: $preferences.spelling.autocorrect)
                Toggle("Smart quotes and dashes", isOn: $preferences.spelling.smartQuotes)
            } header: {
                Text("Typing")
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Notion

    private var notion: some View {
        Form {
            Section {
                SecureField("ntn_…", text: $token)
                Button("Verify and load databases") { verify() }
                    .disabled(token.isEmpty || status == .checking)
                statusLine
            } header: {
                Text("Integration token")
            } footer: {
                Text("Stored in your Keychain, never on disk in the clear.")
                    .font(.caption)
            }

            if !destinations.isEmpty {
                Section {
                    Picker("Journal", selection: destinationBinding) {
                        Text("Choose…").tag(String?.none)
                        ForEach(destinations) { destination in
                            Text(destination.name).tag(String?.some(destination.id))
                        }
                    }
                } header: {
                    Text("Destination")
                }
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private var statusLine: some View {
        switch status {
        case .idle:
            EmptyView()
        case .checking:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Checking…").font(.caption).foregroundStyle(.secondary)
            }
        case .failed(let message):
            Text(message).font(.caption).foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)
        case .notConnected:
            Text("No databases are connected to this integration yet. Open your journal in Notion, click ··· → Connections, and add Goode Morming Pages.")
                .font(.caption)
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
        case .ok(let count):
            Text("Found \(count) database\(count == 1 ? "" : "s").")
                .font(.caption)
                .foregroundStyle(.green)
        }
    }

    private var destinationBinding: Binding<String?> {
        Binding(
            get: { preferences.dataSourceID },
            set: { id in
                guard let match = destinations.first(where: { $0.id == id }) else {
                    preferences.dataSourceID = id
                    return
                }
                preferences.apply(destination: match)
            }
        )
    }

    private func verify() {
        status = .checking
        Keychain.notionToken = token
        let client = NotionClient(token: token)

        Task { @MainActor in
            do {
                let found = try await client.verify()
                destinations = found
                status = found.isEmpty ? .notConnected : .ok(found.count)
            } catch {
                destinations = []
                status = .failed(error.localizedDescription)
            }
        }
    }
}
