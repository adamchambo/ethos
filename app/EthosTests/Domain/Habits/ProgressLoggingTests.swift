import Foundation
import Testing
@testable import Ethos

struct ProgressLoggingTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    @Test
    func ineligibleDateReturnsNil() throws {
        let habit = try makeHabit()
        let goal = try makeGoal(for: habit, target: 1, interval: .week)

        let result = try logProgress(
            habit: habit, goal: goal, schedule: .weekly(eligibleWeekdays: [.monday]),
            amount: 1, on: date(2026, 9, 22), existingPeriods: [], existingEntries: [],
            calendar: calendar, now: date(2026, 9, 22)
        )

        #expect(result == nil)
    }

    @Test
    func reachingDailyTargetFinalizesSucceeded() throws {
        let habit = try makeHabit()
        let goal = try makeGoal(for: habit, target: 2, interval: .day)
        let previous = try ProgressEntry(habitID: habit.id, occurredAt: date(2026, 9, 23), amount: 1)
        let occurredAt = date(2026, 9, 23, hour: 12)

        let result = try #require(try logProgress(
            habit: habit, goal: goal, schedule: .daily, amount: 1, on: occurredAt,
            existingPeriods: [], existingEntries: [previous], calendar: calendar,
            now: occurredAt
        ))

        #expect(result.period.outcome == .succeeded)
        #expect(result.period.isFinalized)
        #expect(result.entry.habitID == habit.id)
        #expect(result.entry.occurredAt == occurredAt)
        #expect(result.entry.amount == 1)
        #expect(result.entries == [previous, result.entry])
    }

    @Test
    func weeklyTargetReachingGoalFinalizesSucceeded() throws {
        let habit = try makeHabit()
        let goal = try makeGoal(for: habit, target: 1, interval: .week)

        let occurredAt = date(2026, 9, 23)
        let result = try #require(try logProgress(
            habit: habit, goal: goal, schedule: .daily, amount: 1,
            on: occurredAt, existingPeriods: [], existingEntries: [],
            calendar: calendar, now: occurredAt
        ))

        #expect(result.period.outcome == .succeeded)
        #expect(result.period.isFinalized)
        #expect(result.entries == [result.entry])
    }

    @Test
    func loggingAgainAfterFinalizationThrows() throws {
        let habit = try makeHabit()
        let goal = try makeGoal(for: habit, target: 1, interval: .day)
        let occurredAt = date(2026, 9, 23)
        let first = try #require(try logProgress(
            habit: habit, goal: goal, schedule: .daily, amount: 1, on: occurredAt,
            existingPeriods: [], existingEntries: [], calendar: calendar, now: occurredAt
        ))

        #expect(throws: QuickLogError.targetReached) {
            try logProgress(
                habit: habit, goal: goal, schedule: .daily, amount: 1,
                on: occurredAt.addingTimeInterval(1), existingPeriods: first.periods,
                existingEntries: first.entries, calendar: calendar, now: occurredAt
            )
        }
        #expect(first.entries == [first.entry])
    }

    @Test(arguments: [Decimal.zero, -1])
    func nonPositiveAmountThrows(amount: Decimal) throws {
        let habit = try makeHabit()
        let goal = try makeGoal(for: habit, target: 1, interval: .day)
        let occurredAt = date(2026, 9, 23)

        #expect(throws: ProgressEntryError.nonPositiveAmount) {
            try logProgress(
                habit: habit, goal: goal, schedule: .daily, amount: amount,
                on: occurredAt, existingPeriods: [], existingEntries: [],
                calendar: calendar, now: occurredAt
            )
        }
    }

    private func makeHabit() throws -> Habit {
        try Habit(title: "Gym", createdAt: date(2026, 9, 1))
    }

    private func makeGoal(for habit: Habit, target: Decimal, interval: GoalInterval) throws -> Goal {
        try Goal(habitID: habit.id, measurement: .count, target: target, interval: interval)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }
}
