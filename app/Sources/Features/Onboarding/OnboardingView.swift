import SwiftUI

struct OnboardingView: View {
    let service: HabitProgressService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step = Step.welcome
    @State private var movingForward = true
    @State private var name = ""
    @State private var habitName = ""
    @State private var target = "1"
    @State private var errorMessage: String?

    private enum Step: Int, CaseIterable {
        case welcome
        case name
        case habit

        var previous: Self {
            Self(rawValue: rawValue - 1) ?? .welcome
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                if step != .welcome {
                    Button("Back", systemImage: "chevron.backward") { go(to: step.previous) }
                        .labelStyle(.iconOnly)
                        .font(.title3.weight(.medium))
                        .frame(width: 44, height: 44, alignment: .leading)
                }
                Spacer()
                HStack(spacing: 6) {
                    ForEach(Step.allCases, id: \.self) { dot in
                        Capsule()
                            .fill(dot.rawValue <= step.rawValue ? EthosColor.accent : EthosColor.track)
                            .frame(width: dot == step ? 20 : 8, height: 8)
                    }
                }
                .accessibilityElement()
                .accessibilityLabel("Step \(step.rawValue + 1) of \(Step.allCases.count)")
            }
            .frame(height: 44)

            Group {
                switch step {
                case .welcome: welcome
                case .name: nameStep
                case .habit: habitStep
                }
            }
            .id(step)
            .transition(transition)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(EthosColor.canvas)
        .alert("Unable to continue", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 16) {
            Spacer()
            Text("Ethos")
                .font(.system(size: 52, weight: .bold))
            Text("Focus, follow-through, and an honest record of what you actually did.")
                .font(.title3)
                .foregroundStyle(EthosColor.secondaryInk)
            Spacer()
            primary("Get started") { go(to: .name) }
            secondary("Explore first") { service.finishOnboarding() }
        }
    }

    private var nameStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What should Ethos call you?")
                .font(.largeTitle.bold())
                .padding(.top, 32)
            field("Name", text: $name)
                .textContentType(.name)
                .submitLabel(.continue)
                .onSubmit { saveName() }
            Spacer()
            primary("Continue") { saveName() }
        }
    }

    private var habitStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What do you want to work on first?")
                .font(.largeTitle.bold())
                .padding(.top, 32)
            Text("A daily count is enough to start. Goal, schedule, and the rest can be edited after.")
                .foregroundStyle(EthosColor.secondaryInk)
            field("Habit", text: $habitName)
            field("Times a day", text: $target)
                .keyboardType(.numberPad)
            Spacer()
            primary("Create habit") { createHabit() }
            secondary("Skip for now") { service.finishOnboarding() }
        }
    }

    private var transition: AnyTransition {
        if reduceMotion { return .opacity }
        return .asymmetric(
            insertion: .move(edge: movingForward ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: movingForward ? .leading : .trailing).combined(with: .opacity)
        )
    }

    private func field(_ title: String, text: Binding<String>) -> some View {
        TextField(title, text: text)
            .font(.title3)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(EthosColor.surface, in: RoundedRectangle(cornerRadius: 12))
    }

    private func primary(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }

    private func secondary(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
    }

    private func go(to next: Step) {
        movingForward = next.rawValue > step.rawValue
        ethosAnimate(reduceMotion) { step = next }
    }

    private func saveName() {
        var profile = service.profile
        profile.displayName = name
        service.updateProfile(profile)
        go(to: .habit)
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