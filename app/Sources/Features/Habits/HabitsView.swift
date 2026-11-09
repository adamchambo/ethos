import SwiftUI

struct HabitsView: View {
    let service: HabitProgressService
    @State private var filter = HabitLifecycle.active
    @State private var query = ""
    @State private var showingAdd = false
    @State private var editing: Habit?

    var body: some View {
        let habits = filtered

        NavigationStack {
            Group {
                if habits.isEmpty {
                    ContentUnavailableView {
                        Label(emptyTitle, systemImage: "list.bullet")
                    } description: {
                        Text(emptyMessage)
                    } actions: {
                        if filter == .active, query.isEmpty {
                            Button("Add habit") { showingAdd = true }
                        }
                    }
                } else {
                    List(habits) { habit in
                        Button {
                            editing = habit
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Circle()
                                        .fill(categoryColor(habit.categoryID, categories: service.categories))
                                        .frame(width: 8, height: 8)
                                    Text(habit.title)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                }
                                Text("\(scheduleText(habit.schedule)) · \(goalText(habit.goal))")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                if let category = service.categories.first(where: { $0.id == habit.categoryID }) {
                                    Text(category.name)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Habits")
            .ethosScreen()
            .searchable(text: $query, prompt: "Search habits")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add", systemImage: "plus") { showingAdd = true }
                }
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink("Categories") {
                        CategoriesView(service: service)
                    }
                }
            }
            .safeAreaInset(edge: .top) {
                Picker("Show", selection: $filter) {
                    Text("Active").tag(HabitLifecycle.active)
                    Text("Paused").tag(HabitLifecycle.paused)
                    Text("Archived").tag(HabitLifecycle.archived)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.bar)
            }
            .sheet(isPresented: $showingAdd) {
                HabitEditor(service: service, habit: nil)
            }
            .sheet(item: $editing) { habit in
                HabitEditor(service: service, habit: habit)
            }
        }
    }

    private var filtered: [Habit] {
        service.habits
            .filter { $0.lifecycle == filter }
            .filter { query.isEmpty || $0.title.localizedStandardContains(query) }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    private var emptyTitle: String {
        if !query.isEmpty { return "No matches" }
        switch filter {
        case .active: return "No active habits"
        case .paused: return "No paused habits"
        case .archived: return "No archived habits"
        }
    }

    private var emptyMessage: String {
        if !query.isEmpty { return "Try a different name." }
        switch filter {
        case .active: return "Create the habits you want to track."
        case .paused: return "Paused habits stay off Today until you resume them."
        case .archived: return "Archived habits stay here."
        }
    }
}

private struct CategoriesView: View {
    let service: HabitProgressService
    @State private var adding = false
    @State private var name = ""
    @State private var errorMessage: String?

    var body: some View {
        List {
            if service.categories.isEmpty {
                Text("Categories group habits on Today and in Insights.")
                    .foregroundStyle(.secondary)
            }
            ForEach(service.categories) { category in
                CategoryRow(category: category, service: service, onError: { errorMessage = $0 })
            }
        }
        .navigationTitle("Categories")
        .toolbar {
            Button("Add", systemImage: "plus") { adding = true }
        }
        .alert("New category", isPresented: $adding) {
            TextField("Name", text: $name)
            Button("Add") { add() }
            Button("Cancel", role: .cancel) { name = "" }
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

    private func add() {
        do {
            _ = try service.addCategory(name: name)
            name = ""
        } catch {
            errorMessage = ethosMessage(error)
        }
    }
}

private struct CategoryRow: View {
    let category: Category
    let service: HabitProgressService
    let onError: (String) -> Void
    @State private var name: String

    init(category: Category, service: HabitProgressService, onError: @escaping (String) -> Void) {
        self.category = category
        self.service = service
        self.onError = onError
        _name = State(initialValue: category.name)
    }

    var body: some View {
        HStack {
            Circle()
                .fill(Color(hex: category.colour))
                .frame(width: 12, height: 12)
            TextField("Name", text: $name)
                .onSubmit { rename() }
        }
    }

    private func rename() {
        do {
            try service.renameCategory(id: category.id, to: name)
        } catch {
            name = category.name
            onError(ethosMessage(error))
        }
    }
}
