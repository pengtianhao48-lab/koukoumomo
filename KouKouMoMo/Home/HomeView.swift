import SwiftUI

struct HomeView: View {
    @State private var isShowingSettings = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topTrailing) {
                DoodleStyle.paper.ignoresSafeArea()

                grid
                    .padding(.horizontal, 22)
                    .padding(.top, 76)
                    .padding(.bottom, 22)

                Button {
                    isShowingSettings = true
                } label: {
                    DoodleSettingsGear()
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .padding(.top, 16)
                .padding(.trailing, 18)
                .accessibilityLabel(Text("settings.title"))
            }
            .navigationBarHidden(true)
        }
        .tint(DoodleStyle.ink)
        .sheet(isPresented: $isShowingSettings) {
            DoodleSettingsSheet()
                .presentationDetents([.height(310)])
                .presentationDragIndicator(.hidden)
        }
    }

    private var grid: some View {
        let columns = [GridItem(.flexible(), spacing: 16),
                       GridItem(.flexible(), spacing: 16)]
        return LazyVGrid(columns: columns, spacing: 18) {
            ForEach(PlayMode.allCases) { mode in
                NavigationLink(destination: GameContainerView(mode: mode).navigationBarHidden(true)) {
                    DoodleCard(mode: mode)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct DoodleCard: View {
    let mode: PlayMode

    var body: some View {
        ZStack {
            Canvas { ctx, size in
                let rect = CGRect(origin: .zero, size: size).insetBy(dx: 4, dy: 4)
                ctx.fill(Rough.roundedRect(rect, corner: 24, wobble: 1.4, seed: mode.hashValue & 0xFF),
                         with: .color(DoodleStyle.paper))
                ctx.stroke(Rough.roundedRect(rect, corner: 24, wobble: 1.4, seed: mode.hashValue & 0xFF),
                           with: .color(DoodleStyle.ink), style: .doodle)
            }
            thumbnail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(14)
                .allowsHitTesting(false)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityLabel(Text(mode.titleKey))
    }

    @ViewBuilder
    private var thumbnail: some View {
        switch mode {
        case .nosePick:     NoseDoodleThumbnail()
        case .navelPoke:    NavelDoodleThumbnail()
        case .earLobe:      EarDoodleThumbnail()
        case .fingerNibble: FingerDoodleThumbnail()
        case .bubbleWrap:   BubblesDoodleThumbnail()
        case .penSpin:      PenDoodleThumbnail()
        }
    }
}

private struct DoodleSettingsGear: View {
    var body: some View {
        Canvas { ctx, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let outer = min(size.width, size.height) * 0.36
            let inner = min(size.width, size.height) * 0.21
            var path = Path()
            for i in 0..<16 {
                let angle = Double(i) * .pi / 8 - .pi / 2
                let radius = i.isMultiple(of: 2) ? outer : outer * 0.78
                let wobble = CGFloat(Rough.noise(91, i)) * 0.7
                let point = CGPoint(x: center.x + CGFloat(cos(angle)) * (radius + wobble),
                                    y: center.y + CGFloat(sin(angle)) * (radius + wobble))
                if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            path.closeSubpath()
            ctx.stroke(path, with: .color(DoodleStyle.ink), style: .doodle)
            let hole = CGRect(x: center.x - inner / 2, y: center.y - inner / 2, width: inner, height: inner)
            ctx.stroke(Rough.ellipse(in: hole, wobble: 0.7, points: 20, seed: 92),
                       with: .color(DoodleStyle.ink), style: .doodleThin)
        }
        .contentShape(Rectangle())
    }
}

private struct DoodleSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @ObservedObject private var prefs = Preferences.shared

    private var version: String {
        let raw = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        let parts = raw.split(separator: ".")
        return parts.count == 2 ? raw + ".0" : raw
    }

    var body: some View {
        ZStack {
            DoodleStyle.paper.ignoresSafeArea()

            VStack(spacing: 0) {
                DoodleSheetHandle()
                    .frame(width: 64, height: 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                DoodleSettingsRow(title: String(localized: "settings.version"), value: version)
                DoodleDivider()
                    .frame(height: 12)
                Button {
                    if let url = URL(string: "mailto:pengtianhao@bytedance.com") {
                        openURL(url)
                    }
                } label: {
                    DoodleSettingsRow(title: String(localized: "settings.contact"), value: "pengtianhao@bytedance.com")
                }
                .buttonStyle(.plain)
                DoodleDivider()
                    .frame(height: 12)
                Toggle(isOn: $prefs.isMuted) {
                    Text("settings.mute")
                        .font(DoodleStyle.mono(17, .bold))
                        .foregroundStyle(DoodleStyle.ink)
                }
                .toggleStyle(.switch)
                .tint(DoodleStyle.ink)
                .padding(.horizontal, 26)
                .padding(.vertical, 12)

                Button {
                    dismiss()
                } label: {
                    Text("action.close")
                        .font(DoodleStyle.mono(17, .bold))
                        .foregroundStyle(DoodleStyle.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background {
                            RoundedRectangle(cornerRadius: 22)
                                .fill(DoodleStyle.paperShadow.opacity(0.45))
                        }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 26)
                .padding(.top, 10)
            }
            .padding(.bottom, 18)
            .background {
                Canvas { ctx, size in
                    let rect = CGRect(origin: .zero, size: size).insetBy(dx: 4, dy: 4)
                    ctx.fill(Rough.roundedRect(rect, corner: 30, wobble: 1.5, seed: 221), with: .color(DoodleStyle.paper))
                    ctx.stroke(Rough.roundedRect(rect, corner: 30, wobble: 1.5, seed: 221), with: .color(DoodleStyle.ink), style: .doodle)
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

private struct DoodleSettingsRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(DoodleStyle.mono(17, .bold))
                .foregroundStyle(DoodleStyle.ink)
            Spacer(minLength: 16)
            Text(value)
                .font(DoodleStyle.mono(15, .semibold))
                .foregroundStyle(DoodleStyle.inkSoft)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 12)
    }
}

private struct DoodleDivider: View {
    var body: some View {
        Canvas { ctx, size in
            ctx.stroke(Rough.line(from: CGPoint(x: 28, y: size.height / 2),
                                  to: CGPoint(x: size.width - 28, y: size.height / 2),
                                  steps: 10, amp: 0.8, seed: 144),
                       with: .color(DoodleStyle.inkFaint), style: .doodleThin)
        }
    }
}

private struct DoodleSheetHandle: View {
    var body: some View {
        Canvas { ctx, size in
            ctx.stroke(Rough.line(from: CGPoint(x: 4, y: size.height / 2),
                                  to: CGPoint(x: size.width - 4, y: size.height / 2),
                                  steps: 5, amp: 0.7, seed: 133),
                       with: .color(DoodleStyle.inkFaint), style: .doodle)
        }
    }
}

#Preview {
    HomeView()
}
