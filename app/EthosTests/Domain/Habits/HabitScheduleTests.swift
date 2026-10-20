import Foundation
import Testing
@testable import Ethos

struct HabitScheduleTests {
    private let calendar = Calendar(identifier: .gregorian)

    @Test
    func weekdaysAreOrderedMondayThroughSunday() {
        #expect(Weekday.allCases == [
            .monday,
            .tuesday,
            .wednesday,
            .thursday,
            .friday,
            .saturday,
            .sunday
        ])
    }

    @Test
    func aDailyScheduleIsEligibleEveryDay() {
        let schedule = HabitSchedule.daily

        #expect(schedule.isEligible(on: date(2026, 9, 21), calendar: calendar))
        #expect(schedule.isEligible(on: date(2026, 9, 22), calendar: calendar))
    }

    @Test
    func aWeeklyScheduleIsEligibleOnSelectedWeekdays() {
        let schedule = HabitSchedule.weekly(eligibleWeekdays: [.monday, .wednesday])

        #expect(schedule.isEligible(on: date(2026, 9, 21), calendar: calendar))
        #expect(!schedule.isEligible(on: date(2026, 9, 22), calendar: calendar))
        #expect(schedule.isEligible(on: date(2026, 9, 23), calendar: calendar))
    }

    @Test
    func aWeeklyScheduleKeepsSundayAsSunday() {
        let schedule = HabitSchedule.weekly(eligibleWeekdays: [.sunday])

        #expect(schedule.isEligible(on: date(2026, 9, 20), calendar: calendar))
        #expect(!schedule.isEligible(on: date(2026, 9, 21), calendar: calendar))
    }

    @Test
    func aWeeklyScheduleWithoutSelectedWeekdaysIsEligibleEveryDay() {
        let schedule = HabitSchedule.weekly(eligibleWeekdays: [])

        #expect(schedule.isEligible(on: date(2026, 9, 21), calendar: calendar))
        #expect(schedule.isEligible(on: date(2026, 9, 22), calendar: calendar))
    }

    @Test
    func aMonthlyDateThatTheMonthDoesNotContainIsNotEligible() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let schedule = HabitSchedule.monthlyDates([31])

        #expect(schedule.isEligible(on: gmtDate(2026, 1, 31, calendar: calendar), calendar: calendar))
        #expect(!schedule.isEligible(on: gmtDate(2026, 2, 15, calendar: calendar), calendar: calendar))
        #expect(!schedule.isEligible(on: gmtDate(2026, 4, 30, calendar: calendar), calendar: calendar))
    }

    @Test
    func aMonthlyWeekdayMatchesTheOrdinalAndTheLastOccurrence() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let firstMonday = HabitSchedule.monthlyWeekday(ordinal: .first, weekday: .monday)
        let lastMonday = HabitSchedule.monthlyWeekday(ordinal: .last, weekday: .monday)

        #expect(firstMonday.isEligible(on: gmtDate(2026, 8, 3, calendar: calendar), calendar: calendar))
        #expect(!firstMonday.isEligible(on: gmtDate(2026, 8, 31, calendar: calendar), calendar: calendar))
        #expect(lastMonday.isEligible(on: gmtDate(2026, 8, 31, calendar: calendar), calendar: calendar))
        #expect(!lastMonday.isEligible(on: gmtDate(2026, 8, 24, calendar: calendar), calendar: calendar))
    }

    @Test
    func everyXDaysCountsFromTheStartDate() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let schedule = HabitSchedule.everyXDays(3)
        let start = gmtDate(2026, 9, 1, calendar: calendar)

        #expect(schedule.isEligible(on: start, calendar: calendar, starting: start))
        #expect(!schedule.isEligible(on: gmtDate(2026, 9, 2, calendar: calendar), calendar: calendar, starting: start))
        #expect(schedule.isEligible(on: gmtDate(2026, 9, 4, calendar: calendar), calendar: calendar, starting: start))
        #expect(!schedule.isEligible(on: gmtDate(2026, 8, 31, calendar: calendar), calendar: calendar, starting: start))
    }

    @Test
    func anInvalidScheduleExplainsWhy() {
        #expect(throws: HabitScheduleError.emptyMonthlyDates) {
            try HabitSchedule.monthlyDates([]).validate()
        }
        #expect(throws: HabitScheduleError.invalidMonthDate) {
            try HabitSchedule.monthlyDates([0, 15]).validate()
        }
        #expect(throws: HabitScheduleError.nonPositiveRepeatInterval) {
            try HabitSchedule.everyXDays(0).validate()
        }
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func gmtDate(_ year: Int, _ month: Int, _ day: Int, calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
}
