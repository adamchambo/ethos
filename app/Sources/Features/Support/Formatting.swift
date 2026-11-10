import SwiftUI

func ethosMessage(_ error: Error) -> String {
    switch error {
    case HabitError.blankTitle:
        "Enter a name."
    case HabitError.nonPositiveBuildTarget:
        "A build habit needs a target above zero."
    case HabitError.invalidSchedule:
        "That schedule isn't valid."
    case HabitError.endDateNotAfterStartDate:
        "The end date has to be after the start."
    case HabitError.cannotResumeArchivedHabit:
        "Archived habits stay archived."
    case HabitError.invalidTimeRange:
        "The end time has to be after the start."
    case HabitError.unknownChecklistItem:
        "That checklist item is no longer on the habit."
    case HabitError.invalidChecklistOrder:
        "The checklist order isn't valid."
    case GoalError.negativeTarget:
        "The target can't be negative."
    case GoalError.blankUnit:
        "Enter a unit."
    case ProgressActionError.nothingRemaining:
        "This habit is already done."
    case ProgressActionError.notAvailableForQuit:
        "Quit habits are logged as slips."
    case ProgressEntryError.nonPositiveAmount:
        "Log an amount above zero."
    case HabitPeriodError.alreadyFinalized:
        "This period is already closed."
    case HabitPeriodError.periodClosed:
        "That period is already over."
    case HabitPeriodError.futureDate:
        "That day is still in the future."
    case HabitPeriodError.cannotReopen:
        "Only a completed period can be undone, and only while it is still open."
    case ReflectionError.blankResponse:
        "Write a response first."
    case ReflectionError.alreadyRecorded:
        "A reflection is already saved for this period."
    case ReflectionError.unknownReflection:
        "That reflection couldn't be found."
    case JournalError.blankText:
        "Write a note first."
    case CategoryError.blankName:
        "Enter a category name."
    case ClockTimeError.invalid:
        "That time isn't valid."
    default:
        error.localizedDescription
    }
}

func amountText(_ value: Decimal) -> String {
    value.formatted(.number.precision(.fractionLength(0...2)))
}

func percentText(_ value: Decimal) -> String {
    (value * 100).formatted(.number.precision(.fractionLength(0))) + "%"
}

func rateText(_ value: Decimal?) -> String {
    value.map(percentText) ?? "—"
}

func doubleValue(_ value: Decimal) -> Double {
    NSDecimalNumber(decimal: value).doubleValue
}

func goalText(_ habit: Habit) -> String {
    guard habit.direction == .quit else { return goalText(habit.goal) }
    if habit.goal.target == .zero { return "Avoid entirely" }
    return "At most \(goalText(habit.goal))"
}

func goalText(_ goal: Goal) -> String {
    if goal.measurement == .boolean, goal.target == 1 {
        return "Once a \(intervalText(goal.interval))"
    }

    let unit = switch goal.unit {
    case .times:
        goal.target == 1 ? "time" : "times"
    case .minutes:
        goal.target == 1 ? "minute" : "minutes"
    case let .custom(name):
        name
    }
    return "\(amountText(goal.target)) \(unit) a \(intervalText(goal.interval))"
}

func intervalText(_ interval: GoalInterval) -> String {
    switch interval {
    case .day: "day"
    case .week: "week"
    case .month: "month"
    case .year: "year"
    }
}

func scheduleText(_ schedule: HabitSchedule) -> String {
    switch schedule {
    case .daily:
        "Every day"
    case let .weekly(days):
        if days.isEmpty || days.count == 7 {
            "Every day"
        } else if days == [.monday, .tuesday, .wednesday, .thursday, .friday] {
            "Weekdays"
        } else if days == [.saturday, .sunday] {
            "Weekends"
        } else {
            days.sorted { $0.rawValue < $1.rawValue }.map(\.shortName).joined(separator: ", ")
        }
    case let .monthlyDates(days):
        "Monthly on \(days.sorted().map(String.init).joined(separator: ", "))"
    case let .monthlyWeekday(ordinal, weekday):
        "\(ordinal.label) \(weekday.name) of the month"
    case let .everyXDays(interval):
        interval == 1 ? "Every day" : "Every \(interval) days"
    }
}

func progressTimeframePhrase(_ interval: GoalInterval) -> String {
    switch interval {
    case .day: "today"
    case .week: "this week"
    case .month: "this month"
    case .year: "this year"
    }
}

func goalUnitSuffix(_ goal: Goal) -> String {
    switch goal.unit {
    case .times: ""
    case .minutes: " min"
    case let .custom(name): " \(name)"
    }
}

/// Left half of the Day row caption: schedule, or flexible period wording like `5 times a week`.
func dayScheduleCaption(for habit: Habit) -> String {
    let schedule = habit.schedule
    let flexibleAnyDay: Bool = switch schedule {
    case .daily: true
    case let .weekly(days): days.isEmpty || days.count == 7
    default: false
    }
    if habit.goal.interval != .day, flexibleAnyDay, habit.direction == .build {
        return goalText(habit.goal)
    }
    return scheduleText(schedule)
}

/// Right half of the Day row caption, including units and counting period.
func dayProgressCaption(
    habit: Habit,
    current: Decimal,
    counts: (done: Int, total: Int),
    loggedToday: Bool,
    outcome: HabitPeriodOutcome?,
    isFuture: Bool,
    notRecorded: Bool
) -> String {
    if isFuture { return goalText(habit) }
    if notRecorded { return "Not recorded" }

    switch outcome {
    case .skipped: return "Skipped"
    case .failed: return habit.direction == .quit ? "Slipped" : "Missed"
    case .succeeded:
        if counts.total > 0 {
            return "\(counts.total)/\(counts.total) \(progressTimeframePhrase(habit.goal.interval))"
        }
        let unit = goalUnitSuffix(habit.goal)
        return "\(amountText(habit.goal.target))/\(amountText(habit.goal.target))\(unit) \(progressTimeframePhrase(habit.goal.interval))"
    case .inProgress, nil:
        break
    }

    if counts.total > 0 {
        return "\(counts.done)/\(counts.total) \(progressTimeframePhrase(habit.goal.interval))"
    }
    if habit.direction == .quit {
        return current == .zero ? "No slips" : "\(amountText(current)) slips"
    }
    if habit.goal.measurement == .boolean, current < habit.goal.target {
        if case .everyXDays = habit.schedule { return "Due today" }
        return "Not yet"
    }
    if case .everyXDays = habit.schedule, current < habit.goal.target, !loggedToday {
        return "Due today"
    }

    let unit = goalUnitSuffix(habit.goal)
    let fraction = "\(amountText(current))/\(amountText(habit.goal.target))\(unit) \(progressTimeframePhrase(habit.goal.interval))"
    if loggedToday, habit.goal.interval != .day {
        return "Logged today · \(fraction)"
    }
    return fraction
}

func dayRowCaption(
    habit: Habit,
    current: Decimal,
    counts: (done: Int, total: Int),
    loggedToday: Bool,
    outcome: HabitPeriodOutcome?,
    isFuture: Bool,
    notRecorded: Bool
) -> String {
    "\(dayScheduleCaption(for: habit)) · \(dayProgressCaption(habit: habit, current: current, counts: counts, loggedToday: loggedToday, outcome: outcome, isFuture: isFuture, notRecorded: notRecorded))"
}

func outcomeText(_ outcome: HabitPeriodOutcome) -> String {
    switch outcome {
    case .inProgress: "In progress"
    case .succeeded: "Done"
    case .failed: "Missed"
    case .skipped: "Skipped"
    }
}

func clockText(_ time: ClockTime) -> String {
    var parts = Calendar.current.dateComponents([.year, .month, .day], from: .now)
    parts.hour = time.hour
    parts.minute = time.minute
    let date = Calendar.current.date(from: parts) ?? .now
    return date.formatted(date: .omitted, time: .shortened)
}

func categoryColor(_ id: UUID?, categories: [Category]) -> Color {
    guard let id, let category = categories.first(where: { $0.id == id }) else { return EthosColor.track }
    return Color(hex: category.colour)
}

extension Weekday {
    var name: String {
        switch self {
        case .monday: "Monday"
        case .tuesday: "Tuesday"
        case .wednesday: "Wednesday"
        case .thursday: "Thursday"
        case .friday: "Friday"
        case .saturday: "Saturday"
        case .sunday: "Sunday"
        }
    }

    var shortName: String {
        switch self {
        case .monday: "Mon"
        case .tuesday: "Tue"
        case .wednesday: "Wed"
        case .thursday: "Thu"
        case .friday: "Fri"
        case .saturday: "Sat"
        case .sunday: "Sun"
        }
    }
}

extension MonthWeekdayOrdinal {
    var label: String {
        switch self {
        case .first: "First"
        case .second: "Second"
        case .third: "Third"
        case .fourth: "Fourth"
        case .last: "Last"
        }
    }
}

extension GoalMeasurement {
    var label: String {
        switch self {
        case .boolean: "Yes or no"
        case .count: "Count"
        case .duration: "Minutes"
        case .quantity: "Amount"
        }
    }
}

extension HabitDirection {
    var label: String {
        switch self {
        case .build: "Build"
        case .quit: "Quit/Avoid"
        }
    }
}

extension AccountabilityTone {
    var label: String {
        switch self {
        case .calm: "Supportive"
        case .direct: "Direct"
        case .firm: "Stern"
        }
    }
}

extension StatisticsRange {
    var label: String {
        switch self {
        case .today: "Today"
        case .week: "Week"
        case .month: "Month"
        case .year: "Year"
        case .all: "All time"
        }
    }
}

extension AccountabilityConsequence {
    var label: String {
        switch self {
        case .none: "None"
        case .reflect: "Reflect"
        case .recoveryAction: "Recovery action"
        case .directFeedback: "Direct feedback"
        }
    }
}

extension Color {
    init(hex: String) {
        var rgb: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&rgb)
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}
