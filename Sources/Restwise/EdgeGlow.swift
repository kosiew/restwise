import AppKit
import SwiftUI

@MainActor
final class GlowModel: ObservableObject {
    @Published var intensity: Double = 0
    @Published var breathe = false
}

/// A soft, click-through glow around the edges of every screen. Used as a
/// gentle escalation when a due break keeps getting ignored.
@MainActor
final class EdgeGlowController {
    private let model = GlowModel()
    private var windows: [NSWindow] = []

    init() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.rebuild() }
        }
    }

    var intensity: Double {
        get { model.intensity }
        set {
            let value = max(0, min(1, newValue))
            guard abs(value - model.intensity) > 0.005 || (value == 0) != (model.intensity == 0) else { return }
            model.intensity = value
            if value > 0, windows.isEmpty { rebuild() }
            windows.forEach { value > 0 ? $0.orderFrontRegardless() : $0.orderOut(nil) }
        }
    }

    private func rebuild() {
        windows.forEach { $0.orderOut(nil) }
        windows = NSScreen.screens.map { screen in
            let w = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
            w.isOpaque = false
            w.backgroundColor = .clear
            w.ignoresMouseEvents = true
            w.hasShadow = false
            w.level = .floating
            w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            w.contentView = NSHostingView(rootView: GlowView(model: model))
            w.setFrame(screen.frame, display: false)
            if model.intensity > 0 { w.orderFrontRegardless() }
            return w
        }
    }
}

private struct GlowView: View {
    @ObservedObject var model: GlowModel

    var body: some View {
        Rectangle()
            .strokeBorder(
                LinearGradient(
                    colors: [Color(red: 1, green: 0.62, blue: 0.32), Color(red: 1, green: 0.45, blue: 0.45)],
                    startPoint: .top, endPoint: .bottom
                ),
                lineWidth: 36
            )
            .blur(radius: 34)
            .opacity(model.breathe ? 1 : 0.55)
            .animation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true), value: model.breathe)
            .opacity(model.intensity)
            .animation(.easeInOut(duration: 1.5), value: model.intensity)
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .onAppear { model.breathe = true }
    }
}
