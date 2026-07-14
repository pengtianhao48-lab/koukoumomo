import SwiftUI

/// The only screen with UI chrome. Six doodle cards in a 2×3 grid.
/// Tapping a card opens the full-screen toy via `NavigationStack`.
struct HomeView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                DoodleStyle.paper.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 24) {
                    header
                    grid
                    Spacer(minLength: 8)
                }
                .padding(.horizontal, 22)
                .padding(.top, 32)
            }
            .navigationBarHidden(true)
        }
        .tint(DoodleStyle.ink)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("home.title")
                .font(DoodleStyle.mono(32, .black))
                .foregroundStyle(DoodleStyle.ink)
                .rotationEffect(.degrees(-1.5))
            Text("home.subtitle")
                .font(DoodleStyle.mono(14, .medium))
                .foregroundStyle(DoodleStyle.inkSoft)
        }
        .padding(.leading, 4)
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

/// A card that shows a static preview of the doodle plus a hand-written label.
private struct DoodleCard: View {
    let mode: PlayMode

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                // Card background with wobble border
                Canvas { ctx, size in
                    let rect = CGRect(origin: .zero, size: size).insetBy(dx: 4, dy: 4)
                    ctx.fill(Rough.roundedRect(rect, corner: 24, wobble: 1.4, seed: mode.hashValue & 0xFF),
                             with: .color(DoodleStyle.paper))
                    ctx.stroke(Rough.roundedRect(rect, corner: 24, wobble: 1.4, seed: mode.hashValue & 0xFF),
                               with: .color(DoodleStyle.ink), style: .doodle)
                }
                // Doodle preview
                thumbnail
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(14)
                    .allowsHitTesting(false)
            }
            .aspectRatio(1, contentMode: .fit)

            VStack(alignment: .leading, spacing: 2) {
                Text(mode.titleKey)
                    .font(DoodleStyle.mono(16, .heavy))
                    .foregroundStyle(DoodleStyle.ink)
                Text(mode.subtitleKey)
                    .font(DoodleStyle.mono(12, .medium))
                    .foregroundStyle(DoodleStyle.inkSoft)
                    .lineLimit(1)
            }
            .padding(.horizontal, 4)
        }
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

#Preview {
    HomeView()
}
