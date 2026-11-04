import Foundation

enum GoalMeasurement: String, Codable, Sendable, CaseIterable {
    case boolean
    case count
    case duration
    case quantity
}

enum GoalInterval: String, Codable, Sendable, CaseIterable {
    case day
    case week
    case month
    case year
}

enum GoalUnit: Equatable, Codable, Sendable {
    case times
    case minutes
    case custom(String)
}

enum GoalError: Error, Equatable {
    case negativeTarget
    case blankUnit
}

/// The target a habit measures within one interval. The habit owns this value.
///
/// A target of zero is allowed here so a quit habit can mean "avoid entirely".
/// A build habit rejects that target when it is created.
struct Goal: Equatable, Sendable, Codable {
    let measurement: GoalMeasurement
    let target: Decimal
    let interval: GoalInterval
    let unit: GoalUnit
    let allowsOverCompletion: Bool

    init(
        measurement: GoalMeasurement,
        target: Decimal,
        interval: GoalInterval,
        unit: GoalUnit? = nil,
        allowsOverCompletion: Bool = true
    ) throws {
        guard target >= .zero else {
            throw GoalError.negativeTarget
        }

        let resolvedUnit = try Self.resolve(unit: unit, measurement: measurement)

        self.measurement = measurement
        self.target = target
        self.interval = interval
        self.unit = resolvedUnit
        self.allowsOverCompletion = allowsOverCompletion
    }

    private static func resolve(unit: GoalUnit?, measurement: GoalMeasurement) throws -> GoalUnit {
        let resolved = unit ?? defaultUnit(for: measurement)

        if case let .custom(name) = resolved {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                throw GoalError.blankUnit
            }
            return .custom(trimmed)
        }

        return resolved
    }

    private static func defaultUnit(for measurement: GoalMeasurement) -> GoalUnit {
        switch measurement {
        case .boolean, .count:
            .times
        case .duration:
            .minutes
        case .quantity:
            .custom("units")
        }
    }
}
