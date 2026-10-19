import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "checkmark.circle.fill") }
            PlanView()
                .tabItem { Label("Plan", systemImage: "list.number") }
            SymptomsView()
                .tabItem { Label("Symptoms", systemImage: "waveform.path.ecg") }
            ReportView()
                .tabItem { Label("Report", systemImage: "doc.text.fill") }
        }
    }
}
