import SwiftUI

@main
struct KouKouMoMoApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            HomeView()
                .preferredColorScheme(.light)
                .tint(DoodleStyle.ink)
                .onAppear {
                    UsageStatsManager.shared.start()
                }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                UsageStatsManager.shared.flush()
            }
        }
    }
}
