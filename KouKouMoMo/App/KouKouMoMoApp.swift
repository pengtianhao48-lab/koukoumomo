import AVFoundation
import SwiftUI

@main
struct KouKouMoMoApp: App {
    init() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers, .allowBluetooth])
        try? session.setActive(true)
        AudioManager.shared.preload()
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .preferredColorScheme(.light)
                .tint(DoodleStyle.ink)
        }
    }
}
