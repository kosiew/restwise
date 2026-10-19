import Foundation
import RestwiseCore

/// UserDefaults keys shared by the engine driver and `@AppStorage` in SettingsView.
enum Pref {
    static let microEnabled = "microEnabled"
    static let microIntervalMinutes = "microIntervalMinutes"
    static let microDurationSeconds = "microDurationSeconds"
    static let longEnabled = "longEnabled"
    static let longIntervalMinutes = "longIntervalMinutes"
    static let longDurationMinutes = "longDurationMinutes"
    static let glowEnabled = "glowEnabled"
    static let glowGraceSeconds = "glowGraceSeconds"
    static let glowMaxIntensity = "glowMaxIntensity"
    static let showCountdown = "showCountdown"
    static let completionSound = "completionSound"
    static let snoozeMinutes = "snoozeMinutes"

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            microEnabled: true,
            microIntervalMinutes: 20.0,
            microDurationSeconds: 20.0,
            longEnabled: true,
            longIntervalMinutes: 60.0,
            longDurationMinutes: 5.0,
            glowEnabled: true,
            glowGraceSeconds: 45.0,
            glowMaxIntensity: 0.55,
            showCountdown: false,
            completionSound: true,
            snoozeMinutes: 5.0,
        ])
    }

    private static var d: UserDefaults { .standard }

    /// `RESTWISE_DEMO=1` shrinks every interval to seconds, for trying things out.
    /// `RESTWISE_DEMO=active` also pretends the user never stops typing, to see the escalation.
    static let demo = ProcessInfo.processInfo.environment["RESTWISE_DEMO"] != nil
    static let demoActiveUser = ProcessInfo.processInfo.environment["RESTWISE_DEMO"] == "active"

    static var breakConfig: BreakConfig {
        if demo {
            return BreakConfig(microInterval: 15, microDuration: 8, longInterval: 70, longDuration: 15, mergeWindow: 5)
        }
        return BreakConfig(
            microEnabled: d.bool(forKey: microEnabled),
            microInterval: d.double(forKey: microIntervalMinutes) * 60,
            microDuration: d.double(forKey: microDurationSeconds),
            longEnabled: d.bool(forKey: longEnabled),
            longInterval: d.double(forKey: longIntervalMinutes) * 60,
            longDuration: d.double(forKey: longDurationMinutes) * 60
        )
    }

    static var glow: (enabled: Bool, grace: TimeInterval, max: Double) {
        (d.bool(forKey: glowEnabled), demo ? 5 : d.double(forKey: glowGraceSeconds), d.double(forKey: glowMaxIntensity))
    }

    static var snooze: TimeInterval { d.double(forKey: snoozeMinutes) * 60 }
}

/// Per-day counts of breaks taken and skipped.
enum DailyStats {
    private static func key(_ name: String) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return "stats.\(f.string(from: Date())).\(name)"
    }

    static var taken: Int { UserDefaults.standard.integer(forKey: key("taken")) }
    static var skipped: Int { UserDefaults.standard.integer(forKey: key("skipped")) }

    static func recordTaken() { bump(key("taken")) }
    static func recordSkipped() { bump(key("skipped")) }

    private static func bump(_ k: String) {
        UserDefaults.standard.set(UserDefaults.standard.integer(forKey: k) + 1, forKey: k)
    }
}
