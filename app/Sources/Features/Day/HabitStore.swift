import Foundation
import Observation

/// In-memory shared state so Day view and habit detail refresh from the same logs.
@Observable
final class HabitStore {
    var definitions: [HabitDefinition]
    var periods: [HabitPeriod] = []
    var entries: [ProgressEntry] = []
    var selectedDate: Date
    var lastUndoableEntryID: UUID?
    var lastErrorMessage: String?
    var hapticsEnabled: Bool = true

    private let calendar: Calendar

    init(
        definitions: [HabitDefinition],
        selectedDate: Date = Date(),
        calendar: Calendar = .current
    ) {
        self.definitions = definitions
        self.selectedDate = selectedDate
        self.calendar = calendar
    }

    var snapshot: DayViewSnapshot {
        makeDayViewSnapshot(
            definitions: definitions,
            on: selectedDate,
            periods: periods,
            entries: entries,
            calendar: calendar,
            now: Date()
        )
    }

    func definition(for habitID: UUID) -> HabitDefinition? {
        definitions.first { $0.habit.id == habitID }
    }

    func shiftDay(_ value: Int) {
        guard let next = calendar.date(byAdding: .day, value: value, to: selectedDate) else {
            return
        }
        selectedDate = next
        lastErrorMessage = nil
    }

    func entries(for habitID: UUID) -> [ProgressEntry] {
        entries
            .filter { $0.habitID == habitID }
            .sorted { $0.occurredAt > $1.occurredAt }
    }

    func checklistStates(for habitID: UUID) -> [ChecklistItemState] {
        guard let definition = definition(for: habitID) else { return [] }
        return checklistItemStates(
            items: definition.quickLog.checklistItems,
            habitID: habitID,
            entries: entries,
            on: selectedDate,
            calendar: calendar
        )
    }

    /// One-tap complete / slip for the selected day — logs remaining amount to hit the target.
    @discardableResult
    func completeFromDay(row: DayHabitRow) -> Bool {
        lastErrorMessage = nil
        guard let definition = definition(for: row.habit.id) else { return false }

        do {
            guard let result = try completeHabitProgress(
                habit: definition.habit,
                goal: definition.goal,
                schedule: definition.schedule,
                on: selectedDate,
                existingPeriods: periods,
                existingEntries: entries,
                calendar: calendar,
                allowLoggingBeyondTarget: definition.quickLog.allowLoggingBeyondTarget,
                now: Date()
            ) else {
                lastErrorMessage = "This habit isn’t eligible on the selected day."
                return false
            }
            periods = result.periods
            entries = result.entries
            lastUndoableEntryID = result.entry.id
            return true
        } catch QuickLogError.futureDate {
            lastErrorMessage = "Logging is disabled for future dates."
        } catch QuickLogError.nothingToComplete, QuickLogError.targetReached {
            lastErrorMessage = "Already complete."
        } catch {
            lastErrorMessage = "Couldn’t save progress."
        }
        return false
    }

    /// Toggle a checklist item: complete with strikethrough state, or undo if already done.
    @discardableResult
    func toggleChecklistItem(habitID: UUID, itemID: UUID) -> Bool {
        lastErrorMessage = nil
        guard let definition = definition(for: habitID) else { return false }

        let states = checklistStates(for: habitID)
        guard let state = states.first(where: { $0.id == itemID }) else { return false }

        if state.isComplete {
            guard let entry = entries.last(where: {
                $0.habitID == habitID && $0.checklistItemID == itemID
            }) else { return false }
            do {
                let result = try undoProgress(
                    entryID: entry.id,
                    habit: definition.habit,
                    goal: definition.goal,
                    schedule: definition.schedule,
                    existingPeriods: periods,
                    existingEntries: entries,
                    calendar: calendar,
                    now: Date()
                )
                periods = result.periods
                entries = result.entries
                if lastUndoableEntryID == entry.id {
                    lastUndoableEntryID = nil
                }
                return true
            } catch {
                lastErrorMessage = "Couldn’t undo that item."
                return false
            }
        }

        do {
            guard let result = try logProgress(
                habit: definition.habit,
                goal: definition.goal,
                schedule: definition.schedule,
                amount: 1,
                on: selectedDate,
                existingPeriods: periods,
                existingEntries: entries,
                calendar: calendar,
                allowLoggingBeyondTarget: definition.quickLog.allowLoggingBeyondTarget,
                checklistItemID: itemID,
                now: Date()
            ) else {
                lastErrorMessage = "This habit isn’t eligible on the selected day."
                return false
            }
            periods = result.periods
            entries = result.entries
            lastUndoableEntryID = result.entry.id
            return true
        } catch {
            lastErrorMessage = "Couldn’t save checklist progress."
            return false
        }
    }

    @discardableResult
    func undoLastLog() -> Bool {
        guard let entryID = lastUndoableEntryID,
              let entry = entries.first(where: { $0.id == entryID }),
              let definition = definition(for: entry.habitID)
        else {
            return false
        }

        do {
            let result = try undoProgress(
                entryID: entryID,
                habit: definition.habit,
                goal: definition.goal,
                schedule: definition.schedule,
                existingPeriods: periods,
                existingEntries: entries,
                calendar: calendar,
                now: Date()
            )
            periods = result.periods
            entries = result.entries
            lastUndoableEntryID = nil
            lastErrorMessage = nil
            return true
        } catch {
            lastErrorMessage = "Couldn’t undo that log."
            return false
        }
    }

    func updateDefinition(_ definition: HabitDefinition) {
        guard let index = definitions.firstIndex(where: { $0.habit.id == definition.habit.id }) else {
            return
        }
        definitions[index] = definition
    }

    func streakCount(for habitID: UUID) -> Int {
        currentStreak(habitID: habitID, periods: periods)
    }

    func rate(for habitID: UUID) -> Decimal? {
        completionRate(habitID: habitID, periods: periods)
    }
}
