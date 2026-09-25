import Foundation
import Testing
@testable import Ethos

struct CompletionRateTests {
    @Test
    func emptyDenominatorHasNoRate() throws {
        let habitID = UUID()
        let periods = try [
            makePeriod(habitID: habitID, outcome: .skipped),
            makePeriod(habitID: habitID, outcome: .inProgress),
            makePeriod(habitID: UUID(), outcome: .succeeded)
        ]

        #expect(completionRate(habitID: habitID, periods: []) == nil)
        #expect(completionRate(habitID: habitID, periods: periods) == nil)
    }

    @Test
    func countsOnlySucceededAndFailedPeriodsForTheHabit() throws {
        let habitID = UUID()
        let periods = try [
            makePeriod(habitID: habitID, outcome: .succeeded),
            makePeriod(habitID: habitID, outcome: .failed),
            makePeriod(habitID: habitID, outcome: .succeeded),
            makePeriod(habitID: habitID, outcome: .skipped),
            makePeriod(habitID: habitID, outcome: .inProgress),
            makePeriod(habitID: UUID(), outcome: .failed)
        ]

        #expect(completionRate(habitID: habitID, periods: periods) == Decimal(2) / Decimal(3))
    }

    @Test
    func failedPeriodsWithoutSuccessReturnZero() throws {
        let habitID = UUID()
        let periods = try [makePeriod(habitID: habitID, outcome: .failed)]

        #expect(completionRate(habitID: habitID, periods: periods) == .zero)
    }

    private func makePeriod(habitID: UUID, outcome: HabitPeriodOutcome) throws -> HabitPeriod {
        let start = Date(timeIntervalSinceReferenceDate: 1_000)
        return try HabitPeriod(
            habitID: habitID,
            startsAt: start,
            endsAt: start.addingTimeInterval(100),
            outcome: outcome
        )
    }
}
