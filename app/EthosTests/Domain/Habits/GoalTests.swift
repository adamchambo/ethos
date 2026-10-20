import Foundation
import Testing
@testable import Ethos

struct GoalTests {
    @Test(arguments: [
        GoalMeasurement.boolean,
        .count,
        .duration,
        .quantity
    ])
    func creationRetainsEachMeasurement(measurement: GoalMeasurement) throws {
        let goal = try Goal(measurement: measurement, target: 2.5, interval: .week)

        #expect(goal.measurement == measurement)
        #expect(goal.target == 2.5)
        #expect(goal.interval == .week)
        #expect(goal.allowsOverCompletion)
    }

    @Test
    func creationUsesAUnitThatMatchesTheMeasurement() throws {
        #expect(try Goal(measurement: .count, target: 1, interval: .day).unit == .times)
        #expect(try Goal(measurement: .duration, target: 1, interval: .day).unit == .minutes)
        #expect(try Goal(measurement: .quantity, target: 1, interval: .day).unit == .custom("units"))
    }

    @Test
    func creationTrimsACustomUnitAndAllowsAZeroTarget() throws {
        let goal = try Goal(measurement: .quantity, target: 0, interval: .day, unit: .custom("  pages  "))

        #expect(goal.target == 0)
        #expect(goal.unit == .custom("pages"))
    }

    @Test(arguments: [
        GoalInterval.day,
        .week,
        .month,
        .year
    ])
    func creationRetainsEachInterval(interval: GoalInterval) throws {
        let goal = try Goal(measurement: .count, target: 1, interval: interval)

        #expect(goal.interval == interval)
    }

    @Test
    func creationRejectsANegativeTarget() {
        #expect(throws: GoalError.negativeTarget) {
            try Goal(measurement: .count, target: -1, interval: .day)
        }
    }

    @Test
    func creationRejectsABlankCustomUnit() {
        #expect(throws: GoalError.blankUnit) {
            try Goal(measurement: .quantity, target: 1, interval: .day, unit: .custom("  "))
        }
    }
}
