import Foundation

/// Returns the current outcome for a period without finalizing it.
func evaluatePeriod(
    goal: Goal,
    period: HabitPeriod,
    entries: [ProgressEntry],
    now: Date,
    isSkipped: Bool,
    isPaused: Bool
) -> HabitPeriodOutcome {
    if isSkipped { return .skipped }
    if isPaused { return .inProgress }

    let total = entries
        .filter {
            $0.habitID == period.habitID
                && $0.occurredAt >= period.startsAt
                && $0.occurredAt < period.endsAt
        }
        .reduce(Decimal.zero) { $0 + $1.amount }

    if goal.interval == .week && now < period.endsAt {
        return .inProgress
    }

    if total >= goal.target { return .succeeded }
    if now >= period.endsAt { return .failed }
    return .inProgress
}
