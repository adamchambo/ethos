import Foundation
import Observation

/// The in-memory app state. Disk writes happen only for the instance the app restores,
/// so tests keep the isolated service they construct.
///
/// A caller that passes `now` and no clock keeps that instant as the present. A default
/// argument cannot see `now`, so that freeze lives in the clock-less `init`. `restored()`
/// passes a live clock.
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
    private(set) var didInstallSample = false
    private(set) var lastSaveError: String?

    private let storeURL: URL?
    private let clock: () -> Date
    private var canSave = true

    convenience init(
        habits: [Habit] = [],
        now: Date = .now,
        calendar: Calendar = .current,
        persists: Bool = false
    ) {
        self.init(habits: habits, now: now, calendar: calendar, persists: persists, clock: { now })
    }

    init(
        habits: [Habit] = [],
        now: Date = .now,
        calendar: Calendar = .current,
        persists: Bool = false,
        clock: @escaping () -> Date
    ) {
        self.clock = clock
        self.storeURL = persists ? Self.defaultStoreURL : nil
        self.habits = habits
        self.periods = []
        self.periods = habits.compactMap {
            resolvePeriod(
                habit: $0,
                on: now,
                existing: [],
                calendar: calendar,
                weekStartsOn: profile.weekStart
            )
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
        let service = HabitProgressService(persists: true, clock: { Date() })
        service.installSampleLibraryIfNeeded()
        if !service.reminders.isEmpty {
            ReminderScheduling.reschedule(reminders: service.reminders, habits: service.habits)
        }
        return service
    }

    /// Fills an empty library once, so deleting every habit does not bring the sample back.
    func installSampleLibraryIfNeeded(now: Date = .now) {
        guard habits.isEmpty, !didInstallSample else { return }
        let sample = SampleLibrary.make(now: now, calendar: calendar)
        habits = sample.habits
        periods = sample.periods
        entries = sample.entries
        categories = sample.categories
        reminders = sample.reminders
        reflections = sample.reflections
        journal = sample.journal
        didInstallSample = true
        didFinishOnboarding = true
        commit()
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
        calendar: Calendar,
        direction: HabitDirection = .build
    ) throws {
        prepare(now: clock())
        let goal = try Goal(measurement: measurement, target: target, interval: .day)
        let habit = try Habit(
            title: title,
            createdAt: date,
            goal: goal,
            schedule: .daily,
            direction: direction
        )
        habits.append(habit)
        if let period = resolvedPeriod(for: habit, on: date, calendar: calendar) {
            periods.append(period)
        }
        commit()
    }

    func save(habit: Habit, reminder: Reminder?, on date: Date, calendar: Calendar) {
        prepare(now: clock())
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

        if isNew, let period = resolvedPeriod(for: habit, on: date, calendar: calendar) {
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
        guard let habit = try beginMutation(habitID: habitID, on: date, calendar: calendar) else { return nil }
        guard let result = try logProgress(
            habit: habit,
            amount: amount,
            on: date,
            existingPeriods: periods,
            existingEntries: entries,
            calendar: calendar,
            checklistItemID: checklistItemID,
            weekStartsOn: profile.weekStart
        ) else { return nil }

        store(period: result.period, entries: result.entries)
        return result.period
    }

    func completeChecklistItem(habitID: UUID, itemID: UUID, on date: Date, calendar: Calendar) throws -> HabitPeriod? {
        guard try beginMutation(habitID: habitID, on: date, calendar: calendar) != nil else { return nil }
        if isItemDone(habitID: habitID, itemID: itemID, on: date, calendar: calendar) {
            return openPeriod(habitID: habitID, on: date, calendar: calendar)
        }
        return try log(habitID: habitID, amount: 1, on: date, calendar: calendar, checklistItemID: itemID)
    }

    @discardableResult
    func quickComplete(habitID: UUID, on date: Date, calendar: Calendar) throws -> HabitPeriod? {
        guard let habit = try beginMutation(habitID: habitID, on: date, calendar: calendar) else { return nil }
        guard let result = try Ethos.quickComplete(
            habit: habit,
            on: date,
            existingPeriods: periods,
            existingEntries: entries,
            calendar: calendar,
            weekStartsOn: profile.weekStart
        ) else { return nil }

        store(period: result.period, entries: result.entries)
        return result.period
    }

    @discardableResult
    func skip(habitID: UUID, on date: Date, calendar: Calendar) throws -> HabitPeriod? {
        guard let habit = try beginMutation(habitID: habitID, on: date, calendar: calendar) else { return nil }
        guard var period = resolvedPeriod(for: habit, on: date, calendar: calendar) else { return nil }

        try period.skip()
        store(period: period, entries: entries)
        return period
    }

    @discardableResult
    func fail(habitID: UUID, on date: Date, calendar: Calendar) throws -> HabitPeriod? {
        guard let habit = try beginMutation(habitID: habitID, on: date, calendar: calendar),
              habit.direction == .build
        else { return nil }
        guard var period = resolvedPeriod(for: habit, on: date, calendar: calendar) else { return nil }

        try period.fail()
        store(period: period, entries: entries)
        return period
    }

    @discardableResult
    func undo(habitID: UUID, on date: Date, calendar: Calendar) throws -> HabitPeriod? {
        guard try beginMutation(habitID: habitID, on: date, calendar: calendar) != nil else { return nil }
        guard let period = openPeriod(habitID: habitID, on: date, calendar: calendar) else { return nil }
        let result = try uncomplete(period: period, entries: entries, now: clock())
        store(period: result.period, entries: result.entries)
        return result.period
    }

    func addReflection(periodID: UUID, response: String, on date: Date) throws {
        let reflection = try Reflection(periodID: periodID, type: .failure, response: response, createdAt: date)
        reflections = try recordReflection(reflection, existing: reflections)
        commit()
    }

    func updateReflection(id: UUID, response: String) throws {
        reflections = try reviseReflection(id: id, response: response, existing: reflections)
        commit()
    }

    func updateIdentity(habitID: UUID, statement: String?) throws {
        guard let index = habits.firstIndex(where: { $0.id == habitID }) else { return }
        habits[index] = try habits[index].withIdentityStatement(statement)
        commit()
    }

    func updateNotes(habitID: UUID, notes: String?) throws {
        guard let index = habits.firstIndex(where: { $0.id == habitID }) else { return }
        habits[index] = try habits[index].withNotes(notes)
        commit()
    }

    func updateAccountability(habitID: UUID, rule: AccountabilityRule?) {
        guard let index = habits.firstIndex(where: { $0.id == habitID }) else { return }
        habits[index].setAccountability(rule)
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
        guard let period = periodForReading(habitID: habitID, on: date, calendar: calendar) else { return .zero }
        return goalTotal(in: period, entries: entries)
    }

    func fraction(habitID: UUID, on date: Date, calendar: Calendar) -> Decimal {
        guard let habit = habits.first(where: { $0.id == habitID }),
              let period = periodForReading(habitID: habitID, on: date, calendar: calendar)
        else { return .zero }

        let counts = checklistProgress(habit: habit, period: period, entries: entries)
        if counts.total > 0 {
            return Decimal(counts.done) / Decimal(counts.total)
        }
        return displayedProgressFraction(habit: habit, period: period, entries: entries)
    }

    func checklistCount(habitID: UUID, on date: Date, calendar: Calendar) -> (done: Int, total: Int) {
        guard let habit = habits.first(where: { $0.id == habitID }),
              let period = periodForReading(habitID: habitID, on: date, calendar: calendar)
        else { return (0, 0) }
        return checklistProgress(habit: habit, period: period, entries: entries)
    }

    func isItemDone(habitID: UUID, itemID: UUID, on date: Date, calendar: Calendar) -> Bool {
        guard let period = periodForReading(habitID: habitID, on: date, calendar: calendar) else { return false }
        return progressEntries(in: period, from: entries).contains { $0.checklistItemID == itemID }
    }

    func hasLogged(habitID: UUID, on date: Date, calendar: Calendar) -> Bool {
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return false }
        return entries.contains {
            $0.habitID == habitID && $0.occurredAt >= start && $0.occurredAt < end
        }
    }

    /// Completes an open checklist item, or clears that item's log (item stays listed with strikethrough off).
    @discardableResult
    func toggleChecklistItem(habitID: UUID, itemID: UUID, on date: Date, calendar: Calendar) throws -> HabitPeriod? {
        guard let habit = try beginMutation(habitID: habitID, on: date, calendar: calendar) else { return nil }

        if isItemDone(habitID: habitID, itemID: itemID, on: date, calendar: calendar) {
            guard var period = resolvedPeriod(for: habit, on: date, calendar: calendar) else { return nil }
            let remaining = entries.filter { entry in
                !(entry.habitID == habitID
                    && entry.checklistItemID == itemID
                    && entry.occurredAt >= period.startsAt
                    && entry.occurredAt < period.endsAt)
            }
            if period.outcome == .succeeded {
                try period.reopen()
            }
            let outcome = evaluatePeriod(
                habit: habit,
                period: period,
                entries: remaining,
                now: max(date, clock()),
                isSkipped: false
            )
            if outcome != .inProgress {
                try period.finalize(as: outcome)
            }
            store(period: period, entries: remaining)
            return period
        }

        return try log(habitID: habitID, amount: 1, on: date, calendar: calendar, checklistItemID: itemID)
    }

    func openPeriod(habitID: UUID, on date: Date, calendar: Calendar) -> HabitPeriod? {
        guard let habit = habits.first(where: { $0.id == habitID }) else { return nil }
        return resolvedPeriod(for: habit, on: date, calendar: calendar)
    }

    /// The stored period covering `date`, if one was recorded. Does not create one.
    func recordedPeriod(habitID: UUID, on date: Date) -> HabitPeriod? {
        periods.first { period in
            period.habitID == habitID && period.startsAt <= date && date < period.endsAt
        }
    }

    func isWindowClosed(habitID: UUID, on date: Date, calendar: Calendar) -> Bool {
        guard let window = coveringWindow(habitID: habitID, on: date, calendar: calendar) else { return false }
        return clock() >= window.endsAt
    }

    func isFuture(_ date: Date, calendar: Calendar) -> Bool {
        guard let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: clock())) else {
            return false
        }
        return date >= end
    }

    func outcomes(
        in range: StatisticsRange,
        containing date: Date,
        calendar: Calendar,
        habitID: UUID? = nil
    ) -> (succeeded: Int, failed: Int) {
        let window = range.window(containing: date, calendar: calendar, weekStartsOn: profile.weekStart)
        var succeeded = 0
        var failed = 0

        for period in periods {
            if let habitID, period.habitID != habitID { continue }
            if let window, period.startsAt >= window.endsAt || period.endsAt <= window.startsAt { continue }
            switch period.outcome {
            case .succeeded:
                succeeded += 1
            case .failed:
                failed += 1
            case .skipped, .inProgress:
                break
            }
        }

        return (succeeded, failed)
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

    private func beginMutation(habitID: UUID, on date: Date, calendar: Calendar) throws -> Habit? {
        prepare(now: clock())
        guard let habit = habits.first(where: { $0.id == habitID }) else { return nil }
        if isFuture(date, calendar: calendar) {
            throw HabitPeriodError.futureDate
        }
        if isWindowClosed(habitID: habitID, on: date, calendar: calendar) {
            throw HabitPeriodError.periodClosed
        }
        return habit
    }

    /// A closed window is read from what was stored. An open window, including an earlier day of the current week, resolves the live period.
    private func periodForReading(habitID: UUID, on date: Date, calendar: Calendar) -> HabitPeriod? {
        if isWindowClosed(habitID: habitID, on: date, calendar: calendar) {
            return recordedPeriod(habitID: habitID, on: date)
        }
        return openPeriod(habitID: habitID, on: date, calendar: calendar)
    }

    private func resolvedPeriod(for habit: Habit, on date: Date, calendar: Calendar) -> HabitPeriod? {
        resolvePeriod(
            habit: habit,
            on: date,
            existing: periods,
            calendar: calendar,
            weekStartsOn: profile.weekStart
        )
    }

    private func coveringWindow(habitID: UUID, on date: Date, calendar: Calendar) -> PeriodWindow? {
        if let period = recordedPeriod(habitID: habitID, on: date) {
            return PeriodWindow(startsAt: period.startsAt, endsAt: period.endsAt)
        }
        guard let habit = habits.first(where: { $0.id == habitID }) else { return nil }
        return periodWindow(
            containing: date,
            interval: habit.goal.interval,
            calendar: calendar,
            weekStartsOn: profile.weekStart
        )
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
            didFinishOnboarding: didFinishOnboarding,
            didInstallSample: didInstallSample
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
        didInstallSample = snapshot.didInstallSample
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
    var didInstallSample = false

    private enum CodingKeys: String, CodingKey {
        case version, habits, periods, entries, categories, reminders, reflections, journal, profile
        case didFinishOnboarding, didInstallSample
    }

    init(
        version: Int = 1,
        habits: [Habit] = [],
        periods: [HabitPeriod] = [],
        entries: [ProgressEntry] = [],
        categories: [Category] = [],
        reminders: [Reminder] = [],
        reflections: [Reflection] = [],
        journal: [JournalEntry] = [],
        profile: LocalProfile = LocalProfile(),
        didFinishOnboarding: Bool = false,
        didInstallSample: Bool = false
    ) {
        self.version = version
        self.habits = habits
        self.periods = periods
        self.entries = entries
        self.categories = categories
        self.reminders = reminders
        self.reflections = reflections
        self.journal = journal
        self.profile = profile
        self.didFinishOnboarding = didFinishOnboarding
        self.didInstallSample = didInstallSample
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        habits = try container.decodeIfPresent([Habit].self, forKey: .habits) ?? []
        periods = try container.decodeIfPresent([HabitPeriod].self, forKey: .periods) ?? []
        entries = try container.decodeIfPresent([ProgressEntry].self, forKey: .entries) ?? []
        categories = try container.decodeIfPresent([Category].self, forKey: .categories) ?? []
        reminders = try container.decodeIfPresent([Reminder].self, forKey: .reminders) ?? []
        reflections = try container.decodeIfPresent([Reflection].self, forKey: .reflections) ?? []
        journal = try container.decodeIfPresent([JournalEntry].self, forKey: .journal) ?? []
        profile = try container.decodeIfPresent(LocalProfile.self, forKey: .profile) ?? LocalProfile()
        didFinishOnboarding = try container.decodeIfPresent(Bool.self, forKey: .didFinishOnboarding) ?? false
        didInstallSample = try container.decodeIfPresent(Bool.self, forKey: .didInstallSample) ?? false
    }
}
