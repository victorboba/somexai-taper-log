import SwiftUI
import SwiftData

@main
struct TaperLog: App {
    @State private var entitlements = EntitlementStore()
    private let container: ModelContainer

    init() {
        let schema = Schema([TaperPlan.self, TaperStep.self, DoseLog.self, SymptomCheckIn.self])
        let configuration = ModelConfiguration(schema: schema, cloudKitDatabase: AppConfig.iCloudSyncEnabled ? .automatic : .none)
        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create the SwiftData container: \(error)")
        }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-resetData") {
            let context = container.mainContext
            try? context.delete(model: DoseLog.self)
            try? context.delete(model: SymptomCheckIn.self)
            try? context.delete(model: TaperStep.self)
            try? context.delete(model: TaperPlan.self)
            try? context.save()
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(entitlements)
        }
        .modelContainer(container)
    }
}
