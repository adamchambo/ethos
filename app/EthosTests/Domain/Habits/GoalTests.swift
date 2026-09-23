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
        let habitID = UUID()
        let goal = try Goal(habitID: habitID, measurement: measurement, target: 2.5, interval: .week)

        #expect(goal.id == habitID)
        #expect(goal.habitID == habitID)
        #expect(goal.measurement == measurement)
        #expect(goal.target == 2.5)
        #expect(goal.interval == .week)
    }

    @Test(arguments: [
        GoalInterval.day,
        .week,
        .month,
        .year
    ])
    func creationRetainsEachInterval(interval: GoalInterval) throws {
        let goal = try Goal(habitID: UUID(), measurement: .count, target: 1, interval: interval)

        #expect(goal.interval == interval)
    }

    @Test(arguments: [Decimal.zero, -1])
    func creationRejectsNonPositiveTargets(target: Decimal) {
        #expect(throws: GoalError.nonPositiveTarget) {
            try Goal(habitID: UUID(), measurement: .count, target: target, interval: .day)
        }
    }
}
