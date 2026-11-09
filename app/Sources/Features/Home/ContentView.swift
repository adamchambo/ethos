import SwiftUI
import Playgrounds

struct ContentView: View {
    let service: HabitProgressService
    @AppStorage("ethosHaptics") private var haptics = true
    @State private var showingAdd = false
    @State private var editing: Habit?
    @State private var reflecting: HabitPeriod?
    @State private var errorMessage: String?

    var body: some View {
        let calendar = service.calendar
        let now = Date.now
        let due = service.habits
            .filter { service.isScheduled($0, on: now, calendar: calendar) }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        let counted = due.filter {
            service.openPeriod(habitID: $0.id, on: now, calendar: calendar)?.outcome != .skipped
        }
        let succeeded = counted.filter {
            service.openPeriod(habitID: $0.id, on: now, calendar: calendar)?.outcome == .succeeded
        }
        let groups = dayGroups(due)
        let reminderRows = service.reminders.filter(\.isEnabled).compactMap { reminder -> (Reminder, Habit)? in
            guard let habit = service.habits.first(where: { $0.id == reminder.habitID }), habit.lifecycle == .active else {
                return nil
            }
            return (reminder, habit)
        }

        NavigationStack {
            List {
                Section {
                    if due.isEmpty {
                        Text(service.habits.isEmpty
                            ? "Add a habit to log it here."
                            : "Nothing scheduled today. Everything else is on the Habits tab.")
                            .foregroundStyle(.secondary)
                    } else if counted.isEmpty {
                        Text("Everything scheduled today is skipped.")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("\(succeeded.count) of \(counted.count) done")
                            .font(.title3.weight(.semibold))
                            .monospacedDigit()
                    }
                } header: {
                    Text(now.formatted(date: .complete, time: .omitted))
                }

                ForEach(groups) { group in
                    Section(group.title) {
                        ForEach(group.habits) { habit in
                            HabitRow(
                                habit: habit,
                                service: service,
                                haptics: haptics,
                                onEdit: { editing = habit },
                                onReflection: { reflecting = $0 },
                                onError: { errorMessage = $0 }
                            )
                        }
                    }
                }

                if !reminderRows.isEmpty {
                    Section("Reminders") {
                        ForEach(reminderRows, id: \.0.id) { reminder, habit in
                            Text("\(habit.title) · \(clockText(reminder.time))")
                        }
                    }
                }

                Section("Journal") {
                    JournalBox(service: service)
                }
            }
            .navigationTitle("Today")
            .ethosScreen()
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add", systemImage: "plus") { showingAdd = true }
                }
            }
            .sheet(isPresented: $showingAdd) {
                HabitEditor(service: service, habit: nil)
            }
            .sheet(item: $editing) { habit in
                HabitEditor(service: service, habit: habit)
            }
            .sheet(item: $reflecting) { period in
                ReflectionSheet(service: service, period: period)
            }
            .alert("Unable to update", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .onAppear { service.prepare(now: .now) }
        }
    }

    private func dayGroups(_ habits: [Habit]) -> [DayGroup] {
        let order = ["Morning", "Afternoon", "Evening", "Anytime"]
        let grouped = Dictionary(grouping: habits, by: groupTitle)
        return order.compactMap { title in
            guard let habits = grouped[title], !habits.isEmpty else { return nil }
            return DayGroup(title: title, habits: habits)
        }
    }

    private func groupTitle(_ habit: Habit) -> String {
        switch habit.timeOfDay {
        case .morning: "Morning"
        case .afternoon: "Afternoon"
        case .evening: "Evening"
        default: "Anytime"
        }
    }
}

private struct DayGroup: Identifiable {
    let title: String
    let habits: [Habit]
    var id: String { title }
}

private struct HabitRow: View {
    let habit: Habit
    let service: HabitProgressService
    let haptics: Bool
    let onEdit: () -> Void
    let onReflection: (HabitPeriod) -> Void
    let onError: (String) -> Void

    @State private var showingAmount = false
    @State private var customAmount = "1"

    var body: some View {
        let calendar = service.calendar
        let now = Date.now
        let current = service.progress(habitID: habit.id, on: now, calendar: calendar)
        let outcome = service.openPeriod(habitID: habit.id, on: now, calendar: calendar)?.outcome ?? .inProgress
        let isFinalized = outcome != .inProgress
        let counts = service.checklistCount(habitID: habit.id, on: now, calendar: calendar)
        let fraction = service.fraction(habitID: habit.id, on: now, calendar: calendar)
        let remaining = habit.goal.target - current
        let canLog = habit.direction == .build && !isFinalized && habit.goal.measurement != .boolean
        let canComplete = habit.direction == .build && !isFinalized && remaining > .zero
        let items = habit.checklist.filter(\.isActive).sorted { $0.sortOrder < $1.sortOrder }

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Circle()
                    .fill(categoryColor(habit.categoryID, categories: service.categories))
                    .frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 2) {
                    Text(habit.title)
                        .font(.headline)
                    if let category = service.categories.first(where: { $0.id == habit.categoryID }) {
                        Text(category.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text(statusText(outcome: outcome, current: current, counts: counts))
                    .font(.subheadline.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(statusColor(outcome: outcome, current: current, counts: counts))
            }

            if habit.direction == .build {
                ProgressView(value: min(doubleValue(fraction), 1))
                    .tint(statusColor(outcome: outcome, current: current, counts: counts))
            }

            if !items.isEmpty {
                ForEach(items) { item in
                    let done = service.isItemDone(habitID: habit.id, itemID: item.id, on: now, calendar: calendar)
                    Button {
                        perform {
                            let period = try service.completeChecklistItem(
                                habitID: habit.id,
                                itemID: item.id,
                                on: .now,
                                calendar: calendar
                            )
                            react(to: period)
                        }
                    } label: {
                        Label(item.title, systemImage: done ? "checkmark.circle.fill" : "circle")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.borderless)
                    .disabled(done || isFinalized)
                }
            }

            HStack {
                if habit.direction == .quit {
                    Button("I slipped") {
                        perform {
                            let period = try service.log(habitID: habit.id, amount: 1, on: .now, calendar: calendar)
                            react(to: period)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isFinalized)
                } else if canLog {
                    Button(logTitle) {
                        perform {
                            let period = try service.log(
                                habitID: habit.id,
                                amount: logAmount,
                                on: .now,
                                calendar: calendar
                            )
                            react(to: period)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    Button("Done") {
                        perform {
                            let period = try service.quickComplete(habitID: habit.id, on: .now, calendar: calendar)
                            react(to: period)
                        }
                    }
                    .buttonStyle(.borderless)
                    .disabled(!canComplete)
                } else {
                    Button("Done") {
                        perform {
                            let period = try service.quickComplete(habitID: habit.id, on: .now, calendar: calendar)
                            react(to: period)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canComplete)
                }

                Spacer()

                Menu {
                    Button("Edit") { onEdit() }
                    if !isFinalized {
                        Button("Skip") {
                            perform {
                                _ = try service.skip(habitID: habit.id, on: .now, calendar: calendar)
                            }
                        }
                        if habit.direction == .build {
                            Button("Mark missed", role: .destructive) {
                                perform {
                                    let period = try service.fail(habitID: habit.id, on: .now, calendar: calendar)
                                    react(to: period)
                                }
                            }
                        }
                        if habit.goal.measurement != .boolean {
                            Button("Log an amount") { showingAmount = true }
                        }
                    }
                    if outcome == .succeeded {
                        Button("Undo") {
                            perform {
                                _ = try service.undo(habitID: habit.id, on: .now, calendar: calendar)
                            }
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .buttonStyle(.borderless)
            }
        }
        .listRowBackground(rowBackground)
        .alert("Log amount", isPresented: $showingAmount) {
            TextField("Amount", text: $customAmount)
                .keyboardType(.decimalPad)
            Button("Log") { logCustomAmount() }
            Button("Cancel", role: .cancel) {}
        }
    }

    @Environment(\.colorScheme) private var colorScheme

    private var rowBackground: Color {
        EthosColor.surface(colorScheme)
    }

    private func statusColor(
        outcome: HabitPeriodOutcome,
        current: Decimal,
        counts: (done: Int, total: Int)
    ) -> Color {
        switch outcome {
        case .succeeded:
            EthosColor.success
        case .failed:
            EthosColor.failure
        case .skipped:
            EthosColor.secondaryInk(colorScheme)
        case .inProgress:
            current > .zero || counts.done > 0 ? EthosColor.attention : EthosColor.secondaryInk(colorScheme)
        }
    }

    private var logAmount: Decimal {
        habit.goal.measurement == .duration ? 15 : 1
    }

    private var logTitle: String {
        habit.goal.measurement == .duration ? "+15" : "+1"
    }

    private func statusText(
        outcome: HabitPeriodOutcome,
        current: Decimal,
        counts: (done: Int, total: Int)
    ) -> String {
        if outcome == .skipped { return "Skipped" }
        if outcome == .failed { return "Missed" }
        if counts.total > 0 {
            return "\(counts.done) of \(counts.total)"
        }
        if habit.direction == .quit {
            return current == .zero ? "No slips" : "\(amountText(current)) slips"
        }
        if outcome == .succeeded { return "Done" }
        return "\(amountText(current)) of \(amountText(habit.goal.target))"
    }

    private func logCustomAmount() {
        guard let amount = Decimal(string: customAmount, locale: .current), amount > .zero else {
            onError("Enter an amount above zero.")
            return
        }
        perform {
            let period = try service.log(habitID: habit.id, amount: amount, on: .now, calendar: service.calendar)
            react(to: period)
        }
    }

    private func react(to period: HabitPeriod?) {
        guard let period else { return }
        if period.outcome == .failed,
           !service.reflections.contains(where: { $0.periodID == period.id }) {
            onReflection(period)
        } else if period.outcome == .succeeded, haptics {
            ethosHaptic()
        }
    }

    private func perform(_ action: () throws -> Void) {
        do {
            try action()
        } catch {
            onError(ethosMessage(error))
        }
    }
}

private struct JournalBox: View {
    let service: HabitProgressService
    @State private var text: String
    @State private var errorMessage: String?

    init(service: HabitProgressService) {
        self.service = service
        _text = State(initialValue: service.journalText(on: .now, calendar: service.calendar))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("How did today go?", text: $text, axis: .vertical)
                .lineLimit(3...6)
            Button("Save note") {
                do {
                    try service.saveJournal(text: text, on: .now, calendar: service.calendar)
                } catch {
                    errorMessage = ethosMessage(error)
                }
            }
            .buttonStyle(.borderless)
        }
        .alert("Unable to save note", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }
}

private struct ReflectionSheet: View {
    let service: HabitProgressService
    let period: HabitPeriod
    @Environment(\.dismiss) private var dismiss
    @State private var response = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(service.habits.first { $0.id == period.habitID }?.title ?? "Habit")
                        .font(.headline)
                    Text("What happened, and what will you do next?")
                        .foregroundStyle(.secondary)
                    TextField("Reflection", text: $response, axis: .vertical)
                        .lineLimit(4...8)
                }
            }
            .navigationTitle("After a miss")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
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

    private func save() {
        do {
            try service.addReflection(periodID: period.id, response: response, on: .now)
            dismiss()
        } catch {
            errorMessage = ethosMessage(error)
        }
    }
}

#Preview {
    let now = Date.now
    let demoHabits = [
        try! Habit(
            title: "Take vitamins",
            createdAt: now,
            goal: Goal(measurement: .boolean, target: 1, interval: .day),
            schedule: .daily
        ),
        try! Habit(
            title: "Drink water",
            createdAt: now,
            goal: Goal(measurement: .count, target: 3, interval: .day),
            schedule: .daily
        )
    ]
    ContentView(service: HabitProgressService(habits: demoHabits, now: now))
}

#Playground {
    _ = 1 + 2
}
