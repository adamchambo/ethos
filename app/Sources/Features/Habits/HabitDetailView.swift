import SwiftUI

/// The single detail screen for a habit. Today, Habits, and Insights all push here; editing starts from its Edit button.
struct HabitDetailView: View {
    let service: HabitProgressService
    let habitID: UUID
    @State private var editing = false

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

                    if !notes.isEmpty {
                        Section("Reflections") {
                            ForEach(notes) { reflection in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(reflection.response)
                                    Text(reflection.createdAt.formatted(date: .abbreviated, time: .omitted))
                                        .font(.caption)
                                        .foregroundStyle(EthosColor.secondaryInk)
                                }
                            }
                        }
                    }

                    if let notesText = habit.notes {
                        Section("Notes") {
                            Text(notesText)
                        }
                    }
                }
                .ethosRows()
            }
            .ethosScreen()
            .navigationTitle(habit.title)
            .toolbar {
                Button("Edit") { editing = true }
            }
            .sheet(isPresented: $editing) {
                HabitEditor(service: service, habit: habit)
            }
        } else {
            ContentUnavailableView("This habit is gone", systemImage: "list.bullet")
                .ethosScreen()
        }
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
        var parts = [scheduleText(habit.schedule)]
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
            return entry.amount == 1 ? "Slipped" : "Slipped \(amountText(entry.amount))"
        }
        if habit.goal.measurement == .boolean {
            return "Done"
        }
        let unit = switch habit.goal.unit {
        case .times: ""
        case .minutes: " min"
        case let .custom(name): " \(name)"
        }
        return "+\(amountText(entry.amount))\(unit)"
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
