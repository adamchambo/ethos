import SwiftUI
import UniformTypeIdentifiers
import UserNotifications

struct SettingsView: View {
    let service: HabitProgressService
    @AppStorage("ethosAppearance") private var appearance = "system"
    @AppStorage("ethosHaptics") private var haptics = true
    @Environment(\.scenePhase) private var scenePhase
    @State private var importing = false
    @State private var exportURL: URL?
    @State private var showingShare = false
    @State private var reminderStatus = UNAuthorizationStatus.notDetermined
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Group {
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
                        reminderRow
                    } header: {
                        Text("Reminders")
                    } footer: {
                        Text("Each habit sets its own reminder time.")
                    }

                    Section("Data") {
                        Button("Export a copy") { export() }
                        Button("Import from a file") { importing = true }
                        if let lastSaveError = service.lastSaveError {
                            Text(lastSaveError)
                                .foregroundStyle(EthosColor.failure)
                            Button("Overwrite the saved file", role: .destructive) {
                                service.overwriteUnreadableStore()
                            }
                        }
                    }

                    Section {
                        Button("Show the introduction again") {
                            service.replayOnboarding()
                        }
                    } footer: {
                        Text("Ethos keeps everything on this device. No account, sync, or payment.")
                    }
                }
                .ethosRows()
            }
            .ethosScreen()
            .navigationTitle("Settings")
            .task { await refreshReminderStatus() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    Task { await refreshReminderStatus() }
                }
            }
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

    @ViewBuilder
    private var reminderRow: some View {
        switch reminderStatus {
        case .notDetermined:
            Button("Allow reminders") {
                Task {
                    await ReminderScheduling.requestAccess()
                    await refreshReminderStatus()
                }
            }
        case .denied:
            LabeledContent("Notifications", value: "Off")
            if let url = URL(string: UIApplication.openSettingsURLString) {
                Link("Turn on in iOS Settings", destination: url)
            }
        default:
            LabeledContent("Notifications", value: "On")
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

    private func refreshReminderStatus() async {
        reminderStatus = await ReminderScheduling.authorizationStatus()
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
