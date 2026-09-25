import Foundation

/// Returns the share of succeeded finalized periods for one habit.
func completionRate(habitID: UUID, periods: [HabitPeriod]) -> Decimal? {
    var succeeded = 0
    var failed = 0

    for period in periods where period.habitID == habitID {
        switch period.outcome {
        case .succeeded:
            succeeded += 1
        case .failed:
            failed += 1
        case .skipped, .inProgress:
            break
        }
    }

    let total = succeeded + failed
    guard total > 0 else { return nil }
    return Decimal(succeeded) / Decimal(total)
}
