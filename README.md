# Ethos

Ethos is a local-first habit tracker for intentional daily practice. It is in its foundation stage: the iOS app launches in the simulator and the first pure Swift domain model is being introduced.

## Run the app

Open `app/Ethos.xcodeproj` in Xcode, choose an iPhone simulator, then press `Command-R`.

VS Code and Xcode work on the same source files. Use VS Code for editing and Xcode for project configuration, simulator selection, previews, and builds.

## Project structure

```text
app/
├── Ethos.xcodeproj/       Xcode project configuration
└── Sources/
    ├── App/               App entry point and dependency wiring
    ├── Domain/            Pure Swift habit models and rules
    ├── Features/          SwiftUI screens, organised by feature
    └── Resources/         App icons, colours, and other assets
```

Xcode automatically includes files placed inside `app/Sources/`.

## Architecture

The domain layer defines the meaning and rules of habits. It does not import SwiftUI, SwiftData, networking, or notification frameworks. Features display and collect user actions; future application services will coordinate those actions; a future data layer will persist them with SwiftData.

Day view rules live in the domain as pure functions: schedule eligibility, period progress, visibility, and row copy (`Weekdays · 30/90 min today`). The Day trailing control checks off the whole habit (`Done` / `Slip`) or expands a checklist. Checklist items stay in the list with strikethrough when done. Habit detail uses Details and Notes tabs; `…` → Edit opens Settings and Recurrence. Row body opens detail; the trailing control never navigates.

## Planning

`planning/` contains private project planning material and is intentionally excluded from version control.
