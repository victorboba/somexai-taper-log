# Taper Log

A diary for people coming off a medicine on a prescriber-written step-down: the schedule as entered, dose ticking, a daily symptom check-in, and a PDF for the next appointment.

One of a set of niche iPhone apps built from a shared SwiftUI template ([somexai-ios-template](https://github.com/victorboba/somexai-ios-template)). It was never released on the App Store; the code is here for anyone to use. The other apps are collected in [somexai-ios-apps](https://github.com/victorboba/somexai-ios-apps).

## What it does

- **Plan**: medicine, form, unit (mg, mcg, mL, g, units), prescriber and clinic, start date, reason and notes.
- **Steps**: dose at each named time of day, start date and duration. A step runs until the next one starts; the last uses its duration. A new step copies the previous step's times and amounts so only the changed numbers need typing.
- **Today**: the current step with day-in-step progress and the next step's date, today's doses with Taken / Partial / Skipped, and the check-in prompt.
- **Symptoms**: 14 withdrawal symptoms rated none to very severe, an overall 0 to 10 rating, hours slept and notes. The chart draws a dashed line at each step change.
- **Report**: 14, 30 or 90 days or all; scheduled versus taken, partial, skipped and not recorded; a dose-over-time chart against the schedule; a symptom summary; PDF and two CSVs.
- Dose reminders at each slot time in the current step, an optional evening check-in nudge, a widget, and a How do I use this app guide.

## The boundary

The app never computes a taper. There is no dose calculator, no schedule generator and no suggestion of what to take next. The user types each step exactly as their prescriber wrote it, and the app stores, displays and totals it. The disclaimer appears on Today, in the plan editor, in Settings and at the foot of every export, and the PDF says the patient entered the schedule from the prescriber's instructions. Stopping some medicines suddenly is dangerous; talk to your prescriber before changing a plan.

## Privacy

Data stays on the device in SwiftData. There is no account, no analytics and no network access; iCloud sync is off (`iCloudSyncEnabled = false`). CSV and PDF files leave the device only when you share them.

## Build and run

Requirements: Xcode 26 or later, [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`), and iOS 17 or later.

```bash
xcodegen generate
open TaperLog.xcodeproj
```

Pick the `TaperLog` scheme and an iPhone simulator, then Run.

Tests:

```bash
xcodebuild -scheme TaperLog -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max' test
```

Paywall: the app has a hard paywall (annual subscription or lifetime purchase). Running from Xcode uses the bundled `Products.storekit` file, so purchases are simulated and free. Debug builds can also skip it with the `-unlock` launch argument or the Debug switch in Settings.

To run on your own device or ship it:

- Set your team in `project.yml` (`DEVELOPMENT_TEAM`).
- Change the `com.example` bundle ID prefix in `project.yml`, both `.entitlements` files and `Products.storekit`.
- Update `supportEmail`, `privacyPolicyURL` and `appStoreID` in `Shared/AppConfig.swift`.

## Notes for developers

- Dose times are stored as strings like `"Morning:1|Evening:0.5"` (`DoseSlot.encode`) and symptom ratings as `"sleep:2|anxiety:3"`, so the models stay CloudKit-friendly.
- `TaperMath` holds every date, adherence and symptom calculation and has no SwiftData dependency, so it is unit-tested directly.
- `DoseReminder.ensurePermission` returns false under `-uiTesting` so the system prompt never lands in a screenshot.

## Project layout

- `TaperLog/App/`: app entry point and `RootView`, the single gate (onboarding, paywall, app).
- `TaperLog/Core/`: `TaperMath`, CSV/PDF export, dose reminders, StoreKit entitlement store, App Intents, review prompt, sample data.
- `TaperLog/Features/`: Today, Plan, Symptoms, Report, Settings, Help, Onboarding, Paywall.
- `TaperLog/Models/`: `TaperPlan`, `TaperStep`, `SymptomCheckIn`.
- `TaperLogWidget/`: home screen widget reading a snapshot from the App Group.
- `TaperLogTests/`, `TaperLogUITests/`: unit tests and screenshot UI tests.
- `Shared/AppConfig.swift`: everything that changes per app (name, copy, product IDs, links, onboarding, how-to guide).
- App Shortcut: "Log a dose in Taper Log".

## License

MIT. See [LICENSE](LICENSE).
