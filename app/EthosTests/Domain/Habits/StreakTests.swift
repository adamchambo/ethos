import Foundation
import Testing
@testable import Ethos

struct StreakTests {
    @Test
    func emptyPeriodsHaveNoStreak() {
        #expect(currentStreak(habitID: UUID(), periods: []) == 0)
    }

    @Test
    func periodsAreProcessedByStartDate() throws {
        let habitID = UUID()
        let periods = try [
            makePeriod(habitID: habitID, startsAt: 3_000, outcome: .succeeded),
            makePeriod(habitID: habitID, startsAt: 1_000, outcome: .failed),
            makePeriod(habitID: habitID, startsAt: 2_000, outcome: .succeeded)
        ]

        #expect(currentStreak(habitID: habitID, periods: periods) == 2)
    }

    @Test
    func failureResetsTheStreak() throws {
        let habitID = UUID()
        let periods = try [
            makePeriod(habitID: habitID, startsAt: 1_000, outcome: .succeeded),
            makePeriod(habitID: habitID, startsAt: 2_000, outcome: .failed),
            makePeriod(habitID: habitID, startsAt: 3_000, outcome: .succeeded)
        ]

        #expect(currentStreak(habitID: habitID, periods: periods) == 1)
    }

    @Test
    func skippedAndInProgressPeriodsDoNotChangeTheStreak() throws {
        let habitID = UUID()
        let periods = try [
            makePeriod(habitID: habitID, startsAt: 1_000, outcome: .succeeded),
            makePeriod(habitID: habitID, startsAt: 2_000, outcome: .skipped),
            makePeriod(habitID: habitID, startsAt: 3_000, outcome: .inProgress)
        ]

        #expect(currentStreak(habitID: habitID, periods: periods) == 1)
    }

    @Test
    func periodsFromOtherHabitsAreIgnored() throws {
        let habitID = UUID()
        let periods = try [
            makePeriod(habitID: habitID, startsAt: 1_000, outcome: .succeeded),
            makePeriod(habitID: UUID(), startsAt: 2_000, outcome: .failed),
            makePeriod(habitID: habitID, startsAt: 3_000, outcome: .succeeded)
        ]

        #expect(currentStreak(habitID: habitID, periods: periods) == 2)
    }

    private func makePeriod(
        habitID: UUID,
        startsAt: TimeInterval,
        outcome: HabitPeriodOutcome
    ) throws -> HabitPeriod {
        let start = Date(timeIntervalSinceReferenceDate: startsAt)
        return try HabitPeriod(
            habitID: habitID,
            startsAt: start,
            endsAt: start.addingTimeInterval(100),
            outcome: outcome
        )
    }
}
