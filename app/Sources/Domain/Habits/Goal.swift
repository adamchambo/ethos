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

/// The target for one habit within its chosen interval.
struct Goal: Identifiable, Equatable, Sendable {
    let habitID: UUID
    let measurement: GoalMeasurement
    let target: Decimal
    let interval: GoalInterval

    var id: UUID { habitID }

    init(
        habitID: UUID,
        measurement: GoalMeasurement,
        target: Decimal,
        interval: GoalInterval
    ) throws {
        guard target > .zero else {
            throw GoalError.nonPositiveTarget
        }

        self.habitID = habitID
        self.measurement = measurement
        self.target = target
        self.interval = interval
    }
}
