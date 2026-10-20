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
        let habit = try makeHabit(target: 1, interval: .week, schedule: .weekly(eligibleWeekdays: [.monday]))

        let result = try logProgress(
            habit: habit, amount: 1, on: date(2026, 9, 22),
            existingPeriods: [], existingEntries: [], calendar: calendar
        )

        #expect(result == nil)
    }

    @Test
    func reachingDailyTargetFinalizesSucceeded() throws {
        let habit = try makeHabit(target: 2, interval: .day, schedule: .daily)
        let previous = try ProgressEntry(habitID: habit.id, occurredAt: date(2026, 9, 23), amount: 1)
        let occurredAt = date(2026, 9, 23, hour: 12)

        let result = try #require(try logProgress(
            habit: habit, amount: 1, on: occurredAt,
            existingPeriods: [], existingEntries: [previous], calendar: calendar
        ))

        #expect(result.period.outcome == .succeeded)
        #expect(result.period.isFinalized)
        #expect(result.entry.habitID == habit.id)
        #expect(result.entry.occurredAt == occurredAt)
        #expect(result.entry.amount == 1)
        #expect(result.entries == [previous, result.entry])
    }

    @Test
    func weeklyTargetBeforePeriodEndStaysInProgress() throws {
        let habit = try makeHabit(target: 1, interval: .week, schedule: .daily)

        let result = try #require(try logProgress(
            habit: habit, amount: 1, on: date(2026, 9, 23),
            existingPeriods: [], existingEntries: [], calendar: calendar
        ))

        #expect(result.period.outcome == .inProgress)
        #expect(!result.period.isFinalized)
        #expect(result.entries == [result.entry])
    }

    @Test
    func loggingAgainAfterFinalizationThrows() throws {
        let habit = try makeHabit(target: 1, interval: .day, schedule: .daily)
        let occurredAt = date(2026, 9, 23)
        let first = try #require(try logProgress(
            habit: habit, amount: 1, on: occurredAt,
            existingPeriods: [], existingEntries: [], calendar: calendar
        ))

        #expect(throws: HabitPeriodError.alreadyFinalized) {
            try logProgress(
                habit: habit, amount: 1, on: occurredAt.addingTimeInterval(1),
                existingPeriods: [first.period], existingEntries: first.entries, calendar: calendar
            )
        }
        #expect(first.entries == [first.entry])
    }

    @Test(arguments: [Decimal.zero, -1])
    func nonPositiveAmountThrows(amount: Decimal) throws {
        let habit = try makeHabit(target: 1, interval: .day, schedule: .daily)

        #expect(throws: ProgressEntryError.nonPositiveAmount) {
            try logProgress(
                habit: habit, amount: amount, on: date(2026, 9, 23),
                existingPeriods: [], existingEntries: [], calendar: calendar
            )
        }
    }

    @Test
    func quickCompleteLogsOnlyTheRemainingAmount() throws {
        let habit = try makeHabit(target: 3, interval: .day, schedule: .daily)
        let existing = try ProgressEntry(habitID: habit.id, occurredAt: date(2026, 9, 23), amount: 1)

        let result = try #require(try quickComplete(
            habit: habit,
            on: date(2026, 9, 23, hour: 12),
            existingPeriods: [],
            existingEntries: [existing],
            calendar: calendar
        ))

        #expect(result.entry.amount == 2)
        #expect(result.period.outcome == .succeeded)
    }

    @Test
    func quickCompleteRefusesAQuitHabitAndAFinishedTarget() throws {
        let quit = try Habit(
            title: "Smoking",
            createdAt: date(2026, 9, 1),
            goal: try Goal(measurement: .count, target: 0, interval: .day),
            schedule: .daily,
            direction: .quit
        )
        #expect(throws: ProgressActionError.notAvailableForQuit) {
            try quickComplete(
                habit: quit, on: date(2026, 9, 23),
                existingPeriods: [], existingEntries: [], calendar: calendar
            )
        }

        let habit = try makeHabit(target: 1, interval: .day, schedule: .daily)
        let done = try ProgressEntry(habitID: habit.id, occurredAt: date(2026, 9, 23), amount: 1)
        #expect(throws: ProgressActionError.nothingRemaining) {
            try quickComplete(
                habit: habit, on: date(2026, 9, 23, hour: 1),
                existingPeriods: [], existingEntries: [done], calendar: calendar
            )
        }
    }

    @Test
    func uncompleteDropsThePeriodsEntriesWhileTheWindowIsOpen() throws {
        let habit = try makeHabit(target: 1, interval: .day, schedule: .daily)
        let logged = try #require(try logProgress(
            habit: habit, amount: 1, on: date(2026, 9, 23, hour: 8),
            existingPeriods: [], existingEntries: [], calendar: calendar
        ))
        let other = try ProgressEntry(
            habitID: UUID(),
            occurredAt: date(2026, 9, 23, hour: 9),
            amount: 1
        )

        let reopened = try uncomplete(
            period: logged.period,
            entries: logged.entries + [other],
            now: date(2026, 9, 23, hour: 12)
        )

        #expect(reopened.period.outcome == .inProgress)
        #expect(reopened.entries == [other])
        #expect(throws: HabitPeriodError.periodClosed) {
            try uncomplete(period: logged.period, entries: logged.entries, now: logged.period.endsAt)
        }
    }

    @Test
    func closingExpiredPeriodsFinalizesBuildAndQuitDifferently() throws {
        let build = try makeHabit(target: 1, interval: .day, schedule: .daily)
        let quit = try Habit(
            title: "Smoking",
            createdAt: date(2026, 9, 1),
            goal: try Goal(measurement: .count, target: 0, interval: .day),
            schedule: .daily,
            direction: .quit
        )
        var paused = try makeHabit(target: 1, interval: .day, schedule: .daily)
        paused.pause()
        let buildPeriod = try HabitPeriod(
            habitID: build.id, startsAt: date(2026, 9, 23), endsAt: date(2026, 9, 24)
        )
        let quitPeriod = try HabitPeriod(
            habitID: quit.id, startsAt: date(2026, 9, 23), endsAt: date(2026, 9, 24)
        )
        let pausedPeriod = try HabitPeriod(
            habitID: paused.id, startsAt: date(2026, 9, 23), endsAt: date(2026, 9, 24)
        )

        let closed = closeExpiredPeriods(
            habits: [build, quit, paused],
            periods: [buildPeriod, quitPeriod, pausedPeriod],
            entries: [],
            now: date(2026, 9, 24)
        )

        #expect(closed[0].outcome == .failed)
        #expect(closed[1].outcome == .succeeded)
        #expect(closed[2].outcome == .inProgress)
    }

    private func makeHabit(target: Decimal, interval: GoalInterval, schedule: HabitSchedule) throws -> Habit {
        try Habit(
            title: "Gym",
            createdAt: date(2026, 9, 1),
            goal: try Goal(measurement: .count, target: target, interval: interval),
            schedule: schedule
        )
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }
}
