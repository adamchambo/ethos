import SwiftUI

private enum HabitDetailTab: String, CaseIterable, Identifiable {
    case details = "Details"
    case notes = "Notes"

    var id: String { rawValue }
}

struct HabitDetailView: View {
    @Bindable var store: HabitStore
    let habitID: UUID

    @State private var tab: HabitDetailTab = .details
    @State private var draftNotes = ""
    @State private var showingEditor = false

    private var definition: HabitDefinition? {
        store.definition(for: habitID)
    }

    private var row: DayHabitRow? {
        store.snapshot.morning.first { $0.id == habitID }
            ?? store.snapshot.afternoon.first { $0.id == habitID }
            ?? store.snapshot.evening.first { $0.id == habitID }
            ?? store.snapshot.anytime.first { $0.id == habitID }
            ?? store.snapshot.finished.first { $0.id == habitID }
            ?? makeDetailRow()
    }

    var body: some View {
        Group {
            if let definition, let row {
                VStack(spacing: 0) {
                    Picker("Section", selection: $tab) {
                        ForEach(HabitDetailTab.allCases) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding()

                    switch tab {
                    case .details:
                        detailsList(definition: definition, row: row)
                    case .notes:
                        notesList(definition: definition)
                    }
                }
                .navigationTitle(definition.habit.title)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button("Edit") { showingEditor = true }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                        .accessibilityLabel("More")
                    }
                }
                .sheet(isPresented: $showingEditor) {
                    HabitEditView(store: store, habitID: habitID)
                }
                .onAppear { draftNotes = definition.notes }
            } else {
                ContentUnavailableView("Habit unavailable", systemImage: "questionmark.circle")
            }
        }
    }

    private func detailsList(definition: HabitDefinition, row: DayHabitRow) -> some View {
        List {
            Section("Details") {
                LabeledContent("Status", value: row.progressLabel)
                LabeledContent("Schedule", value: row.scheduleLabel)
                LabeledContent("Time of day", value: definition.habit.dayPart.rawValue.capitalized)
                LabeledContent("Streak", value: "\(store.streakCount(for: habitID))")
                if let rate = store.rate(for: habitID) {
                    LabeledContent("Completion", value: "\(formatGoalAmount(rate * 100))%")
                }
                if definition.quickLog.kind == .quit {
                    Text("Quit habits use Slip on the Day view.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if definition.quickLog.kind == .checklist {
                Section("Checklist") {
                    ForEach(store.checklistStates(for: habitID)) { state in
                        HStack {
                            Image(systemName: state.isComplete ? "checkmark.circle.fill" : "circle")
                            Text(state.item.title)
                                .strikethrough(state.isComplete)
                                .foregroundStyle(state.isComplete ? .secondary : .primary)
                        }
                    }
                }
            }

            Section("History") {
                let history = store.entries(for: habitID)
                if history.isEmpty {
                    Text("No entries yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(history) { entry in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.occurredAt.formatted(date: .abbreviated, time: .shortened))
                            Text(historyLine(entry, definition: definition))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func notesList(definition: HabitDefinition) -> some View {
        List {
            Section("Notes") {
                TextField("Reflection", text: $draftNotes, axis: .vertical)
                    .lineLimit(6...12)
                Button("Save notes") {
                    var updated = definition
                    updated.notes = draftNotes
                    store.updateDefinition(updated)
                }
            }
        }
    }

    private func historyLine(_ entry: ProgressEntry, definition: HabitDefinition) -> String {
        if let itemID = entry.checklistItemID,
           let title = definition.quickLog.checklistItems.first(where: { $0.id == itemID })?.title {
            return title
        }
        if definition.quickLog.kind == .quit {
            return "Slip"
        }
        return "\(formatGoalAmount(entry.amount))\(unitSuffix(definition.quickLog.unitLabel))"
    }

    private func makeDetailRow() -> DayHabitRow? {
        guard let definition = definition else { return nil }
        return makeDayHabitRow(
            habit: definition.habit,
            goal: definition.goal,
            schedule: definition.schedule,
            quickLog: definition.quickLog,
            on: store.selectedDate,
            periods: store.periods,
            entries: store.entries,
            calendar: .current,
            now: Date()
        )
    }
}
