import SwiftUI

struct TodayView: View {
    let service: HabitProgressService
    @AppStorage("ethosHaptics") private var haptics = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showingAdd = false
    @State private var editing: Habit?
    @State private var detailID: UUID?
    @State private var reflecting: HabitPeriod?
    @State private var errorMessage: String?

    var body: some View {
        let calendar = service.calendar
        let now = Date.now
        let due = service.habits
            .filter { service.isScheduled($0, on: now, calendar: calendar) }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        let outcomes = Dictionary(uniqueKeysWithValues: due.map { habit in
            (habit.id, service.openPeriod(habitID: habit.id, on: now, calendar: calendar)?.outcome ?? .inProgress)
        })
        let open = due.filter { outcomes[$0.id] == .inProgress }
        let finished = due.filter { outcomes[$0.id] != .inProgress }
        let build = due.filter { $0.direction == .build && outcomes[$0.id] != .skipped }
        let quit = due.filter { $0.direction == .quit && outcomes[$0.id] != .skipped }

        NavigationStack {
            List {
                Section {
                    TodaySummary(
                        date: now,
                        hasHabits: !service.habits.isEmpty,
                        hasDue: !due.isEmpty,
                        done: build.filter { outcomes[$0.id] == .succeeded }.count,
                        total: build.count,
                        avoiding: quit.count,
                        slipped: quit.filter { outcomes[$0.id] == .failed }.count,
                        fills: build.map { habit in
                            (outcomes[habit.id] ?? .inProgress).fillColor(hasProgress: hasProgress(habit, now: now))
                        },
                        onAdd: { showingAdd = true }
                    )
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 8, trailing: 20))
                }

                ForEach(dayGroups(open)) { group in
                    Section(group.title) {
                        ForEach(group.habits) { habit in
                            row(habit)
                        }
                    }
                    .ethosRows()
                }

                if !finished.isEmpty {
                    Section("Finished") {
                        ForEach(finished) { habit in
                            row(habit)
                        }
                    }
                    .ethosRows()
                }

                if !service.habits.isEmpty {
                    Section("Journal") {
                        JournalBox(service: service)
                    }
                    .ethosRows()
                }
            }
            .ethosScreen()
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add habit", systemImage: "plus") { showingAdd = true }
                }
            }
            .navigationDestination(item: $detailID) { id in
                HabitDetailView(service: service, habitID: id)
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
            .sensoryFeedback(trigger: build.filter { outcomes[$0.id] == .succeeded }.count) { old, new in
                haptics && new > old ? .success : nil
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

    private func row(_ habit: Habit) -> some View {
        HabitRow(
            habit: habit,
            service: service,
            haptics: haptics,
            reduceMotion: reduceMotion,
            onDetails: { detailID = habit.id },
            onEdit: { editing = habit },
            onReflection: { reflecting = $0 },
            onError: { errorMessage = $0 }
        )
    }

    private func hasProgress(_ habit: Habit, now: Date) -> Bool {
        service.progress(habitID: habit.id, on: now, calendar: service.calendar) > .zero
            || service.checklistCount(habitID: habit.id, on: now, calendar: service.calendar).done > 0
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

/// The day's headline: build habits done out of those that count, and quit habits reported separately,
/// because a quit habit only succeeds when its window closes.
private struct TodaySummary: View {
    let date: Date
    let hasHabits: Bool
    let hasDue: Bool
    let done: Int
    let total: Int
    let avoiding: Int
    let slipped: Int
    let fills: [Color]
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(EthosColor.secondaryInk)

            if !hasHabits {
                Text("Add a habit to start the day's record.")
                    .font(.title3)
                Button("Add habit", action: onAdd)
                    .buttonStyle(.borderedProminent)
            } else if !hasDue {
                Text("Nothing scheduled today.")
                    .font(.title3)
            } else {
                if total > 0 {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(done) of \(total)")
                            .font(.system(size: 40, weight: .semibold))
                            .monospacedDigit()
                            .contentTransition(.numericText(value: Double(done)))
                        Text("done")
                            .font(.title3)
                            .foregroundStyle(EthosColor.secondaryInk)
                    }
                    .accessibilityElement(children: .combine)

                    HStack(spacing: 4) {
                        ForEach(fills.indices, id: \.self) { index in
                            Capsule()
                                .fill(fills[index])
                                .frame(height: 6)
                        }
                    }
                    .accessibilityHidden(true)
                }
                if avoiding > 0 {
                    Text(avoidingText)
                        .font(.subheadline)
                        .foregroundStyle(slipped > 0 ? EthosColor.failure : EthosColor.secondaryInk)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var avoidingText: String {
        let habits = avoiding == 1 ? "1 habit to avoid" : "\(avoiding) habits to avoid"
        return slipped == 0 ? "\(habits), no slips so far" : "\(habits), \(slipped) slipped"
    }
}

private struct HabitRow: View {
    let habit: Habit
    let service: HabitProgressService
    let haptics: Bool
    let reduceMotion: Bool
    let onDetails: () -> Void
    let onEdit: () -> Void
    let onReflection: (HabitPeriod) -> Void
    let onError: (String) -> Void

    @State private var showingAmount = false
    @State private var customAmount = "1"

    var body: some View {
        let calendar = service.calendar
        let now = Date.now
        let period = service.openPeriod(habitID: habit.id, on: now, calendar: calendar)
        let outcome = period?.outcome ?? .inProgress
        let isFinalized = outcome != .inProgress
        let current = service.progress(habitID: habit.id, on: now, calendar: calendar)
        let counts = service.checklistCount(habitID: habit.id, on: now, calendar: calendar)
        let hasProgress = current > .zero || counts.done > 0
        let items = habit.checklist.filter(\.isActive).sorted { $0.sortOrder < $1.sortOrder }
        let remainingItems = items.filter {
            !service.isItemDone(habitID: habit.id, itemID: $0.id, on: now, calendar: calendar)
        }
        let status = statusText(outcome: outcome, current: current, counts: counts)
        let needsReflection = outcome == .failed
            && period.map { period in !service.reflections.contains { $0.periodID == period.id } } ?? false

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Circle()
                    .fill(categoryColor(habit.categoryID, categories: service.categories))
                    .frame(width: 8, height: 8)
                    .accessibilityHidden(true)
                Text(habit.title)
                    .font(.headline)
                    .foregroundStyle(isFinalized ? EthosColor.secondaryInk : .primary)
                Spacer(minLength: 8)
                Text(status)
                    .font(.subheadline.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(outcome.statusColor(hasProgress: hasProgress))
                    .contentTransition(.numericText())
                actions(outcome: outcome, current: current, hasChecklist: !items.isEmpty)
            }

            if !isFinalized {
                if habit.direction == .build {
                    ProgressBar(
                        fraction: min(doubleValue(service.fraction(habitID: habit.id, on: now, calendar: calendar)), 1),
                        color: outcome.fillColor(hasProgress: hasProgress)
                    )
                }

                ForEach(remainingItems) { item in
                    Button {
                        perform {
                            try service.completeChecklistItem(habitID: habit.id, itemID: item.id, on: .now, calendar: calendar)
                        }
                    } label: {
                        Label {
                            Text(item.title)
                                .foregroundStyle(Color.primary)
                        } icon: {
                            Image(systemName: "circle")
                                .foregroundStyle(EthosColor.accent)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .accessibilityHint("Marks this item done")
                }

                primaryAction(hasChecklist: !items.isEmpty)
            } else if needsReflection, let period {
                Button("Reflect on this miss") { onReflection(period) }
                    .buttonStyle(.borderless)
                    .font(.subheadline)
            }
        }
        .padding(.vertical, 4)
        .sensoryFeedback(trigger: current) { old, new in
            haptics && new > old && !isFinalized ? .increase : nil
        }
        .alert("Log an amount", isPresented: $showingAmount) {
            TextField("Amount", text: $customAmount)
                .keyboardType(.decimalPad)
            Button("Log") { logCustomAmount() }
            Button("Cancel", role: .cancel) {}
        }
    }

    @ViewBuilder
    private func primaryAction(hasChecklist: Bool) -> some View {
        if habit.direction == .quit {
            Button("I slipped") {
                perform { try service.log(habitID: habit.id, amount: 1, on: .now, calendar: service.calendar) }
            }
            .buttonStyle(.bordered)
        } else if !hasChecklist {
            if habit.goal.measurement == .boolean {
                Button("Done") {
                    perform { try service.quickComplete(habitID: habit.id, on: .now, calendar: service.calendar) }
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button(stepTitle) {
                    perform { try service.log(habitID: habit.id, amount: stepAmount, on: .now, calendar: service.calendar) }
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("Log \(stepTitle)")
            }
        }
    }

    private func actions(outcome: HabitPeriodOutcome, current: Decimal, hasChecklist: Bool) -> some View {
        let isOpen = outcome == .inProgress
        let calendar = service.calendar
        return Menu {
            Button("Details", systemImage: "info.circle", action: onDetails)
            Button("Edit", systemImage: "pencil", action: onEdit)
            if isOpen {
                Divider()
                if habit.direction == .build, habit.goal.measurement != .boolean, !hasChecklist {
                    if current < habit.goal.target {
                        Button("Log the rest", systemImage: "checkmark") {
                            perform { try service.quickComplete(habitID: habit.id, on: .now, calendar: calendar) }
                        }
                    }
                    Button("Log an amount", systemImage: "number") { showingAmount = true }
                }
                Button("Skip", systemImage: "arrow.uturn.forward") {
                    perform { try service.skip(habitID: habit.id, on: .now, calendar: calendar) }
                }
                if habit.direction == .build {
                    Button("Mark missed", systemImage: "xmark", role: .destructive) {
                        perform { try service.fail(habitID: habit.id, on: .now, calendar: calendar) }
                    }
                }
            }
            if outcome == .succeeded {
                Divider()
                Button("Undo", systemImage: "arrow.uturn.backward") {
                    perform { try service.undo(habitID: habit.id, on: .now, calendar: calendar) }
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.body.weight(.semibold))
                .foregroundStyle(EthosColor.secondaryInk)
                .frame(width: 32, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("More for \(habit.title)")
    }

    private var stepAmount: Decimal {
        habit.goal.measurement == .duration ? 15 : 1
    }

    private var stepTitle: String {
        habit.goal.measurement == .duration ? "+15 min" : "+1"
    }

    private func statusText(
        outcome: HabitPeriodOutcome,
        current: Decimal,
        counts: (done: Int, total: Int)
    ) -> String {
        switch outcome {
        case .skipped: return "Skipped"
        case .failed: return habit.direction == .quit ? "Slipped" : "Missed"
        case .succeeded: return "Done"
        case .inProgress: break
        }
        if counts.total > 0 {
            return "\(counts.done) of \(counts.total)"
        }
        if habit.direction == .quit {
            return current == .zero ? "No slips" : "\(amountText(current)) slips"
        }
        if habit.goal.measurement == .boolean {
            return "Not yet"
        }
        return "\(amountText(current)) of \(amountText(habit.goal.target))"
    }

    private func logCustomAmount() {
        guard let amount = Decimal(string: customAmount, locale: .current), amount > .zero else {
            onError("Enter an amount above zero.")
            return
        }
        perform { try service.log(habitID: habit.id, amount: amount, on: .now, calendar: service.calendar) }
    }

    private func perform(_ action: () throws -> HabitPeriod?) {
        do {
            let period = try ethosAnimate(reduceMotion, action)
            guard let period, period.outcome == .failed,
                  !service.reflections.contains(where: { $0.periodID == period.id })
            else { return }
            Task {
                try? await Task.sleep(for: .milliseconds(700))
                onReflection(period)
            }
        } catch {
            onError(ethosMessage(error))
        }
    }
}

private struct ProgressBar: View {
    let fraction: Double
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(EthosColor.track)
                Capsule()
                    .fill(color)
                    .frame(width: geometry.size.width * fraction)
            }
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }
}

private struct JournalBox: View {
    let service: HabitProgressService
    @State private var text: String
    @State private var saved: String
    @State private var errorMessage: String?

    init(service: HabitProgressService) {
        self.service = service
        let existing = service.journalText(on: .now, calendar: service.calendar)
        _text = State(initialValue: existing)
        _saved = State(initialValue: existing)
    }

    var body: some View {
        let isBlank = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        VStack(alignment: .leading, spacing: 8) {
            TextField("How did today go?", text: $text, axis: .vertical)
                .lineLimit(3...6)
            Button(text == saved && !isBlank ? "Saved" : "Save note") {
                do {
                    try service.saveJournal(text: text, on: .now, calendar: service.calendar)
                    saved = text
                } catch {
                    errorMessage = ethosMessage(error)
                }
            }
            .buttonStyle(.borderless)
            .font(.subheadline.weight(.medium))
            .disabled(text == saved || isBlank)
        }
        .padding(.vertical, 4)
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
                    TextField("What happened, and what will you do next time?", text: $response, axis: .vertical)
                        .lineLimit(4...8)
                } header: {
                    Text(service.habits.first { $0.id == period.habitID }?.title ?? "Habit")
                } footer: {
                    Text("Kept with the habit and in My Ethos.")
                }
                .ethosRows()
            }
            .ethosScreen()
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
        .presentationDetents([.medium])
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
    TodayView(service: HabitProgressService(habits: demoHabits, now: now))
}
