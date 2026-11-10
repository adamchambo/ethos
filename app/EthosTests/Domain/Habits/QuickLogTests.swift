import Foundation
import Testing
@testable import Ethos

struct QuickLogTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    @Test
    func loggingOnAFutureDateFails() throws {
        let habit = try Habit(title: "Read", createdAt: date(2026, 11, 1))
        let goal = try Goal(habitID: habit.id, measurement: .count, target: 1, interval: .day)

        #expect(throws: QuickLogError.futureDate) {
            try logProgress(
                habit: habit,
                goal: goal,
                schedule: .daily,
                amount: 1,
                on: date(2026, 11, 11),
                existingPeriods: [],
                existingEntries: [],
                calendar: calendar,
                now: date(2026, 11, 10)
            )
        }
    }

    @Test
    func undoRemovesEntryAndReopensCompletion() throws {
        let day = date(2026, 11, 10)
        let habit = try Habit(title: "Vitamins", createdAt: day)
        let goal = try Goal(habitID: habit.id, measurement: .boolean, target: 1, interval: .day)

        let logged = try #require(try logProgress(
            habit: habit,
            goal: goal,
            schedule: .daily,
            amount: 1,
            on: day,
            existingPeriods: [],
            existingEntries: [],
            calendar: calendar,
            now: day
        ))
        #expect(logged.period.outcome == .succeeded)

        let undone = try undoProgress(
            entryID: logged.entry.id,
            habit: habit,
            goal: goal,
            schedule: .daily,
            existingPeriods: logged.periods,
            existingEntries: logged.entries,
            calendar: calendar,
            now: day
        )

        #expect(undone.entries.isEmpty)
        #expect(undone.periods.first?.outcome == .inProgress)

        let row = try #require(makeDayHabitRow(
            habit: habit,
            goal: goal,
            schedule: .daily,
            quickLog: .done(),
            on: day,
            periods: undone.periods,
            entries: undone.entries,
            calendar: calendar,
            now: day
        ))
        #expect(row.placement == .inProgress(.anytime))
        #expect(row.progressLabel == "Not yet")
    }

    @Test
    func beyondTargetLoggingRequiresPermission() throws {
        let day = date(2026, 11, 10)
        let habit = try Habit(title: "Deep work", createdAt: day)
        let goal = try Goal(habitID: habit.id, measurement: .duration, target: 30, interval: .day)
        let first = try #require(try logProgress(
            habit: habit,
            goal: goal,
            schedule: .daily,
            amount: 30,
            on: day,
            existingPeriods: [],
            existingEntries: [],
            calendar: calendar,
            now: day
        ))

        #expect(throws: QuickLogError.targetReached) {
            try logProgress(
                habit: habit,
                goal: goal,
                schedule: .daily,
                amount: 15,
                on: day,
                existingPeriods: first.periods,
                existingEntries: first.entries,
                calendar: calendar,
                allowLoggingBeyondTarget: false,
                now: day
            )
        }

        let beyond = try #require(try logProgress(
            habit: habit,
            goal: goal,
            schedule: .daily,
            amount: 15,
            on: day,
            existingPeriods: first.periods,
            existingEntries: first.entries,
            calendar: calendar,
            allowLoggingBeyondTarget: true,
            now: day
        ))
        #expect(beyond.entries.count == 2)
        #expect(
            progressTowardGoal(
                goal: goal,
                period: beyond.period,
                entries: beyond.entries,
                calendar: calendar
            ) == 45
        )
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
}
