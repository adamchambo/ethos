import Foundation

/// The one local profile for this installation. It is not an account.
struct LocalProfile: Identifiable, Equatable, Sendable, Codable {
    let id: UUID
    var displayName: String
    var timeZone: TimeZone
    var locale: Locale
    var weekStart: Weekday

    init(
        id: UUID = UUID(),
        displayName: String = "",
        timeZone: TimeZone = .current,
        locale: Locale = .current,
        weekStart: Weekday = .monday
    ) {
        self.id = id
        self.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.timeZone = timeZone
        self.locale = locale
        self.weekStart = weekStart
    }
}
