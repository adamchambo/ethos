import Foundation
import Testing
@testable import Ethos

struct HabitProgressServiceTests {
    @Test
    func repeatedLogsUseStoredPeriodAndEntries() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let today = calendar.date(from: DateComponents(year: 2026, month: 10, day: 11, hour: 12))!
        let habit = try Habit(
            title: "Drink water",
            createdAt: today,
            goal: Goal(measurement: .count, target: 3, interval: .day),
            schedule: .daily
        )
        let service = HabitProgressService(habits: [habit], now: today, calendar: calendar)
        let initialPeriod = try #require(service.periods.first { $0.habitID == habit.id })

        try service.log(habitID: habit.id, amount: 1, on: today, calendar: calendar)

        #expect(service.entries.count == 1)
        #expect(service.entries[0].amount == 1)
        #expect(service.periods.first { $0.habitID == habit.id }?.id == initialPeriod.id)
        #expect(service.periods.first { $0.habitID == habit.id }?.outcome == .inProgress)

        try service.log(habitID: habit.id, amount: 2, on: today.addingTimeInterval(60), calendar: calendar)

        #expect(service.entries.count == 2)
        #expect(service.progress(habitID: habit.id, on: today, calendar: calendar) == 3)
        #expect(service.periods.first { $0.habitID == habit.id }?.id == initialPeriod.id)
        #expect(service.periods.first { $0.habitID == habit.id }?.outcome == .succeeded)
    }
}
