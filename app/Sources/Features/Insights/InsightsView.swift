import SwiftUI

struct InsightsView: View {
    let service: HabitProgressService
    @State private var range = InsightRange.month

    var body: some View {
        let habits = service.habits.filter { $0.lifecycle != .archived }
        let start = range.start(from: .now, calendar: service.calendar)
        let decided = service.periods.filter { period in
            (period.outcome == .succeeded || period.outcome == .failed)
                && start.map { period.endsAt > $0 } ?? true
        }
        let succeeded = decided.filter { $0.outcome == .succeeded }.count
        let missed = decided.count - succeeded
        let longest = habits.map { service.streak(habitID: $0.id) }.max() ?? 0

        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 14) {
                        Picker("Range", selection: $range) {
                            ForEach(InsightRange.allCases) { range in
                                Text(range.label).tag(range)
                            }
                        }
                        .pickerStyle(.segmented)

                        HStack(alignment: .firstTextBaseline) {
                            headline(
                                decided.isEmpty ? "—" : percentText(Decimal(succeeded) / Decimal(decided.count)),
                                caption: "completion"
                            )
                            headline("\(longest)", caption: "longest streak")
                        }

                        if !decided.isEmpty {
                            Text("\(succeeded) done, \(missed) missed. Skips are left out.")
                                .font(.subheadline)
                                .foregroundStyle(EthosColor.secondaryInk)
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 8, trailing: 20))
                }

                Section("Habits") {
                    if habits.isEmpty {
                        Text("Streaks and completion show up after you add a habit.")
                            .foregroundStyle(EthosColor.secondaryInk)
                    } else {
                        ForEach(habits) { habit in
                            NavigationLink(value: habit.id) {
                                HabitSummaryRow(
                                    habit: habit,
                                    categories: service.categories,
                                    detail: "Streak \(service.streak(habitID: habit.id)) · Best \(service.best(habitID: habit.id))",
                                    trailing: rateText(rate(habit.id, in: decided))
                                )
                            }
                        }
                    }
                }
                .ethosRows()
            }
            .ethosScreen()
            .navigationTitle("Insights")
            .navigationDestination(for: UUID.self) { id in
                HabitDetailView(service: service, habitID: id)
            }
            .animation(.default, value: range)
        }
    }

    private func headline(_ value: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 40, weight: .semibold))
                .monospacedDigit()
                .contentTransition(.numericText())
            Text(caption)
                .font(.subheadline)
                .foregroundStyle(EthosColor.secondaryInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func rate(_ habitID: UUID, in decided: [HabitPeriod]) -> Decimal? {
        let mine = decided.filter { $0.habitID == habitID }
        guard !mine.isEmpty else { return nil }
        return Decimal(mine.filter { $0.outcome == .succeeded }.count) / Decimal(mine.count)
    }
}

private enum InsightRange: String, CaseIterable, Identifiable {
    case week
    case month
    case all

    var id: String { rawValue }

    var label: String {
        switch self {
        case .week: "7 days"
        case .month: "30 days"
        case .all: "All time"
        }
    }

    func start(from now: Date, calendar: Calendar) -> Date? {
        switch self {
        case .week: calendar.date(byAdding: .day, value: -7, to: now)
        case .month: calendar.date(byAdding: .day, value: -30, to: now)
        case .all: nil
        }
    }
}
