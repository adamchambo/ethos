import Foundation

enum ProgressEntryError: Error, Equatable {
    case nonPositiveAmount
}

/// An immutable action that contributes progress toward a habit in a period.
struct ProgressEntry: Identifiable, Equatable, Sendable {
    let id: UUID
    let habitID: UUID
    let occurredAt: Date
    let amount: Decimal

    init(
        id: UUID = UUID(),
        habitID: UUID,
        occurredAt: Date,
        amount: Decimal
    ) throws {
        guard amount > .zero else {
            throw ProgressEntryError.nonPositiveAmount
        }

        self.id = id
        self.habitID = habitID
        self.occurredAt = occurredAt
        self.amount = amount
    }
}
