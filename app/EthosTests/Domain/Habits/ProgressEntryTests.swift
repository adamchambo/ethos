import Foundation
import Testing
@testable import Ethos

struct ProgressEntryTests {
    @Test
    func creationRetainsTheMeasuredContribution() throws {
        let habitID = UUID()
        let occurredAt = Date(timeIntervalSinceReferenceDate: 1_000)

        let entry = try ProgressEntry(
            habitID: habitID,
            occurredAt: occurredAt,
            amount: 2.5
        )

        #expect(entry.habitID == habitID)
        #expect(entry.occurredAt == occurredAt)
        #expect(entry.amount == 2.5)
    }

    @Test(arguments: [Decimal.zero, -1])
    func creationRejectsNonPositiveAmounts(amount: Decimal) {
        #expect(throws: ProgressEntryError.nonPositiveAmount) {
            try ProgressEntry(habitID: UUID(), occurredAt: .now, amount: amount)
        }
    }
}
