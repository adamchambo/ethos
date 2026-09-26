import Foundation
import Testing
@testable import Ethos

struct PeriodResolutionTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    @Test
    func aDayWindowRunsFromMidnightToTheNextMidnight() {
        let window = periodWindow(containing: date(2026, 9, 23, hour: 15), interval: .day, calendar: calendar)

        #expect(window?.startsAt == date(2026, 9, 23))
        #expect(window?.endsAt == date(2026, 9, 24))
    }

    @Test
    func aWeekWindowStartsOnMonday() {
        let window = periodWindow(containing: date(2026, 9, 23), interval: .week, calendar: calendar)

        #expect(window?.startsAt == date(2026, 9, 21))
        #expect(window?.endsAt == date(2026, 9, 28))
    }

    @Test
    func aMonthWindowCoversTheCalendarMonth() {
        let window = periodWindow(containing: date(2026, 9, 23), interval: .month, calendar: calendar)

        #expect(window?.startsAt == date(2026, 9, 1))
        #expect(window?.endsAt == date(2026, 10, 1))
    }

    @Test
    func aYearWindowCoversTheCalendarYear() {
        let window = periodWindow(containing: date(2026, 9, 23), interval: .year, calendar: calendar)

        #expect(window?.startsAt == date(2026, 1, 1))
        #expect(window?.endsAt == date(2027, 1, 1))
    }

    @Test
    func anEligibleDateCreatesTheGoalIntervalWindow() throws {
        let habit = try Habit(title: "Gym", createdAt: date(2026, 9, 1))
        let goal = try Goal(habitID: habit.id, measurement: .count, target: 3, interval: .week)
        let schedule = HabitSchedule.weekly(eligibleWeekdays: [.monday, .wednesday])

        let period = resolvePeriod(
            habit: habit,
            goal: goal,
            schedule: schedule,
            on: date(2026, 9, 23),
            existing: [],
            calendar: calendar
        )

        #expect(period?.habitID == habit.id)
        #expect(period?.startsAt == date(2026, 9, 21))
        #expect(period?.endsAt == date(2026, 9, 28))
        #expect(period?.outcome == .inProgress)
    }

    @Test
    func anIneligibleDateCreatesNothing() throws {
        let habit = try Habit(title: "Gym", createdAt: date(2026, 9, 1))
        let goal = try Goal(habitID: habit.id, measurement: .count, target: 3, interval: .week)
        let schedule = HabitSchedule.weekly(eligibleWeekdays: [.monday, .wednesday])

        let period = resolvePeriod(
            habit: habit,
            goal: goal,
            schedule: schedule,
            on: date(2026, 9, 22),
            existing: [],
            calendar: calendar
        )

        #expect(period == nil)
    }

    @Test
    func aPausedHabitDoesNotCreateAPeriod() throws {
        var habit = try Habit(title: "Gym", createdAt: date(2026, 9, 1))
        habit.pause()
        let goal = try Goal(habitID: habit.id, measurement: .count, target: 1, interval: .day)

        let period = resolvePeriod(
            habit: habit,
            goal: goal,
            schedule: .daily,
            on: date(2026, 9, 23),
            existing: [],
            calendar: calendar
        )

        #expect(period == nil)
    }

    @Test
    func anExistingCoveringPeriodIsReused() throws {
        let habit = try Habit(title: "Gym", createdAt: date(2026, 9, 1))
        let goal = try Goal(habitID: habit.id, measurement: .count, target: 3, interval: .week)
        let existing = try HabitPeriod(
            habitID: habit.id,
            startsAt: date(2026, 9, 21),
            endsAt: date(2026, 9, 28),
            outcome: .succeeded
        )

        let period = resolvePeriod(
            habit: habit,
            goal: goal,
            schedule: .daily,
            on: date(2026, 9, 23),
            existing: [existing],
            calendar: calendar
        )

        #expect(period == existing)
    }

    @Test
    func aPausedHabitStillReturnsThePeriodThatCoversTheDate() throws {
        var habit = try Habit(title: "Gym", createdAt: date(2026, 9, 1))
        habit.pause()
        let goal = try Goal(habitID: habit.id, measurement: .count, target: 3, interval: .week)
        let existing = try HabitPeriod(
            habitID: habit.id,
            startsAt: date(2026, 9, 21),
            endsAt: date(2026, 9, 28)
        )

        let period = resolvePeriod(
            habit: habit,
            goal: goal,
            schedule: .daily,
            on: date(2026, 9, 22),
            existing: [existing],
            calendar: calendar
        )

        #expect(period?.id == existing.id)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }
}
