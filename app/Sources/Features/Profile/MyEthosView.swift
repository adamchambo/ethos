import SwiftUI

struct MyEthosView: View {
    let service: HabitProgressService
    @State private var name: String

    init(service: HabitProgressService) {
        self.service = service
        _name = State(initialValue: service.profile.displayName)
    }

    var body: some View {
        let active = service.habits.filter { $0.lifecycle == .active }
        let identities = service.habits.compactMap { habit -> (Habit, String)? in
            guard let statement = habit.identityStatement else { return nil }
            return (habit, statement)
        }
        let accountable = service.habits.compactMap { habit -> (Habit, AccountabilityRule)? in
            guard let rule = habit.accountability, rule.isEnabled else { return nil }
            return (habit, rule)
        }
        let notes = service.journal.sorted { $0.dayStart > $1.dayStart }
        let reflections = service.reflections.sorted { $0.createdAt > $1.createdAt }
        let isEmpty = identities.isEmpty && accountable.isEmpty && notes.isEmpty && reflections.isEmpty
        let longest = active.map { service.streak(habitID: $0.id) }.max() ?? 0

        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        TextField("Your name", text: $name)
                            .font(.title.weight(.semibold))
                            .textContentType(.name)
                            .submitLabel(.done)
                            .onSubmit { saveName() }
                        Text("\(active.count) active \(active.count == 1 ? "habit" : "habits") · longest streak \(longest)")
                            .font(.subheadline)
                            .monospacedDigit()
                            .foregroundStyle(EthosColor.secondaryInk)
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 8, trailing: 20))
                } footer: {
                    Text("Kept on this device. It is not an account.")
                }

                Group {
                    if isEmpty {
                        Section {
                            Text("Identity statements and accountability you set on a habit, reflections after a miss, and the notes you write on Today all collect here.")
                                .foregroundStyle(EthosColor.secondaryInk)
                        }
                    }

                    if !identities.isEmpty {
                        Section("Who I'm becoming") {
                            ForEach(identities, id: \.0.id) { habit, statement in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(statement)
                                    Text(habit.title)
                                        .font(.subheadline)
                                        .foregroundStyle(EthosColor.secondaryInk)
                                }
                            }
                        }
                    }

                    if !accountable.isEmpty {
                        Section("Accountability") {
                            ForEach(accountable, id: \.0.id) { habit, rule in
                                LabeledContent(habit.title, value: "\(rule.tone.label) · \(rule.consequence.label)")
                            }
                        }
                    }

                    if !reflections.isEmpty {
                        Section("Reflections") {
                            ForEach(reflections) { reflection in
                                dated(reflection.response, reflection.createdAt)
                            }
                        }
                    }

                    if !notes.isEmpty {
                        Section("Journal") {
                            ForEach(notes) { entry in
                                dated(entry.text, entry.dayStart)
                            }
                        }
                    }
                }
                .ethosRows()
            }
            .ethosScreen()
            .navigationTitle("My Ethos")
            .onDisappear { saveName() }
        }
    }

    private func dated(_ text: String, _ date: Date) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(text)
            Text(date.formatted(date: .abbreviated, time: .omitted))
                .font(.caption)
                .foregroundStyle(EthosColor.secondaryInk)
        }
    }

    private func saveName() {
        guard name != service.profile.displayName else { return }
        var profile = service.profile
        profile.displayName = name
        service.updateProfile(profile)
    }
}
