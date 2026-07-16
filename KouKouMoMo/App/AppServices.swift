import StoreKit
import SwiftUI
import UIKit

@MainActor
final class UsageStatsManager: ObservableObject {
    static let shared = UsageStatsManager()

    @Published private(set) var totalUsageSeconds: TimeInterval

    private var timer: Timer?
    private var lastTick = Date()
    private let key = "totalUsageSeconds"

    private init() {
        totalUsageSeconds = UserDefaults.standard.double(forKey: key)
    }

    func start() {
        guard timer == nil else { return }
        lastTick = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.flush() }
        }
    }

    func flush() {
        let now = Date()
        let delta = max(0, now.timeIntervalSince(lastTick))
        guard delta > 0 else { return }
        totalUsageSeconds += delta
        lastTick = now
        UserDefaults.standard.set(totalUsageSeconds, forKey: key)
    }

    func formattedUsageText() -> String {
        let seconds = max(0, Int(ceil(totalUsageSeconds)))
        if seconds < 3600 {
            let minutes = max(1, Int(ceil(Double(seconds) / 60.0)))
            return String.localizedStringWithFormat(String(localized: "usage.minutes"), "\(minutes)")
        }
        let hours = seconds / 3600
        let remaining = seconds % 3600
        let minutes = Int(ceil(Double(remaining) / 60.0))
        return String.localizedStringWithFormat(String(localized: "usage.hours_minutes"), "\(hours)", "\(minutes)")
    }
}

@MainActor
enum ReviewManager {
    private static let playedModesKey = "playedGameModes"
    private static let threeGamesKey = "reviewPrompt.threeGames"
    private static let sixtyMinutesKey = "reviewPrompt.sixtyMinutes"
    private static let oneEightyMinutesKey = "reviewPrompt.oneEightyMinutes"

    static func recordPlayedMode(_ mode: PlayMode) {
        var modes = Set(UserDefaults.standard.stringArray(forKey: playedModesKey) ?? [])
        modes.insert(mode.rawValue)
        UserDefaults.standard.set(Array(modes), forKey: playedModesKey)
    }

    static func checkOnHomeAppear() {
        UsageStatsManager.shared.flush()
        let defaults = UserDefaults.standard
        let modes = Set(defaults.stringArray(forKey: playedModesKey) ?? [])
        if modes.count >= 3, !defaults.bool(forKey: threeGamesKey) {
            defaults.set(true, forKey: threeGamesKey)
            requestReview()
            return
        }
        let total = defaults.double(forKey: "totalUsageSeconds")
        if total >= 3600, !defaults.bool(forKey: sixtyMinutesKey) {
            defaults.set(true, forKey: sixtyMinutesKey)
            requestReview()
            return
        }
        if total >= 10800, !defaults.bool(forKey: oneEightyMinutesKey) {
            defaults.set(true, forKey: oneEightyMinutesKey)
            requestReview()
        }
    }

    static func openWriteReview() {
        guard let url = URL(string: "https://apps.apple.com/app/idYOUR_APP_ID?action=write-review") else { return }
        UIApplication.shared.open(url)
    }

    private static func requestReview() {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else { return }
        SKStoreReviewController.requestReview(in: scene)
    }
}
