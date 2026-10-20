import Foundation

/// One finished focus session, as stored in history.
public struct SessionRecord: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var startedAt: Date
    public var focused: TimeInterval
    /// The minimum that was in effect for this session.
    public var minimum: TimeInterval

    public init(id: UUID = UUID(), startedAt: Date, focused: TimeInterval, minimum: TimeInterval) {
        self.id = id
        self.startedAt = startedAt
        self.focused = focused
        self.minimum = minimum
    }

    /// The part of the session spent reaching the minimum.
    public var base: TimeInterval { min(focused, minimum) }

    /// The part of the session spent in flow beyond the minimum.
    public var flowExtra: TimeInterval { max(0, focused - minimum) }

    /// True when the session kept going for at least a minute past the minimum.
    public var ranPastMinimum: Bool { flowExtra >= 60 }
}
