import SwiftUI

private enum HabitDetailTab: String, CaseIterable, Identifiable {
    case details = "Details"
    case notes = "Notes"

    var id: String { rawValue }
}

/// The single detail screen for a habit. Today, Habits, and Insights all push here; editing starts from … → Edit.
struct HabitDetailView: View {
    let service: HabitProgressService
    let habitID: UUID
    @State private var editing = false
    @State private var tab: HabitDetailTab = .details
    @State private var draftNotes = ""

    var body: some View {
        if let habit = service.habits.first(where: { $0.id == habitID }) {
            let periods = service.periods
                .filter { $0.habitID == habitID }
                .sorted { $0.startsAt < $1.startsAt }
            let recent = Array(periods.suffix(28))
            let entries = service.entries
                .filter { $0.habitID == habitID }
                .sorted { $0.occurredAt > $1.occurredAt }
            let notes = service.reflections
                .filter { reflection in periods.contains { $0.id == reflection.periodID } }
                .sorted { $0.createdAt > $1.createdAt }
            let reminder = service.reminders.first { $0.habitID == habitID && $0.isEnabled }
            let category = service.categories.first { $0.id == habit.categoryID }

            VStack(spacing: 0) {
                Picker("Section", selection: $tab) {
                    ForEach(HabitDetailTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

                switch tab {
                case .details:
                    detailsList(
                        habit: habit,
                        recent: recent,
                        entries: entries,
                        reminder: reminder,
                        category: category
                    )
                case .notes:
                    notesList(habit: habit, reflections: notes)
                }
            }
            .ethosScreen()
            .navigationTitle(habit.title)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Edit", systemImage: "pencil") { editing = true }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("More")
                }
            }
            .sheet(isPresented: $editing) {
                HabitEditor(service: service, habit: habit)
            }
            .onAppear { draftNotes = habit.notes ?? "" }
            .onChange(of: habit.notes) { _, notes in
                draftNotes = notes ?? ""
            }
        } else {
            ContentUnavailableView("This habit is gone", systemImage: "list.bullet")
                .ethosScreen()
        }
    }

    private func detailsList(
        habit: Habit,
        recent: [HabitPeriod],
        entries: [ProgressEntry],
        reminder: Reminder?,
        category: Category?
    ) -> some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(goalText(habit))
                        .font(.title3.weight(.semibold))
                    Text(subtitle(habit, category: category, reminder: reminder))
                        .font(.subheadline)
                        .foregroundStyle(EthosColor.secondaryInk)
                    if let identity = habit.identityStatement {
                        Text(identity)
                            .font(.subheadline)
                            .padding(.top, 4)
                    }
                }
                .listRowBackground(Color.clear)
            }

            Group {
                Section {
                    HStack {
                        stat("Streak", "\(service.streak(habitID: habitID))")
                        stat("Best", "\(service.best(habitID: habitID))")
                        stat("Completion", rateText(service.rate(habitID: habitID)))
                    }
                }

                if !recent.isEmpty {
                    Section {
                        PeriodGrid(periods: recent)
                    } header: {
                        Text("Last \(recent.count) periods")
                    } footer: {
                        Text("Oldest first. Skips stay out of the completion rate.")
                    }
                }

                let checklist = habit.checklist.filter(\.isActive).sorted { $0.sortOrder < $1.sortOrder }
                if !checklist.isEmpty {
                    Section("Checklist") {
                        ForEach(checklist) { item in
                            let done = service.isItemDone(
                                habitID: habitID,
                                itemID: item.id,
                                on: .now,
                                calendar: service.calendar
                            )
                            HStack {
                                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(done ? EthosColor.accent : EthosColor.secondaryInk)
                                Text(item.title)
                                    .strikethrough(done)
                                    .foregroundStyle(done ? EthosColor.secondaryInk : .primary)
                            }
                        }
                    }
                }

                if !entries.isEmpty {
                    Section("Log") {
                        ForEach(entries.prefix(20)) { entry in
                            HStack(alignment: .firstTextBaseline) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entryText(entry, habit: habit))
                                    if let note = entry.note {
                                        Text(note)
                                            .font(.subheadline)
                                            .foregroundStyle(EthosColor.secondaryInk)
                                    }
                                }
                                Spacer()
                                Text(entry.occurredAt.formatted(.dateTime.day().month(.abbreviated).hour().minute()))
                                    .font(.subheadline)
                                    .monospacedDigit()
                                    .foregroundStyle(EthosColor.secondaryInk)
                            }
                        }
                    }
                }
            }
            .ethosRows()
        }
    }

    private func notesList(habit: Habit, reflections: [Reflection]) -> some View {
        List {
            Section("Notes") {
                TextField("Notes", text: $draftNotes, axis: .vertical)
                    .lineLimit(4...10)
                Button("Save notes") {
                    do {
                        try service.updateNotes(habitID: habitID, notes: draftNotes)
                    } catch {
                        // Detail stays editable; editor surfaces stronger errors.
                    }
                }
            }

            if !reflections.isEmpty {
                Section("Reflections") {
                    ForEach(reflections) { reflection in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(reflection.response)
                            Text(reflection.createdAt.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundStyle(EthosColor.secondaryInk)
                        }
                    }
                }
            }
        }
        .ethosRows()
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title2.weight(.semibold))
                .monospacedDigit()
            Text(title)
                .font(.caption)
                .foregroundStyle(EthosColor.secondaryInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func subtitle(_ habit: Habit, category: Category?, reminder: Reminder?) -> String {
        var parts: [String] = []
        if habit.direction == .quit {
            parts.append(habit.direction.label)
        }
        parts.append(scheduleText(habit.schedule))
        if let category { parts.append(category.name) }
        if let reminder { parts.append("Reminder \(clockText(reminder.time))") }
        if habit.lifecycle != .active { parts.append(habit.lifecycle.label) }
        return parts.joined(separator: " · ")
    }

    private func entryText(_ entry: ProgressEntry, habit: Habit) -> String {
        if let itemID = entry.checklistItemID {
            return habit.checklist.first { $0.id == itemID }?.title ?? "Checklist item"
        }
        if habit.direction == .quit {
            return entry.amount == 1 ? "Slip" : "Slip \(amountText(entry.amount))"
        }
        if habit.goal.measurement == .boolean {
            return "Done"
        }
        let unit = goalUnitSuffix(habit.goal)
        return "\(amountText(entry.amount))\(unit)"
    }
}

/// Seven to a row, oldest first, with the outcome in words for VoiceOver and a legend underneath.
private struct PeriodGrid: View {
    let periods: [HabitPeriod]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(periods) { period in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(period.outcome.fillColor(hasProgress: true))
                        .overlay {
                            if period.outcome == .inProgress {
                                RoundedRectangle(cornerRadius: 4)
                                    .strokeBorder(EthosColor.attentionFill, lineWidth: 1.5)
                                    .background(EthosColor.surface, in: RoundedRectangle(cornerRadius: 4))
                            }
                        }
                        .aspectRatio(1, contentMode: .fit)
                        .accessibilityLabel(
                            "\(period.startsAt.formatted(date: .abbreviated, time: .omitted)), \(outcomeText(period.outcome))"
                        )
                }
            }
            HStack(spacing: 14) {
                legend("Done", EthosColor.successFill)
                legend("Missed", EthosColor.failureFill)
                legend("Skipped", EthosColor.track)
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(EthosColor.attentionFill, lineWidth: 1.5)
                        .frame(width: 10, height: 10)
                    Text("Open")
                }
            }
            .font(.caption)
            .foregroundStyle(EthosColor.secondaryInk)
            .accessibilityHidden(true)
        }
        .padding(.vertical, 4)
    }

    private func legend(_ title: String, _ color: Color) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 10, height: 10)
            Text(title)
        }
    }
}
