import AppKit
import CoreGraphics
import RestwiseCore
import SwiftUI

@MainActor
final class AppController: NSObject, NSApplicationDelegate {
    private(set) var engine = BreakEngine()
    private var status: StatusItemController!
    private let pill = BreakPillController()
    private let glow = EdgeGlowController()
    private var timer: Timer?
    private var lastTick = Date()
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Pref.registerDefaults()
        status = StatusItemController(app: self)
        pill.onSnooze = { [weak self] in self?.snooze() }
        pill.onSkip = { [weak self] in self?.skip() }

        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        timer.tolerance = 0.2
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    // MARK: - Tick

    private func tick() {
        let now = Date()
        let gap = now.timeIntervalSince(lastTick)
        lastTick = now
        // After sleep the timer fires late; treat the whole gap as time away.
        let idle = Pref.demoActiveUser ? 0 : max(Self.secondsSinceLastInput(), gap > 5 ? gap : 0)
        let config = Pref.breakConfig

        for event in engine.tick(dt: gap, idle: idle, now: now, config: config) {
            switch event {
            case .breakDue(let kind):
                pill.show(kind)
                if UserDefaults.standard.bool(forKey: Pref.startSound) {
                    Gong.play(.small)
                }
            case .breakCompleted:
                DailyStats.recordTaken()
                glow.intensity = 0
                pill.finish()
                if UserDefaults.standard.bool(forKey: Pref.completionSound) {
                    Gong.play(.large)
                }
            case .naturalBreak, .resumed:
                break
            }
        }

        if case .onBreak(let kind) = engine.phase {
            let duration = config.duration(of: kind)
            pill.update(
                remaining: max(0, duration - engine.rested),
                progress: duration > 0 ? engine.rested / duration : 1,
                resting: idle >= config.restThreshold
            )
            glow.intensity = glowIntensity(ignored: engine.ignored, resting: idle >= config.restThreshold)
        }
        status.refresh()
    }

    /// Fades in after a grace period of ignoring the break; fades back down while resting.
    private func glowIntensity(ignored: TimeInterval, resting: Bool) -> Double {
        let glow = Pref.glow
        guard glow.enabled, !resting else { return 0 }
        let ramp: TimeInterval = Pref.demo ? 10 : 90
        return glow.max * min(1, max(0, (ignored - glow.grace) / ramp))
    }

    static func secondsSinceLastInput() -> TimeInterval {
        // kCGAnyInputEventType: keyboard, mouse, trackpad, scroll.
        let anyInput = CGEventType(rawValue: ~0)!
        return CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput)
    }

    // MARK: - Actions

    private func endBreakUI() {
        pill.hide()
        glow.intensity = 0
        status.refresh()
    }

    func startBreak(_ kind: BreakKind) {
        engine.startBreak(kind)
        pill.show(kind)
        status.refresh()
    }

    func snooze() {
        engine.snooze(Pref.snooze, config: Pref.breakConfig)
        endBreakUI()
    }

    func skip() {
        guard case .onBreak = engine.phase else { return }
        engine.skip()
        DailyStats.recordSkipped()
        endBreakUI()
    }

    func pause(until: Date?) {
        engine.pause(until: until)
        endBreakUI()
    }

    func resume() {
        engine.resume()
        status.refresh()
    }

    func resetTimers() {
        engine.resetTimers()
        status.refresh()
    }

    func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 460, height: 520),
                styleMask: [.titled, .closable], backing: .buffered, defer: false
            )
            window.title = "Restwise Settings"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SettingsView(loginItem: LoginItemModel()))
            window.center()
            settingsWindow = window
        }
        NSApp.activate()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}
