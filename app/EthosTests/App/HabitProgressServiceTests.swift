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

    @Test
    func addStoresTheHabitAndItsPeriodOnlyInThatService() throws {
        let (calendar, today) = utcToday()
        let service = HabitProgressService(now: today, calendar: calendar)

        try service.add(title: "Read", measurement: .boolean, target: 1, on: today, calendar: calendar)

        let habit = try #require(service.habits.first)
        #expect(habit.title == "Read")
        #expect(habit.schedule == .daily)
        #expect(habit.goal.interval == .day)
        #expect(service.periods.count == 1)
        #expect(service.periods[0].habitID == habit.id)

        let fresh = HabitProgressService(now: today, calendar: calendar)
        #expect(fresh.habits.isEmpty)
        #expect(fresh.periods.isEmpty)
    }

    @Test
    func quickCompleteLogsTheRemainingAmount() throws {
        let (calendar, today) = utcToday()
        let habit = try dailyHabit(title: "Drink water", target: 3, on: today)
        let service = HabitProgressService(habits: [habit], now: today, calendar: calendar)

        try service.quickComplete(habitID: habit.id, on: today, calendar: calendar)

        #expect(service.entries.map(\.amount) == [3])
        #expect(service.progress(habitID: habit.id, on: today, calendar: calendar) == 3)
        #expect(service.periods.first { $0.habitID == habit.id }?.outcome == .succeeded)
    }

    @Test
    func skipFinalizesTheOpenPeriod() throws {
        let (calendar, today) = utcToday()
        let habit = try dailyHabit(title: "Read", target: 1, on: today)
        let service = HabitProgressService(habits: [habit], now: today, calendar: calendar)

        try service.skip(habitID: habit.id, on: today, calendar: calendar)

        #expect(service.entries.isEmpty)
        #expect(service.periods.first { $0.habitID == habit.id }?.outcome == .skipped)
    }

    @Test
    func prepareFailsABuildPeriodWhoseWindowHasEnded() throws {
        let (calendar, today) = utcToday()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let habit = try dailyHabit(title: "Read", target: 1, on: yesterday)
        let service = HabitProgressService(habits: [habit], now: yesterday, calendar: calendar)

        service.prepare(now: today)

        #expect(service.periods.first { $0.habitID == habit.id }?.outcome == .failed)
    }

    @Test
    func sampleLibraryMixesDonePartialAndAMiss() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let monday = calendar.date(from: DateComponents(year: 2026, month: 11, day: 9, hour: 12))!
        let sample = SampleLibrary.make(now: monday, calendar: calendar)

        #expect(sample.habits.count == 6)
        #expect(sample.reflections.count == 1)
        #expect(sample.journal.count == 1)

        let vitamins = try #require(sample.habits.first { $0.title == "Take vitamins" })
        let water = try #require(sample.habits.first { $0.title == "Drink water" })
        let vitaminToday = try #require(sample.periods.first {
            $0.habitID == vitamins.id && $0.startsAt <= monday && monday < $0.endsAt
        })
        let waterToday = try #require(sample.periods.first {
            $0.habitID == water.id && $0.startsAt <= monday && monday < $0.endsAt
        })

        #expect(vitaminToday.outcome == .succeeded)
        #expect(waterToday.outcome == .inProgress)
        #expect(sample.periods.contains { $0.habitID == vitamins.id && $0.outcome == .failed })
    }
}

private func utcToday() -> (Calendar, Date) {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let today = calendar.date(from: DateComponents(year: 2026, month: 10, day: 11, hour: 12))!
    return (calendar, today)
}

private func dailyHabit(title: String, target: Decimal, on date: Date) throws -> Habit {
    try Habit(
        title: title,
        createdAt: date,
        goal: Goal(measurement: .count, target: target, interval: .day),
        schedule: .daily
    )
}
