import Foundation
import Testing
@testable import Ethos

struct PeriodEvaluationTests {
    private let start = Date(timeIntervalSinceReferenceDate: 1_000)
    private let end = Date(timeIntervalSinceReferenceDate: 2_000)

    @Test
    func skippedTakesPriorityOverPausedAndProgress() throws {
        let (goal, period) = try makeGoalAndPeriod(interval: .week)

        let outcome = evaluatePeriod(
            goal: goal, period: period, entries: [], now: end,
            isSkipped: true, isPaused: true
        )

        #expect(outcome == .skipped)
        #expect(period.outcome == .inProgress)
    }

    @Test
    func pausedStaysInProgressEvenAfterThePeriodEnds() throws {
        let (goal, period) = try makeGoalAndPeriod(interval: .day)

        #expect(evaluatePeriod(
            goal: goal, period: period, entries: [], now: end,
            isSkipped: false, isPaused: true
        ) == .inProgress)
    }

    @Test
    func weeklyGoalWaitsUntilTheEndEvenAfterReachingTheTarget() throws {
        let (goal, period) = try makeGoalAndPeriod(interval: .week)
        let entry = try makeEntry(habitID: period.habitID, at: start, amount: 2)

        #expect(evaluatePeriod(
            goal: goal, period: period, entries: [entry], now: end.addingTimeInterval(-1),
            isSkipped: false, isPaused: false
        ) == .inProgress)
        #expect(evaluatePeriod(
            goal: goal, period: period, entries: [entry], now: end,
            isSkipped: false, isPaused: false
        ) == .succeeded)
    }

    @Test(arguments: [GoalInterval.day, .month, .year])
    func nonWeeklyGoalsCanSucceedBeforeTheEnd(interval: GoalInterval) throws {
        let (goal, period) = try makeGoalAndPeriod(interval: interval)
        let entry = try makeEntry(habitID: period.habitID, at: start, amount: 2)

        #expect(evaluatePeriod(
            goal: goal, period: period, entries: [entry], now: start,
            isSkipped: false, isPaused: false
        ) == .succeeded)
    }

    @Test(arguments: [GoalInterval.day, .week, .month, .year])
    func shortfallFailsAtTheEnd(interval: GoalInterval) throws {
        let (goal, period) = try makeGoalAndPeriod(interval: interval)

        #expect(evaluatePeriod(
            goal: goal, period: period, entries: [], now: end.addingTimeInterval(-1),
            isSkipped: false, isPaused: false
        ) == .inProgress)
        #expect(evaluatePeriod(
            goal: goal, period: period, entries: [], now: end,
            isSkipped: false, isPaused: false
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
            isSkipped: false, isPaused: false
        ) == .succeeded)
        #expect(period.outcome == .inProgress)
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
