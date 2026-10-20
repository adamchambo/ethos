import Foundation

enum JournalError: Error, Equatable {
    case blankText
    case alreadyRecorded
}

/// One journal entry for a local calendar day.
struct JournalEntry: Identifiable, Equatable, Sendable {
    let id: UUID
    let dayStart: Date
    let text: String
    let createdAt: Date

    init(id: UUID = UUID(), dayStart: Date, text: String, createdAt: Date) throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw JournalError.blankText
        }

        self.id = id
        self.dayStart = dayStart
        self.text = trimmed
        self.createdAt = createdAt
    }
}

func recordJournalEntry(
    text: String,
    on date: Date,
    existing: [JournalEntry],
    calendar: Calendar,
    createdAt: Date
) throws -> JournalEntry {
    let dayStart = calendar.startOfDay(for: date)
    guard !existing.contains(where: { calendar.isDate($0.dayStart, inSameDayAs: dayStart) }) else {
        throw JournalError.alreadyRecorded
    }
    return try JournalEntry(dayStart: dayStart, text: text, createdAt: createdAt)
}
