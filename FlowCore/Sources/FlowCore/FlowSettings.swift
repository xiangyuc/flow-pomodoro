import Foundation

/// The knobs of the "minimum, not maximum" timer.
public struct FlowSettings: Codable, Equatable, Sendable {
    /// Focus time that has to pass before the gentle cue. Not a hard stop.
    public var minimumFocus: TimeInterval
    /// One minute of break is earned per `breakRatio` minutes of focus.
    public var breakRatio: Double
    /// After this much focus, a real notification suggests a break.
    public var ceiling: TimeInterval
    /// Length of the "Wrap up" grace period.
    public var wrapUpLength: TimeInterval
    /// How often the ceiling nudge repeats while it is ignored.
    public var renudgeInterval: TimeInterval

    public init(
        minimumFocus: TimeInterval = 25 * 60,
        breakRatio: Double = 5,
        ceiling: TimeInterval = 90 * 60,
        wrapUpLength: TimeInterval = 5 * 60,
        renudgeInterval: TimeInterval = 10 * 60
    ) {
        self.minimumFocus = minimumFocus
        self.breakRatio = breakRatio
        self.ceiling = ceiling
        self.wrapUpLength = wrapUpLength
        self.renudgeInterval = renudgeInterval
    }

    /// Break earned for a stretch of focus, rounded to whole minutes, at least one minute.
    /// With the defaults: 25 min → 5, 38 min → 8, 90 min → 18.
    public func earnedBreak(for focused: TimeInterval) -> TimeInterval {
        let minutes = (focused / 60 / breakRatio).rounded()
        return max(1, minutes) * 60
    }
}
