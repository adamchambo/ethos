import Foundation

/// A half-open evaluation window: `startsAt` is included and `endsAt` is not.
struct PeriodWindow: Equatable, Sendable {
    let startsAt: Date
    let endsAt: Date
}

/// The calendar window that contains `date` for a goal interval.
///
/// Weeks start on Monday. Foundation numbers that day as `2`, so the copy of
/// `calendar` used for a week sets `firstWeekday` without changing the caller's calendar.
func periodWindow(
    containing date: Date,
    interval: GoalInterval,
    calendar: Calendar
) -> PeriodWindow? {
    var calendar = calendar
    let component: Calendar.Component

    switch interval {
    case .day:
        component = .day
    case .week:
        calendar.firstWeekday = 2
        component = .weekOfYear
    case .month:
        component = .month
    case .year:
        component = .year
    }

    guard let bounds = calendar.dateInterval(of: component, for: date) else {
        return nil
    }

    return PeriodWindow(startsAt: bounds.start, endsAt: bounds.end)
}

/// Returns the period a habit should use on `date`.
///
/// An existing period that already covers the date is reused, including when the
/// habit is paused or the date is not eligible. A new in-progress period is created
/// only for an active habit on an eligible date that has no covering period.
func resolvePeriod(
    habit: Habit,
    goal: Goal,
    schedule: HabitSchedule,
    on date: Date,
    existing: [HabitPeriod],
    calendar: Calendar
) -> HabitPeriod? {
    if let covering = existing.first(where: { period in
        period.habitID == habit.id && period.startsAt <= date && date < period.endsAt
    }) {
        return covering
    }

    guard habit.isActive, goal.habitID == habit.id else { return nil }
    guard schedule.isEligible(on: date, calendar: calendar) else { return nil }
    guard let window = periodWindow(containing: date, interval: goal.interval, calendar: calendar) else {
        return nil
    }

    return try? HabitPeriod(
        habitID: habit.id,
        startsAt: window.startsAt,
        endsAt: window.endsAt
    )
}
