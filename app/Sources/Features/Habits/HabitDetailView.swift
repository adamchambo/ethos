import SwiftUI

struct HabitDetailView: View {
    @Bindable var store: HabitStore
    let habitID: UUID

    @State private var customAmountText = ""
    @State private var draftNotes = ""

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
                List {
                    Section("Progress") {
                        LabeledContent("Status", value: row.progressLabel)
                        LabeledContent("Schedule", value: row.scheduleLabel)
                        LabeledContent("Streak", value: "\(store.streakCount(for: habitID))")
                        if let rate = store.rate(for: habitID) {
                            LabeledContent(
                                "Completion",
                                value: "\(formatGoalAmount(rate * 100))%"
                            )
                        }
                    }

                    Section("Quick log") {
                        LabeledContent("Action", value: row.quickActionTitle)
                        LabeledContent(
                            "Amount",
                            value: "\(formatGoalAmount(definition.quickLog.amount))\(unitSuffix(definition.quickLog.unitLabel))"
                        )
                        if definition.quickLog.kind == .quit {
                            Text("Quit habits log slips — keep the label explicit.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        Button("Log \(row.quickActionTitle)") {
                            _ = store.quickLog(row: row)
                        }
                        .disabled(!row.canQuickLog || row.opensChecklist)

                        HStack {
                            TextField("Custom amount", text: $customAmountText)
                                .keyboardType(.decimalPad)
                            Button("Log custom") {
                                logCustom(row: row)
                            }
                            .disabled(store.snapshot.isFutureDate)
                        }
                    }

                    if definition.quickLog.kind == .checklist {
                        Section("Checklist") {
                            ForEach(definition.quickLog.checklistItems) { item in
                                Button(item.title) {
                                    _ = store.logChecklistItem(habitID: habitID, item: item)
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
                                    Text("\(formatGoalAmount(entry.amount))\(unitSuffix(definition.quickLog.unitLabel))")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    Section("Notes") {
                        TextField("Reflection", text: $draftNotes, axis: .vertical)
                            .lineLimit(3...6)
                        Button("Save notes") {
                            var updated = definition
                            updated.notes = draftNotes
                            store.updateDefinition(updated)
                        }
                    }

                    Section("Edit") {
                        LabeledContent("Time of day", value: definition.habit.dayPart.rawValue.capitalized)
                        LabeledContent(
                            "Beyond target",
                            value: definition.quickLog.allowLoggingBeyondTarget ? "Allowed" : "Blocked"
                        )
                        Toggle(
                            "Allow logging beyond target",
                            isOn: beyondTargetBinding(definition)
                        )
                    }
                }
                .navigationTitle(definition.habit.title)
                .onAppear { draftNotes = definition.notes }
            } else {
                ContentUnavailableView("Habit unavailable", systemImage: "questionmark.circle")
            }
        }
    }

    private func beyondTargetBinding(_ definition: HabitDefinition) -> Binding<Bool> {
        Binding(
            get: { definition.quickLog.allowLoggingBeyondTarget },
            set: { newValue in
                var updated = definition
                updated.quickLog.allowLoggingBeyondTarget = newValue
                store.updateDefinition(updated)
            }
        )
    }

    private func logCustom(row: DayHabitRow) {
        let normalized = customAmountText.replacingOccurrences(of: ",", with: ".")
        guard let amount = Decimal(string: normalized), amount > 0 else {
            store.lastErrorMessage = "Enter a positive amount."
            return
        }
        _ = store.quickLog(row: row, amount: amount)
        customAmountText = ""
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
