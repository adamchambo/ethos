import SwiftUI

struct MyEthosView: View {
    let service: HabitProgressService
    @State private var name: String

    init(service: HabitProgressService) {
        self.service = service
        _name = State(initialValue: service.profile.displayName)
    }

    var body: some View {
        let identities = service.habits.compactMap { habit -> (Habit, String)? in
            guard let statement = habit.identityStatement else { return nil }
            return (habit, statement)
        }
        let accountable = service.habits.filter { $0.accountability?.isEnabled == true }
        let notes = service.journal.sorted { $0.dayStart > $1.dayStart }
        let reflections = service.reflections.sorted { $0.createdAt > $1.createdAt }

        NavigationStack {
            List {
                Section {
                    TextField("Your name", text: $name)
                        .onSubmit { saveName() }
                } header: {
                    Text("Name")
                } footer: {
                    Text("This stays on this device. It is not an account.")
                }

                Section {
                    if identities.isEmpty {
                        Text("Identity statements you add on a habit show up here.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(identities, id: \.0.id) { habit, statement in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(habit.title)
                                    .font(.headline)
                                Text(statement)
                            }
                        }
                    }
                } header: {
                    Text("Identity")
                }

                Section {
                    if accountable.isEmpty {
                        Text("Accountability is set on each habit, and shows up here once it is on.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(accountable) { habit in
                            if let rule = habit.accountability {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(habit.title)
                                        .font(.headline)
                                    Text("\(rule.tone.label) · \(rule.consequence.label)")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Accountability")
                }

                Section("Reflections") {
                    if reflections.isEmpty {
                        Text("After a miss, Ethos asks what happened. Those notes stay here.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(reflections) { reflection in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(reflection.response)
                                Text(reflection.createdAt.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("Journal") {
                    if notes.isEmpty {
                        Text("The note you save on Today is kept here.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(notes) { entry in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.text)
                                Text(entry.dayStart.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("My Ethos")
            .ethosScreen()
        }
    }

    private func saveName() {
        var profile = service.profile
        profile.displayName = name
        service.updateProfile(profile)
    }
}
