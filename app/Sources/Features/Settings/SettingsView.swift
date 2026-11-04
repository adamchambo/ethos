import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    let service: HabitProgressService
    @AppStorage("ethosAppearance") private var appearance = "system"
    @AppStorage("ethosHaptics") private var haptics = true
    @State private var importing = false
    @State private var exportURL: URL?
    @State private var showingShare = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section("General") {
                    Picker("Appearance", selection: $appearance) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                    Toggle("Haptics", isOn: $haptics)
                    Picker("First day of week", selection: weekStart) {
                        ForEach(Weekday.allCases, id: \.self) { day in
                            Text(day.name).tag(day)
                        }
                    }
                }

                Section {
                    Button("Allow reminders") {
                        ReminderScheduling.requestAccess()
                    }
                } footer: {
                    Text("Reminders fire at the time set on each habit. Ethos asks before the first one.")
                }

                Section("Data") {
                    Button("Export") { export() }
                    Button("Import") { importing = true }
                    if let lastSaveError = service.lastSaveError {
                        Text(lastSaveError)
                            .foregroundStyle(.secondary)
                        Button("Overwrite the saved file") {
                            service.overwriteUnreadableStore()
                        }
                    }
                }

                Section {
                    Button("Show the introduction again") {
                        service.replayOnboarding()
                    }
                }

                Section("About") {
                    Text("Ethos is a local habit record. Progress stays on this device. There is no account, sync, or payment in this build.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                importFile(result)
            }
            .sheet(isPresented: $showingShare) {
                if let exportURL {
                    ShareLink(item: exportURL) {
                        Label("Share Ethos export", systemImage: "square.and.arrow.up")
                            .padding()
                    }
                    .presentationDetents([.medium])
                }
            }
            .alert("Unable to update data", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var weekStart: Binding<Weekday> {
        Binding(
            get: { service.profile.weekStart },
            set: { day in
                var profile = service.profile
                profile.weekStart = day
                service.updateProfile(profile)
            }
        )
    }

    private func export() {
        do {
            exportURL = try service.exportFile()
            showingShare = true
        } catch {
            errorMessage = ethosMessage(error)
        }
    }

    private func importFile(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            try service.replace(with: data)
        } catch {
            errorMessage = ethosMessage(error)
        }
    }
}
