import SwiftUI

@main
struct KouKouMoMoApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
                .preferredColorScheme(.light)
                .tint(DoodleStyle.ink)
        }
    }
}
