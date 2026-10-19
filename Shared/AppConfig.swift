import Foundation

/// The one file to edit when starting a new app from this template.
enum AppConfig {
    // MARK: Identity
    static let appName = "Taper Log"
    static let bundleID = "com.example.taper-log"
    static let appGroupID = "group.com.example.taper-log"
    static let appStoreID = ""

    // MARK: Sync
    static let iCloudSyncEnabled = false

    // MARK: StoreKit
    static let productPrefix = bundleID.replacingOccurrences(of: "-", with: "")
    static let annualProductID = "\(productPrefix).pro.annual"
    static let lifetimeProductID = "\(productPrefix).pro.lifetime"

    // MARK: Links
    static let supportEmail = "support@somexai.com"
    static let privacyPolicyURL = URL(string: "https://somexai.com/privacy/taper-log/")!
    static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    // MARK: Copy
    static let entryNoun = "Dose"
    static let entryNounPlural = "Doses"
    static let exportFileStem = "taper-log"

    /// Shown on the Today screen, in the plan editor and at the foot of every export.
    static let disclaimer = "Taper Log records the schedule your prescriber gave you and what you actually took. It never works out a taper, suggests a dose, or tells you to change anything. Stopping or reducing some medicines suddenly is dangerous, so talk to your prescriber before changing the plan, and seek medical help if you feel unwell."

    static let onboarding: [OnboardingPage] = [
        OnboardingPage(symbol: "list.number", title: "Type in the schedule you were given",
                       body: "One step per reduction: the dose, the times of day, and the date it starts. The app stores your prescriber's plan. It never calculates one."),
        OnboardingPage(symbol: "checkmark.circle", title: "Tick off each dose",
                       body: "Today's doses are waiting on the first screen. Mark them taken, partial or skipped in a tap, and note anything unusual."),
        OnboardingPage(symbol: "waveform.path.ecg", title: "Track how you feel",
                       body: "A daily check-in for sleep, anxiety, nausea and the rest. Over weeks it becomes a chart you can hand to your prescriber as a PDF."),
    ]

    static let paywallSymbol = "chart.line.downtrend.xyaxis"
    static let paywallHeadline = "Unlock \(appName)"
    static let paywallBenefits = [
        "Your prescriber's schedule, step by step, with dates",
        "Dose ticking with taken, partial and skipped",
        "Daily symptom check-in with charts over weeks",
        "PDF and CSV for your prescriber, all on your device",
    ]

    // MARK: How-to guide
    static let howToIntro = "Set the plan up once from your prescription, then it is a few taps a day. Here is the order to do it in."
    static let howTo: [HowToStep] = [
        HowToStep(symbol: "pills", title: "Add the medicine",
                  body: "On the Plan tab tap Set Up Plan. Enter the medicine name, the units it is measured in (mg, mcg, mL), and your prescriber's name so it prints on the report.",
                  tip: "One plan at a time. If you taper a second medicine later, finish or archive this one first."),
        HowToStep(symbol: "list.number", title: "Type each step of the schedule",
                  body: "Tap Add Step for every reduction your prescriber wrote down: the dose at each time of day, the date it starts, and how long it lasts. Repeat until the schedule is complete.",
                  tip: "Copy the numbers exactly as written. The app never works out a step for you, and never changes one on its own."),
        HowToStep(symbol: "checkmark.circle", title: "Tick off today's doses",
                  body: "The Today tab lists each dose due today. Tap Taken, or Partial if you took less, or Skipped. Tap a dose again to correct it.",
                  tip: "Say \"Log a dose in \(appName)\" to Siri to open Today from anywhere."),
        HowToStep(symbol: "waveform.path.ecg", title: "Do the daily check-in",
                  body: "On the Symptoms tab tap Check In and rate sleep, anxiety, nausea and the rest from none to severe, plus how the day went overall. One check-in a day is plenty."),
        HowToStep(symbol: "chart.xyaxis.line", title: "Watch the pattern, not one bad day",
                  body: "The Symptoms tab charts each symptom against your step changes, so you can see whether a rough patch lines up with a reduction."),
        HowToStep(symbol: "doc.text", title: "Export before your appointment",
                  body: "Report tab → choose the period → PDF. It has the schedule, how closely you followed it, the symptom chart and your notes. CSV is there too."),
        HowToStep(symbol: "bell", title: "Dose reminders",
                  body: "Settings → Dose reminders puts a notification at each time of day in your current step. For the widget, long-press the Home Screen, tap +, search \"\(appName)\"."),
    ]

    static let mockPrices = (annual: "$5.99", lifetime: "$14.99")

    // MARK: Behaviour
    static let reviewAfterSuccesses = 5
}

struct HowToStep: Identifiable, Hashable {
    var id: String { title }
    let symbol: String
    let title: String
    let body: String
    var tip: String? = nil
}

struct OnboardingPage: Identifiable, Hashable {
    var id: String { title }
    let symbol: String
    let title: String
    let body: String
}
