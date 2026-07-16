import SwiftUI

struct GestureHintView: View {
    let hintText: String
    let isTriggered: Bool
    let usePaperBackground: Bool

    @State private var isVisible = true
    @State private var isDismissed = false
    @State private var pulse = false

    init(hintText: String, isTriggered: Bool, usePaperBackground: Bool = false) {
        self.hintText = hintText
        self.isTriggered = isTriggered
        self.usePaperBackground = usePaperBackground
    }

    var body: some View {
        GeometryReader { proxy in
            VStack {
                hintContent
                    .padding(.horizontal, effectivePaperBackground ? 16 : 0)
                    .padding(.vertical, effectivePaperBackground ? 8 : 0)
                    .background {
                        if effectivePaperBackground {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(DoodleStyle.paper.opacity(0.75))
                        }
                    }
                    .scaleEffect(pulse ? 1.02 : 0.98)
                    .opacity(isVisible && !isDismissed ? 1 : 0)
                    .animation(.easeInOut(duration: 0.35), value: isVisible)
                    .animation(.easeInOut(duration: 0.35), value: isDismissed)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulse)
                    .padding(.top, proxy.size.height * 0.18)
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

    private var hintContent: some View {
        VStack(spacing: 3) {
            Text(copy.zh)
                .font(DoodleStyle.mono(15, .medium))
            Text(copy.en)
                .font(DoodleStyle.mono(14, .medium))
        }
        .foregroundStyle(DoodleStyle.ink.opacity(effectivePaperBackground ? 0.7 : 0.45))
        .multilineTextAlignment(.center)
    }

    private var effectivePaperBackground: Bool {
        usePaperBackground || hintText == "轻触"
    }

    private var copy: (zh: String, en: String) {
        switch hintText {
        case "画圈":
            return ("画圈抠鼻", "Draw circles")
        case "轻触":
            return ("轻触戳气泡", "Tap to pop")
        case "拖动":
            return ("拖动", "Drag")
        default:
            return splitCopy(hintText)
        }
    }

    private func splitCopy(_ text: String) -> (zh: String, en: String) {
        let parts = text.split(separator: "/", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
        if parts.count == 2 {
            return (parts[0], parts[1])
        }
        return (text, "")
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
