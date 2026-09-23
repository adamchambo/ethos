import Foundation
import Testing
@testable import Ethos

struct HabitPeriodTests {
    @Test
    func creationStartsInProgress() throws {
        let period = try makePeriod()

        #expect(period.outcome == .inProgress)
        #expect(!period.isFinalized)
    }

    @Test
    func creationRejectsAnEmptyOrReversedDateRange() {
        let start = Date(timeIntervalSinceReferenceDate: 1_000)

        #expect(throws: HabitPeriodError.invalidDateRange) {
            try HabitPeriod(habitID: UUID(), startsAt: start, endsAt: start)
        }
        #expect(throws: HabitPeriodError.invalidDateRange) {
            try HabitPeriod(habitID: UUID(), startsAt: start, endsAt: start.addingTimeInterval(-1))
        }
    }

    @Test
    func anInProgressPeriodCanBeFinalized() throws {
        var period = try makePeriod()

        try period.finalize(as: .succeeded)

        #expect(period.outcome == .succeeded)
        #expect(period.isFinalized)
    }

    @Test
    func aPeriodCannotBeFinalizedAsInProgress() throws {
        var period = try makePeriod()

        #expect(throws: HabitPeriodError.cannotFinalizeAsInProgress) {
            try period.finalize(as: .inProgress)
        }
    }

    @Test
    func aFinalizedPeriodCannotBeFinalizedAgain() throws {
        var period = try makePeriod()
        try period.finalize(as: .failed)

        #expect(throws: HabitPeriodError.alreadyFinalized) {
            try period.finalize(as: .skipped)
        }
    }

    private func makePeriod() throws -> HabitPeriod {
        let start = Date(timeIntervalSinceReferenceDate: 1_000)
        return try HabitPeriod(
            habitID: UUID(),
            startsAt: start,
            endsAt: start.addingTimeInterval(86_400)
        )
    }
}
