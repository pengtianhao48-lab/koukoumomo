import SwiftUI

/// Full-screen gesture surface. Any doodle behind it will receive normalized progress events
/// through the shared `GestureEngine`, so no doodle handles raw drags itself.
struct GestureSurface: ViewModifier {
    let engine: GestureEngine
    let kind: GestureKind

    func body(content: Content) -> some View {
        GeometryReader { proxy in
            content
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onChanged { engine.handleDrag($0, in: proxy.size) }
                        .onEnded { _ in engine.handleEnded() }
                )
                .simultaneousGesture(TapGesture().onEnded { engine.handleTap() })
        }
    }
}

extension View {
    func doodleGesture(engine: GestureEngine, kind: GestureKind) -> some View {
        modifier(GestureSurface(engine: engine, kind: kind))
    }
}
