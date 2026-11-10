import Foundation
import Testing
@testable import Ethos

struct PeriodEvaluationTests {
    private let start = Date(timeIntervalSinceReferenceDate: 1_000)
    private let end = Date(timeIntervalSinceReferenceDate: 2_000)

    @Test
    func skippedTakesPriorityOverPausedAndProgress() throws {
        var (habit, period) = try makeHabitAndPeriod(interval: .week)
        habit.pause()

        let outcome = evaluatePeriod(
            habit: habit, period: period, entries: [], now: end, isSkipped: true
        )

        #expect(outcome == .skipped)
        #expect(period.outcome == .inProgress)
    }

    @Test
    func pausedStaysInProgressEvenAfterThePeriodEnds() throws {
        var (habit, period) = try makeHabitAndPeriod(interval: .day)
        habit.pause()

        #expect(evaluatePeriod(
            habit: habit, period: period, entries: [], now: end, isSkipped: false
        ) == .inProgress)
    }

    @Test
    func weeklyGoalSucceedsAsSoonAsTheTargetIsReached() throws {
        let (habit, period) = try makeHabitAndPeriod(interval: .week)
        let entry = try makeEntry(habitID: period.habitID, at: start, amount: 2)

        #expect(evaluatePeriod(
            habit: habit, period: period, entries: [entry], now: end.addingTimeInterval(-1),
            isSkipped: false
        ) == .succeeded)
        #expect(evaluatePeriod(
            habit: habit, period: period, entries: [entry], now: end, isSkipped: false
        ) == .succeeded)
    }

    @Test(arguments: [GoalInterval.day, .week, .month, .year])
    func buildGoalsCanSucceedBeforeTheEnd(interval: GoalInterval) throws {
        let (habit, period) = try makeHabitAndPeriod(interval: interval)
        let entry = try makeEntry(habitID: period.habitID, at: start, amount: 2)

        #expect(evaluatePeriod(
            habit: habit, period: period, entries: [entry], now: start, isSkipped: false
        ) == .succeeded)
    }

    @Test(arguments: [GoalInterval.day, .week, .month, .year])
    func shortfallFailsAtTheEnd(interval: GoalInterval) throws {
        let (habit, period) = try makeHabitAndPeriod(interval: interval)

        #expect(evaluatePeriod(
            habit: habit, period: period, entries: [], now: end.addingTimeInterval(-1),
            isSkipped: false
        ) == .inProgress)
        #expect(evaluatePeriod(
            habit: habit, period: period, entries: [], now: end, isSkipped: false
        ) == .failed)
    }

    @Test(arguments: [
        GoalMeasurement.boolean, .count, .duration, .quantity
    ])
    func sumsOnlyMatchingEntriesInTheHalfOpenPeriod(measurement: GoalMeasurement) throws {
        let (habit, period) = try makeHabitAndPeriod(measurement: measurement, target: 3)
        let entries = try [
            makeEntry(habitID: period.habitID, at: start.addingTimeInterval(-1), amount: 10),
            makeEntry(habitID: period.habitID, at: start, amount: 1),
            makeEntry(habitID: period.habitID, at: end.addingTimeInterval(-1), amount: 2),
            makeEntry(habitID: period.habitID, at: end, amount: 10),
            makeEntry(habitID: UUID(), at: start, amount: 10)
        ]

        #expect(evaluatePeriod(
            habit: habit, period: period, entries: entries, now: start, isSkipped: false
        ) == .succeeded)
        #expect(period.outcome == .inProgress)
    }

    @Test
    func aQuitHabitFailsAsSoonAsSlipsPassTheLimit() throws {
        let (habit, period) = try makeHabitAndPeriod(target: 0, direction: .quit)
        let slip = try makeEntry(habitID: period.habitID, at: start, amount: 1)

        #expect(evaluatePeriod(
            habit: habit, period: period, entries: [slip], now: start, isSkipped: false
        ) == .failed)
    }

    @Test
    func aQuitHabitSucceedsOnlyWhenThePeriodClosesAtOrUnderTheLimit() throws {
        let (habit, period) = try makeHabitAndPeriod(target: 1, interval: .week, direction: .quit)
        let slip = try makeEntry(habitID: period.habitID, at: start, amount: 1)

        #expect(evaluatePeriod(
            habit: habit, period: period, entries: [slip], now: end.addingTimeInterval(-1), isSkipped: false
        ) == .inProgress)
        #expect(evaluatePeriod(
            habit: habit, period: period, entries: [slip], now: end, isSkipped: false
        ) == .succeeded)
    }

    @Test
    func progressFractionReportsTheTotalAgainstTheTarget() throws {
        let (habit, period) = try makeHabitAndPeriod(target: 2)
        let entry = try makeEntry(habitID: period.habitID, at: start, amount: 3)

        #expect(progressFraction(habit: habit, period: period, entries: [entry]) == Decimal(3) / Decimal(2))
        #expect(displayedProgressFraction(habit: habit, period: period, entries: [entry]) == Decimal(3) / Decimal(2))

        var capped = habit
        try capped.changeGoal(to: try Goal(
            measurement: .count,
            target: 2,
            interval: .day,
            allowsOverCompletion: false
        ))
        #expect(displayedProgressFraction(habit: capped, period: period, entries: [entry]) == 1)
    }

    @Test
    func completingEveryChecklistItemSucceedsABuildHabit() throws {
        var (habit, period) = try makeHabitAndPeriod(target: 5)
        try habit.addChecklistItem(title: "Make bed")
        try habit.addChecklistItem(title: "Stretch")
        let entries = try habit.checklist.map { item in
            try ProgressEntry(
                habitID: habit.id,
                occurredAt: start,
                amount: 1,
                checklistItemID: item.id
            )
        }

        #expect(evaluatePeriod(
            habit: habit, period: period, entries: entries, now: start, isSkipped: false
        ) == .succeeded)
        #expect(checklistProgress(habit: habit, period: period, entries: entries) == (done: 2, total: 2))
    }

    @Test
    func aChecklistEntryDoesNotCountTowardTheGoalTotal() throws {
        var (habit, period) = try makeHabitAndPeriod(target: 5)
        try habit.addChecklistItem(title: "Make bed")
        try habit.addChecklistItem(title: "Stretch")
        let entry = try ProgressEntry(
            habitID: habit.id,
            occurredAt: start,
            amount: 5,
            checklistItemID: habit.checklist[0].id
        )

        #expect(goalTotal(in: period, entries: [entry]) == 0)
        #expect(evaluatePeriod(
            habit: habit, period: period, entries: [entry], now: start, isSkipped: false
        ) == .inProgress)
    }

    private func makeHabitAndPeriod(
        measurement: GoalMeasurement = .count,
        target: Decimal = 2,
        interval: GoalInterval = .day,
        direction: HabitDirection = .build
    ) throws -> (Habit, HabitPeriod) {
        let habit = try Habit(
            title: "Read",
            createdAt: start,
            goal: try Goal(measurement: measurement, target: target, interval: interval),
            schedule: .daily,
            direction: direction
        )
        let period = try HabitPeriod(habitID: habit.id, startsAt: start, endsAt: end)
        return (habit, period)
    }

    private func makeEntry(habitID: UUID, at date: Date, amount: Decimal) throws -> ProgressEntry {
        try ProgressEntry(habitID: habitID, occurredAt: date, amount: amount)
    }
}
