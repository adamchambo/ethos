import SwiftUI

private enum HabitEditSection: String, CaseIterable, Identifiable {
    case settings = "Settings"
    case recurrence = "Recurrence"

    var id: String { rawValue }
}

struct HabitEditView: View {
    @Bindable var store: HabitStore
    let habitID: UUID
    @Environment(\.dismiss) private var dismiss

    @State private var section: HabitEditSection = .settings
    @State private var title: String = ""
    @State private var dayPart: DayPart = .anytime
    @State private var unitLabel: String = ""
    @State private var allowBeyond = false
    @State private var kind: HabitInteractionKind = .standard
    @State private var scheduleMode: ScheduleMode = .daily
    @State private var selectedWeekdays: Set<Weekday> = []
    @State private var everyDays: Int = 3
    @State private var targetText: String = "1"
    @State private var interval: GoalInterval = .day

    private enum ScheduleMode: String, CaseIterable, Identifiable {
        case daily = "Every day"
        case weekdays = "Weekdays"
        case fixed = "Selected days"
        case every = "Every N days"
        case flexibleWeekly = "Flexible weekly"

        var id: String { rawValue }
    }

    private var definition: HabitDefinition? {
        store.definition(for: habitID)
    }

    var body: some View {
        NavigationStack {
            Group {
                if definition != nil {
                    VStack(spacing: 0) {
                        Picker("Edit", selection: $section) {
                            ForEach(HabitEditSection.allCases) { section in
                                Text(section.rawValue).tag(section)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding()

                        Form {
                            switch section {
                            case .settings:
                                settingsForm
                            case .recurrence:
                                recurrenceForm
                            }
                        }
                    }
                } else {
                    ContentUnavailableView("Habit unavailable", systemImage: "questionmark.circle")
                }
            }
            .navigationTitle("Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save(); dismiss() }
                }
            }
            .onAppear(perform: load)
        }
    }

    @ViewBuilder
    private var settingsForm: some View {
        Section("Habit") {
            TextField("Name", text: $title)
            Picker("Time of day", selection: $dayPart) {
                ForEach(DayPart.allCases, id: \.self) { part in
                    Text(part.rawValue.capitalized).tag(part)
                }
            }
            Picker("Type", selection: $kind) {
                Text("Standard").tag(HabitInteractionKind.standard)
                Text("Quit").tag(HabitInteractionKind.quit)
                Text("Checklist").tag(HabitInteractionKind.checklist)
            }
            TextField("Unit label", text: $unitLabel)
                .textInputAutocapitalization(.never)
            Toggle("Allow logging beyond target", isOn: $allowBeyond)
        }

        Section("Goal") {
            TextField("Target", text: $targetText)
                .keyboardType(.decimalPad)
            Picker("Counting period", selection: $interval) {
                Text("Day").tag(GoalInterval.day)
                Text("Week").tag(GoalInterval.week)
                Text("Month").tag(GoalInterval.month)
                Text("Year").tag(GoalInterval.year)
            }
        }
    }

    @ViewBuilder
    private var recurrenceForm: some View {
        Section {
            Picker("Repeats", selection: $scheduleMode) {
                ForEach(ScheduleMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }

            if scheduleMode == .fixed {
                ForEach(Weekday.allCases, id: \.self) { day in
                    Toggle(day.shortName, isOn: Binding(
                        get: { selectedWeekdays.contains(day) },
                        set: { isOn in
                            if isOn { selectedWeekdays.insert(day) }
                            else { selectedWeekdays.remove(day) }
                        }
                    ))
                }
            }

            if scheduleMode == .every {
                Stepper("Every \(everyDays) days", value: $everyDays, in: 1...30)
            }
        } header: {
            Text("Schedule")
        } footer: {
            Text("Schedule controls which days appear on Day view. The goal’s counting period is separate.")
        }
    }

    private func load() {
        guard let definition else { return }
        title = definition.habit.title
        dayPart = definition.habit.dayPart
        unitLabel = definition.quickLog.unitLabel
        allowBeyond = definition.quickLog.allowLoggingBeyondTarget
        kind = definition.quickLog.kind
        targetText = formatGoalAmount(definition.goal.target)
        interval = definition.goal.interval

        switch definition.schedule {
        case .daily:
            scheduleMode = definition.goal.interval == .week ? .flexibleWeekly : .daily
        case let .weekly(days):
            if days.isEmpty {
                scheduleMode = .flexibleWeekly
            } else if days == [.monday, .tuesday, .wednesday, .thursday, .friday] {
                scheduleMode = .weekdays
            } else {
                scheduleMode = .fixed
                selectedWeekdays = days
            }
        case let .every(days, _):
            scheduleMode = .every
            everyDays = days
        }
    }

    private func save() {
        guard var definition else { return }
        let target = Decimal(string: targetText.replacingOccurrences(of: ",", with: ".")) ?? definition.goal.target

        do {
            let habit = try Habit(
                id: definition.habit.id,
                title: title,
                createdAt: definition.habit.createdAt,
                lifecycle: definition.habit.lifecycle,
                dayPart: dayPart
            )
            let goal = try Goal(
                habitID: habit.id,
                measurement: definition.goal.measurement,
                target: max(target, 1),
                interval: interval,
                countingMode: definition.goal.countingMode
            )
            let schedule: HabitSchedule
            switch scheduleMode {
            case .daily:
                schedule = .daily
            case .weekdays:
                schedule = .weekly(eligibleWeekdays: [
                    .monday, .tuesday, .wednesday, .thursday, .friday
                ])
            case .fixed:
                schedule = .weekly(eligibleWeekdays: selectedWeekdays)
            case .every:
                schedule = .every(days: everyDays, anchorStart: habit.createdAt)
            case .flexibleWeekly:
                schedule = .weekly(eligibleWeekdays: [])
            }

            var quickLog = definition.quickLog
            quickLog.unitLabel = unitLabel.trimmingCharacters(in: .whitespacesAndNewlines)
            quickLog.allowLoggingBeyondTarget = allowBeyond
            quickLog.kind = kind
            if kind != .checklist {
                quickLog.checklistItems = []
            }

            definition.habit = habit
            definition.goal = goal
            definition.schedule = schedule
            definition.quickLog = quickLog
            store.updateDefinition(definition)
        } catch {
            store.lastErrorMessage = "Couldn’t save habit edits."
        }
    }
}
