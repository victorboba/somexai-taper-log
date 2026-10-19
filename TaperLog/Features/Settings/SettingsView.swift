import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(EntitlementStore.self) private var store
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Query(sort: \TaperPlan.createdAt) private var plans: [TaperPlan]
    @Query(sort: \TaperStep.startDate) private var allSteps: [TaperStep]

    @AppStorage(DoseReminder.enabledKey) private var doseReminders = false
    @AppStorage(DoseReminder.checkInEnabledKey) private var checkInReminder = false
    @AppStorage(DoseReminder.checkInHourKey) private var checkInHour = 20

    @State private var editingPlan = false
    @State private var confirmingDeleteAll = false
    #if DEBUG
    @State private var sampleDataImported = false
    @AppStorage(DebugFlags.unlockKey) private var debugUnlock = false
    @AppStorage("onboarding.completed") private var onboardingCompleted = true
    #endif

    private var plan: TaperPlan? { plans.first { $0.isActive } ?? plans.first }
    private var currentSlots: [DoseSlot] {
        TaperMath.scheduledDoses(on: .now, in: TaperMath.steps(allSteps, for: plan))
    }

    private var version: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Plan") {
                    if let plan {
                        Button { editingPlan = true } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(plan.medicationName).foregroundStyle(.primary)
                                Text("\(TaperMath.steps(allSteps, for: plan).count) steps · \(plan.subtitle)").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        Text("No plan yet. Set one up on the Plan tab.").foregroundStyle(.secondary)
                    }
                }

                Section {
                    Toggle("Remind me at each dose time", isOn: $doseReminders)
                    if doseReminders, !currentSlots.isEmpty {
                        ForEach(currentSlots) { slot in
                            Picker(slot.label, selection: Binding(
                                get: { DoseReminder.hour(for: slot.label) },
                                set: { DoseReminder.setHour($0, for: slot.label); reschedule() }
                            )) {
                                ForEach(Array(0...23), id: \.self) { h in
                                    Text(Calendar.current.date(bySettingHour: h, minute: 0, second: 0, of: .now)!.formatted(date: .omitted, time: .shortened)).tag(h)
                                }
                            }
                        }
                    }
                    Toggle("Evening check-in reminder", isOn: $checkInReminder)
                    if checkInReminder {
                        Picker("Check-in time", selection: $checkInHour) {
                            ForEach([17, 18, 19, 20, 21, 22], id: \.self) { h in
                                Text(Calendar.current.date(bySettingHour: h, minute: 0, second: 0, of: .now)!.formatted(date: .omitted, time: .shortened)).tag(h)
                            }
                        }
                    }
                } header: { Text("Reminders") } footer: {
                    Text("Dose reminders follow the times in your current step. They are a nudge, not instructions.")
                }
                .onChange(of: [doseReminders ? 1 : 0, checkInReminder ? 1 : 0, checkInHour]) { reschedule() }

                Section("Help") {
                    NavigationLink { HowToView() } label: { Label("How do I use \(AppConfig.appName)?", systemImage: "questionmark.circle") }
                }

                Section("Your plan") {
                    LabeledContent("Status", value: planDescription)
                    if store.isEntitled && !store.isLifetime {
                        Button("Manage Subscription") { openURL(URL(string: "https://apps.apple.com/account/subscriptions")!) }
                    }
                    Button("Restore Purchases") { Task { await store.restore() } }
                    if let error = store.lastError { Text(error).font(.footnote).foregroundStyle(.red) }
                }

                Section("Your data") {
                    Text("Your schedule, your doses and your check-ins stay on this device\(AppConfig.iCloudSyncEnabled ? " and in your private iCloud" : ""). There is no account and no server, so none of it reaches us.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button("Delete All Data", role: .destructive) { confirmingDeleteAll = true }
                }

                Section("About") {
                    Text(AppConfig.disclaimer).font(.footnote).foregroundStyle(.secondary)
                    if !AppConfig.appStoreID.isEmpty {
                        Button("Rate \(AppConfig.appName)") { openURL(URL(string: "https://apps.apple.com/app/id\(AppConfig.appStoreID)?action=write-review")!) }
                    }
                    Button("Contact Support") {
                        let subject = "\(AppConfig.appName) \(version)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                        openURL(URL(string: "mailto:\(AppConfig.supportEmail)?subject=\(subject)")!)
                    }
                    NavigationLink("Privacy Policy") { PrivacyPolicyView() }
                    Link("Terms of Use", destination: AppConfig.termsURL)
                    LabeledContent("Version", value: version)
                }

                #if DEBUG
                Section("Debug (not in release builds)") {
                    Toggle("Unlock without purchase", isOn: $debugUnlock)
                        .onChange(of: debugUnlock) { Task { await store.refreshEntitlements() } }
                    Button("Show onboarding again") { onboardingCompleted = false; dismiss() }
                    Button(sampleDataImported ? "Imported ✓" : "Insert sample data (10 weeks)") {
                        SampleData.insert(into: context)
                        sampleDataImported = true
                        Task { try? await Task.sleep(for: .seconds(2)); sampleDataImported = false }
                    }
                    .disabled(sampleDataImported)
                }
                #endif
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
                }
            }
            .sheet(isPresented: $editingPlan) { PlanEditorView(plan: plan) }
            .confirmationDialog("Delete the plan, every dose and every check-in on this device?", isPresented: $confirmingDeleteAll, titleVisibility: .visible) {
                Button("Delete All", role: .destructive) {
                    try? context.delete(model: DoseLog.self)
                    try? context.delete(model: SymptomCheckIn.self)
                    try? context.delete(model: TaperStep.self)
                    try? context.delete(model: TaperPlan.self)
                    DoseReminder.cancelAll()
                    WidgetSync.update(plan: nil, steps: [], logs: [], checkIns: [])
                }
                Button("Cancel", role: .cancel) {}
            } message: { Text("This cannot be undone. Export the PDF first if you want a copy.") }
        }
    }

    private func reschedule() {
        let p = plan, s = allSteps
        Task { await DoseReminder.reschedule(plan: p, steps: s) }
    }

    private var planDescription: String {
        guard store.isEntitled else { return "Not active" }
        if store.isLifetime { return "Lifetime" }
        if let expiry = store.expiresAt { return "Annual, renews \(expiry.formatted(date: .abbreviated, time: .omitted))" }
        return "Active"
    }
}
