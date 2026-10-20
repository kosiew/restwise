import Foundation
import Testing
@testable import RestwiseCore

private let config = BreakConfig(
    microInterval: 20 * 60, microDuration: 20,
    longInterval: 60 * 60, longDuration: 5 * 60
)
private let now = Date(timeIntervalSince1970: 0)

/// Advances the engine one second at a time, collecting events.
@discardableResult
private func run(_ engine: inout BreakEngine, seconds: Int, idle: TimeInterval = 0, config: BreakConfig = config) -> [EngineEvent] {
    var events: [EngineEvent] = []
    for _ in 0..<seconds {
        events += engine.tick(dt: 1, idle: idle, now: now, config: config)
    }
    return events
}

@Test func microBreakComesDueAfterInterval() {
    var engine = BreakEngine()
    #expect(run(&engine, seconds: 20 * 60 - 1).isEmpty)
    #expect(run(&engine, seconds: 1) == [.breakDue(.micro)])
    #expect(engine.phase == .onBreak(.micro))
}

@Test func breakOnlyProgressesWhileHandsAreOff() {
    var engine = BreakEngine()
    engine.startBreak(.micro)
    run(&engine, seconds: 30, idle: 0)
    #expect(engine.rested == 0)
    #expect(engine.ignored == 30)
    #expect(run(&engine, seconds: 20, idle: 5) == [.breakCompleted(.micro)])
    #expect(engine.phase == .working)
    #expect(engine.sinceMicro == 0)
}

@Test func steppingAwayCountsAsNaturalBreak() {
    var engine = BreakEngine()
    run(&engine, seconds: 10 * 60)
    let events = run(&engine, seconds: 1, idle: 20)
    #expect(events == [.naturalBreak(.micro)])
    #expect(engine.sinceMicro == 0)
    #expect(engine.sinceLong == 10 * 60)
    // Staying away does not keep firing events or accumulating work time.
    #expect(run(&engine, seconds: 60, idle: 30).isEmpty)
    #expect(engine.sinceLong == 10 * 60)
}

@Test func longAbsenceResetsBothTimers() {
    var engine = BreakEngine()
    run(&engine, seconds: 15 * 60)
    #expect(engine.tick(dt: 1, idle: 6 * 60, now: now, config: config) == [.naturalBreak(.long)])
    #expect(engine.sinceMicro == 0)
    #expect(engine.sinceLong == 0)
}

@Test func microBreakNearLongBreakIsMerged() {
    var engine = BreakEngine()
    let cfg = BreakConfig(microInterval: 20 * 60, longInterval: 22 * 60, mergeWindow: 3 * 60)
    #expect(run(&engine, seconds: 20 * 60, config: cfg) == [.breakDue(.long)])
}

@Test func snoozeBringsBreakBackLater() {
    var engine = BreakEngine()
    run(&engine, seconds: 20 * 60)
    engine.snooze(5 * 60, config: config)
    #expect(engine.phase == .working)
    #expect(run(&engine, seconds: 5 * 60 - 1).isEmpty)
    #expect(run(&engine, seconds: 1) == [.breakDue(.micro)])
}

@Test func skipResetsWithoutCompleting() {
    var engine = BreakEngine()
    run(&engine, seconds: 20 * 60)
    engine.skip()
    #expect(engine.phase == .working)
    #expect(engine.sinceMicro == 0)
}

@Test func timedPauseResumes() {
    var engine = BreakEngine()
    engine.pause(until: now.addingTimeInterval(60))
    #expect(engine.tick(dt: 1, idle: 0, now: now.addingTimeInterval(30), config: config).isEmpty)
    #expect(engine.tick(dt: 1, idle: 0, now: now.addingTimeInterval(61), config: config) == [.resumed])
    #expect(engine.phase == .working)
}

@Test func disabledBreaksNeverFire() {
    var engine = BreakEngine()
    let cfg = BreakConfig(microEnabled: false, longEnabled: false)
    #expect(run(&engine, seconds: 2 * 60 * 60, config: cfg).isEmpty)
    #expect(engine.next(cfg) == nil)
}

@Test func stepAwayThresholdIsIndependentOfBreakLength() {
    let custom = BreakConfig(microDuration: 20, microStepAway: 60)
    var engine = BreakEngine()
    run(&engine, seconds: 60, config: custom)
    #expect(engine.tick(dt: 1, idle: 30, now: now, config: custom).isEmpty)
    #expect(engine.tick(dt: 1, idle: 60, now: now, config: custom) == [.naturalBreak(.micro)])
}

@Test func restThresholdGatesBreakCountdown() {
    let custom = BreakConfig(microDuration: 20, restThreshold: 10)
    var engine = BreakEngine()
    engine.startBreak(.micro)
    run(&engine, seconds: 5, idle: 5, config: custom)
    #expect(engine.rested == 0)
    run(&engine, seconds: 5, idle: 10, config: custom)
    #expect(engine.rested == 5)
}

@Test func videoPlayingCountsAsActive() {
    #expect(effectiveIdle(input: 300, sinceVideo: 0) == 0)
    #expect(effectiveIdle(input: 300, sinceVideo: nil) == 300)
}

@Test func briefVideoGapWithoutInputIsNotIdle() {
    // Chrome drops its wake lock for a few seconds between clips.
    #expect(effectiveIdle(input: 300, sinceVideo: 5) == 0)
    #expect(effectiveIdle(input: 300, sinceVideo: 90) == 30)
}

@Test func inputAfterVideoStopsUsesInputIdle() {
    // The user paused the video, then took their hands off.
    #expect(effectiveIdle(input: 10, sinceVideo: 15) == 10)
}
