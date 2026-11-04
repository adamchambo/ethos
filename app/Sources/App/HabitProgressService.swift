import Foundation
import Observation

/// The in-memory app state. Disk writes happen only for the instance the app restores,
/// so tests keep the isolated service they construct.
@Observable
final class HabitProgressService {
    private(set) var habits: [Habit]
    private(set) var periods: [HabitPeriod]
    private(set) var entries: [ProgressEntry] = []
    private(set) var categories: [Category] = []
    private(set) var reminders: [Reminder] = []
    private(set) var reflections: [Reflection] = []
    private(set) var journal: [JournalEntry] = []
    private(set) var profile = LocalProfile()
    private(set) var didFinishOnboarding = false
    private(set) var lastSaveError: String?

    private let storeURL: URL?
    private var canSave = true

    init(habits: [Habit] = [], now: Date = .now, calendar: Calendar = .current, persists: Bool = false) {
        self.storeURL = persists ? Self.defaultStoreURL : nil
        self.habits = habits
        self.periods = habits.compactMap {
            resolvePeriod(habit: $0, on: now, existing: [], calendar: calendar)
        }

        guard persists else { return }

        switch Self.read(from: Self.defaultStoreURL) {
        case .missing:
            self.habits = []
            self.periods = []
        case let .found(snapshot):
            apply(snapshot)
        case .unreadable:
            self.habits = []
            self.periods = []
            canSave = false
            lastSaveError = "Saved data couldn't be read. It has not been overwritten."
        }
    }

    static func restored() -> HabitProgressService {
        let service = HabitProgressService(persists: true)
        if !service.reminders.isEmpty {
            ReminderScheduling.reschedule(reminders: service.reminders, habits: service.habits)
        }
        return service
    }

    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = profile.timeZone
        calendar.locale = profile.locale
        calendar.firstWeekday = profile.weekStart.foundationIndex
        return calendar
    }

    /// Creates a daily build habit and opens its current period. The goal interval is one day.
    func add(
        title: String,
        measurement: GoalMeasurement,
        target: Decimal,
        on date: Date,
        calendar: Calendar
    ) throws {
        prepare(now: date)
        let goal = try Goal(measurement: measurement, target: target, interval: .day)
        let habit = try Habit(
            title: title,
            createdAt: date,
            goal: goal,
            schedule: .daily
        )
        habits.append(habit)
        if let period = resolvePeriod(habit: habit, on: date, existing: periods, calendar: calendar) {
            periods.append(period)
        }
        commit()
    }

    func save(habit: Habit, reminder: Reminder?, on date: Date, calendar: Calendar) {
        prepare(now: date)
        let isNew = !habits.contains { $0.id == habit.id }
        if let index = habits.firstIndex(where: { $0.id == habit.id }) {
            habits[index] = habit
        } else {
            habits.append(habit)
        }

        reminders.removeAll { $0.habitID == habit.id }
        if let reminder {
            reminders.append(reminder)
        }

        if isNew, let period = resolvePeriod(habit: habit, on: date, existing: periods, calendar: calendar) {
            periods.append(period)
        }

        commit()
        ReminderScheduling.reschedule(reminders: reminders, habits: habits)
    }

    func pause(habitID: UUID) {
        guard let index = habits.firstIndex(where: { $0.id == habitID }) else { return }
        habits[index].pause()
        commit()
        ReminderScheduling.reschedule(reminders: reminders, habits: habits)
    }

    func resume(habitID: UUID) throws {
        guard let index = habits.firstIndex(where: { $0.id == habitID }) else { return }
        try habits[index].resume()
        commit()
        ReminderScheduling.reschedule(reminders: reminders, habits: habits)
    }

    func archive(habitID: UUID) {
        guard let index = habits.firstIndex(where: { $0.id == habitID }) else { return }
        habits[index].archive()
        commit()
        ReminderScheduling.reschedule(reminders: reminders, habits: habits)
    }

    @discardableResult
    func addCategory(name: String) throws -> Category {
        let palette = ["4C7DFF", "E15A3A", "2F9E74", "C48A12", "7A5AF8"]
        let category = try Category(
            name: name,
            colour: palette[categories.count % palette.count],
            icon: "tag"
        )
        categories.append(category)
        commit()
        return category
    }

    func renameCategory(id: UUID, to name: String) throws {
        guard let index = categories.firstIndex(where: { $0.id == id }) else { return }
        let existing = categories[index]
        categories[index] = try Category(id: existing.id, name: name, colour: existing.colour, icon: existing.icon)
        commit()
    }

    func updateProfile(_ profile: LocalProfile) {
        self.profile = profile
        commit()
    }

    func finishOnboarding() {
        didFinishOnboarding = true
        commit()
    }

    func replayOnboarding() {
        didFinishOnboarding = false
        commit()
    }

    @discardableResult
    func log(
        habitID: UUID,
        amount: Decimal,
        on date: Date,
        calendar: Calendar,
        checklistItemID: UUID? = nil
    ) throws -> HabitPeriod? {
        prepare(now: date)
        guard let habit = habits.first(where: { $0.id == habitID }) else { return nil }
        guard let result = try logProgress(
            habit: habit,
            amount: amount,
            on: date,
            existingPeriods: periods,
            existingEntries: entries,
            calendar: calendar,
            checklistItemID: checklistItemID
        ) else { return nil }

        store(period: result.period, entries: result.entries)
        return result.period
    }

    func completeChecklistItem(habitID: UUID, itemID: UUID, on date: Date, calendar: Calendar) throws -> HabitPeriod? {
        if isItemDone(habitID: habitID, itemID: itemID, on: date, calendar: calendar) {
            return openPeriod(habitID: habitID, on: date, calendar: calendar)
        }
        return try log(habitID: habitID, amount: 1, on: date, calendar: calendar, checklistItemID: itemID)
    }

    @discardableResult
    func quickComplete(habitID: UUID, on date: Date, calendar: Calendar) throws -> HabitPeriod? {
        prepare(now: date)
        guard let habit = habits.first(where: { $0.id == habitID }) else { return nil }
        guard let result = try Ethos.quickComplete(
            habit: habit,
            on: date,
            existingPeriods: periods,
            existingEntries: entries,
            calendar: calendar
        ) else { return nil }

        store(period: result.period, entries: result.entries)
        return result.period
    }

    @discardableResult
    func skip(habitID: UUID, on date: Date, calendar: Calendar) throws -> HabitPeriod? {
        prepare(now: date)
        guard let habit = habits.first(where: { $0.id == habitID }) else { return nil }
        guard var period = resolvePeriod(habit: habit, on: date, existing: periods, calendar: calendar) else {
            return nil
        }

        try period.skip()
        store(period: period, entries: entries)
        return period
    }

    @discardableResult
    func fail(habitID: UUID, on date: Date, calendar: Calendar) throws -> HabitPeriod? {
        prepare(now: date)
        guard let habit = habits.first(where: { $0.id == habitID }), habit.direction == .build else { return nil }
        guard var period = resolvePeriod(habit: habit, on: date, existing: periods, calendar: calendar) else {
            return nil
        }

        try period.fail()
        store(period: period, entries: entries)
        return period
    }

    @discardableResult
    func undo(habitID: UUID, on date: Date, calendar: Calendar) throws -> HabitPeriod? {
        prepare(now: date)
        guard let period = openPeriod(habitID: habitID, on: date, calendar: calendar) else { return nil }
        let result = try uncomplete(period: period, entries: entries, now: date)
        store(period: result.period, entries: result.entries)
        return result.period
    }

    func addReflection(periodID: UUID, response: String, on date: Date) throws {
        let reflection = try Reflection(periodID: periodID, type: .failure, response: response, createdAt: date)
        reflections = try recordReflection(reflection, existing: reflections)
        commit()
    }

    func journalText(on date: Date, calendar: Calendar) -> String {
        journal.first { calendar.isDate($0.dayStart, inSameDayAs: date) }?.text ?? ""
    }

    func saveJournal(text: String, on date: Date, calendar: Calendar) throws {
        journal.removeAll { calendar.isDate($0.dayStart, inSameDayAs: date) }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            let entry = try recordJournalEntry(
                text: trimmed,
                on: date,
                existing: journal,
                calendar: calendar,
                createdAt: date
            )
            journal.append(entry)
        }
        commit()
    }

    /// Finalizes periods whose window has ended before Today reads them.
    func prepare(now: Date) {
        let closed = closeExpiredPeriods(habits: habits, periods: periods, entries: entries, now: now)
        guard closed != periods else { return }
        periods = closed
        commit()
    }

    func progress(habitID: UUID, on date: Date, calendar: Calendar) -> Decimal {
        guard let period = openPeriod(habitID: habitID, on: date, calendar: calendar) else { return .zero }
        return goalTotal(in: period, entries: entries)
    }

    func fraction(habitID: UUID, on date: Date, calendar: Calendar) -> Decimal {
        guard let habit = habits.first(where: { $0.id == habitID }),
              let period = openPeriod(habitID: habitID, on: date, calendar: calendar)
        else { return .zero }

        let counts = checklistProgress(habit: habit, period: period, entries: entries)
        if counts.total > 0 {
            return Decimal(counts.done) / Decimal(counts.total)
        }
        return displayedProgressFraction(habit: habit, period: period, entries: entries)
    }

    func checklistCount(habitID: UUID, on date: Date, calendar: Calendar) -> (done: Int, total: Int) {
        guard let habit = habits.first(where: { $0.id == habitID }),
              let period = openPeriod(habitID: habitID, on: date, calendar: calendar)
        else { return (0, 0) }
        return checklistProgress(habit: habit, period: period, entries: entries)
    }

    func isItemDone(habitID: UUID, itemID: UUID, on date: Date, calendar: Calendar) -> Bool {
        guard let period = openPeriod(habitID: habitID, on: date, calendar: calendar) else { return false }
        return progressEntries(in: period, from: entries).contains { $0.checklistItemID == itemID }
    }

    func openPeriod(habitID: UUID, on date: Date, calendar: Calendar) -> HabitPeriod? {
        guard let habit = habits.first(where: { $0.id == habitID }) else { return nil }
        return resolvePeriod(habit: habit, on: date, existing: periods, calendar: calendar)
    }

    func isScheduled(_ habit: Habit, on date: Date, calendar: Calendar) -> Bool {
        guard habit.lifecycle == .active else { return false }
        let day = calendar.startOfDay(for: date)
        guard day >= calendar.startOfDay(for: habit.startDate) else { return false }
        if let endDate = habit.endDate, day > calendar.startOfDay(for: endDate) { return false }
        return habit.schedule.isEligible(on: date, calendar: calendar, starting: habit.startDate)
    }

    func streak(habitID: UUID) -> Int {
        currentStreak(habitID: habitID, periods: periods)
    }

    func best(habitID: UUID) -> Int {
        bestStreak(habitID: habitID, periods: periods)
    }

    func rate(habitID: UUID) -> Decimal? {
        completionRate(habitID: habitID, periods: periods)
    }

    func exportFile() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ethos-export.json")
        try Self.encoder().encode(snapshot()).write(to: url, options: .atomic)
        return url
    }

    func replace(with data: Data) throws {
        let snapshot = try Self.decoder().decode(AppSnapshot.self, from: data)
        apply(snapshot)
        canSave = true
        lastSaveError = nil
        commit()
        ReminderScheduling.reschedule(reminders: reminders, habits: habits)
    }

    func overwriteUnreadableStore() {
        canSave = true
        lastSaveError = nil
        commit()
    }

    private func store(period: HabitPeriod, entries: [ProgressEntry]) {
        if let index = periods.firstIndex(where: { $0.id == period.id }) {
            periods[index] = period
        } else {
            periods.append(period)
        }
        self.entries = entries
        commit()
    }

    private func snapshot() -> AppSnapshot {
        AppSnapshot(
            habits: habits,
            periods: periods,
            entries: entries,
            categories: categories,
            reminders: reminders,
            reflections: reflections,
            journal: journal,
            profile: profile,
            didFinishOnboarding: didFinishOnboarding
        )
    }

    private func apply(_ snapshot: AppSnapshot) {
        habits = snapshot.habits
        periods = snapshot.periods
        entries = snapshot.entries
        categories = snapshot.categories
        reminders = snapshot.reminders
        reflections = snapshot.reflections
        journal = snapshot.journal
        profile = snapshot.profile
        didFinishOnboarding = snapshot.didFinishOnboarding
    }

    private func commit() {
        guard let storeURL, canSave else { return }
        do {
            try FileManager.default.createDirectory(
                at: storeURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try Self.encoder().encode(snapshot()).write(to: storeURL, options: .atomic)
            lastSaveError = nil
        } catch {
            lastSaveError = "Changes couldn't be saved."
        }
    }

    private static var defaultStoreURL: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Ethos", isDirectory: true)
            .appendingPathComponent("store.json")
    }

    private static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private static func read(from url: URL) -> StoreRead {
        guard FileManager.default.fileExists(atPath: url.path) else { return .missing }
        guard let data = try? Data(contentsOf: url),
              let snapshot = try? decoder().decode(AppSnapshot.self, from: data)
        else { return .unreadable }
        return .found(snapshot)
    }
}

private enum StoreRead {
    case missing
    case found(AppSnapshot)
    case unreadable
}

struct AppSnapshot: Codable {
    var version = 1
    var habits: [Habit] = []
    var periods: [HabitPeriod] = []
    var entries: [ProgressEntry] = []
    var categories: [Category] = []
    var reminders: [Reminder] = []
    var reflections: [Reflection] = []
    var journal: [JournalEntry] = []
    var profile = LocalProfile()
    var didFinishOnboarding = false
}
