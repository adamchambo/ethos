import Foundation

struct Reminder: Identifiable, Equatable, Sendable, Codable {
    let id: UUID
    let habitID: UUID
    var time: ClockTime
    var weekdays: Set<Weekday>
    var repeatIntervalMinutes: Int?
    var snoozedUntil: Date?
    var skipNext: Bool
    var stopsWhenTargetReached: Bool
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        habitID: UUID,
        time: ClockTime,
        weekdays: Set<Weekday> = [],
        repeatIntervalMinutes: Int? = nil,
        snoozedUntil: Date? = nil,
        skipNext: Bool = false,
        stopsWhenTargetReached: Bool = true,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.habitID = habitID
        self.time = time
        self.weekdays = weekdays
        self.repeatIntervalMinutes = repeatIntervalMinutes
        self.snoozedUntil = snoozedUntil
        self.skipNext = skipNext
        self.stopsWhenTargetReached = stopsWhenTargetReached
        self.isEnabled = isEnabled
    }

    /// Whether this reminder should fire at `date`. An empty weekday set means every day.
    /// A repeat interval also fires later the same day, on whole multiples of that interval.
    func isDue(on date: Date, calendar: Calendar, targetReached: Bool) -> Bool {
        guard isEnabled, !skipNext else { return false }
        if stopsWhenTargetReached, targetReached { return false }
        if let snoozedUntil, date < snoozedUntil { return false }

        if !weekdays.isEmpty {
            guard let weekday = Weekday(foundationWeekday: calendar.component(.weekday, from: date)),
                  weekdays.contains(weekday)
            else {
                return false
            }
        }

        let current = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        let scheduled = time.minutesFromMidnight
        if current == scheduled { return true }

        guard let repeatIntervalMinutes, repeatIntervalMinutes > 0, current > scheduled else {
            return false
        }
        return (current - scheduled).isMultiple(of: repeatIntervalMinutes)
    }
}
