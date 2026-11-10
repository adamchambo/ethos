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

struct ChecklistItemState: Identifiable, Equatable, Sendable {
    let item: ChecklistItem
    let isComplete: Bool

    var id: UUID { item.id }
}

/// Per-habit interaction configuration for the Day view.
struct QuickLogSettings: Equatable, Sendable {
    /// Display unit for progress copy such as `min`, or empty for unitless counts.
    var unitLabel: String
    var kind: HabitInteractionKind
    var checklistItems: [ChecklistItem]
    /// When true, logging may continue after the period target is met.
    var allowLoggingBeyondTarget: Bool

    init(
        unitLabel: String = "",
        kind: HabitInteractionKind = .standard,
        checklistItems: [ChecklistItem] = [],
        allowLoggingBeyondTarget: Bool = false
    ) {
        self.unitLabel = unitLabel
        self.kind = kind
        self.checklistItems = checklistItems
        self.allowLoggingBeyondTarget = allowLoggingBeyondTarget
    }

    static func done(unitLabel: String = "", allowBeyond: Bool = false) -> QuickLogSettings {
        QuickLogSettings(unitLabel: unitLabel, kind: .standard, allowLoggingBeyondTarget: allowBeyond)
    }

    static func slip(allowBeyond: Bool = true) -> QuickLogSettings {
        QuickLogSettings(unitLabel: "", kind: .quit, allowLoggingBeyondTarget: allowBeyond)
    }

    static func checklist(_ items: [ChecklistItem], allowBeyond: Bool = false) -> QuickLogSettings {
        QuickLogSettings(
            unitLabel: "",
            kind: .checklist,
            checklistItems: items,
            allowLoggingBeyondTarget: allowBeyond
        )
    }
}

enum DayTrailingAction: Equatable, Sendable {
    case complete
    case slip
    case expandChecklist
    case none
}

func dayTrailingAction(settings: QuickLogSettings) -> DayTrailingAction {
    switch settings.kind {
    case .quit: .slip
    case .checklist: .expandChecklist
    case .standard: .complete
    }
}

func dayTrailingTitle(settings: QuickLogSettings) -> String {
    switch dayTrailingAction(settings: settings) {
    case .complete: "Done"
    case .slip: "Slip"
    case .expandChecklist: "Items"
    case .none: ""
    }
}

/// Amount needed to finish the current period target in one check-off.
func remainingToComplete(goal: Goal, progress: Decimal) -> Decimal {
    max(goal.target - progress, 0)
}

enum QuickLogError: Error, Equatable {
    case futureDate
    case notEligible
    case targetReached
    case alreadyFinalized
    case checklistRequiresItems
    case nothingToComplete
}

struct QuickLogSuccess: Equatable, Sendable {
    var period: HabitPeriod
    var entry: ProgressEntry
    var entries: [ProgressEntry]
    var periods: [HabitPeriod]
}

func isFutureDay(date: Date, now: Date, calendar: Calendar) -> Bool {
    calendar.startOfDay(for: date) > calendar.startOfDay(for: now)
}

func canUseDayTrailingAction(
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
    switch settings.kind {
    case .checklist:
        return !settings.checklistItems.isEmpty
    case .quit, .standard:
        if progress >= goal.target, !settings.allowLoggingBeyondTarget {
            return false
        }
        return remainingToComplete(goal: goal, progress: progress) > 0
            || settings.allowLoggingBeyondTarget
    }
}

func checklistItemStates(
    items: [ChecklistItem],
    habitID: UUID,
    entries: [ProgressEntry],
    on date: Date,
    calendar: Calendar
) -> [ChecklistItemState] {
    let start = calendar.startOfDay(for: date)
    let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
    let completedIDs = Set(
        entries.compactMap { entry -> UUID? in
            guard entry.habitID == habitID,
                  let itemID = entry.checklistItemID,
                  entry.occurredAt >= start,
                  entry.occurredAt < end
            else { return nil }
            return itemID
        }
    )
    return items.map { ChecklistItemState(item: $0, isComplete: completedIDs.contains($0.id)) }
}
