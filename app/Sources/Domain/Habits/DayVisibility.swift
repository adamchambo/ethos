import Foundation

/// Where a habit belongs in the Day view for a selected date.
enum DayPlacement: Equatable, Sendable {
    case hidden
    case inProgress(DayPart)
    case finished
}

/// Flexible week/month/year targets: logged across eligible days, judged when the period ends.
func isFlexiblePeriodTarget(goal: Goal, schedule: HabitSchedule) -> Bool {
    goal.interval != .day && schedule.allowsAnyDay
}

/// Daily commitments that can show as unfinished for the selected day.
func countsAsDailyCommitment(goal: Goal) -> Bool {
    goal.interval == .day
}

/// Decides whether a habit appears on `date`, and in which Day view section.
func dayPlacement(
    habit: Habit,
    goal: Goal,
    schedule: HabitSchedule,
    on date: Date,
    period: HabitPeriod?,
    entries: [ProgressEntry],
    calendar: Calendar
) -> DayPlacement {
    guard habit.isActive, goal.habitID == habit.id else { return .hidden }
    guard schedule.isEligible(on: date, calendar: calendar) else { return .hidden }

    let covering = period ?? resolvePeriod(
        habit: habit,
        goal: goal,
        schedule: schedule,
        on: date,
        existing: [],
        calendar: calendar
    )

    guard let covering else { return .hidden }

    let progress = progressTowardGoal(
        goal: goal,
        period: covering,
        entries: entries,
        calendar: calendar
    )

    if progress >= goal.target || covering.outcome == .succeeded {
        return .finished
    }

    if isFlexiblePeriodTarget(goal: goal, schedule: schedule) {
        // Still unfinished for this week/month — show on every eligible day.
        return .inProgress(habit.dayPart)
    }

    return .inProgress(habit.dayPart)
}
