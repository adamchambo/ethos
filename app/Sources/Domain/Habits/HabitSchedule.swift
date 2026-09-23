import Foundation

enum Weekday: Int, CaseIterable, Codable, Sendable {
    case monday = 1
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday 
    case sunday
}

enum HabitSchedule: Codable, Equatable, Sendable {
    case daily
    case weekly(eligibleWeekdays: Set<Weekday>)

    func isEligible(on date: Date, calendar: Calendar) -> Bool {
        switch self {
        case .daily:
            return true

        case let .weekly(eligibleWeekdays):
            guard !eligibleWeekdays.isEmpty else {
                return true
            }

            guard let weekday = Weekday(rawValue: calendar.component(.weekday, from: date)) else {
                return false
            }

            return eligibleWeekdays.contains(weekday)
        }
    }
}
