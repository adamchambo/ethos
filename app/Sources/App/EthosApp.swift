import SwiftUI

@main struct EthosApp: App {
    @State private var progressService = HabitProgressService.restored()
    @AppStorage("ethosAppearance") private var appearance = "system"

    var body: some Scene {
        WindowGroup {
            AppTabs(service: progressService)
                .preferredColorScheme(preferredScheme)
        }
    }

    private var preferredScheme: ColorScheme? {
        switch appearance {
        case "light": .light
        case "dark": .dark
        default: nil
        }
    }
}
