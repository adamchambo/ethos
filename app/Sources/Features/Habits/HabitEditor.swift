import SwiftUI

struct HabitEditor: View {
    let service: HabitProgressService
    @Environment(\.dismiss) private var dismiss
    @State private var draft: HabitDraft
    @State private var checklistTitle = ""
    @State private var categoryName = ""
    @State private var addingCategory = false
    @State private var confirmingArchive = false
    @State private var showingMore: Bool
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
            Form {
                Group {
                    coreSections
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
                .ethosRows()
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
    private var coreSections: some View {
        Section("Habit") {
            TextField("Name", text: $draft.title)
            Picker("Direction", selection: $draft.direction) {
                Text("Build").tag(HabitDirection.build)
                Text("Quit").tag(HabitDirection.quit)
            }
        }

        Section {
            Picker("Measure", selection: $draft.measurement) {
                ForEach(GoalMeasurement.allCases, id: \.self) { measurement in
                    Text(measurement.label).tag(measurement)
                }
            }
            if draft.direction == .quit || draft.measurement != .boolean {
            LabeledContent("Target") {
                TextField("Target", text: $draft.target)
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
            Picker("Interval", selection: $draft.interval) {
                ForEach(GoalInterval.allCases, id: \.self) { interval in
                    Text(intervalText(interval).capitalized).tag(interval)
                }
            }
            Toggle("Allow going past the target", isOn: $draft.allowsOverCompletion)
        } header: {
            Text("Goal")
        } footer: {
            Text(draft.direction == .quit
                ? "A slip is logged against the target. The period succeeds when it ends without going over. Zero means avoid it entirely."
                : "The interval is the goal window. The schedule below decides which days count.")
        }

        Section("Schedule") {
            Picker("Repeats", selection: $draft.scheduleKind) {
                ForEach(ScheduleKind.allCases) { kind in
                    Text(kind.label).tag(kind)
                }
            }
            switch draft.scheduleKind {
            case .daily:
                EmptyView()
            case .weekly:
                WeekdayChips(selection: $draft.weekdays)
            case .monthlyDates:
                TextField("Days of the month", text: $draft.monthDays)
            case .monthlyWeekday:
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
            case .everyXDays:
                Stepper("Every \(draft.everyX) days", value: $draft.everyX, in: 1...60)
            }
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
                Text(draft.scheduleKind == .weekly
                    ? "The reminder fires on the days picked above."
                    : "The reminder fires every day at this time.")
            }
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
                Toggle("Ask me to confirm", isOn: $draft.requiresConfirmation)
            }
        } header: {
            Text("Accountability")
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

private enum ScheduleKind: String, CaseIterable, Identifiable {
    case daily
    case weekly
    case monthlyDates
    case monthlyWeekday
    case everyXDays

    var id: String { rawValue }

    var label: String {
        switch self {
        case .daily: "Every day"
        case .weekly: "Days of the week"
        case .monthlyDates: "Dates in the month"
        case .monthlyWeekday: "A weekday each month"
        case .everyXDays: "Every few days"
        }
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
    var scheduleKind = ScheduleKind.daily
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
                scheduleKind = .daily
            case let .weekly(days):
                scheduleKind = .weekly
                weekdays = days.isEmpty ? Set(Weekday.allCases) : days
            case let .monthlyDates(days):
                scheduleKind = .monthlyDates
                monthDays = days.sorted().map(String.init).joined(separator: ", ")
            case let .monthlyWeekday(ordinal, weekday):
                scheduleKind = .monthlyWeekday
                self.ordinal = ordinal
                monthlyWeekday = weekday
            case let .everyXDays(interval):
                scheduleKind = .everyXDays
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

    mutating func deactivate(_ itemID: UUID) {
        guard let index = checklist.firstIndex(where: { $0.id == itemID }) else { return }
        checklist[index].isActive = false
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
        let days: Set<Weekday> = scheduleKind == .weekly ? weekdays : []
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
        switch scheduleKind {
        case .daily:
            return .daily
        case .weekly:
            guard !weekdays.isEmpty else { throw HabitError.invalidSchedule }
            return .weekly(eligibleWeekdays: weekdays)
        case .monthlyDates:
            let days = Set(monthDays.split(separator: ",").compactMap {
                Int($0.trimmingCharacters(in: .whitespaces))
            })
            return .monthlyDates(days)
        case .monthlyWeekday:
            return .monthlyWeekday(ordinal: ordinal, weekday: monthlyWeekday)
        case .everyXDays:
            return .everyXDays(everyX)
        }
    }

    private func makeAccountability() -> AccountabilityRule? {
        guard accountabilityEnabled else { return nil }
        return AccountabilityRule(
            tone: tone,
            consequence: consequence,
            requiresConfirmation: requiresConfirmation,
            isEnabled: true
        )
    }

    private static func date(from time: ClockTime?) -> Date {
        var parts = Calendar.current.dateComponents([.year, .month, .day], from: .now)
        parts.hour = time?.hour ?? 8
        parts.minute = time?.minute ?? 0
        return Calendar.current.date(from: parts) ?? .now
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
