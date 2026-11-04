import Foundation

enum Weekday: Int, CaseIterable, Codable, Sendable {
    case monday = 1
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday 
    case sunday

    /// Foundation's Gregorian weekday component counts Sunday as 1.
    init?(foundationWeekday component: Int) {
        let rawValue = component == 1 ? 7 : component - 1
        self.init(rawValue: rawValue)
    }

    /// Foundation's `Calendar.firstWeekday`, where Sunday is 1.
    var foundationIndex: Int {
        self == .sunday ? 1 : rawValue + 1
    }
}

enum MonthWeekdayOrdinal: Int, Codable, Sendable, CaseIterable {
    case first = 1
    case second
    case third
    case fourth
    case last
}

enum HabitScheduleError: Error, Equatable {
    case emptyMonthlyDates
    case invalidMonthDate
    case nonPositiveRepeatInterval
}

enum HabitSchedule: Codable, Equatable, Sendable {
    case daily
    case weekly(eligibleWeekdays: Set<Weekday>)
    case monthlyDates(Set<Int>)
    case monthlyWeekday(ordinal: MonthWeekdayOrdinal, weekday: Weekday)
    case everyXDays(Int)

    func validate() throws {
        switch self {
        case .daily, .weekly, .monthlyWeekday:
            break
        case let .monthlyDates(days):
            guard !days.isEmpty else {
                throw HabitScheduleError.emptyMonthlyDates
            }
            guard days.allSatisfy({ (1...31).contains($0) }) else {
                throw HabitScheduleError.invalidMonthDate
            }
        case let .everyXDays(interval):
            guard interval >= 1 else {
                throw HabitScheduleError.nonPositiveRepeatInterval
            }
        }
    }

    /// `starting` anchors `.everyXDays`. Daily and weekly schedules ignore it.
    /// A day number that the month does not contain, such as 31 in February, is not eligible.
    func isEligible(on date: Date, calendar: Calendar, starting startDate: Date? = nil) -> Bool {
        switch self {
        case .daily:
            return true

        case let .weekly(eligibleWeekdays):
            guard !eligibleWeekdays.isEmpty else {
                return true
            }

            guard let weekday = Weekday(foundationWeekday: calendar.component(.weekday, from: date)) else {
                return false
            }

            return eligibleWeekdays.contains(weekday)

        case let .monthlyDates(days):
            let day = calendar.component(.day, from: date)
            return days.contains(day)

        case let .monthlyWeekday(ordinal, weekday):
            guard let dateWeekday = Weekday(foundationWeekday: calendar.component(.weekday, from: date)),
                  dateWeekday == weekday
            else {
                return false
            }

            if ordinal == .last {
                guard let nextWeek = calendar.date(byAdding: .day, value: 7, to: date) else {
                    return false
                }
                return calendar.component(.month, from: nextWeek) != calendar.component(.month, from: date)
            }

            let day = calendar.component(.day, from: date)
            return (day - 1) / 7 + 1 == ordinal.rawValue

        case let .everyXDays(interval):
            guard interval >= 1, let startDate else {
                return false
            }

            let start = calendar.startOfDay(for: startDate)
            let day = calendar.startOfDay(for: date)
            guard let distance = calendar.dateComponents([.day], from: start, to: day).day, distance >= 0 else {
                return false
            }

            return distance.isMultiple(of: interval)
        }
    }
}
