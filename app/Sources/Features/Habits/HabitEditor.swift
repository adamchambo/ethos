import SwiftUI

private enum HabitEditorPane: String, CaseIterable, Identifiable {
    case settings = "Settings"
    case recurrence = "Recurrence"

    var id: String { rawValue }
}

struct HabitEditor: View {
    let service: HabitProgressService
    @Environment(\.dismiss) private var dismiss
    @State private var draft: HabitDraft
    @State private var checklistTitle = ""
    @State private var categoryName = ""
    @State private var addingCategory = false
    @State private var confirmingArchive = false
    @State private var showingMore: Bool
    @State private var pane: HabitEditorPane = .settings
    @State private var errorMessage: String?

    init(service: HabitProgressService, habit: Habit?) {
        self.service = service
        let reminder = habit.flatMap { habit in
            service.reminders.first { $0.habitID == habit.id }
        }
        let draft = HabitDraft(habit: habit, reminder: reminder)
        _draft = State(initialValue: draft)
        _showingMore = State(initialValue: draft.usesMoreOptions)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Edit", selection: $pane) {
                    ForEach(HabitEditorPane.allCases) { pane in
                        Text(pane.rawValue).tag(pane)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

                Form {
                    Group {
                        switch pane {
                        case .settings:
                            settingsSections
                        case .recurrence:
                            recurrenceSection
                        }
                    }
                    .ethosRows()
                }
            }
            .ethosScreen()
            .navigationTitle(draft.isEditing ? "Edit habit" : "Add habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
            .onChange(of: draft.direction) { _, direction in
                if direction == .quit, draft.measurement == .boolean {
                    draft.target = "0"
                }
            }
            .onChange(of: draft.measurement) { _, measurement in
                if draft.direction == .quit, measurement == .boolean {
                    draft.target = "0"
                }
            }
            .onChange(of: draft.interval) { _, interval in
                if !DayPattern.standard(for: interval).contains(draft.dayPattern) {
                    draft.dayPattern = .everyDay
                }
            }
            .alert("New category", isPresented: $addingCategory) {
                TextField("Name", text: $categoryName)
                Button("Add") { addCategory() }
                Button("Cancel", role: .cancel) { categoryName = "" }
            }
            .alert("Archive this habit?", isPresented: $confirmingArchive) {
                Button("Archive", role: .destructive) { archive() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("It leaves Today and stays in the archived list.")
            }
            .alert("Unable to save", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    @ViewBuilder
    private var settingsSections: some View {
        Section {
            Picker("Direction", selection: $draft.direction) {
                ForEach(HabitDirection.allCases, id: \.self) { direction in
                    Text(direction.label).tag(direction)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .accessibilityLabel("Direction")
            TextField("Name", text: $draft.title)
        } header: {
            Text("Habit")
        } footer: {
            Text(draft.direction == .quit
                ? "Success means staying at or under the limit. A limit of 0 means avoid it entirely."
                : "Success means doing it.")
        }

        Section {
            Picker("Measure", selection: $draft.measurement) {
                ForEach(GoalMeasurement.allCases, id: \.self) { measurement in
                    Text(measurement.label).tag(measurement)
                }
            }
            if draft.direction == .quit || draft.measurement != .boolean {
                LabeledContent(targetLabel) {
                    TextField(targetLabel, text: $draft.target)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
            }
            if draft.measurement == .quantity {
                LabeledContent("Unit") {
                    TextField("pages, glasses", text: $draft.unitName)
                        .multilineTextAlignment(.trailing)
                }
            }
            if draft.direction == .build {
                Toggle("Allow going past the target", isOn: $draft.allowsOverCompletion)
            }
        } header: {
            Text("Goal")
        }

        Section {
            Picker("Time of day", selection: $draft.timeChoice) {
                ForEach(TimeChoice.allCases) { choice in
                    Text(choice.label).tag(choice)
                }
            }
            Toggle("Remind me", isOn: $draft.reminderEnabled)
            if draft.reminderEnabled {
                DatePicker("Reminder", selection: $draft.reminderDate, displayedComponents: .hourAndMinute)
            }
        } header: {
            Text("When")
        } footer: {
            if draft.reminderEnabled {
                Text(draft.dayPattern == .specificWeekdays
                    ? "The reminder fires on the days picked above."
                    : "The reminder fires every day at this time.")
            }
        }

        Section {
            Button(showingMore ? "Fewer options" : "More options") {
                withAnimation { showingMore.toggle() }
            }
        } footer: {
            if !showingMore {
                Text("Category, checklist, identity, notes, dates, and accountability.")
            }
        }
        if showingMore {
            moreSections
        }
        statusSection
    }

    @ViewBuilder
    private var recurrenceSection: some View {
        Section {
            Picker("How often", selection: $draft.interval) {
                ForEach(GoalInterval.allCases, id: \.self) { interval in
                    Text(frequencyLabel(interval)).tag(interval)
                }
            }
            Picker("Which days", selection: $draft.dayPattern) {
                ForEach(draft.dayPatternChoices) { pattern in
                    Text(pattern.label(for: draft.interval)).tag(pattern)
                }
            }
            switch draft.dayPattern {
            case .everyDay:
                EmptyView()
            case .specificWeekdays:
                WeekdayChips(selection: $draft.weekdays)
            case .everyFewDays:
                Stepper(everyXLabel, value: $draft.everyX, in: 1...60)
            case .monthDates:
                TextField("Days of the month", text: $draft.monthDays)
            case .monthWeekday:
                Picker("Week", selection: $draft.ordinal) {
                    ForEach(MonthWeekdayOrdinal.allCases, id: \.self) { ordinal in
                        Text(ordinal.label).tag(ordinal)
                    }
                }
                Picker("Day", selection: $draft.monthlyWeekday) {
                    ForEach(Weekday.allCases, id: \.self) { day in
                        Text(day.name).tag(day)
                    }
                }
            }
        } header: {
            Text("Schedule")
        } footer: {
            Text(draft.schedulePreview()
                ?? "Schedule controls which days appear on Day view. The goal counting period is separate.")
        }
    }

    @ViewBuilder
    private var moreSections: some View {
        Section("Category") {
            Picker("Category", selection: $draft.categoryID) {
                Text("None").tag(Optional<UUID>.none)
                ForEach(service.categories) { category in
                    Text(category.name).tag(Optional(category.id))
                }
            }
            Button("New category") { addingCategory = true }
        }

        Section("Checklist") {
            ForEach(draft.checklist.filter(\.isActive).sorted { $0.sortOrder < $1.sortOrder }) { item in
                HStack {
                    Text(item.title)
                    Spacer()
                    Button("Remove", role: .destructive) { draft.deactivate(item.id) }
                        .buttonStyle(.borderless)
                }
            }
            HStack {
                TextField("Add an item", text: $checklistTitle)
                Button("Add") { addChecklistItem() }
                    .disabled(checklistTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }

        Section("Identity") {
            TextField("Who this is for", text: $draft.identity, axis: .vertical)
        }

        Section("Notes") {
            TextField("Notes", text: $draft.notes, axis: .vertical)
        }

        Section("Dates") {
            DatePicker("Starts", selection: $draft.startDate, displayedComponents: .date)
            Toggle("Ends", isOn: $draft.hasEndDate)
            if draft.hasEndDate {
                DatePicker("End", selection: $draft.endDate, displayedComponents: .date)
            }
        }

        Section {
            Toggle("Accountability", isOn: $draft.accountabilityEnabled)
            if draft.accountabilityEnabled {
                Picker("Tone", selection: $draft.tone) {
                    ForEach(AccountabilityTone.allCases, id: \.self) { tone in
                        Text(tone.label).tag(tone)
                    }
                }
                Picker("After a miss", selection: $draft.consequence) {
                    ForEach(AccountabilityConsequence.allCases, id: \.self) { consequence in
                        Text(consequence.label).tag(consequence)
                    }
                }
                if draft.consequence == .recoveryAction {
                    TextField(
                        "Recovery action",
                        text: $draft.recoveryAction,
                        prompt: Text("What will you do to make up for it?"),
                        axis: .vertical
                    )
                }
                Toggle("Ask me to confirm", isOn: $draft.requiresConfirmation)
            }
        } header: {
            Text("Accountability")
        } footer: {
            if draft.accountabilityEnabled {
                Text("Ethos asks before you log a slip or mark this missed.")
            }
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        if draft.isEditing {
            Section {
                if draft.lifecycle == .active {
                    Button("Pause") { pause() }
                }
                if draft.lifecycle == .paused {
                    Button("Resume") { resume() }
                }
                if draft.lifecycle != .archived {
                    Button("Archive", role: .destructive) { confirmingArchive = true }
                }
            } header: {
                Text("Status")
            } footer: {
                Text("This habit is \(draft.lifecycle.label.lowercased()).")
            }
        }
    }

    private var targetLabel: String {
        if draft.direction == .quit {
            return "Limit"
        }
        switch draft.measurement {
        case .count, .boolean:
            return "Times"
        case .duration:
            return "Minutes"
        case .quantity:
            return "Amount"
        }
    }

    private var everyXLabel: String {
        draft.everyX == 1 ? "Every day" : "Every \(draft.everyX) days"
    }

    private func addChecklistItem() {
        let title = checklistTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let order = (draft.checklist.map(\.sortOrder).max() ?? -1) + 1
        draft.checklist.append(ChecklistItem(title: title, sortOrder: order))
        checklistTitle = ""
    }

    private func addCategory() {
        do {
            let category = try service.addCategory(name: categoryName)
            draft.categoryID = category.id
            categoryName = ""
        } catch {
            errorMessage = ethosMessage(error)
        }
    }

    private func save() {
        do {
            try write()
            dismiss()
        } catch {
            errorMessage = ethosMessage(error)
        }
    }

    private func pause() {
        do {
            try write()
            service.pause(habitID: draft.id)
            draft.lifecycle = .paused
        } catch {
            errorMessage = ethosMessage(error)
        }
    }

    private func resume() {
        do {
            try write()
            try service.resume(habitID: draft.id)
            draft.lifecycle = .active
        } catch {
            errorMessage = ethosMessage(error)
        }
    }

    private func archive() {
        do {
            try write()
            service.archive(habitID: draft.id)
            dismiss()
        } catch {
            errorMessage = ethosMessage(error)
        }
    }

    private func write() throws {
        let habit = try draft.makeHabit()
        let reminder = try draft.makeReminder()
        service.save(habit: habit, reminder: reminder, on: .now, calendar: service.calendar)
    }
}

/// One row of day chips in place of seven toggles.
private struct WeekdayChips: View {
    @Binding var selection: Set<Weekday>

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Weekday.allCases, id: \.self) { day in
                let isOn = selection.contains(day)
                Button {
                    if isOn {
                        selection.remove(day)
                    } else {
                        selection.insert(day)
                    }
                } label: {
                    Text(String(day.shortName.prefix(1)))
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .foregroundStyle(isOn ? Color.white : Color.primary)
                        .background(isOn ? EthosColor.accent : EthosColor.track, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(day.name)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
    }
}

private enum DayPattern: String, CaseIterable, Identifiable {
    case everyDay
    case specificWeekdays
    case everyFewDays
    case monthDates
    case monthWeekday

    var id: String { rawValue }

    func label(for interval: GoalInterval) -> String {
        switch self {
        case .everyDay:
            interval == .day ? "Every day" : "Any day"
        case .specificWeekdays:
            "Specific weekdays"
        case .everyFewDays:
            "Every few days"
        case .monthDates:
            "Dates in the month"
        case .monthWeekday:
            "A weekday each month"
        }
    }

    static func standard(for interval: GoalInterval) -> [DayPattern] {
        switch interval {
        case .day:
            [.everyDay, .specificWeekdays, .everyFewDays]
        case .week:
            [.everyDay, .specificWeekdays]
        case .month:
            [.everyDay, .monthDates, .monthWeekday]
        case .year:
            [.everyDay]
        }
    }
}

private func frequencyLabel(_ interval: GoalInterval) -> String {
    switch interval {
    case .day: "Daily"
    case .week: "Weekly"
    case .month: "Monthly"
    case .year: "Yearly"
    }
}

private enum TimeChoice: String, CaseIterable, Identifiable {
    case anytime
    case morning
    case afternoon
    case evening

    var id: String { rawValue }

    var label: String {
        switch self {
        case .anytime: "Anytime"
        case .morning: "Morning"
        case .afternoon: "Afternoon"
        case .evening: "Evening"
        }
    }

    var timeOfDay: TimeOfDay {
        switch self {
        case .anytime: .none
        case .morning: .morning
        case .afternoon: .afternoon
        case .evening: .evening
        }
    }
}

private struct HabitDraft {
    var id = UUID()
    var createdAt = Date.now
    var lifecycle = HabitLifecycle.active
    var isEditing = false
    var title = ""
    var direction = HabitDirection.build
    var measurement = GoalMeasurement.count
    var target = "1"
    var interval = GoalInterval.day
    var unitName = ""
    var allowsOverCompletion = true
    var dayPattern = DayPattern.everyDay
    var weekdays = Set(Weekday.allCases)
    var monthDays = "1"
    var ordinal = MonthWeekdayOrdinal.first
    var monthlyWeekday = Weekday.monday
    var everyX = 2
    var timeChoice = TimeChoice.anytime
    var preservedCustomTime: TimeOfDay?
    var categoryID: UUID?
    var identity = ""
    var notes = ""
    var checklist: [ChecklistItem] = []
    var startDate = Date.now
    var hasEndDate = false
    var endDate = Date.now.addingTimeInterval(60 * 60 * 24 * 30)
    var accountabilityEnabled = false
    var tone = AccountabilityTone.direct
    var consequence = AccountabilityConsequence.reflect
    var requiresConfirmation = false
    var recoveryAction = ""
    var reminderEnabled = false
    var reminderID = UUID()
    var reminderDate = HabitDraft.date(from: nil)

    init(habit: Habit?, reminder: Reminder?) {
        if let habit {
            id = habit.id
            createdAt = habit.createdAt
            lifecycle = habit.lifecycle
            isEditing = true
            title = habit.title
            direction = habit.direction
            measurement = habit.goal.measurement
            target = amountText(habit.goal.target)
            interval = habit.goal.interval
            unitName = {
                if case let .custom(name) = habit.goal.unit { return name }
                return ""
            }()
            allowsOverCompletion = habit.goal.allowsOverCompletion
            switch habit.schedule {
            case .daily:
                dayPattern = .everyDay
            case let .weekly(days):
                dayPattern = .specificWeekdays
                weekdays = days.isEmpty ? Set(Weekday.allCases) : days
            case let .monthlyDates(days):
                dayPattern = .monthDates
                monthDays = days.sorted().map(String.init).joined(separator: ", ")
            case let .monthlyWeekday(ordinal, weekday):
                dayPattern = .monthWeekday
                self.ordinal = ordinal
                monthlyWeekday = weekday
            case let .everyXDays(interval):
                dayPattern = .everyFewDays
                everyX = interval
            }
            switch habit.timeOfDay {
            case .morning: timeChoice = .morning
            case .afternoon: timeChoice = .afternoon
            case .evening: timeChoice = .evening
            case .none:
                timeChoice = .anytime
            case .custom:
                timeChoice = .anytime
                preservedCustomTime = habit.timeOfDay
            }
            categoryID = habit.categoryID
            identity = habit.identityStatement ?? ""
            notes = habit.notes ?? ""
            checklist = habit.checklist
            startDate = habit.startDate
            hasEndDate = habit.endDate != nil
            endDate = habit.endDate ?? habit.startDate.addingTimeInterval(60 * 60 * 24 * 30)
            if let rule = habit.accountability {
                accountabilityEnabled = rule.isEnabled
                tone = rule.tone
                consequence = rule.consequence
                requiresConfirmation = rule.requiresConfirmation
                recoveryAction = rule.recoveryAction ?? ""
            }
        } else {
            id = UUID()
            createdAt = .now
            isEditing = false
            title = ""
            startDate = .now
            endDate = .now.addingTimeInterval(60 * 60 * 24 * 30)
        }

        reminderID = reminder?.id ?? reminderID
        reminderEnabled = reminder?.isEnabled ?? false
        reminderDate = Self.date(from: reminder?.time)
    }

    var usesMoreOptions: Bool {
        categoryID != nil
            || checklist.contains(where: \.isActive)
            || !identity.isEmpty
            || !notes.isEmpty
            || hasEndDate
            || accountabilityEnabled
    }

    var dayPatternChoices: [DayPattern] {
        var choices = DayPattern.standard(for: interval)
        if !choices.contains(dayPattern) {
            choices.append(dayPattern)
        }
        return choices
    }

    mutating func deactivate(_ itemID: UUID) {
        guard let index = checklist.firstIndex(where: { $0.id == itemID }) else { return }
        checklist[index].isActive = false
    }

    func schedulePreview() -> String? {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        var preview = self
        if trimmedTitle.isEmpty {
            preview.title = "Habit"
        }
        guard let habit = try? preview.makeHabit() else { return nil }
        return scheduleSentence(for: habit, includeTitle: !trimmedTitle.isEmpty)
    }

    func makeHabit() throws -> Habit {
        let amount = try parsedTarget()
        let unit: GoalUnit? = measurement == .quantity ? .custom(unitName) : nil
        let goal = try Goal(
            measurement: measurement,
            target: amount,
            interval: interval,
            unit: unit,
            allowsOverCompletion: allowsOverCompletion
        )
        return try Habit(
            id: id,
            title: title,
            createdAt: createdAt,
            goal: goal,
            schedule: try makeSchedule(),
            lifecycle: lifecycle,
            direction: direction,
            timeOfDay: resolvedTime,
            identityStatement: identity,
            notes: notes,
            startDate: startDate,
            endDate: hasEndDate ? endDate : nil,
            categoryID: categoryID,
            checklist: checklist,
            accountability: makeAccountability()
        )
    }

    func makeReminder() throws -> Reminder? {
        guard reminderEnabled else { return nil }
        let parts = Calendar.current.dateComponents([.hour, .minute], from: reminderDate)
        let time = try ClockTime(hour: parts.hour ?? 8, minute: parts.minute ?? 0)
        let days: Set<Weekday> = dayPattern == .specificWeekdays ? weekdays : []
        return Reminder(id: reminderID, habitID: id, time: time, weekdays: days, isEnabled: true)
    }

    private var resolvedTime: TimeOfDay {
        if timeChoice == .anytime, let preservedCustomTime {
            return preservedCustomTime
        }
        return timeChoice.timeOfDay
    }

    private func parsedTarget() throws -> Decimal {
        if direction == .build, measurement == .boolean {
            return 1
        }
        guard let amount = Decimal(string: target, locale: .current) else {
            throw GoalError.negativeTarget
        }
        return amount
    }

    private func makeSchedule() throws -> HabitSchedule {
        switch dayPattern {
        case .everyDay:
            return .daily
        case .specificWeekdays:
            guard !weekdays.isEmpty else { throw HabitError.invalidSchedule }
            return .weekly(eligibleWeekdays: weekdays)
        case .monthDates:
            let days = Set(monthDays.split(separator: ",").compactMap {
                Int($0.trimmingCharacters(in: .whitespaces))
            })
            return .monthlyDates(days)
        case .monthWeekday:
            return .monthlyWeekday(ordinal: ordinal, weekday: monthlyWeekday)
        case .everyFewDays:
            return .everyXDays(everyX)
        }
    }

    private func makeAccountability() -> AccountabilityRule? {
        guard accountabilityEnabled else { return nil }
        let action = recoveryAction.trimmingCharacters(in: .whitespacesAndNewlines)
        return AccountabilityRule(
            tone: tone,
            consequence: consequence,
            requiresConfirmation: requiresConfirmation,
            isEnabled: true,
            recoveryAction: action.isEmpty ? nil : action
        )
    }

    private static func date(from time: ClockTime?) -> Date {
        var parts = Calendar.current.dateComponents([.year, .month, .day], from: .now)
        parts.hour = time?.hour ?? 8
        parts.minute = time?.minute ?? 0
        return Calendar.current.date(from: parts) ?? .now
    }
}

/// `scheduleText` says "Every day" for a daily schedule. Weekly, monthly, and yearly
/// goals use that same schedule to mean any day in the window.
private func scheduleSentence(for habit: Habit, includeTitle: Bool) -> String {
    let phrase = cadencePhrase(for: habit)
    if habit.direction == .quit, habit.goal.target == .zero {
        if includeTitle {
            return "\(habit.title), avoid entirely, \(phrase)."
        }
        return "Avoid entirely, \(phrase)."
    }

    let body = "\(goalText(habit)), \(phrase)."
    guard includeTitle else { return body }
    let lowered = body.prefix(1).lowercased() + body.dropFirst()
    return "\(habit.title) \(lowered)"
}

private func cadencePhrase(for habit: Habit) -> String {
    if case .daily = habit.schedule, habit.goal.interval != .day {
        return "any day"
    }

    let text = scheduleText(habit.schedule)
    let lowered = text.prefix(1).lowercased() + text.dropFirst()
    switch habit.schedule {
    case let .weekly(days) where !days.isEmpty && days.count != 7:
        return text.contains(",") ? "on \(text)" : "on \(lowered)"
    case .monthlyWeekday:
        return "on \(lowered)"
    default:
        return lowered
    }
}

extension HabitLifecycle {
    var label: String {
        switch self {
        case .active: "Active"
        case .paused: "Paused"
        case .archived: "Archived"
        }
    }
}
