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
}

enum GoalError: Error, Equatable {
    case nonPositiveTarget
}

/// The target a habit measures within one interval. The habit owns this value.
struct Goal: Equatable, Sendable {
    let measurement: GoalMeasurement
    let target: Decimal
    let interval: GoalInterval

    init(
        measurement: GoalMeasurement,
        target: Decimal,
        interval: GoalInterval
    ) throws {
        guard target > .zero else {
            throw GoalError.nonPositiveTarget
        }

        self.measurement = measurement
        self.target = target
        self.interval = interval
    }
}
