import Foundation

enum GoalMeasurement: String, Codable, Sendable {
    case boolean
    case count
    case duration
    case quantity
}

enum GoalInterval: String, Codable, Sendable {
    case day
    case week
    case month
    case year

    var progressTimeframePhrase: String {
        switch self {
        case .day: "today"
        case .week: "this week"
        case .month: "this month"
        case .year: "this year"
        }
    }
}

/// How logs accumulate toward the goal target.
///
/// - `sessions`: each log's amount adds up; multiple sessions in one day all count.
/// - `days`: each calendar day with at least one log counts once toward the target.
enum GoalCountingMode: String, Codable, Sendable {
    case sessions
    case days
}

enum GoalError: Error, Equatable {
    case nonPositiveTarget
}

/// The target for one habit within its chosen interval.
struct Goal: Identifiable, Equatable, Sendable {
    let habitID: UUID
    let measurement: GoalMeasurement
    let target: Decimal
    let interval: GoalInterval
    let countingMode: GoalCountingMode

    var id: UUID { habitID }

    init(
        habitID: UUID,
        measurement: GoalMeasurement,
        target: Decimal,
        interval: GoalInterval,
        countingMode: GoalCountingMode = .sessions
    ) throws {
        guard target > .zero else {
            throw GoalError.nonPositiveTarget
        }

        self.habitID = habitID
        self.measurement = measurement
        self.target = target
        self.interval = interval
        self.countingMode = countingMode
    }
}
