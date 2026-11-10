import Foundation
import Testing
@testable import Ethos

struct PeriodEvaluationTests {
    private let start = Date(timeIntervalSinceReferenceDate: 1_000)
    private let end = Date(timeIntervalSinceReferenceDate: 2_000)
    private let calendar = Calendar(identifier: .gregorian)

    @Test
    func skippedTakesPriorityOverPausedAndProgress() throws {
        let (goal, period) = try makeGoalAndPeriod(interval: .week)

        let outcome = evaluatePeriod(
            goal: goal, period: period, entries: [], now: end,
            isSkipped: true, isPaused: true, calendar: calendar
        )

        #expect(outcome == .skipped)
        #expect(period.outcome == .inProgress)
    }

    @Test
    func pausedStaysInProgressEvenAfterThePeriodEnds() throws {
        let (goal, period) = try makeGoalAndPeriod(interval: .day)

        #expect(evaluatePeriod(
            goal: goal, period: period, entries: [], now: end,
            isSkipped: false, isPaused: true, calendar: calendar
        ) == .inProgress)
    }

    @Test
    func weeklyGoalSucceedsAsSoonAsTheTargetIsReached() throws {
        let (goal, period) = try makeGoalAndPeriod(interval: .week)
        let entry = try makeEntry(habitID: period.habitID, at: start, amount: 2)

        #expect(evaluatePeriod(
            goal: goal, period: period, entries: [entry], now: end.addingTimeInterval(-1),
            isSkipped: false, isPaused: false, calendar: calendar
        ) == .succeeded)
    }

    @Test(arguments: [GoalInterval.day, .week, .month, .year])
    func goalsCanSucceedBeforeTheEnd(interval: GoalInterval) throws {
        let (goal, period) = try makeGoalAndPeriod(interval: interval)
        let entry = try makeEntry(habitID: period.habitID, at: start, amount: 2)

        #expect(evaluatePeriod(
            goal: goal, period: period, entries: [entry], now: start,
            isSkipped: false, isPaused: false, calendar: calendar
        ) == .succeeded)
    }

    @Test(arguments: [GoalInterval.day, .week, .month, .year])
    func shortfallFailsAtTheEnd(interval: GoalInterval) throws {
        let (goal, period) = try makeGoalAndPeriod(interval: interval)

        #expect(evaluatePeriod(
            goal: goal, period: period, entries: [], now: end.addingTimeInterval(-1),
            isSkipped: false, isPaused: false, calendar: calendar
        ) == .inProgress)
        #expect(evaluatePeriod(
            goal: goal, period: period, entries: [], now: end,
            isSkipped: false, isPaused: false, calendar: calendar
        ) == .failed)
    }

    @Test(arguments: [
        GoalMeasurement.boolean, .count, .duration, .quantity
    ])
    func sumsOnlyMatchingEntriesInTheHalfOpenPeriod(measurement: GoalMeasurement) throws {
        let (goal, period) = try makeGoalAndPeriod(measurement: measurement, target: 3)
        let entries = try [
            makeEntry(habitID: period.habitID, at: start.addingTimeInterval(-1), amount: 10),
            makeEntry(habitID: period.habitID, at: start, amount: 1),
            makeEntry(habitID: period.habitID, at: end.addingTimeInterval(-1), amount: 2),
            makeEntry(habitID: period.habitID, at: end, amount: 10),
            makeEntry(habitID: UUID(), at: start, amount: 10)
        ]

        #expect(evaluatePeriod(
            goal: goal, period: period, entries: entries, now: start,
            isSkipped: false, isPaused: false, calendar: calendar
        ) == .succeeded)
        #expect(period.outcome == .inProgress)
    }

    @Test
    func daysCountingModeCountsUniqueCalendarDays() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = calendar.date(from: DateComponents(year: 2026, month: 11, day: 10))!
        let periodStart = day
        let periodEnd = calendar.date(byAdding: .day, value: 7, to: day)!
        let habitID = UUID()
        let goal = try Goal(
            habitID: habitID,
            measurement: .count,
            target: 2,
            interval: .week,
            countingMode: .days
        )
        let period = try HabitPeriod(habitID: habitID, startsAt: periodStart, endsAt: periodEnd)
        let entries = try [
            ProgressEntry(habitID: habitID, occurredAt: day, amount: 3),
            ProgressEntry(
                habitID: habitID,
                occurredAt: day.addingTimeInterval(60 * 60),
                amount: 4
            ),
            ProgressEntry(
                habitID: habitID,
                occurredAt: calendar.date(byAdding: .day, value: 1, to: day)!,
                amount: 1
            )
        ]

        #expect(progressTowardGoal(
            goal: goal, period: period, entries: entries, calendar: calendar
        ) == 2)
        #expect(evaluatePeriod(
            goal: goal, period: period, entries: entries, now: day,
            isSkipped: false, isPaused: false, calendar: calendar
        ) == .succeeded)
    }

    private func makeGoalAndPeriod(
        measurement: GoalMeasurement = .count,
        target: Decimal = 2,
        interval: GoalInterval = .day
    ) throws -> (Goal, HabitPeriod) {
        let habitID = UUID()
        return (
            try Goal(habitID: habitID, measurement: measurement, target: target, interval: interval),
            try HabitPeriod(habitID: habitID, startsAt: start, endsAt: end)
        )
    }

    private func makeEntry(habitID: UUID, at date: Date, amount: Decimal) throws -> ProgressEntry {
        try ProgressEntry(habitID: habitID, occurredAt: date, amount: amount)
    }
}
