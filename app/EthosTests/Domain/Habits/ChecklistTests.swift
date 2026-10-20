import Foundation
import Testing
@testable import Ethos

struct ChecklistTests {
    @Test
    func itemsCanBeAddedReorderedAndDeactivated() throws {
        var habit = try makeHabit()
        try habit.addChecklistItem(title: " Make bed ")
        try habit.addChecklistItem(title: "Stretch")
        let ids = habit.checklist.map(\.id)

        try habit.reorderChecklist([ids[1], ids[0]])
        try habit.deactivateChecklistItem(id: ids[1])

        #expect(habit.checklist.map(\.title) == ["Stretch", "Make bed"])
        #expect(habit.checklist.map(\.sortOrder) == [0, 1])
        #expect(habit.checklist[0].isActive == false)
        #expect(checklistProgress(
            habit: habit,
            period: try makePeriod(habitID: habit.id),
            entries: []
        ) == (done: 0, total: 1))
    }

    @Test
    func loggingAnUnknownChecklistItemThrows() throws {
        let habit = try makeHabit()

        #expect(throws: HabitError.unknownChecklistItem) {
            try logProgress(
                habit: habit,
                amount: 1,
                on: .now,
                existingPeriods: [],
                existingEntries: [],
                calendar: .current,
                checklistItemID: UUID()
            )
        }
    }

    private func makeHabit() throws -> Habit {
        try Habit(
            title: "Morning",
            createdAt: .now,
            goal: try Goal(measurement: .boolean, target: 1, interval: .day),
            schedule: .daily
        )
    }

    private func makePeriod(habitID: UUID) throws -> HabitPeriod {
        let start = Date(timeIntervalSinceReferenceDate: 1_000)
        return try HabitPeriod(habitID: habitID, startsAt: start, endsAt: start.addingTimeInterval(86_400))
    }
}
