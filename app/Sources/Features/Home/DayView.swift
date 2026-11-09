import SwiftUI

struct DayView: View {
    let service: HabitProgressService
    @AppStorage("ethosHaptics") private var haptics = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedDate: Date
    @State private var showingAdd = false
    @State private var showingCalendar = false
    @State private var editing: Habit?
    @State private var detailID: UUID?
    @State private var reflectionRequest: ReflectionRequest?
    @State private var errorMessage: String?
    @State private var expandedID: UUID?
    @State private var finishedExpanded = false
    @State private var query = ""

    init(service: HabitProgressService) {
        self.service = service
        _selectedDate = State(initialValue: service.calendar.startOfDay(for: .now))
    }

    var body: some View {
        NavigationStack {
            dayList
                .ethosScreen()
                .navigationTitle(dateTitle)
                .modifier(DaySubtitle(word: relativeWord))
                .toolbarTitleDisplayMode(.large)
                .toolbarVisibility(.visible, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .largeTitle) {
                        // A full weekday and month is wider than the large title on an iPhone 17.
                        Text(dateTitle)
                            .font(.largeTitle.bold())
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                            .allowsTightening(true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if let relativeWord {
                        ToolbarItem(placement: .largeSubtitle) {
                            Text(relativeWord)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(EthosColor.secondaryInk)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    if !isToday {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Today") { select(today) }
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button("Calendar", systemImage: "calendar") { showingCalendar = true }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button("Add habit", systemImage: "plus") { showingAdd = true }
                    }
                }
                .modifier(DaySearch(isShown: showsSearch, query: $query))
                .navigationDestination(item: $detailID) { id in
                    HabitDetailView(service: service, habitID: id)
                }
                .sheet(isPresented: $showingAdd) {
                    HabitEditor(service: service, habit: nil)
                }
                .sheet(item: $editing) { habit in
                    HabitEditor(service: service, habit: habit)
                }
                .sheet(item: $reflectionRequest) { request in
                    ReflectionSheet(
                        service: service,
                        period: request.period,
                        existing: request.existing
                    )
                }
                .sheet(isPresented: $showingCalendar) {
                    DayCalendarSheet(calendar: calendar, date: calendarSelection)
                }
                .sensoryFeedback(trigger: successPulse) { old, new in
                    haptics && old.day == new.day && new.count > old.count ? .success : nil
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

    private var dayList: some View {
        List {
            Section {
                WeekStrip(
                    calendar: calendar,
                    selectedDate: selectedDate,
                    onSelect: select,
                    onShift: shiftWeek
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))

                if showsSummary {
                    DaySummary(
                        isToday: isToday,
                        isFuture: isFutureDay,
                        hasHabits: !service.habits.isEmpty,
                        scheduledCount: scheduled.count,
                        done: doneCount,
                        total: countedBuild.count,
                        avoiding: countedQuit.count,
                        slipped: slippedCount,
                        fills: capsuleFills,
                        onAdd: { showingAdd = true }
                    )
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 8, trailing: 20))
                    .listRowSeparator(.hidden)
                }

                if noMatches {
                    Text("No matches.")
                        .foregroundStyle(EthosColor.secondaryInk)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }

            ForEach(dayGroups(openHabits)) { group in
                Section(group.title) {
                    ForEach(group.habits) { habit in
                        habitRow(habit)
                    }
                }
                .ethosRows()
            }

            if !finishedHabits.isEmpty {
                if isSearching {
                    Section("Finished") {
                        ForEach(finishedHabits) { habit in
                            habitRow(habit)
                        }
                    }
                    .ethosRows()
                } else {
                    Section {
                        finishedToggle
                        if finishedExpanded {
                            ForEach(finishedHabits) { habit in
                                habitRow(habit)
                            }
                        }
                    }
                    .ethosRows()
                }
            }

            if !service.habits.isEmpty, !isFutureDay {
                Section("Journal") {
                    JournalBox(service: service, date: selectedDate)
                        .id(selectedDate)
                }
                .ethosRows()
            }
        }
    }

    private var finishedToggle: some View {
        Button {
            ethosAnimate(reduceMotion) { finishedExpanded.toggle() }
        } label: {
            HStack {
                Text("\(finishedHabits.count) finished")
                    .font(.headline)
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: finishedExpanded ? "chevron.up" : "chevron.down")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(EthosColor.secondaryInk)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityValue(finishedExpanded ? "Expanded" : "Collapsed")
        .accessibilityHint(finishedExpanded ? "Hides finished habits" : "Shows finished habits")
    }

    private func habitRow(_ habit: Habit) -> some View {
        HabitDayRow(
            habit: habit,
            service: service,
            date: selectedDate,
            isExpanded: expandedID == habit.id,
            haptics: haptics,
            reduceMotion: reduceMotion,
            onToggle: { toggleExpanded(habit.id) },
            onDetails: { detailID = habit.id },
            onEdit: { editing = habit },
            onReflection: { period, existing in
                reflectionRequest = ReflectionRequest(period: period, existing: existing)
            },
            onFailed: {
                expandedID = habit.id
                finishedExpanded = true
            },
            onError: { errorMessage = $0 }
        )
    }

    private var calendar: Calendar { service.calendar }

    private var today: Date { calendar.startOfDay(for: .now) }

    private var isToday: Bool { calendar.isDateInToday(selectedDate) }

    private var isFutureDay: Bool { service.isFuture(selectedDate, calendar: calendar) }

    private var relativeWord: String? {
        if calendar.isDateInToday(selectedDate) { return "Today" }
        if calendar.isDateInYesterday(selectedDate) { return "Yesterday" }
        if calendar.isDateInTomorrow(selectedDate) { return "Tomorrow" }
        return nil
    }

    private var dateTitle: String {
        ethosDateText(
            selectedDate,
            calendar: calendar,
            style: Date.FormatStyle().weekday(.wide).day().month(.wide)
        )
    }

    private var scheduled: [Habit] {
        service.habits
            .filter { service.isScheduled($0, on: selectedDate, calendar: calendar) }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    private var showsSearch: Bool { scheduled.count > 8 }

    private var isSearching: Bool { showsSearch && !query.isEmpty }

    private var visibleHabits: [Habit] {
        guard isSearching else { return scheduled }
        return scheduled.filter { $0.title.localizedStandardContains(query) }
    }

    private var openHabits: [Habit] {
        visibleHabits.filter { !dayReading($0, on: selectedDate, service: service).isFinished }
    }

    private var finishedHabits: [Habit] {
        visibleHabits.filter { dayReading($0, on: selectedDate, service: service).isFinished }
    }

    private var noMatches: Bool { isSearching && visibleHabits.isEmpty }

    private var countedBuild: [Habit] {
        scheduled.filter { habit in
            guard habit.direction == .build else { return false }
            return dayReading(habit, on: selectedDate, service: service).outcome != .skipped
        }
    }

    private var countedQuit: [Habit] {
        scheduled.filter { habit in
            guard habit.direction == .quit else { return false }
            return dayReading(habit, on: selectedDate, service: service).outcome != .skipped
        }
    }

    private var doneCount: Int {
        countedBuild.filter { dayReading($0, on: selectedDate, service: service).outcome == .succeeded }.count
    }

    private var slippedCount: Int {
        countedQuit.filter { dayReading($0, on: selectedDate, service: service).outcome == .failed }.count
    }

    private var showsSummary: Bool {
        if service.habits.isEmpty || scheduled.isEmpty || isFutureDay { return true }
        return !countedBuild.isEmpty || !countedQuit.isEmpty
    }

    private var capsuleFills: [Color] {
        countedBuild.map { habit in
            let reading = dayReading(habit, on: selectedDate, service: service)
            guard let outcome = reading.outcome else { return EthosColor.track }
            return outcome.fillColor(hasProgress: hasProgress(habit))
        }
    }

    private var successPulse: SuccessPulse {
        SuccessPulse(day: selectedDate, count: doneCount)
    }

    private var calendarSelection: Binding<Date> {
        Binding(get: { selectedDate }, set: select)
    }

    private func hasProgress(_ habit: Habit) -> Bool {
        service.progress(habitID: habit.id, on: selectedDate, calendar: calendar) > .zero
            || service.checklistCount(habitID: habit.id, on: selectedDate, calendar: calendar).done > 0
    }

    private func select(_ date: Date) {
        let day = calendar.startOfDay(for: date)
        guard !calendar.isDate(day, inSameDayAs: selectedDate) else { return }
        service.prepare(now: .now)
        ethosAnimate(reduceMotion) {
            selectedDate = day
            expandedID = nil
            finishedExpanded = false
            query = ""
        }
    }

    private func shiftWeek(by weeks: Int) {
        guard let next = calendar.date(byAdding: .day, value: weeks * 7, to: selectedDate) else { return }
        select(next)
    }

    private func toggleExpanded(_ id: UUID) {
        ethosAnimate(reduceMotion) {
            expandedID = expandedID == id ? nil : id
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

/// Closed windows come from the stored period. Resolving a live one would invent a period
/// for a day that was never recorded.
private struct DayHabitReading {
    var outcome: HabitPeriodOutcome?
    var period: HabitPeriod?
    var notRecorded = false
    var isFuture = false
    var allowsLogging = false

    var isFinished: Bool {
        guard let outcome else { return false }
        return outcome != .inProgress
    }
}

private func dayReading(_ habit: Habit, on date: Date, service: HabitProgressService) -> DayHabitReading {
    let calendar = service.calendar
    if service.isFuture(date, calendar: calendar) {
        return DayHabitReading(isFuture: true)
    }
    if service.isWindowClosed(habitID: habit.id, on: date, calendar: calendar) {
        guard let period = service.recordedPeriod(habitID: habit.id, on: date) else {
            return DayHabitReading(notRecorded: true)
        }
        return DayHabitReading(outcome: period.outcome, period: period)
    }
    let period = service.openPeriod(habitID: habit.id, on: date, calendar: calendar)
    return DayHabitReading(
        outcome: period?.outcome ?? .inProgress,
        period: period,
        allowsLogging: true
    )
}

private func ethosDateText(_ date: Date, calendar: Calendar, style: Date.FormatStyle) -> String {
    var style = style
    style.calendar = calendar
    style.timeZone = calendar.timeZone
    style.locale = calendar.locale ?? .autoupdatingCurrent
    return date.formatted(style)
}

private struct WeekStrip: View {
    let calendar: Calendar
    let selectedDate: Date
    let onSelect: (Date) -> Void
    let onShift: (Int) -> Void

    var body: some View {
        HStack(spacing: 2) {
            Button("Previous week", systemImage: "chevron.left") { onShift(-1) }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .foregroundStyle(EthosColor.secondaryInk)
                .frame(width: 32, height: 44)

            HStack(spacing: 2) {
                ForEach(days, id: \.self) { day in
                    dayCell(day)
                }
            }

            Button("Next week", systemImage: "chevron.right") { onShift(1) }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .foregroundStyle(EthosColor.secondaryInk)
                .frame(width: 32, height: 44)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    let dx = value.translation.width
                    guard abs(dx) > 48, abs(dx) > abs(value.translation.height) * 1.2 else { return }
                    onShift(dx < 0 ? 1 : -1)
                }
        )
    }

    private var days: [Date] {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: selectedDate) else { return [] }
        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: week.start).map { calendar.startOfDay(for: $0) }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(day)
        let title = ethosDateText(
            day,
            calendar: calendar,
            style: Date.FormatStyle().weekday(.wide).day().month(.wide)
        )

        return Button {
            onSelect(day)
        } label: {
            VStack(spacing: 2) {
                Text(ethosDateText(day, calendar: calendar, style: Date.FormatStyle().weekday(.abbreviated)))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(isSelected ? EthosColor.canvas : EthosColor.secondaryInk)
                Text(ethosDateText(day, calendar: calendar, style: Date.FormatStyle().day()))
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(numberColor(isSelected: isSelected, isToday: isToday))
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .background {
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? EthosColor.accent : Color.clear)
            }
            .overlay {
                if isToday {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(isSelected ? EthosColor.canvas : EthosColor.accent, lineWidth: 1.5)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isToday ? "\(title), today" : title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func numberColor(isSelected: Bool, isToday: Bool) -> Color {
        if isSelected { return EthosColor.canvas }
        if isToday { return EthosColor.accent }
        return .primary
    }
}

/// Build habits count toward the total. Quit habits are separate, because one succeeds
/// only when its window closes. A future day is a plan.
private struct DaySummary: View {
    let isToday: Bool
    let isFuture: Bool
    let hasHabits: Bool
    let scheduledCount: Int
    let done: Int
    let total: Int
    let avoiding: Int
    let slipped: Int
    let fills: [Color]
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !hasHabits {
                Text("Add a habit to start the day's record.")
                    .font(.title3)
                Button("Add habit", action: onAdd)
                    .buttonStyle(.borderedProminent)
            } else if scheduledCount == 0 {
                Text(isToday ? "Nothing scheduled today." : "Nothing scheduled.")
                    .font(.title3)
            } else if isFuture {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(scheduledCount)")
                        .font(.system(size: 40, weight: .semibold))
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(scheduledCount)))
                    Text("scheduled")
                        .font(.title3)
                        .foregroundStyle(EthosColor.secondaryInk)
                }
                .accessibilityElement(children: .combine)
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
        if slipped > 0 { return "\(habits), \(slipped) slipped" }
        return isToday ? "\(habits), no slips so far" : "\(habits), no slips"
    }
}

private struct HabitDayRow: View {
    let habit: Habit
    let service: HabitProgressService
    let date: Date
    let isExpanded: Bool
    let haptics: Bool
    let reduceMotion: Bool
    let onToggle: () -> Void
    let onDetails: () -> Void
    let onEdit: () -> Void
    let onReflection: (HabitPeriod, Reflection?) -> Void
    let onFailed: () -> Void
    let onError: (String) -> Void

    @State private var showingAmount = false
    @State private var customAmount = "1"
    @State private var confirmingSlip = false
    @State private var confirmingMiss = false

    var body: some View {
        let reading = self.reading
        let current = service.progress(habitID: habit.id, on: date, calendar: service.calendar)
        let counts = service.checklistCount(habitID: habit.id, on: date, calendar: service.calendar)
        let hasProgress = current > .zero || counts.done > 0
        let items = habit.checklist.filter(\.isActive).sorted { $0.sortOrder < $1.sortOrder }
        let remaining = items.filter {
            !service.isItemDone(habitID: habit.id, itemID: $0.id, on: date, calendar: service.calendar)
        }
        let showsAction = reading.allowsLogging && reading.outcome == .inProgress
        let showsBar = habit.direction == .build && reading.outcome != nil
        let showsFollowUp = reading.outcome == .failed && reading.period != nil && hasMissFollowUp(habit)
        let showsDetails = showsBar || showsAction || showsFollowUp

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                if showsDetails {
                    Button(action: onToggle) {
                        label(reading: reading, current: current, counts: counts, hasProgress: hasProgress)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityHint(isExpanded ? "Hides details" : "Shows details")
                } else {
                    label(reading: reading, current: current, counts: counts, hasProgress: hasProgress)
                }
                actions(
                    reading: reading,
                    current: current,
                    hasChecklist: !items.isEmpty,
                    canChange: showsAction
                )
            }

            if isExpanded, showsDetails {
                VStack(alignment: .leading, spacing: 10) {
                    if showsBar, let outcome = reading.outcome {
                        ProgressBar(
                            fraction: min(doubleValue(service.fraction(habitID: habit.id, on: date, calendar: service.calendar)), 1),
                            color: outcome.fillColor(hasProgress: hasProgress)
                        )
                    }
                    if showsAction {
                        primaryAction(hasChecklist: !items.isEmpty)
                    }
                    if showsAction {
                        ForEach(remaining) { item in
                            Button {
                                perform {
                                    try service.completeChecklistItem(
                                        habitID: habit.id,
                                        itemID: item.id,
                                        on: date,
                                        calendar: service.calendar
                                    )
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
                    }
                    if showsFollowUp, let period = reading.period {
                        MissFollowUp(
                            habit: habit,
                            reflection: reflection(for: period),
                            onReflect: { onReflection(period, nil) },
                            onEdit: { onReflection(period, reflection(for: period)) }
                        )
                    }
                }
                .padding(.leading, 18)
            }
        }
        .padding(.vertical, 4)
        .sensoryFeedback(trigger: StepPulse(day: date, amount: current)) { old, new in
            haptics && old.day == new.day && new.amount > old.amount && reading.outcome == .inProgress ? .increase : nil
        }
        .alert("Log an amount", isPresented: $showingAmount) {
            TextField("Amount", text: $customAmount)
                .keyboardType(.decimalPad)
            Button("Log") { logCustomAmount() }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Record a slip?", isPresented: $confirmingSlip, titleVisibility: .visible) {
            Button("I slipped", role: .destructive) { slip() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(habit.title)
        }
        .confirmationDialog("Mark this as missed?", isPresented: $confirmingMiss, titleVisibility: .visible) {
            Button("Mark missed", role: .destructive) { miss() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(habit.title)
        }
    }

    private var reading: DayHabitReading {
        dayReading(habit, on: date, service: service)
    }

    private func label(
        reading: DayHabitReading,
        current: Decimal,
        counts: (done: Int, total: Int),
        hasProgress: Bool
    ) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(categoryColor(habit.categoryID, categories: service.categories))
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)
            Text(habit.title)
                .font(.headline)
                .lineLimit(1)
                .foregroundStyle(reading.isFinished || reading.notRecorded ? EthosColor.secondaryInk : .primary)
            Spacer(minLength: 8)
            Text(statusText(reading: reading, current: current, counts: counts))
                .font(.subheadline.weight(.medium))
                .monospacedDigit()
                .lineLimit(1)
                .layoutPriority(1)
                .foregroundStyle(statusColor(reading: reading, hasProgress: hasProgress))
                .contentTransition(.numericText())
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func primaryAction(hasChecklist: Bool) -> some View {
        if habit.direction == .quit {
            Button("I slipped") { requestSlip() }
                .buttonStyle(.bordered)
        } else if hasChecklist || habit.goal.measurement == .boolean {
            Button("Done") {
                perform { try service.quickComplete(habitID: habit.id, on: date, calendar: service.calendar) }
            }
            .buttonStyle(.borderedProminent)
        } else {
            Button(stepTitle) {
                perform { try service.log(habitID: habit.id, amount: stepAmount, on: date, calendar: service.calendar) }
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel("Log \(stepTitle)")
        }
    }

    private func actions(
        reading: DayHabitReading,
        current: Decimal,
        hasChecklist: Bool,
        canChange: Bool
    ) -> some View {
        let canUndo = reading.allowsLogging && reading.outcome == .succeeded
        let canLogAmount = canChange && habit.direction == .build && habit.goal.measurement != .boolean && !hasChecklist
        return Menu {
            Button("Details", systemImage: "info.circle", action: onDetails)
            Button("Edit", systemImage: "pencil", action: onEdit)
            if canChange {
                Divider()
                if canLogAmount {
                    if current < habit.goal.target {
                        Button("Log the rest", systemImage: "checkmark") {
                            perform { try service.quickComplete(habitID: habit.id, on: date, calendar: service.calendar) }
                        }
                    }
                    Button("Log an amount", systemImage: "number") { showingAmount = true }
                }
                Button("Skip", systemImage: "arrow.uturn.forward") {
                    perform { try service.skip(habitID: habit.id, on: date, calendar: service.calendar) }
                }
                if habit.direction == .build {
                    Button("Mark missed", systemImage: "xmark", role: .destructive) { requestMiss() }
                }
            } else if canUndo {
                Divider()
                Button("Undo", systemImage: "arrow.uturn.backward") {
                    perform { try service.undo(habitID: habit.id, on: date, calendar: service.calendar) }
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

    private var confirmsMiss: Bool {
        guard let rule = habit.accountability, rule.isEnabled else { return false }
        return rule.requiresConfirmation
    }

    private func statusText(
        reading: DayHabitReading,
        current: Decimal,
        counts: (done: Int, total: Int)
    ) -> String {
        if reading.isFuture { return goalText(habit) }
        if reading.notRecorded { return "Not recorded" }
        switch reading.outcome {
        case .skipped: return "Skipped"
        case .failed: return habit.direction == .quit ? "Slipped" : "Missed"
        case .succeeded: return "Done"
        case .inProgress, nil: break
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

    private func statusColor(reading: DayHabitReading, hasProgress: Bool) -> Color {
        if reading.isFuture || reading.notRecorded { return EthosColor.secondaryInk }
        guard let outcome = reading.outcome else { return EthosColor.secondaryInk }
        return outcome.statusColor(hasProgress: hasProgress)
    }

    private func reflection(for period: HabitPeriod) -> Reflection? {
        service.reflections.first { $0.periodID == period.id }
    }

    private func requestSlip() {
        if confirmsMiss { confirmingSlip = true } else { slip() }
    }

    private func requestMiss() {
        if confirmsMiss { confirmingMiss = true } else { miss() }
    }

    private func slip() {
        perform { try service.log(habitID: habit.id, amount: 1, on: date, calendar: service.calendar) }
    }

    private func miss() {
        perform { try service.fail(habitID: habit.id, on: date, calendar: service.calendar) }
    }

    private func logCustomAmount() {
        guard let amount = Decimal(string: customAmount, locale: .current), amount > .zero else {
            onError("Enter an amount above zero.")
            return
        }
        perform { try service.log(habitID: habit.id, amount: amount, on: date, calendar: service.calendar) }
    }

    private func perform(_ action: () throws -> HabitPeriod?) {
        do {
            try ethosAnimate(reduceMotion) {
                let period = try action()
                if period?.outcome == .failed {
                    onFailed()
                }
            }
        } catch {
            onError(ethosMessage(error))
        }
    }
}

private struct MissFollowUp: View {
    let habit: Habit
    let reflection: Reflection?
    let onReflect: () -> Void
    let onEdit: () -> Void

    var body: some View {
        if let rule = habit.accountability, rule.isEnabled {
            enabled(rule)
        } else if let reflection {
            saved(reflection)
        } else {
            Button("Reflect on this miss", action: onReflect)
                .buttonStyle(.borderless)
                .font(.subheadline)
        }
    }

    @ViewBuilder
    private func enabled(_ rule: AccountabilityRule) -> some View {
        switch rule.consequence {
        case .none:
            EmptyView()
        case .reflect:
            prompt(tonePrompt(rule.tone))
        case .recoveryAction:
            prompt(recoveryLine(rule))
        case .directFeedback:
            prompt(tonePrompt(rule.tone))
        }
    }

    @ViewBuilder
    private func prompt(_ text: String) -> some View {
        if let reflection {
            saved(reflection)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(EthosColor.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Reflect", action: onReflect)
                    .buttonStyle(.bordered)
            }
        }
    }

    private func saved(_ reflection: Reflection) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(reflection.response)
                .font(.subheadline)
                .foregroundStyle(EthosColor.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
            Button("Edit", action: onEdit)
                .buttonStyle(.borderless)
                .font(.subheadline.weight(.medium))
        }
    }
}

private func hasMissFollowUp(_ habit: Habit) -> Bool {
    guard let rule = habit.accountability, rule.isEnabled else { return true }
    return rule.consequence != .none
}

private func tonePrompt(_ tone: AccountabilityTone) -> String {
    switch tone {
    case .calm:
        "Missed this one. What would make next time easier?"
    case .direct:
        "You missed this. What got in the way?"
    case .firm:
        "You committed to this and didn't follow through. What specifically stopped you?"
    }
}

private func recoveryLine(_ rule: AccountabilityRule) -> String {
    let action = rule.recoveryAction?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if action.isEmpty { return "Pick one small action to make up for it." }
    return "Recovery: \(action)"
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
    let date: Date
    @State private var text: String
    @State private var saved: String
    @State private var errorMessage: String?

    init(service: HabitProgressService, date: Date) {
        self.service = service
        self.date = date
        let existing = service.journalText(on: date, calendar: service.calendar)
        _text = State(initialValue: existing)
        _saved = State(initialValue: existing)
    }

    var body: some View {
        let prompt = service.calendar.isDateInToday(date) ? "How did today go?" : "How did this day go?"

        VStack(alignment: .leading, spacing: 8) {
            TextField(prompt, text: $text, axis: .vertical)
                .lineLimit(3...6)
            Button(saveTitle) { save() }
                .buttonStyle(.borderless)
                .font(.subheadline.weight(.medium))
                .disabled(text == saved)
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

    private var saveTitle: String {
        let isBlank = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if text == saved { return isBlank ? "Save note" : "Saved" }
        return isBlank ? "Remove note" : "Save note"
    }

    private func save() {
        do {
            try service.saveJournal(text: text, on: date, calendar: service.calendar)
            saved = text
        } catch {
            errorMessage = ethosMessage(error)
        }
    }
}

private struct ReflectionRequest: Identifiable {
    let period: HabitPeriod
    let existing: Reflection?
    var id: UUID { period.id }
}

private struct ReflectionSheet: View {
    let service: HabitProgressService
    let period: HabitPeriod
    let existing: Reflection?
    @Environment(\.dismiss) private var dismiss
    @State private var response: String
    @State private var errorMessage: String?

    init(service: HabitProgressService, period: HabitPeriod, existing: Reflection?) {
        self.service = service
        self.period = period
        self.existing = existing
        _response = State(initialValue: existing?.response ?? "")
    }

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
            .navigationTitle(existing == nil ? "After a miss" : "Edit reflection")
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
            if let existing {
                try service.updateReflection(id: existing.id, response: response)
            } else {
                try service.addReflection(periodID: period.id, response: response, on: .now)
            }
            dismiss()
        } catch {
            errorMessage = ethosMessage(error)
        }
    }
}

private struct DayCalendarSheet: View {
    let calendar: Calendar
    @Binding var date: Date
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            DatePicker("Date", selection: $date, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()
                .padding(.horizontal, 12)
                .navigationTitle("Choose a day")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
        .environment(\.calendar, calendar)
        .environment(\.locale, calendar.locale ?? .autoupdatingCurrent)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

private struct DaySubtitle: ViewModifier {
    let word: String?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let word {
            content.navigationSubtitle(word)
        } else {
            content
        }
    }
}

private struct DaySearch: ViewModifier {
    let isShown: Bool
    @Binding var query: String

    @ViewBuilder
    func body(content: Content) -> some View {
        if isShown {
            content.searchable(text: $query, prompt: "Search habits")
        } else {
            content
        }
    }
}

private struct SuccessPulse: Equatable {
    let day: Date
    let count: Int
}

private struct StepPulse: Equatable {
    let day: Date
    let amount: Decimal
}

private struct DayGroup: Identifiable {
    let title: String
    let habits: [Habit]
    var id: String { title }
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
    DayView(service: HabitProgressService(habits: demoHabits, now: now))
}
