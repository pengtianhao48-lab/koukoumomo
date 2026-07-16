import SwiftUI

struct GestureHintView: View {
    let zhText: String
    let enText: String
    let isTriggered: Bool
    let usePaperBackground: Bool

    @State private var isVisible = true
    @State private var isDismissed = false
    @State private var pulse = false

    init(zhText: String, enText: String, isTriggered: Bool, usePaperBackground: Bool = false) {
        self.zhText = zhText
        self.enText = enText
        self.isTriggered = isTriggered
        self.usePaperBackground = usePaperBackground
    }

    var body: some View {
        GeometryReader { proxy in
            VStack {
                Text(displayText)
                    .font(DoodleStyle.mono(17, .medium))
                    .foregroundStyle(DoodleStyle.ink.opacity(usePaperBackground ? 0.7 : 0.45))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, usePaperBackground ? 16 : 0)
                    .padding(.vertical, usePaperBackground ? 8 : 0)
                    .background {
                        if usePaperBackground {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(DoodleStyle.paper.opacity(0.75))
                        }
                    }
                    .scaleEffect(pulse ? 1.02 : 0.98)
                    .opacity(isVisible && !isDismissed ? 1 : 0)
                    .animation(.easeInOut(duration: 0.35), value: isVisible)
                    .animation(.easeInOut(duration: 0.35), value: isDismissed)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulse)
                    .padding(.top, proxy.size.height * 0.10)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .allowsHitTesting(false)
        .task {
            pulse = true
            await runHintSchedule()
        }
        .onChange(of: isTriggered) { _, triggered in
            if triggered {
                isDismissed = true
                isVisible = false
            }
        }
    }

    private var displayText: String {
        Locale.current.language.languageCode?.identifier == "zh" ? zhText : enText
    }

    private func runHintSchedule() async {
        await flash(after: 2.0, visible: false)
        await flash(after: 1.0, visible: true)
        await flash(after: 1.8, visible: false)
        await flash(after: 5.2, visible: true)
        await flash(after: 1.8, visible: false)
    }

    private func flash(after delay: Double, visible: Bool) async {
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        guard !Task.isCancelled, !isDismissed else { return }
        isVisible = visible
    }
}
