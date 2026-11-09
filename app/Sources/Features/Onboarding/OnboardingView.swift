import SwiftUI

struct OnboardingView: View {
    let service: HabitProgressService
    @Environment(\.colorScheme) private var colorScheme
    @State private var step = Step.welcome
    @State private var name = ""
    @State private var habitName = ""
    @State private var target = "1"
    @State private var errorMessage: String?

    private enum Step {
        case welcome
        case name
        case habit
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer()
            switch step {
            case .welcome:
                Text("Ethos")
                    .font(.largeTitle.bold())
                Text("Focus, follow-through, and an honest record of what you actually did.")
                    .font(.title3)
                Spacer()
                Button("Get started") { step = .name }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                Button("Explore first") { service.finishOnboarding() }
            case .name:
                Text("What should Ethos call you?")
                    .font(.largeTitle.bold())
                TextField("Name", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.name)
                Spacer()
                Button("Continue") { saveName() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            case .habit:
                Text("What do you want to work on first?")
                    .font(.largeTitle.bold())
                Text("A daily count is enough to start. Goal, schedule, and the rest can be edited after.")
                    .foregroundStyle(.secondary)
                TextField("Habit", text: $habitName)
                    .textFieldStyle(.roundedBorder)
                TextField("Target", text: $target)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.decimalPad)
                Spacer()
                Button("Create habit") { createHabit() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                Button("Skip for now") { service.finishOnboarding() }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(EthosColor.canvas(colorScheme))
        .foregroundStyle(EthosColor.ink(colorScheme))
        .alert("Unable to continue", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func saveName() {
        var profile = service.profile
        profile.displayName = name
        service.updateProfile(profile)
        step = .habit
    }

    private func createHabit() {
        guard let amount = Decimal(string: target, locale: .current), amount > .zero else {
            errorMessage = "Enter a positive target."
            return
        }

        do {
            try service.add(
                title: habitName,
                measurement: .count,
                target: amount,
                on: .now,
                calendar: service.calendar
            )
            service.finishOnboarding()
        } catch {
            errorMessage = ethosMessage(error)
        }
    }
}
