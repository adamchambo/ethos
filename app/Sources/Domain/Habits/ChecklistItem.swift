import Foundation

struct ChecklistItem: Identifiable, Equatable, Sendable, Codable {
    let id: UUID
    var title: String
    var sortOrder: Int
    var isActive: Bool

    init(id: UUID = UUID(), title: String, sortOrder: Int, isActive: Bool = true) {
        self.id = id
        self.title = title
        self.sortOrder = sortOrder
        self.isActive = isActive
    }
}

/// Active checklist items completed inside the period, over the active item count.
func checklistProgress(
    habit: Habit,
    period: HabitPeriod,
    entries: [ProgressEntry]
) -> (done: Int, total: Int) {
    let active = habit.checklist.filter(\.isActive)
    let completed = Set(
        progressEntries(in: period, from: entries).compactMap(\.checklistItemID)
    )
    let done = active.filter { completed.contains($0.id) }.count
    return (done, active.count)
}
