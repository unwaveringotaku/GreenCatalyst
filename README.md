# 🌿 GreenCatalyst

**Behavior-change sustainability app for iOS & watchOS**

GreenCatalyst helps people understand, track, and reduce their personal carbon footprint through intelligent nudges, HealthKit integration, habit streaks, and real-time CO₂ feedback — all powered by on-device intelligence.

---

## What It Does

- **Carbon Dashboard** — Daily CO₂ breakdown across energy, transport, food, and shopping
- **Smart Nudges** — Personalized, time-sensitive actions with CO₂ and cost savings
- **Habit Streaks** — Build sustainable routines with streak tracking and reminders
- **HealthKit Integration** — Automatically infers transport mode (walking, cycling, driving) from step/workout data
- **Location Awareness** — Detects commute trips and geofences to suggest contextual actions
- **Siri Shortcuts** — "Hey Siri, log my bike commute" or "What's my carbon score?"
- **watchOS Companion** — Ring view + daily nudge on your wrist
- **WidgetKit Widgets** — Glanceable CO₂ ring on your Home Screen

---

## Tech Stack

| Layer | Technology |
|---|---|
| UI | SwiftUI |
| State Management | `@Observable` macro (Swift 5.9+) |
| Persistence | SwiftData + UserDefaults |
| Health Data | HealthKit |
| Location | CoreLocation |
| Notifications | UserNotifications |
| Siri | AppIntents framework |
| Widgets | WidgetKit |
| Watch | watchOS 10 + WatchConnectivity |
| Build System | Swift Package Manager |
| Minimum OS | iOS 17 / watchOS 10 |

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        GreenCatalyst iOS                        │
│                                                                 │
│  ┌──────────┐   ┌──────────────┐   ┌───────────────────────┐  │
│  │  Views   │──▶│  ViewModels  │──▶│       Services        │  │
│  │          │   │ (@Observable)│   │                       │  │
│  │HomeView  │   │HomeViewModel │   │ CarbonCalculator      │  │
│  │ImpactView│   │ImpactVM      │   │ HealthKitManager      │  │
│  │HabitsView│   │HabitsVM      │   │ LocationManager       │  │
│  └──────────┘   └──────────────┘   │ NotificationManager   │  │
│                                    │ DataStore (SwiftData)  │  │
│  ┌──────────┐                      └───────────────────────┘  │
│  │ AppIntents│                                                  │
│  │ LogActivity│──────────────────────────────────────────────▶ │
│  │ GetScore   │         Siri / Shortcuts                        │
│  └──────────┘                                                  │
└──────────────────────────┬──────────────────────────────────────┘
                           │ WatchConnectivity
           ┌───────────────▼──────────────┐
           │     GreenCatalyst watchOS     │
           │                              │
           │  WatchHomeView (Ring + Nudge) │
           │  WatchComplicationView        │
           └──────────────────────────────┘

           ┌──────────────────────────────┐
           │   GreenCatalystWidgets        │
           │   Small: Ring + CO₂ number   │
           │   Medium: Ring + Top Nudge   │
           └──────────────────────────────┘
```

---

## Setup Instructions

### Prerequisites

- Xcode 15.2+
- iOS 17+ device or simulator
- watchOS 10+ (for Watch companion)

### Clone & Open

```bash
git clone https://github.com/YOUR_USERNAME/GreenCatalyst.git
cd GreenCatalyst
open Package.swift
```

Xcode will resolve the Swift package automatically. Select the `GreenCatalystApp` scheme and run on your target device.

### Required Permissions

Add the following keys to your `Info.plist`:

```xml
<!-- HealthKit -->
<key>NSHealthShareUsageDescription</key>
<string>GreenCatalyst reads your activity data to automatically track transport emissions.</string>
<key>NSHealthUpdateUsageDescription</key>
<string>GreenCatalyst logs carbon-saving workouts to your Health app.</string>

<!-- Location -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>GreenCatalyst detects your commute to estimate transport emissions.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>GreenCatalyst uses background location to automatically log trips.</string>

<!-- Notifications -->
<!-- Requested at runtime via UNUserNotificationCenter -->
```

### HealthKit Capability

In Xcode, under your target's **Signing & Capabilities**, add:
- HealthKit
- Background Modes → Background fetch, Remote notifications

### Widget Extension Setup

Add a new **Widget Extension** target in Xcode named `GreenCatalystWidgets`. The source is already in `Sources/GreenCatalystWidgets/`.

---

## Project Structure

```
GreenCatalyst/
├── Package.swift                   # SPM manifest
├── .gitignore
├── README.md
├── Sources/
│   ├── GreenCatalystApp/           # iOS App
│   │   ├── GreenCatalystApp.swift  # App entry point
│   │   ├── ContentView.swift       # Root tab view
│   │   ├── Models/                 # Pure data models (Codable, Identifiable)
│   │   ├── ViewModels/             # @Observable business logic
│   │   ├── Views/                  # SwiftUI screens + components
│   │   ├── Services/               # HealthKit, Location, Notifications, Data
│   │   └── Intents/                # AppIntents for Siri Shortcuts
│   ├── GreenCatalystWatch/         # watchOS companion
│   └── GreenCatalystWidgets/       # WidgetKit extension
└── prototype/                      # HTML prototype (for design reference)
```

---

## Roadmap

### v1.0 (MVP)
- [x] Carbon dashboard with manual logging
- [x] Habit tracker with streaks
- [x] Nudge engine with cost + CO₂ savings
- [x] HealthKit transport inference
- [x] watchOS companion ring view
- [x] Siri Shortcuts (LogActivity, GetCarbonScore)
- [x] Home Screen widgets (small + medium)

### v1.1
- [ ] Social challenges — compete with friends on carbon reduction
- [ ] Carbon marketplace — offset credits integration
- [ ] AI-powered meal scanner (photo → CO₂ estimate)
- [ ] Business travel expense sync

### v1.2
- [ ] Team/company dashboards for B2B
- [ ] Carbon budget API for developers
- [ ] Apple Watch Ultra always-on complication
- [ ] CarPlay integration for real-time trip scoring

### v2.0
- [ ] Machine learning model for personalized nudge timing
- [ ] AR footprint visualizer ("this steak = this much CO₂")
- [ ] Verified carbon credits marketplace
- [ ] ESG reporting export for enterprise

---

## Contributing

1. Fork the repo
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Commit: `git commit -m 'Add my feature'`
4. Push: `git push origin feature/my-feature`
5. Open a Pull Request

Please follow Swift API Design Guidelines and add unit tests for any new service logic.

---

## License

MIT License — see [LICENSE](LICENSE) for details.

---

## Contact

Built with ☀️ by the GreenCatalyst team. Questions? Open an issue or reach out at hello@greencatalyst.app
