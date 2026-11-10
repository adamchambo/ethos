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

    var shortName: String {
        switch self {
        case .monday: "Mon"
        case .tuesday: "Tue"
        case .wednesday: "Wed"
        case .thursday: "Thu"
        case .friday: "Fri"
        case .saturday: "Sat"
        case .sunday: "Sun"
        }
    }
}

enum HabitSchedule: Codable, Equatable, Sendable {
    case daily
    /// Empty weekdays means any day (flexible). Non-empty means only those weekdays.
    case weekly(eligibleWeekdays: Set<Weekday>)
    /// Due every `days` calendar days, counted from the start of `anchorStart`.
    case every(days: Int, anchorStart: Date)

    /// Flexible weekly logging: any day is eligible.
    var allowsAnyDay: Bool {
        switch self {
        case .daily:
            return true
        case let .weekly(eligibleWeekdays):
            return eligibleWeekdays.isEmpty
        case .every:
            return false
        }
    }

    var isFixedWeekdays: Bool {
        if case let .weekly(eligibleWeekdays) = self {
            return !eligibleWeekdays.isEmpty
        }
        return false
    }

    func isEligible(on date: Date, calendar: Calendar) -> Bool {
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

        case let .every(days, anchorStart):
            guard days > 0 else { return false }

            let start = calendar.startOfDay(for: anchorStart)
            let day = calendar.startOfDay(for: date)
            guard day >= start else { return false }

            let distance = calendar.dateComponents([.day], from: start, to: day).day ?? -1
            return distance % days == 0
        }
    }
}
