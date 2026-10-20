import Foundation

enum ClockTimeError: Error, Equatable {
    case invalid
}

/// A time of day, independent of a calendar date.
struct ClockTime: Equatable, Codable, Sendable {
    let hour: Int
    let minute: Int

    init(hour: Int, minute: Int) throws {
        guard (0...23).contains(hour), (0...59).contains(minute) else {
            throw ClockTimeError.invalid
        }

        self.hour = hour
        self.minute = minute
    }

    var minutesFromMidnight: Int {
        hour * 60 + minute
    }
}

enum TimeOfDay: Equatable, Codable, Sendable {
    case morning
    case afternoon
    case evening
    case custom(start: ClockTime, end: ClockTime)
    case none
}
