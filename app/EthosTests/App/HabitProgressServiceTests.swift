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

    @Test
    func aSundayWeekStartOpensTheWeeklyPeriodOnSunday() throws {
        let (calendar, sunday) = utcDate(year: 2026, month: 9, day: 20)
        let saturday = calendar.date(byAdding: .day, value: -1, to: sunday)!
        let service = HabitProgressService(now: sunday, calendar: calendar)
        var profile = service.profile
        profile.weekStart = .sunday
        service.updateProfile(profile)

        let habit = try Habit(
            title: "Gym",
            createdAt: sunday,
            goal: Goal(measurement: .count, target: 3, interval: .week),
            schedule: .daily,
            startDate: sunday
        )
        service.save(habit: habit, reminder: nil, on: saturday, calendar: calendar)
        #expect(service.periods.isEmpty)

        let opened = try #require(service.openPeriod(habitID: habit.id, on: sunday, calendar: calendar))
        #expect(opened.startsAt == startOfDay(sunday, calendar: calendar))
        #expect(opened.endsAt == startOfDay(calendar.date(byAdding: .day, value: 7, to: sunday)!, calendar: calendar))

        try service.log(habitID: habit.id, amount: 1, on: sunday, calendar: calendar)

        let stored = try #require(service.recordedPeriod(habitID: habit.id, on: sunday))
        #expect(stored.startsAt == opened.startsAt)
        #expect(stored.endsAt == opened.endsAt)
    }

    @Test
    func anOpenWeekAcceptsALogOnAnEarlierDay() throws {
        let (calendar, wednesday) = utcDate(year: 2026, month: 9, day: 23, hour: 12)
        let monday = calendar.date(from: DateComponents(year: 2026, month: 9, day: 21, hour: 9))!
        let habit = try Habit(
            title: "Gym",
            createdAt: monday,
            goal: Goal(measurement: .count, target: 3, interval: .week),
            schedule: .daily
        )
        let service = HabitProgressService(habits: [habit], now: wednesday, calendar: calendar)

        try service.log(habitID: habit.id, amount: 1, on: monday, calendar: calendar)

        #expect(service.progress(habitID: habit.id, on: monday, calendar: calendar) == 1)
        #expect(service.progress(habitID: habit.id, on: wednesday, calendar: calendar) == 1)
        #expect(!service.isWindowClosed(habitID: habit.id, on: monday, calendar: calendar))
        #expect(!service.isFuture(monday, calendar: calendar))
        #expect(service.recordedPeriod(habitID: habit.id, on: monday)?.id == service.recordedPeriod(habitID: habit.id, on: wednesday)?.id)
    }

    @Test
    func aClosedDayIsReadOnlyAndAFutureDayIsRefused() throws {
        let (calendar, tuesday) = utcDate(year: 2026, month: 9, day: 22, hour: 12)
        let sunday = calendar.date(from: DateComponents(year: 2026, month: 9, day: 20, hour: 8))!
        let monday = calendar.date(from: DateComponents(year: 2026, month: 9, day: 21, hour: 8))!
        let wednesday = calendar.date(from: DateComponents(year: 2026, month: 9, day: 23, hour: 8))!
        let habit = try dailyHabit(title: "Read", target: 1, on: sunday)
        let service = HabitProgressService(habits: [habit], now: tuesday, calendar: calendar)

        #expect(service.recordedPeriod(habitID: habit.id, on: monday) == nil)
        #expect(service.isWindowClosed(habitID: habit.id, on: monday, calendar: calendar))
        #expect(service.progress(habitID: habit.id, on: monday, calendar: calendar) == 0)
        #expect(service.openPeriod(habitID: habit.id, on: monday, calendar: calendar) != nil)
        #expect(service.periods.allSatisfy { $0.startsAt != startOfDay(monday, calendar: calendar) })

        #expect(throws: HabitPeriodError.periodClosed) {
            try service.log(habitID: habit.id, amount: 1, on: monday, calendar: calendar)
        }
        #expect(throws: HabitPeriodError.periodClosed) {
            try service.quickComplete(habitID: habit.id, on: monday, calendar: calendar)
        }
        #expect(throws: HabitPeriodError.periodClosed) {
            try service.skip(habitID: habit.id, on: monday, calendar: calendar)
        }
        #expect(throws: HabitPeriodError.periodClosed) {
            try service.fail(habitID: habit.id, on: monday, calendar: calendar)
        }
        #expect(throws: HabitPeriodError.periodClosed) {
            try service.undo(habitID: habit.id, on: monday, calendar: calendar)
        }
        #expect(throws: HabitPeriodError.futureDate) {
            try service.log(habitID: habit.id, amount: 1, on: wednesday, calendar: calendar)
        }
        #expect(throws: HabitPeriodError.futureDate) {
            try service.completeChecklistItem(habitID: habit.id, itemID: UUID(), on: wednesday, calendar: calendar)
        }
        #expect(service.isFuture(wednesday, calendar: calendar))
        #expect(service.entries.isEmpty)
    }

    @Test
    func aRecordedPastDayKeepsItsProgressAfterTheWindowCloses() throws {
        let (calendar, monday) = utcDate(year: 2026, month: 9, day: 21, hour: 12)
        let clock = ManualClock(monday)
        let habit = try Habit(
            title: "Morning routine",
            createdAt: monday,
            goal: Goal(measurement: .boolean, target: 1, interval: .day),
            schedule: .daily,
            checklist: [ChecklistItem(title: "Water", sortOrder: 0)]
        )
        let service = HabitProgressService(habits: [habit], now: monday, calendar: calendar, clock: clock.callAsFunction)
        let itemID = habit.checklist[0].id

        try service.completeChecklistItem(habitID: habit.id, itemID: itemID, on: monday, calendar: calendar)
        #expect(service.isItemDone(habitID: habit.id, itemID: itemID, on: monday, calendar: calendar))
        #expect(service.fraction(habitID: habit.id, on: monday, calendar: calendar) == 1)

        clock.date = calendar.date(byAdding: .day, value: 1, to: monday)!

        #expect(service.isWindowClosed(habitID: habit.id, on: monday, calendar: calendar))
        #expect(service.recordedPeriod(habitID: habit.id, on: monday)?.outcome == .succeeded)
        #expect(service.checklistCount(habitID: habit.id, on: monday, calendar: calendar) == (done: 1, total: 1))
        #expect(service.isItemDone(habitID: habit.id, itemID: itemID, on: monday, calendar: calendar))
        #expect(service.fraction(habitID: habit.id, on: monday, calendar: calendar) == 1)
    }

    @Test
    func outcomesCountFinalizedPeriodsThatOverlapTheRange() throws {
        let (calendar, sunday) = utcDate(year: 2026, month: 9, day: 20, hour: 12)
        let monday = calendar.date(byAdding: .day, value: 1, to: sunday)!
        let wednesday = calendar.date(from: DateComponents(year: 2026, month: 9, day: 23, hour: 12))!
        let clock = ManualClock(sunday)
        let read = try dailyHabit(title: "Read", target: 1, on: sunday)
        let stretch = try dailyHabit(title: "Stretch", target: 1, on: sunday)
        let service = HabitProgressService(
            habits: [read, stretch],
            now: sunday,
            calendar: calendar,
            clock: clock.callAsFunction
        )

        try service.log(habitID: read.id, amount: 1, on: sunday, calendar: calendar)
        clock.date = monday
        service.prepare(now: monday)

        #expect(service.outcomes(in: .today, containing: sunday, calendar: calendar) == (succeeded: 1, failed: 1))
        #expect(service.outcomes(in: .today, containing: sunday, calendar: calendar, habitID: read.id) == (succeeded: 1, failed: 0))
        #expect(service.outcomes(in: .today, containing: monday, calendar: calendar) == (succeeded: 0, failed: 0))
        #expect(service.outcomes(in: .all, containing: monday, calendar: calendar) == (succeeded: 1, failed: 1))

        var profile = service.profile
        profile.weekStart = .sunday
        service.updateProfile(profile)
        #expect(service.outcomes(in: .week, containing: wednesday, calendar: calendar, habitID: read.id).succeeded == 1)

        profile.weekStart = .monday
        service.updateProfile(profile)
        #expect(service.outcomes(in: .week, containing: wednesday, calendar: calendar, habitID: read.id).succeeded == 0)
    }

    @Test
    func aSkipIsLeftOutOfOutcomeCounts() throws {
        let (calendar, today) = utcToday()
        let habit = try dailyHabit(title: "Read", target: 1, on: today)
        let service = HabitProgressService(habits: [habit], now: today, calendar: calendar)

        try service.skip(habitID: habit.id, on: today, calendar: calendar)

        #expect(service.outcomes(in: .all, containing: today, calendar: calendar) == (succeeded: 0, failed: 0))
    }

    @Test
    func addCanCreateAQuitHabitThatAvoidsEntirely() throws {
        let (calendar, today) = utcToday()
        let service = HabitProgressService(now: today, calendar: calendar)

        try service.add(
            title: "Phone in bed",
            measurement: .boolean,
            target: 0,
            on: today,
            calendar: calendar,
            direction: .quit
        )

        let habit = try #require(service.habits.first)
        #expect(habit.direction == .quit)
        #expect(habit.goal.target == 0)
        #expect(service.periods.count == 1)
    }

    @Test
    func identityAccountabilityAndReflectionsCanBeEdited() throws {
        let (calendar, today) = utcToday()
        let habit = try dailyHabit(title: "Read", target: 1, on: today)
        let service = HabitProgressService(habits: [habit], now: today, calendar: calendar)
        let period = try #require(service.periods.first)

        try service.updateIdentity(habitID: habit.id, statement: "  Someone who reads ")
        #expect(service.habits[0].id == habit.id)
        #expect(service.habits[0].title == habit.title)
        #expect(service.habits[0].identityStatement == "Someone who reads")
        try service.updateIdentity(habitID: habit.id, statement: " ")
        #expect(service.habits[0].identityStatement == nil)

        let rule = AccountabilityRule(
            tone: .firm,
            consequence: .recoveryAction,
            requiresConfirmation: true,
            isEnabled: true,
            recoveryAction: "Put the book on the pillow"
        )
        service.updateAccountability(habitID: habit.id, rule: rule)
        #expect(service.habits[0].accountability == rule)

        try service.addReflection(periodID: period.id, response: "Forgot", on: today)
        let reflectionID = try #require(service.reflections.first).id
        try service.updateReflection(id: reflectionID, response: " Left it at work ")
        #expect(service.reflections[0].id == reflectionID)
        #expect(service.reflections[0].periodID == period.id)
        #expect(service.reflections[0].response == "Left it at work")
        #expect(service.reflections[0].createdAt == today)
        #expect(throws: ReflectionError.blankResponse) {
            try service.updateReflection(id: reflectionID, response: " ")
        }
    }
}

private final class ManualClock {
    var date: Date
    init(_ date: Date) { self.date = date }
    func callAsFunction() -> Date { date }
}

private func utcToday() -> (Calendar, Date) {
    utcDate(year: 2026, month: 10, day: 11)
}

private func utcDate(year: Int, month: Int, day: Int, hour: Int = 12) -> (Calendar, Date) {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let date = calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    return (calendar, date)
}

private func startOfDay(_ date: Date, calendar: Calendar) -> Date {
    calendar.startOfDay(for: date)
}

private func dailyHabit(title: String, target: Decimal, on date: Date) throws -> Habit {
    try Habit(
        title: title,
        createdAt: date,
        goal: Goal(measurement: .count, target: target, interval: .day),
        schedule: .daily
    )
}
