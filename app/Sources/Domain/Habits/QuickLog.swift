import Foundation

enum HabitInteractionKind: Equatable, Sendable {
    case standard
    case quit
    case checklist
}

struct ChecklistItem: Identifiable, Equatable, Sendable {
    let id: UUID
    var title: String

    init(id: UUID = UUID(), title: String) {
        self.id = id
        self.title = title
    }
}

/// Per-habit quick action configuration for the Day view.
struct QuickLogSettings: Equatable, Sendable {
    var amount: Decimal
    /// Display unit such as `min`, or empty for unitless counts.
    var unitLabel: String
    var kind: HabitInteractionKind
    var checklistItems: [ChecklistItem]
    /// When true, logging may continue after the period target is met.
    var allowLoggingBeyondTarget: Bool

    init(
        amount: Decimal = 1,
        unitLabel: String = "",
        kind: HabitInteractionKind = .standard,
        checklistItems: [ChecklistItem] = [],
        allowLoggingBeyondTarget: Bool = false
    ) {
        self.amount = amount
        self.unitLabel = unitLabel
        self.kind = kind
        self.checklistItems = checklistItems
        self.allowLoggingBeyondTarget = allowLoggingBeyondTarget
    }

    static func done(allowBeyond: Bool = false) -> QuickLogSettings {
        QuickLogSettings(amount: 1, unitLabel: "", kind: .standard, allowLoggingBeyondTarget: allowBeyond)
    }

    static func increment(
        _ amount: Decimal,
        unitLabel: String = "",
        allowBeyond: Bool = false
    ) -> QuickLogSettings {
        QuickLogSettings(
            amount: amount,
            unitLabel: unitLabel,
            kind: .standard,
            allowLoggingBeyondTarget: allowBeyond
        )
    }

    static func slip(allowBeyond: Bool = true) -> QuickLogSettings {
        QuickLogSettings(amount: 1, unitLabel: "", kind: .quit, allowLoggingBeyondTarget: allowBeyond)
    }

    static func checklist(_ items: [ChecklistItem], allowBeyond: Bool = false) -> QuickLogSettings {
        QuickLogSettings(
            amount: 1,
            unitLabel: "",
            kind: .checklist,
            checklistItems: items,
            allowLoggingBeyondTarget: allowBeyond
        )
    }
}

enum QuickActionStyle: Equatable, Sendable {
    case done
    case increment
    case slip
    case checklist
}

func quickActionStyle(goal: Goal, settings: QuickLogSettings) -> QuickActionStyle {
    switch settings.kind {
    case .quit:
        return .slip
    case .checklist:
        return .checklist
    case .standard:
        if goal.measurement == .boolean || (settings.amount == 1 && settings.unitLabel.isEmpty && goal.target == 1 && goal.measurement != .duration) {
            return .done
        }
        return .increment
    }
}

func quickActionTitle(goal: Goal, settings: QuickLogSettings) -> String {
    switch quickActionStyle(goal: goal, settings: settings) {
    case .done:
        return "Done"
    case .slip:
        return "Slip"
    case .checklist:
        return "Items"
    case .increment:
        let amount = formatGoalAmount(settings.amount)
        if settings.unitLabel.isEmpty {
            return "+\(amount)"
        }
        return "+\(amount) \(settings.unitLabel)"
    }
}

enum QuickLogError: Error, Equatable {
    case futureDate
    case notEligible
    case targetReached
    case alreadyFinalized
    case checklistRequiresItems
}

struct QuickLogSuccess: Equatable, Sendable {
    var period: HabitPeriod
    var entry: ProgressEntry
    var entries: [ProgressEntry]
    var periods: [HabitPeriod]
}

/// Whether `date` is after today in `calendar` (logging must be disabled).
func isFutureDay(date: Date, now: Date, calendar: Calendar) -> Bool {
    calendar.startOfDay(for: date) > calendar.startOfDay(for: now)
}

func canQuickLog(
    goal: Goal,
    settings: QuickLogSettings,
    placement: DayPlacement,
    progress: Decimal,
    on date: Date,
    now: Date,
    calendar: Calendar
) -> Bool {
    if isFutureDay(date: date, now: now, calendar: calendar) {
        return false
    }
    if case .hidden = placement {
        return false
    }
    if settings.kind == .checklist {
        return !settings.checklistItems.isEmpty
    }
    if progress >= goal.target, !settings.allowLoggingBeyondTarget {
        return false
    }
    return true
}
