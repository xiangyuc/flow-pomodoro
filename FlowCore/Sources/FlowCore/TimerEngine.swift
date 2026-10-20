import Foundation

/// A focus session in progress. Focus and flow are the same session:
/// it is "focus" until `minimumFocus` has elapsed and "flow" after.
public struct FocusSession: Equatable, Sendable {
    public var startedAt: Date
    public var pausedAt: Date?
    public var pausedTotal: TimeInterval = 0
    public var wrapUpDeadline: Date?
    /// When the next ceiling nudge is due. Nil until the ceiling is first reached.
    public var nextNudgeAt: Date?
    public var minimumAnnounced = false

    public init(startedAt: Date) {
        self.startedAt = startedAt
    }

    public var isPaused: Bool { pausedAt != nil }
    public var isWrappingUp: Bool { wrapUpDeadline != nil }

    public func elapsed(at now: Date) -> TimeInterval {
        let end = pausedAt ?? now
        return max(0, end.timeIntervalSince(startedAt) - pausedTotal)
    }
}

/// Focus has ended and the app is asking for a parking note.
public struct ParkedFocus: Equatable, Sendable {
    public var record: SessionRecord
    public var earnedBreak: TimeInterval

    public init(record: SessionRecord, earnedBreak: TimeInterval) {
        self.record = record
        self.earnedBreak = earnedBreak
    }
}

public struct BreakSession: Equatable, Sendable {
    public var startedAt: Date
    public var length: TimeInterval
    /// The focus time that earned this break.
    public var focused: TimeInterval

    public init(startedAt: Date, length: TimeInterval, focused: TimeInterval) {
        self.startedAt = startedAt
        self.length = length
        self.focused = focused
    }

    public var endsAt: Date { startedAt.addingTimeInterval(length) }

    public func remaining(at now: Date) -> TimeInterval {
        max(0, endsAt.timeIntervalSince(now))
    }
}

public enum Phase: Equatable, Sendable {
    case idle
    case focusing(FocusSession)
    case parking(ParkedFocus)
    case onBreak(BreakSession)
}

public enum EngineEvent: Equatable, Sendable {
    /// The minimum just passed: tint the icon and chime once. Never interrupt.
    case reachedMinimum
    /// The ceiling was reached (or a snoozed nudge came due).
    case ceilingNudge(focused: TimeInterval)
    /// The "Wrap up" grace period ran out and focus ended.
    case wrapUpEnded
    case sessionCompleted(SessionRecord)
    case breakEnded
}

/// The timer's state machine. Pure value type: time is always passed in, so it is easy to test.
public struct TimerEngine: Sendable {
    public var settings: FlowSettings
    public private(set) var phase: Phase = .idle

    public init(settings: FlowSettings = FlowSettings()) {
        self.settings = settings
    }

    public mutating func startFocus(at now: Date) {
        phase = .focusing(FocusSession(startedAt: now))
    }

    public mutating func pause(at now: Date) {
        guard case .focusing(var session) = phase, session.pausedAt == nil else { return }
        session.pausedAt = now
        phase = .focusing(session)
    }

    public mutating func resume(at now: Date) {
        guard case .focusing(var session) = phase, let pausedAt = session.pausedAt else { return }
        let gap = now.timeIntervalSince(pausedAt)
        session.pausedTotal += gap
        session.pausedAt = nil
        session.wrapUpDeadline = session.wrapUpDeadline?.addingTimeInterval(gap)
        session.nextNudgeAt = session.nextNudgeAt?.addingTimeInterval(gap)
        phase = .focusing(session)
    }

    public mutating func wrapUp(at now: Date) {
        guard case .focusing(var session) = phase, !session.isPaused, !session.isWrappingUp else { return }
        session.wrapUpDeadline = now.addingTimeInterval(settings.wrapUpLength)
        phase = .focusing(session)
    }

    public mutating func snoozeCeiling(at now: Date) {
        guard case .focusing(var session) = phase else { return }
        session.nextNudgeAt = now.addingTimeInterval(settings.renudgeInterval)
        phase = .focusing(session)
    }

    /// Ends focus and moves on to the parking note. Returns the finished session.
    @discardableResult
    public mutating func takeBreak(at now: Date) -> SessionRecord? {
        guard case .focusing(let session) = phase else { return nil }
        let record = finish(session, at: now)
        park(record)
        return record
    }

    /// Ends focus without a break. Sessions shorter than a minute are discarded.
    @discardableResult
    public mutating func endFocus(at now: Date) -> SessionRecord? {
        guard case .focusing(let session) = phase else { return nil }
        let record = finish(session, at: now)
        phase = .idle
        return record.focused >= 60 ? record : nil
    }

    public mutating func startBreak(at now: Date) {
        guard case .parking(let parked) = phase else { return }
        phase = .onBreak(BreakSession(startedAt: now, length: parked.earnedBreak, focused: parked.record.focused))
    }

    /// Skips or ends the break early and goes back to ready.
    public mutating func endBreak() {
        switch phase {
        case .parking, .onBreak:
            phase = .idle
        case .idle, .focusing:
            break
        }
    }

    /// Advances time. Call about once a second; also safe to call after sleep.
    public mutating func tick(at now: Date) -> [EngineEvent] {
        switch phase {
        case .focusing(var session):
            guard !session.isPaused else { return [] }

            if let deadline = session.wrapUpDeadline, now >= deadline {
                let record = finish(session, at: deadline)
                park(record)
                return [.wrapUpEnded, .sessionCompleted(record)]
            }

            var events: [EngineEvent] = []
            let elapsed = session.elapsed(at: now)
            if !session.minimumAnnounced && elapsed >= settings.minimumFocus {
                session.minimumAnnounced = true
                events.append(.reachedMinimum)
            }
            if elapsed >= settings.ceiling && !session.isWrappingUp {
                let due = session.nextNudgeAt.map { now >= $0 } ?? true
                if due {
                    session.nextNudgeAt = now.addingTimeInterval(settings.renudgeInterval)
                    events.append(.ceilingNudge(focused: elapsed))
                }
            }
            phase = .focusing(session)
            return events

        case .onBreak(let breakSession):
            guard now >= breakSession.endsAt else { return [] }
            phase = .idle
            return [.breakEnded]

        case .idle, .parking:
            return []
        }
    }

    private func finish(_ session: FocusSession, at now: Date) -> SessionRecord {
        SessionRecord(startedAt: session.startedAt, focused: session.elapsed(at: now), minimum: settings.minimumFocus)
    }

    private mutating func park(_ record: SessionRecord) {
        phase = .parking(ParkedFocus(record: record, earnedBreak: settings.earnedBreak(for: record.focused)))
    }
}
