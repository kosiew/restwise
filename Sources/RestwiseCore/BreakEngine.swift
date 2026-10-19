import Foundation

public enum BreakKind: String, Sendable {
    /// Short eye break (20-20-20 rule by default).
    case micro
    /// Longer stand-up / stretch break.
    case long
}

public struct BreakConfig: Equatable, Sendable {
    public var microEnabled: Bool
    public var microInterval: TimeInterval
    public var microDuration: TimeInterval
    public var longEnabled: Bool
    public var longInterval: TimeInterval
    public var longDuration: TimeInterval
    /// Seconds without keyboard/mouse input before we consider the user "resting".
    public var restThreshold: TimeInterval
    /// If a micro break comes due this close to a long break, take the long one instead.
    public var mergeWindow: TimeInterval

    public init(
        microEnabled: Bool = true,
        microInterval: TimeInterval = 20 * 60,
        microDuration: TimeInterval = 20,
        longEnabled: Bool = true,
        longInterval: TimeInterval = 60 * 60,
        longDuration: TimeInterval = 5 * 60,
        restThreshold: TimeInterval = 2,
        mergeWindow: TimeInterval = 3 * 60
    ) {
        self.microEnabled = microEnabled
        self.microInterval = microInterval
        self.microDuration = microDuration
        self.longEnabled = longEnabled
        self.longInterval = longInterval
        self.longDuration = longDuration
        self.restThreshold = restThreshold
        self.mergeWindow = mergeWindow
    }

    public func duration(of kind: BreakKind) -> TimeInterval {
        kind == .micro ? microDuration : longDuration
    }

    public func interval(of kind: BreakKind) -> TimeInterval {
        kind == .micro ? microInterval : longInterval
    }

    /// Idle time after which work time stops accumulating (the user has stepped away).
    var awayThreshold: TimeInterval { min(microDuration, 30) }
}

public enum EngineEvent: Equatable, Sendable {
    case breakDue(BreakKind)
    case breakCompleted(BreakKind)
    /// The user stepped away long enough on their own; the timer was reset.
    case naturalBreak(BreakKind)
    case resumed
}

/// Break scheduling state machine. Driven by `tick` with elapsed time and
/// current input-idle time; contains no timers or UI of its own.
public struct BreakEngine: Sendable {
    public enum Phase: Equatable, Sendable {
        case working
        case onBreak(BreakKind)
        case paused(until: Date?)
    }

    public private(set) var phase: Phase = .working
    /// Active work time since the last eye break.
    public private(set) var sinceMicro: TimeInterval = 0
    /// Active work time since the last long break.
    public private(set) var sinceLong: TimeInterval = 0
    /// Rest accumulated during the current break.
    public private(set) var rested: TimeInterval = 0
    /// Time the user kept working while the current break was due.
    public private(set) var ignored: TimeInterval = 0

    public init() {}

    public mutating func tick(dt: TimeInterval, idle: TimeInterval, now: Date, config: BreakConfig) -> [EngineEvent] {
        var events: [EngineEvent] = []
        switch phase {
        case .paused(let until):
            if let until, now >= until {
                resume()
                events.append(.resumed)
            }

        case .working:
            if config.longEnabled, idle >= config.longDuration, sinceLong > 0 {
                sinceLong = 0
                sinceMicro = 0
                events.append(.naturalBreak(.long))
            } else if config.microEnabled, idle >= config.microDuration, sinceMicro > 0 {
                sinceMicro = 0
                events.append(.naturalBreak(.micro))
            }
            if idle < config.awayThreshold {
                sinceMicro += dt
                sinceLong += dt
            }
            if let kind = dueKind(config) {
                startBreak(kind)
                events.append(.breakDue(kind))
            }

        case .onBreak(let kind):
            if idle >= config.restThreshold {
                rested += dt
            } else {
                ignored += dt
            }
            if rested >= config.duration(of: kind) {
                finish(kind)
                events.append(.breakCompleted(kind))
            }
        }
        return events
    }

    private func dueKind(_ config: BreakConfig) -> BreakKind? {
        if config.longEnabled, sinceLong >= config.longInterval {
            return .long
        }
        if config.microEnabled, sinceMicro >= config.microInterval {
            if config.longEnabled, config.longInterval - sinceLong <= config.mergeWindow {
                return .long
            }
            return .micro
        }
        return nil
    }

    // MARK: - User actions

    public mutating func startBreak(_ kind: BreakKind) {
        phase = .onBreak(kind)
        rested = 0
        ignored = 0
    }

    /// Ends the current break without credit and resets its timer.
    public mutating func skip() {
        guard case .onBreak(let kind) = phase else { return }
        finish(kind)
    }

    /// Ends the current break and brings it back after `delay` of work.
    public mutating func snooze(_ delay: TimeInterval, config: BreakConfig) {
        guard case .onBreak(let kind) = phase else { return }
        phase = .working
        rested = 0
        ignored = 0
        switch kind {
        case .micro: sinceMicro = max(0, config.microInterval - delay)
        case .long: sinceLong = max(0, config.longInterval - delay)
        }
    }

    public mutating func pause(until: Date?) {
        phase = .paused(until: until)
        rested = 0
        ignored = 0
    }

    public mutating func resume() {
        phase = .working
        resetTimers()
    }

    public mutating func resetTimers() {
        sinceMicro = 0
        sinceLong = 0
    }

    private mutating func finish(_ kind: BreakKind) {
        phase = .working
        rested = 0
        ignored = 0
        sinceMicro = 0
        if kind == .long { sinceLong = 0 }
    }

    // MARK: - Queries

    /// The next scheduled break and the work time remaining until it.
    public func next(_ config: BreakConfig) -> (kind: BreakKind, remaining: TimeInterval)? {
        var candidates: [(BreakKind, TimeInterval)] = []
        if config.microEnabled { candidates.append((.micro, config.microInterval - sinceMicro)) }
        if config.longEnabled { candidates.append((.long, config.longInterval - sinceLong)) }
        return candidates.min { $0.1 < $1.1 }.map { (kind: $0.0, remaining: max(0, $0.1)) }
    }

    /// Fraction of the way to the next break, 0...1.
    public func progressToNext(_ config: BreakConfig) -> Double {
        guard let next = next(config) else { return 0 }
        let interval = config.interval(of: next.kind)
        guard interval > 0 else { return 1 }
        return min(1, max(0, 1 - next.remaining / interval))
    }
}
