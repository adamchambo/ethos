import Foundation

/// Counts succeeded periods since the last failure for one habit.
func currentStreak(habitID: UUID, periods: [HabitPeriod]) -> Int {
    let matchingPeriods = periods
        .filter { $0.habitID == habitID }
        .sorted { $0.startsAt < $1.startsAt }

    var streak = 0
    for period in matchingPeriods {
        switch period.outcome {
        case .succeeded:
            streak += 1
        case .failed:
            streak = 0
        case .skipped, .inProgress:
            break
        }
    }

    return streak
}
