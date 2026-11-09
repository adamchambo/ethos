import Foundation

enum StatisticsRange: String, Codable, Sendable, CaseIterable, Hashable {
    case today
    case week
    case month
    case year
    case all

    func window(containing date: Date, calendar: Calendar, weekStartsOn: Weekday = .monday) -> PeriodWindow? {
        let interval: GoalInterval? = switch self {
        case .today: .day
        case .week: .week
        case .month: .month
        case .year: .year
        case .all: nil
        }
        guard let interval else { return nil }
        return periodWindow(
            containing: date,
            interval: interval,
            calendar: calendar,
            weekStartsOn: weekStartsOn
        )
    }
}
