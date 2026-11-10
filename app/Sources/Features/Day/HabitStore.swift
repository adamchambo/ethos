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

    @discardableResult
    func quickLog(row: DayHabitRow, amount: Decimal? = nil) -> Bool {
        lastErrorMessage = nil

        if row.opensChecklist {
            lastErrorMessage = nil
            return false
        }

        guard let definition = definition(for: row.habit.id) else { return false }

        do {
            guard let result = try logProgress(
                habit: definition.habit,
                goal: definition.goal,
                schedule: definition.schedule,
                amount: amount ?? definition.quickLog.amount,
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
        } catch QuickLogError.targetReached {
            lastErrorMessage = "Target already reached."
        } catch QuickLogError.alreadyFinalized {
            lastErrorMessage = "This period is closed."
        } catch {
            lastErrorMessage = "Couldn’t save progress."
        }
        return false
    }

    @discardableResult
    func logChecklistItem(habitID: UUID, item: ChecklistItem) -> Bool {
        guard let index = definitions.firstIndex(where: { $0.habit.id == habitID }) else {
            return false
        }
        // Checklist items are exposed for selection; each confirmation logs one unit.
        _ = item
        let definition = definitions[index]
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
