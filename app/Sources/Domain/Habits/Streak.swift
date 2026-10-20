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

/// The longest run of succeeded periods for one habit. Skips and in-progress periods do not break it.
func bestStreak(habitID: UUID, periods: [HabitPeriod]) -> Int {
    let matchingPeriods = periods
        .filter { $0.habitID == habitID }
        .sorted { $0.startsAt < $1.startsAt }

    var best = 0
    var streak = 0
    for period in matchingPeriods {
        switch period.outcome {
        case .succeeded:
            streak += 1
            best = max(best, streak)
        case .failed:
            streak = 0
        case .skipped, .inProgress:
            break
        }
    }

    return best
}
