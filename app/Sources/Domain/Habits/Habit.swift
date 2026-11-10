import Foundation

enum HabitLifecycle: String, Codable, Sendable {
    case active
    case paused
    case archived
}

enum HabitDirection: String, Codable, Sendable, CaseIterable {
    case build
    case quit
}

enum HabitError: Error, Equatable {
    case blankTitle
    case cannotResumeArchivedHabit
    case nonPositiveBuildTarget
    case endDateNotAfterStartDate
    case invalidTimeRange
    case invalidSchedule
    case unknownChecklistItem
    case invalidChecklistOrder
}

struct Habit: Identifiable, Equatable, Sendable, Codable {
    let id: UUID
    let createdAt: Date
    let direction: HabitDirection
    let timeOfDay: TimeOfDay
    let identityStatement: String?
    let notes: String?
    let startDate: Date
    let endDate: Date?
    let categoryID: UUID?
    private(set) var goal: Goal
    private(set) var schedule: HabitSchedule
    private(set) var title: String
    private(set) var lifecycle: HabitLifecycle
    private(set) var checklist: [ChecklistItem]
    private(set) var accountability: AccountabilityRule?

    init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date,
        goal: Goal,
        schedule: HabitSchedule,
        lifecycle: HabitLifecycle = .active,
        direction: HabitDirection = .build,
        timeOfDay: TimeOfDay = .none,
        identityStatement: String? = nil,
        notes: String? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        categoryID: UUID? = nil,
        checklist: [ChecklistItem] = [],
        accountability: AccountabilityRule? = nil
    ) throws {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedTitle.isEmpty else {
            throw HabitError.blankTitle
        }

        let resolvedStart = startDate ?? createdAt
        try Self.validate(
            direction: direction,
            goal: goal,
            schedule: schedule,
            timeOfDay: timeOfDay,
            startDate: resolvedStart,
            endDate: endDate
        )

        self.id = id
        self.title = normalizedTitle
        self.createdAt = createdAt
        self.goal = goal
        self.schedule = schedule
        self.lifecycle = lifecycle
        self.direction = direction
        self.timeOfDay = timeOfDay
        self.identityStatement = Self.normalizedOptional(identityStatement)
        self.notes = Self.normalizedOptional(notes)
        self.startDate = resolvedStart
        self.endDate = endDate
        self.categoryID = categoryID
        self.checklist = checklist
        self.accountability = accountability
    }

    var isActive: Bool {
        lifecycle == .active
    }

    mutating func rename(to newTitle: String) throws {
        let normalizedTitle = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalizedTitle.isEmpty else {
            throw HabitError.blankTitle
        }

        title = normalizedTitle
    }

    mutating func pause() {
        guard lifecycle == .active else { return }
        lifecycle = .paused
    }

    mutating func resume() throws {
        guard lifecycle != .archived else {
            throw HabitError.cannotResumeArchivedHabit
        }

        lifecycle = .active
    }

    mutating func archive() {
        lifecycle = .archived
    }

    /// Replaces the goal from now on. Periods already finalized keep the outcome they have.
    mutating func changeGoal(to newGoal: Goal) throws {
        try Self.validate(
            direction: direction,
            goal: newGoal,
            schedule: schedule,
            timeOfDay: timeOfDay,
            startDate: startDate,
            endDate: endDate
        )
        goal = newGoal
    }

    /// Replaces the schedule from now on. Periods already finalized keep the outcome they have.
    mutating func changeSchedule(to newSchedule: HabitSchedule) throws {
        try Self.validate(
            direction: direction,
            goal: goal,
            schedule: newSchedule,
            timeOfDay: timeOfDay,
            startDate: startDate,
            endDate: endDate
        )
        schedule = newSchedule
    }

    mutating func addChecklistItem(title: String) throws {
        let normalized = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            throw HabitError.blankTitle
        }

        let order = (checklist.map(\.sortOrder).max() ?? -1) + 1
        checklist.append(ChecklistItem(title: normalized, sortOrder: order))
    }

    mutating func reorderChecklist(_ orderedIDs: [UUID]) throws {
        let currentIDs = checklist.map(\.id)
        guard orderedIDs.count == currentIDs.count, Set(orderedIDs) == Set(currentIDs) else {
            throw HabitError.invalidChecklistOrder
        }

        checklist = orderedIDs.enumerated().map { index, id in
            var item = checklist.first { $0.id == id }!
            item.sortOrder = index
            return item
        }
    }

    mutating func deactivateChecklistItem(id: UUID) throws {
        guard let index = checklist.firstIndex(where: { $0.id == id }) else {
            throw HabitError.unknownChecklistItem
        }
        checklist[index].isActive = false
    }

    mutating func setAccountability(_ rule: AccountabilityRule?) {
        accountability = rule
    }

    func withIdentityStatement(_ statement: String?) throws -> Habit {
        try Habit(
            id: id,
            title: title,
            createdAt: createdAt,
            goal: goal,
            schedule: schedule,
            lifecycle: lifecycle,
            direction: direction,
            timeOfDay: timeOfDay,
            identityStatement: statement,
            notes: notes,
            startDate: startDate,
            endDate: endDate,
            categoryID: categoryID,
            checklist: checklist,
            accountability: accountability
        )
    }

    func withNotes(_ notes: String?) throws -> Habit {
        try Habit(
            id: id,
            title: title,
            createdAt: createdAt,
            goal: goal,
            schedule: schedule,
            lifecycle: lifecycle,
            direction: direction,
            timeOfDay: timeOfDay,
            identityStatement: identityStatement,
            notes: notes,
            startDate: startDate,
            endDate: endDate,
            categoryID: categoryID,
            checklist: checklist,
            accountability: accountability
        )
    }

    private static func validate(
        direction: HabitDirection,
        goal: Goal,
        schedule: HabitSchedule,
        timeOfDay: TimeOfDay,
        startDate: Date,
        endDate: Date?
    ) throws {
        if direction == .build, goal.target == .zero {
            throw HabitError.nonPositiveBuildTarget
        }

        if let endDate, endDate <= startDate {
            throw HabitError.endDateNotAfterStartDate
        }

        if case let .custom(start, end) = timeOfDay, end.minutesFromMidnight <= start.minutesFromMidnight {
            throw HabitError.invalidTimeRange
        }

        do {
            try schedule.validate()
        } catch {
            throw HabitError.invalidSchedule
        }
    }

    private static func normalizedOptional(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}
