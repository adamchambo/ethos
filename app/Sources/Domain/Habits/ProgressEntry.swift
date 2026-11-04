import Foundation

enum ProgressEntryError: Error, Equatable {
    case nonPositiveAmount
}

/// An immutable action that contributes progress toward a habit in a period.
struct ProgressEntry: Identifiable, Equatable, Sendable, Codable {
    let id: UUID
    let habitID: UUID
    let occurredAt: Date
    let amount: Decimal
    let checklistItemID: UUID?
    let note: String?

    init(
        id: UUID = UUID(),
        habitID: UUID,
        occurredAt: Date,
        amount: Decimal,
        checklistItemID: UUID? = nil,
        note: String? = nil
    ) throws {
        guard amount > .zero else {
            throw ProgressEntryError.nonPositiveAmount
        }

        self.id = id
        self.habitID = habitID
        self.occurredAt = occurredAt
        self.amount = amount
        self.checklistItemID = checklistItemID
        self.note = Self.normalized(note)
    }

    private static func normalized(_ note: String?) -> String? {
        guard let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}
