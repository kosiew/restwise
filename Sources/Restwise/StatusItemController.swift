import AppKit
import RestwiseCore

/// Menu bar icon: a small ring that fills toward the next break.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private unowned let app: AppController
    private var lastRendered = ""

    init(app: AppController) {
        self.app = app
        super.init()
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        item.button?.imagePosition = .imageLeading
        refresh()
    }

    func refresh() {
        let engine = app.engine
        let config = Pref.breakConfig
        let image: NSImage
        var title = ""
        var key: String

        switch engine.phase {
        case .paused:
            image = Self.symbol("pause.circle")
            key = "paused"
        case .onBreak(let kind):
            image = Self.symbol(kind == .micro ? "eye" : "figure.walk")
            key = "break.\(kind)"
        case .working:
            let progress = engine.progressToNext(config)
            // Quantize so we only redraw when the ring visibly changes.
            let step = (progress * 24).rounded() / 24
            image = Self.ring(progress: step)
            key = "ring.\(step)"
            if UserDefaults.standard.bool(forKey: Pref.showCountdown), let next = engine.next(config) {
                title = " \(Self.shortDuration(next.remaining))"
            }
        }
        key += title
        guard key != lastRendered else { return }
        lastRendered = key
        item.button?.image = image
        item.button?.title = title
        item.button?.toolTip = "Restwise"
    }

    // MARK: - Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let engine = app.engine
        let config = Pref.breakConfig

        switch engine.phase {
        case .paused(let until):
            if let until {
                menu.addItem(disabled: "Paused until \(until.formatted(date: .omitted, time: .shortened))")
            } else {
                menu.addItem(disabled: "Paused")
            }
            menu.addItem(action("Resume", #selector(resume)))
        case .onBreak(let kind):
            menu.addItem(disabled: kind == .micro ? "Eye break in progress" : "Long break in progress")
            menu.addItem(action("Snooze", #selector(snooze)))
            menu.addItem(action("Skip This Break", #selector(skip)))
        case .working:
            if config.microEnabled {
                menu.addItem(disabled: "Eye break in \(Self.longDuration(config.microInterval - engine.sinceMicro))")
            }
            if config.longEnabled {
                menu.addItem(disabled: "Long break in \(Self.longDuration(config.longInterval - engine.sinceLong))")
            }
            if !config.microEnabled && !config.longEnabled {
                menu.addItem(disabled: "All breaks are turned off")
            }
            menu.addItem(.separator())
            menu.addItem(action("Take an Eye Break Now", #selector(startMicro)))
            menu.addItem(action("Take a Long Break Now", #selector(startLong)))
            let pause = NSMenuItem(title: "Pause", action: nil, keyEquivalent: "")
            let sub = NSMenu()
            for (label, minutes) in [("For 30 Minutes", 30), ("For 1 Hour", 60), ("For 2 Hours", 120)] {
                let i = action(label, #selector(pauseFor(_:)))
                i.tag = minutes
                sub.addItem(i)
            }
            sub.addItem(action("Until Tomorrow", #selector(pauseUntilTomorrow)))
            sub.addItem(action("Until I Resume", #selector(pauseIndefinitely)))
            pause.submenu = sub
            menu.addItem(pause)
            menu.addItem(action("Reset Timers", #selector(reset)))
        }

        menu.addItem(.separator())
        menu.addItem(disabled: "Today: \(DailyStats.taken) taken · \(DailyStats.skipped) skipped")
        menu.addItem(.separator())
        menu.addItem(action("Settings…", #selector(openSettings), key: ","))
        menu.addItem(action("Quit Restwise", #selector(quit), key: "q"))
    }

    private func action(_ title: String, _ selector: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc private func resume() { app.resume() }
    @objc private func snooze() { app.snooze() }
    @objc private func skip() { app.skip() }
    @objc private func startMicro() { app.startBreak(.micro) }
    @objc private func startLong() { app.startBreak(.long) }
    @objc private func pauseFor(_ sender: NSMenuItem) { app.pause(until: Date().addingTimeInterval(TimeInterval(sender.tag * 60))) }
    @objc private func pauseUntilTomorrow() { app.pause(until: Calendar.current.startOfDay(for: Date().addingTimeInterval(86_400))) }
    @objc private func pauseIndefinitely() { app.pause(until: nil) }
    @objc private func reset() { app.resetTimers() }
    @objc private func openSettings() { app.showSettings() }
    @objc private func quit() { NSApp.terminate(nil) }

    // MARK: - Drawing

    private static func symbol(_ name: String) -> NSImage {
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        let image = NSImage(systemSymbolName: name, accessibilityDescription: "Restwise")!.withSymbolConfiguration(config)!
        image.isTemplate = true
        return image
    }

    private static func ring(progress: Double) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let inset = rect.insetBy(dx: 2.5, dy: 2.5)
            let center = NSPoint(x: inset.midX, y: inset.midY)
            let radius = inset.width / 2

            NSColor.black.withAlphaComponent(0.3).setStroke()
            let track = NSBezierPath(ovalIn: inset)
            track.lineWidth = 1.6
            track.stroke()

            if progress > 0 {
                NSColor.black.setStroke()
                let arc = NSBezierPath()
                arc.appendArc(withCenter: center, radius: radius, startAngle: 90, endAngle: 90 - 360 * progress, clockwise: true)
                arc.lineWidth = 2.2
                arc.lineCapStyle = .round
                arc.stroke()
            }
            return true
        }
        image.isTemplate = true
        return image
    }

    private static func shortDuration(_ t: TimeInterval) -> String {
        let m = Int((max(0, t) / 60).rounded(.up))
        return m >= 60 ? "\(m / 60)h\(m % 60 > 0 ? "\(m % 60)" : "")" : "\(m)m"
    }

    private static func longDuration(_ t: TimeInterval) -> String {
        let m = Int((max(0, t) / 60).rounded(.up))
        if m < 1 { return "less than a minute" }
        if m < 60 { return "\(m) min" }
        return "\(m / 60) h \(m % 60) min"
    }
}

private extension NSMenu {
    func addItem(disabled title: String) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        addItem(item)
    }
}
