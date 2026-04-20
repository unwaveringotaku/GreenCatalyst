# GreenCatalyst

GreenCatalyst is a SwiftUI sustainability app for iOS, watchOS, and WidgetKit. It helps users log carbon-impacting actions, complete low-carbon nudges, build sustainable habits, and track progress through a daily CO2 ring, impact summaries, and lightweight gamification.

## Current Product Surface

- Home
  - Daily CO2 ring and net-emissions summary
  - Quick log flow for transport and manual carbon entries
  - Actionable nudges with CO2, cost, and points impact
  - Level guide sheet from the current level indicator
  - Recent entries list
- Impact
  - Period summaries for today, week, month, and year
  - Category breakdowns and comparison metrics
  - CSV export of historical entries
- Habits
  - Default sustainable habits on first launch
  - Streak tracking, reminders, and edit flow
  - Habit completions contribute to saved CO2, saved cost, and points
  - Matching nudges can mark the corresponding habit as completed
- Onboarding and profile
  - Carousel onboarding followed by user-info capture
  - SwiftData-backed profile storage
  - iCloud key-value backup and restore path where supported
- Integrations
  - App Intents for Siri / Shortcuts
  - HealthKit sync entry point
  - watchOS companion views
  - WidgetKit extension

## Tech Stack

| Layer | Technology |
| --- | --- |
| UI | SwiftUI |
| State | Observation with `@Observable` |
| Persistence | SwiftData, `UserDefaults`, `NSUbiquitousKeyValueStore` |
| Intents | App Intents |
| Health | HealthKit |
| Location | CoreLocation |
| Notifications | UserNotifications |
| Widgets | WidgetKit |
| Watch | watchOS companion target |
| Tests | Swift Testing |

## Architecture

The app follows a straightforward SwiftUI architecture:

- Views render the UI and own local presentation state.
- ViewModels coordinate user actions, loading, and cross-feature updates.
- Services contain persistence, calculations, and OS integrations.
- SwiftData models store entries, nudges, habits, and the user profile.

Primary app areas:

- `Sources/GreenCatalystApp/Views`
- `Sources/GreenCatalystApp/ViewModels`
- `Sources/GreenCatalystApp/Services`
- `Sources/GreenCatalystApp/Models`
- `Sources/GreenCatalystApp/Intents`

## Setup

### Requirements

- Xcode 15.2 or newer
- iOS 17+ simulator or device
- watchOS 10+ for the watch target
- `xcodegen` if regenerating the project from `project.yml`

### Open the project

```bash
git clone https://github.com/YOUR_USERNAME/GreenCatalyst.git
cd GreenCatalyst
./scripts/run-ios.sh
```

The helper script:

1. verifies that full Xcode is selected
2. generates `GreenCatalyst.xcodeproj` from `project.yml` if needed
3. opens the project in Xcode

If `xcodegen` is missing:

```bash
brew install xcodegen
```

You can also regenerate manually:

```bash
xcodegen generate
open GreenCatalyst.xcodeproj
```

## Signing And Capability Notes

The repo builds without requiring every Apple capability to be enabled, but some features are limited unless the target is signed with a properly provisioned Apple Developer account.

Features that require additional capability support:

- HealthKit
- Siri / App Shortcuts related entitlements
- Sign in with Apple
- iCloud key-value backup / restore

On a Personal Team build, capability-backed features may be unavailable or intentionally degraded so the app remains buildable.

## Persistence Notes

- SwiftData is the main local persistence layer.
- The app stores its SwiftData file in Application Support.
- If the local persistent store is incompatible after schema changes, the app will attempt to recreate the local store instead of crashing on launch.
- If persistent store creation still fails after recovery, the app falls back to an in-memory store for that session.

## Project Structure

```text
GreenCatalyst/
├── Config/
├── GreenCatalyst.xcodeproj/
├── Package.swift
├── README.md
├── Sources/
│   ├── GreenCatalystApp/
│   │   ├── ContentView.swift
│   │   ├── GreenCatalystApp.swift
│   │   ├── Intents/
│   │   ├── Models/
│   │   ├── Services/
│   │   ├── ViewModels/
│   │   └── Views/
│   ├── GreenCatalystWatch/
│   └── GreenCatalystWidgets/
├── Tests/
│   └── GreenCatalystTests/
├── project.yml
└── scripts/
```

## Development Notes

- The Home quick-log sheet now follows the same visual design language as the Habits creation flow.
- Completing a habit writes a negative carbon entry and updates saved metrics and points.
- Completing a matching nudge can also complete the corresponding habit without double-counting points.
- Home and Impact refresh when habit data changes so summaries stay in sync across tabs.

## Testing

Unit coverage lives in `Tests/GreenCatalystTests/GreenCatalystTests.swift` using the Swift Testing framework.

For app-level verification:

- build the `GreenCatalystApp` scheme in Xcode
- run the app and verify onboarding, home logging, nudges, and habits flows
- run tests from Xcode if the local test host configuration is valid

## License

MIT. See [LICENSE](LICENSE).
