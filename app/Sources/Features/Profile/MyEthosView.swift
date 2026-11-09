import SwiftUI

struct MyEthosView: View {
    let service: HabitProgressService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var name: String
    @State private var identityDrafts: [UUID: String] = [:]
    @State private var pendingIdentityIDs: Set<UUID> = []
    @State private var editingHabit: Habit?
    @State private var editingNote: EditableNote?
    @State private var errorMessage: String?
    @FocusState private var focusedIdentityID: UUID?

    init(service: HabitProgressService) {
        self.service = service
        _name = State(initialValue: service.profile.displayName)
    }

    var body: some View {
        let active = service.habits.filter { $0.lifecycle == .active }
        let identityHabits = service.habits.filter { habit in
            habit.identityStatement != nil || pendingIdentityIDs.contains(habit.id)
        }
        let identityCandidates = service.habits
            .filter { $0.lifecycle == .active && $0.identityStatement == nil && !pendingIdentityIDs.contains($0.id) }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        let accountable = service.habits.compactMap { habit -> (Habit, AccountabilityRule)? in
            guard let rule = habit.accountability, rule.isEnabled else { return nil }
            return (habit, rule)
        }
        let notes = service.journal.sorted { $0.dayStart > $1.dayStart }
        let reflections = service.reflections.sorted { $0.createdAt > $1.createdAt }
        let isEmpty = identityHabits.isEmpty && accountable.isEmpty && notes.isEmpty && reflections.isEmpty
        let longest = active.map { service.streak(habitID: $0.id) }.max() ?? 0

        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            TextField("Add your name", text: $name)
                                .font(.title.weight(.semibold))
                                .textContentType(.name)
                                .submitLabel(.done)
                                .accessibilityLabel("Name")
                                .onSubmit(saveName)
                            Image(systemName: "pencil")
                                .font(.body)
                                .foregroundStyle(EthosColor.secondaryInk)
                                .accessibilityHidden(true)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(EthosColor.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

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

                    if !identityHabits.isEmpty || !identityCandidates.isEmpty {
                        Section("Who I'm becoming") {
                            ForEach(identityHabits) { habit in
                                VStack(alignment: .leading, spacing: 2) {
                                    TextField("Add an identity", text: identityBinding(habit), axis: .vertical)
                                        .lineLimit(1...6)
                                        .submitLabel(.done)
                                        .focused($focusedIdentityID, equals: habit.id)
                                        .onSubmit { saveIdentity(habit.id) }
                                        .onChange(of: habit.identityStatement) { _, updated in
                                            let incoming = updated ?? ""
                                            guard identityDrafts[habit.id]?.trimmingCharacters(in: .whitespacesAndNewlines) == incoming else {
                                                return
                                            }
                                            identityDrafts[habit.id] = nil
                                        }
                                    Text(habit.title)
                                        .font(.subheadline)
                                        .foregroundStyle(EthosColor.secondaryInk)
                                }
                            }

                            if !identityCandidates.isEmpty {
                                Menu("Add for a habit", systemImage: "plus") {
                                    ForEach(identityCandidates) { habit in
                                        Button {
                                            beginIdentity(for: habit.id)
                                        } label: {
                                            Text(habit.title)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    if !accountable.isEmpty {
                        Section("Accountability") {
                            ForEach(accountable, id: \.0.id) { habit, rule in
                                Button {
                                    editingHabit = habit
                                } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(habit.title)
                                        Text("\(rule.tone.label) · \(rule.consequence.label)")
                                            .font(.subheadline)
                                            .foregroundStyle(EthosColor.secondaryInk)
                                        if let recovery = rule.recoveryAction?.trimmingCharacters(in: .whitespacesAndNewlines),
                                           !recovery.isEmpty {
                                            Text(recovery)
                                                .font(.subheadline)
                                                .foregroundStyle(EthosColor.secondaryInk)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if !reflections.isEmpty {
                        Section("Reflections") {
                            ForEach(reflections) { reflection in
                                Button {
                                    editingNote = EditableNote(reflection: reflection, habitName: habitName(forPeriod: reflection.periodID))
                                } label: {
                                    noteLabel(
                                        title: habitName(forPeriod: reflection.periodID),
                                        text: reflection.response,
                                        date: reflection.createdAt
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if !notes.isEmpty {
                        Section("Journal") {
                            ForEach(notes) { entry in
                                Button {
                                    editingNote = EditableNote(entry: entry)
                                } label: {
                                    noteLabel(title: nil, text: entry.text, date: entry.dayStart)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .ethosRows()
            }
            .ethosScreen()
            .navigationTitle("My Ethos")
            .onDisappear {
                saveName()
                saveIdentities()
            }
            .sheet(item: $editingHabit) { habit in
                HabitEditor(service: service, habit: habit)
            }
            .sheet(item: $editingNote) { note in
                NoteEditorSheet(note: note) { text in
                    try save(note, text: text)
                }
            }
            .alert("Unable to save", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func noteLabel(title: String?, text: String, date: Date) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let title {
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            Text(text)
            Text(date.formatted(date: .abbreviated, time: .omitted))
                .font(.caption)
                .foregroundStyle(EthosColor.secondaryInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func identityBinding(_ habit: Habit) -> Binding<String> {
        Binding(
            get: { identityDrafts[habit.id] ?? habit.identityStatement ?? "" },
            set: { identityDrafts[habit.id] = $0 }
        )
    }

    private func beginIdentity(for habitID: UUID) {
        ethosAnimate(reduceMotion) {
            identityDrafts[habitID] = ""
            pendingIdentityIDs.insert(habitID)
        }
        focusedIdentityID = habitID
    }

    private func habitName(forPeriod periodID: UUID) -> String {
        guard let habitID = service.periods.first(where: { $0.id == periodID })?.habitID else {
            return "Habit"
        }
        return service.habits.first { $0.id == habitID }?.title ?? "Habit"
    }

    private func saveName() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != service.profile.displayName else {
            if name != trimmed { name = trimmed }
            return
        }
        var profile = service.profile
        profile.displayName = trimmed
        name = trimmed
        service.updateProfile(profile)
    }

    private func saveIdentities() {
        let ids = Set(identityDrafts.keys).union(pendingIdentityIDs)
        for id in ids {
            saveIdentity(id)
        }
    }

    private func saveIdentity(_ habitID: UUID) {
        guard let habit = service.habits.first(where: { $0.id == habitID }) else {
            pendingIdentityIDs.remove(habitID)
            identityDrafts[habitID] = nil
            return
        }

        let draft = identityDrafts[habitID] ?? habit.identityStatement ?? ""
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        let current = habit.identityStatement ?? ""
        guard trimmed != current else {
            if trimmed.isEmpty {
                pendingIdentityIDs.remove(habitID)
                identityDrafts[habitID] = nil
            }
            return
        }

        do {
            try service.updateIdentity(habitID: habitID, statement: trimmed.isEmpty ? nil : trimmed)
            pendingIdentityIDs.remove(habitID)
            identityDrafts[habitID] = trimmed.isEmpty ? nil : trimmed
        } catch {
            errorMessage = ethosMessage(error)
        }
    }

    private func save(_ note: EditableNote, text: String) throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        switch note.kind {
        case .reflection:
            guard let current = service.reflections.first(where: { $0.id == note.id }) else { return }
            guard trimmed != current.response else { return }
            try service.updateReflection(id: note.id, response: text)
        case .journal(let dayStart):
            guard trimmed != service.journalText(on: dayStart, calendar: service.calendar) else { return }
            try service.saveJournal(text: text, on: dayStart, calendar: service.calendar)
        }
    }
}

private struct EditableNote: Identifiable {
    enum Kind {
        case reflection
        case journal(dayStart: Date)
    }

    let id: UUID
    let title: String
    let subtitle: String
    let text: String
    let footer: String
    let kind: Kind

    init(reflection: Reflection, habitName: String) {
        id = reflection.id
        title = habitName
        subtitle = reflection.createdAt.formatted(date: .long, time: .omitted)
        text = reflection.response
        footer = "A response is required."
        kind = .reflection
    }

    init(entry: JournalEntry) {
        id = entry.id
        title = "Journal"
        subtitle = entry.dayStart.formatted(date: .long, time: .omitted)
        text = entry.text
        footer = "Clearing the text deletes this note."
        kind = .journal(dayStart: entry.dayStart)
    }
}

private struct NoteEditorSheet: View {
    let note: EditableNote
    let onSave: (String) throws -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    @State private var errorMessage: String?

    init(note: EditableNote, onSave: @escaping (String) throws -> Void) {
        self.note = note
        self.onSave = onSave
        _text = State(initialValue: note.text)
    }

    var body: some View {
        let unchanged = text.trimmingCharacters(in: .whitespacesAndNewlines)
            == note.text.trimmingCharacters(in: .whitespacesAndNewlines)

        NavigationStack {
            Form {
                Section {
                    TextField(note.kind.prompt, text: $text, axis: .vertical)
                        .lineLimit(4...10)
                } footer: {
                    Text(note.footer)
                }
                .ethosRows()
            }
            .ethosScreen()
            .navigationTitle(note.title)
            .navigationSubtitle(note.subtitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(unchanged)
                }
            }
            .alert("Unable to save", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func save() {
        do {
            try onSave(text)
            dismiss()
        } catch {
            errorMessage = ethosMessage(error)
        }
    }
}

private extension EditableNote.Kind {
    var prompt: String {
        switch self {
        case .reflection: "What happened, and what will you do next time?"
        case .journal: "How did this day go?"
        }
    }
}
