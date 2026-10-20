import ServiceManagement
import SwiftUI

@MainActor
final class LoginItemModel: ObservableObject {
    @Published var enabled = SMAppService.mainApp.status == .enabled
    @Published var error: String?

    func set(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            error = nil
        } catch {
            self.error = "Couldn't update login item: \(error.localizedDescription)"
        }
        self.enabled = SMAppService.mainApp.status == .enabled
    }
}

struct SettingsView: View {
    @AppStorage(Pref.microEnabled) private var microEnabled = true
    @AppStorage(Pref.microIntervalMinutes) private var microInterval = 20.0
    @AppStorage(Pref.microDurationSeconds) private var microDuration = 20.0
    @AppStorage(Pref.longEnabled) private var longEnabled = true
    @AppStorage(Pref.longIntervalMinutes) private var longInterval = 60.0
    @AppStorage(Pref.longDurationMinutes) private var longDuration = 5.0
    @AppStorage(Pref.microStepAwaySeconds) private var microStepAway = 20.0
    @AppStorage(Pref.longStepAwayMinutes) private var longStepAway = 5.0
    @AppStorage(Pref.restThresholdSeconds) private var restThreshold = 2.0
    @AppStorage(Pref.snoozeMinutes) private var snooze = 5.0
    @AppStorage(Pref.glowEnabled) private var glowEnabled = true
    @AppStorage(Pref.glowGraceSeconds) private var glowGrace = 45.0
    @AppStorage(Pref.glowMaxIntensity) private var glowMax = 0.55
    @AppStorage(Pref.showCountdown) private var showCountdown = false
    @AppStorage(Pref.completionSound) private var completionSound = true
    @ObservedObject var loginItem: LoginItemModel

    var body: some View {
        Form {
            Section("Eye breaks") {
                Toggle("Remind me to rest my eyes", isOn: $microEnabled)
                Stepper("Every \(Int(microInterval)) minutes", value: $microInterval, in: 5...120, step: 5)
                    .disabled(!microEnabled)
                Stepper("For \(Int(microDuration)) seconds", value: $microDuration, in: 10...120, step: 5)
                    .disabled(!microEnabled)
                Stepper("Stepping away for \(Int(microStepAway)) seconds counts", value: $microStepAway, in: 10...300, step: 5)
                    .disabled(!microEnabled)
            }
            Section("Long breaks") {
                Toggle("Remind me to get up and move", isOn: $longEnabled)
                Stepper("Every \(Int(longInterval)) minutes", value: $longInterval, in: 15...180, step: 5)
                    .disabled(!longEnabled)
                Stepper("For \(Int(longDuration)) minutes", value: $longDuration, in: 1...30)
                    .disabled(!longEnabled)
                Stepper("Stepping away for \(Int(longStepAway)) minutes counts", value: $longStepAway, in: 1...30)
                    .disabled(!longEnabled)
            }
            Section {
                Stepper("Break counts down after \(Int(restThreshold)) seconds hands-off", value: $restThreshold, in: 1...30)
                Stepper("Snooze for \(Int(snooze)) minutes", value: $snooze, in: 1...30)
                Toggle("Glow around the screen edges if I keep working", isOn: $glowEnabled)
                Stepper("Start glowing after \(Int(glowGrace)) seconds", value: $glowGrace, in: 0...300, step: 15)
                    .disabled(!glowEnabled)
                LabeledContent("Glow strength") {
                    Slider(value: $glowMax, in: 0.15...1)
                }
                .disabled(!glowEnabled)
            } header: {
                Text("Nudges")
            } footer: {
                Text("A break counts down only while your hands are off the keyboard and mouse. If you step away on your own for long enough, Restwise counts it as a break.")
                    .foregroundStyle(.secondary)
            }
            Section("General") {
                Toggle("Show minutes until next break in menu bar", isOn: $showCountdown)
                Toggle("Play a soft sound when a break ends", isOn: $completionSound)
                Toggle("Launch at login", isOn: Binding(get: { loginItem.enabled }, set: { loginItem.set($0) }))
                if let error = loginItem.error {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }
}
