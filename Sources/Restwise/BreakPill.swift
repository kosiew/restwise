import AppKit
import RestwiseCore
import SwiftUI

@MainActor
final class PillModel: ObservableObject {
    @Published var kind: BreakKind = .micro
    @Published var tip = ""
    @Published var remaining: TimeInterval = 0
    @Published var progress: Double = 0
    @Published var resting = false
    @Published var done = false
    @Published var hovering = false
}

/// A panel that floats above other windows but never becomes key or steals focus.
private final class PillPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Lets the pill's buttons respond to the first click even though the app isn't active.
private final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

@MainActor
final class BreakPillController {
    let model = PillModel()
    var onSnooze: () -> Void = {}
    var onSkip: () -> Void = {}

    private lazy var panel: PillPanel = makePanel()
    private var hideWork: DispatchWorkItem?

    func show(_ kind: BreakKind) {
        hideWork?.cancel()
        model.kind = kind
        model.tip = Tips.random(for: kind)
        model.done = false
        model.progress = 0
        model.resting = false
        position()
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { $0.duration = 0.35; panel.animator().alphaValue = 1 }
    }

    func update(remaining: TimeInterval, progress: Double, resting: Bool) {
        model.remaining = remaining
        model.progress = progress
        model.resting = resting
    }

    /// Shows a brief "nice" state, then fades out.
    func finish() {
        model.done = true
        model.progress = 1
        let work = DispatchWorkItem { [weak self] in self?.hide() }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: work)
    }

    func hide() {
        hideWork?.cancel()
        guard panel.isVisible else { return }
        NSAnimationContext.runAnimationGroup({ $0.duration = 0.4; panel.animator().alphaValue = 0 }) { [panel] in
            MainActor.assumeIsolated { panel.orderOut(nil) }
        }
    }

    private func makePanel() -> PillPanel {
        let panel = PillPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 76),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: true
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        let view = PillView(
            model: model,
            snooze: { [weak self] in self?.onSnooze() },
            skip: { [weak self] in self?.onSkip() }
        )
        let host = FirstMouseHostingView(rootView: view)
        host.sizingOptions = []
        panel.contentView = host
        return panel
    }

    /// Top-center of the screen the user is working on, just under the menu bar.
    private func position() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }
        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(x: visible.midX - size.width / 2, y: visible.maxY - size.height - 6))
    }
}

private struct PillView: View {
    @ObservedObject var model: PillModel
    let snooze: () -> Void
    let skip: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ring
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer(minLength: 4)
            if !model.done {
                HStack(spacing: 2) {
                    PillButton(symbol: "clock.arrow.circlepath", help: "Snooze", action: snooze)
                    PillButton(symbol: "forward.end", help: "Skip this break", action: skip)
                }
                .opacity(model.hovering ? 1 : 0.55)
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, 10)
        .frame(width: 400, height: 56)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.primary.opacity(0.08)))
        .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
        .frame(width: 420, height: 76)
        .onHover { model.hovering = $0 }
        .animation(.easeInOut(duration: 0.25), value: model.done)
        .animation(.easeInOut(duration: 0.25), value: model.resting)
    }

    private var ring: some View {
        ZStack {
            Circle().stroke(.primary.opacity(0.12), lineWidth: 3)
            Circle()
                .trim(from: 0, to: model.progress)
                .stroke(accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: model.progress)
            Image(systemName: model.done ? "checkmark" : (model.kind == .micro ? "eye" : "figure.walk"))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(accent)
        }
        .frame(width: 34, height: 34)
    }

    private var accent: Color { model.kind == .micro ? .teal : .orange }

    private var title: String {
        if model.done { return model.kind == .micro ? "Eyes refreshed" : "Welcome back" }
        let what = model.kind == .micro ? "Eye break" : "Time to move"
        return "\(what) · \(Self.format(model.remaining))"
    }

    private var subtitle: String {
        if model.done { return "Nice. Back to it." }
        if model.resting { return model.tip }
        return "Hands off the keyboard to start. \(model.tip)"
    }

    static func format(_ t: TimeInterval) -> String {
        let s = Int(t.rounded(.up))
        return s >= 60 ? String(format: "%d:%02d", s / 60, s % 60) : "\(s)s"
    }
}

private struct PillButton: View {
    let symbol: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 26, height: 26)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .help(help)
    }
}
