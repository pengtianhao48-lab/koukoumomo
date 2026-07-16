import AVFoundation
import SwiftUI

@main
struct KouKouMoMoApp: App {
    init() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .preferredColorScheme(.light)
                .tint(DoodleStyle.ink)
        }
    }
}
