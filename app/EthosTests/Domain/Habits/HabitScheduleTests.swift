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
    func aWeeklyScheduleWithoutSelectedWeekdaysIsEligibleEveryDay() {
        let schedule = HabitSchedule.weekly(eligibleWeekdays: [])

        #expect(schedule.isEligible(on: date(2026, 9, 21), calendar: calendar))
        #expect(schedule.isEligible(on: date(2026, 9, 22), calendar: calendar))
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
}
