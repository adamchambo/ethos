import Foundation
import Observation

@Observable
final class HabitProgressService {
    private(set) var habits: [Habit]
    private(set) var periods: [HabitPeriod]
    private(set) var entries: [ProgressEntry] = []

    init(habits: [Habit] = [], now: Date = .now, calendar: Calendar = .current) {
        self.habits = habits
        periods = habits.compactMap {
            resolvePeriod(habit: $0, on: now, existing: [], calendar: calendar)
        }
    }

    func log(habitID: UUID, amount: Decimal, on date: Date, calendar: Calendar) throws {
        guard let habit = habits.first(where: { $0.id == habitID }) else { return }
        guard let result = try logProgress(
            habit: habit,
            amount: amount,
            on: date,
            existingPeriods: periods,
            existingEntries: entries,
            calendar: calendar
        ) else { return }

        if let index = periods.firstIndex(where: { $0.id == result.period.id }) {
            periods[index] = result.period
        } else {
            periods.append(result.period)
        }
        entries = result.entries
    }

    func progress(habitID: UUID, on date: Date, calendar: Calendar) -> Decimal {
        guard let habit = habits.first(where: { $0.id == habitID }),
              let window = periodWindow(containing: date, interval: habit.goal.interval, calendar: calendar)
        else { return .zero }

        return entries
            .filter {
                $0.habitID == habitID && $0.occurredAt >= window.startsAt && $0.occurredAt < window.endsAt
            }
            .reduce(.zero) { $0 + $1.amount }
    }

    func streak(habitID: UUID) -> Int {
        currentStreak(habitID: habitID, periods: periods)
    }

    func rate(habitID: UUID) -> Decimal? {
        completionRate(habitID: habitID, periods: periods)
    }
}
