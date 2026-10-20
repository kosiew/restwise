import Foundation

/// Idle time as the engine should see it, given raw input idle and video playback.
///
/// Video players drop their wake lock briefly between clips, for ads, and while
/// buffering, so a stop with no input since is only treated as idle after `grace`.
/// Input after the stop means the user is present and stopped it on purpose.
///
/// - Parameters:
///   - input: Seconds since the last keyboard/mouse input.
///   - sinceVideo: Seconds since video was last seen playing (0 while playing), or nil if never.
public func effectiveIdle(input: TimeInterval, sinceVideo: TimeInterval?, grace: TimeInterval = 60) -> TimeInterval {
    guard let sinceVideo, input >= sinceVideo else { return input }
    return max(0, sinceVideo - grace)
}
