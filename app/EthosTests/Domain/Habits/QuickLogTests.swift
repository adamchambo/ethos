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
    func completeHabitLogsRemainingAmount() throws {
        let day = date(2026, 11, 10)
        let habit = try Habit(title: "Deep work", createdAt: day)
        let goal = try Goal(habitID: habit.id, measurement: .duration, target: 90, interval: .day)
        let existing = try ProgressEntry(habitID: habit.id, occurredAt: day, amount: 30)

        let result = try #require(try completeHabitProgress(
            habit: habit,
            goal: goal,
            schedule: .daily,
            on: day,
            existingPeriods: [],
            existingEntries: [existing],
            calendar: calendar,
            now: day
        ))

        #expect(result.entry.amount == 60)
        #expect(result.period.outcome == .succeeded)
    }

    @Test
    func checklistCompletionKeepsItemIdentity() throws {
        let day = date(2026, 11, 10)
        let item = ChecklistItem(title: "Make bed")
        let habit = try Habit(title: "Morning routine", createdAt: day)
        let goal = try Goal(habitID: habit.id, measurement: .count, target: 3, interval: .day)

        let result = try #require(try logProgress(
            habit: habit,
            goal: goal,
            schedule: .daily,
            amount: 1,
            on: day,
            existingPeriods: [],
            existingEntries: [],
            calendar: calendar,
            checklistItemID: item.id,
            now: day
        ))

        #expect(result.entry.checklistItemID == item.id)
        let states = checklistItemStates(
            items: [item, ChecklistItem(title: "Stretch")],
            habitID: habit.id,
            entries: result.entries,
            on: day,
            calendar: calendar
        )
        #expect(states[0].isComplete)
        #expect(!states[1].isComplete)
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
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
}
