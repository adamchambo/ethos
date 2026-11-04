import SwiftUI

struct InsightsView: View {
    let service: HabitProgressService

    var body: some View {
        let habits = service.habits.filter { $0.lifecycle != .archived }
        let decided = service.periods.filter { $0.outcome == .succeeded || $0.outcome == .failed }
        let succeeded = decided.filter { $0.outcome == .succeeded }.count
        let longest = habits.map { service.streak(habitID: $0.id) }.max() ?? 0

        NavigationStack {
            List {
                Section("Overall") {
                    LabeledContent("Active habits", value: "\(habits.count)")
                    LabeledContent("Completion", value: decided.isEmpty ? "—" : percentText(Decimal(succeeded) / Decimal(decided.count)))
                    LabeledContent("Longest current streak", value: "\(longest)")
                }

                Section("Habits") {
                    if habits.isEmpty {
                        Text("Streaks and completion show up after you add a habit.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(habits) { habit in
                            NavigationLink(habit.title) {
                                HabitInsightView(service: service, habitID: habit.id)
                            }
                        }
                    }
                }

                Section {
                    Text("A skip stays out of the completion rate. A miss breaks the streak. A weekly goal stays in progress until the week ends.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Insights")
        }
    }
}

private struct HabitInsightView: View {
    let service: HabitProgressService
    let habitID: UUID
    @State private var editing = false

    var body: some View {
        if let habit = service.habits.first(where: { $0.id == habitID }) {
            let periods = service.periods
                .filter { $0.habitID == habitID }
                .sorted { $0.startsAt > $1.startsAt }
            let notes = service.reflections.filter { reflection in
                periods.contains { $0.id == reflection.periodID }
            }

            List {
                Section {
                    LabeledContent("Streak", value: "\(service.streak(habitID: habitID))")
                    LabeledContent("Best streak", value: "\(service.best(habitID: habitID))")
                    LabeledContent("Completion", value: rateText(service.rate(habitID: habitID)))
                    LabeledContent("Goal", value: goalText(habit.goal))
                    LabeledContent("Schedule", value: scheduleText(habit.schedule))
                }

                if !periods.isEmpty {
                    Section("Recent periods") {
                        HStack(spacing: 6) {
                            ForEach(periods.prefix(28)) { period in
                                Circle()
                                    .fill(color(for: period.outcome))
                                    .frame(width: 10, height: 10)
                            }
                        }
                        ForEach(periods.prefix(12)) { period in
                            LabeledContent(
                                period.startsAt.formatted(date: .abbreviated, time: .omitted),
                                value: outcomeText(period.outcome)
                            )
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
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle(habit.title)
            .toolbar {
                Button("Edit") { editing = true }
            }
            .sheet(isPresented: $editing) {
                HabitEditor(service: service, habit: habit)
            }
        } else {
            ContentUnavailableView("Habit unavailable", systemImage: "chart.bar")
        }
    }

    private func color(for outcome: HabitPeriodOutcome) -> Color {
        switch outcome {
        case .succeeded: .green
        case .failed: .red
        case .skipped: .gray
        case .inProgress: .orange
        }
    }
}
