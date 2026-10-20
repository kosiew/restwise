# Restwise

A quiet macOS menu bar app for break reminders, eye rest, and healthier computer habits. Built as a calmer replacement for Stretchly.

Stretchly covers your screen with a big dialog. Restwise starts small and only gets more noticeable if you keep ignoring it:

| Stage | What you see | Steals focus? | Blocks clicks? |
|---|---|---|---|
| Working | A small ring in the menu bar fills toward the next break | No | No |
| Break due | A slim pill slides in under the menu bar with a tip and countdown | No | No |
| Still ignoring it after 45 s | A soft, breathing glow fades in around the screen edges | No | No (click-through) |
| Resting | Countdown runs; glow fades away | — | — |
| Done | Pill shows a checkmark and fades out, with an optional gong | — | — |

**How breaks count down:** the countdown only advances while your hands are off the keyboard and mouse. You can't sit through a break while still typing; you have to actually stop. If you've already stepped away for longer than a break on your own (coffee, a meeting, a locked screen, sleep), Restwise counts it as a break and resets the timer.

## Defaults

- **Eye break:** every 20 min, for 20 s (the 20-20-20 rule)
- **Long break:** every 60 min, for 5 min. If an eye break comes due within 3 min of a long break, the long break is taken instead.
- **Snooze:** 5 min. **Skip** is always one click away on the pill.
- **Pause:** 30 min, 1 h, 2 h, until tomorrow, or until you resume (from the menu bar).
- **Daily tally:** breaks taken and skipped today, shown in the menu.

You can change all of these under **Settings…** (⌘,) in the menu bar menu, along with glow strength and delay, a menu bar countdown, the completion sound, and launch at login.

## Build & install

Requires macOS 14+ and the Swift toolchain (the Xcode Command Line Tools are enough).

```sh
scripts/build-app.sh            # builds build/Restwise.app (ad-hoc signed)
scripts/build-app.sh --install  # also copies it to /Applications and launches it
```

To try it out with intervals of a few seconds:

```sh
RESTWISE_DEMO=1 build/Restwise.app/Contents/MacOS/Restwise       # real idle detection
RESTWISE_DEMO=active build/Restwise.app/Contents/MacOS/Restwise  # pretends you never stop typing, to see the glow
```

## Development

```sh
swift build
swift test   # scheduling logic in RestwiseCore
```

- `Sources/RestwiseCore/BreakEngine.swift`: the scheduling state machine. It has no UI and no timers, and is fully unit-tested.
- `Sources/Restwise/AppController.swift`: a 1 s tick that reads input idle time (`CGEventSource`), drives the engine, and updates the UI.
- `Sources/Restwise/BreakPill.swift`: a non-activating floating panel that never becomes key.
- `Sources/Restwise/EdgeGlow.swift`: a click-through glow window on each screen.
- `Sources/Restwise/StatusItemController.swift`: the menu bar ring and menu.

No special permissions are needed. Reading idle time doesn't require Accessibility or Input Monitoring access.

> **Note:** with only the Command Line Tools installed, `swift test` sometimes fails with "plugin for module 'TestingMacros' not found" after a release build. `rm -rf .build` fixes it.
