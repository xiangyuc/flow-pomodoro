import XCTest
import FlowCore

final class TimerEngineTests: XCTestCase {
    private let t0 = Date(timeIntervalSinceReferenceDate: 0)

    private func at(_ minutes: Double, _ seconds: Double = 0) -> Date {
        t0.addingTimeInterval(minutes * 60 + seconds)
    }

    func testEarnedBreakScalesWithFocus() {
        let settings = FlowSettings()
        XCTAssertEqual(settings.earnedBreak(for: 25 * 60), 5 * 60)
        XCTAssertEqual(settings.earnedBreak(for: 38 * 60 + 12), 8 * 60)
        XCTAssertEqual(settings.earnedBreak(for: 90 * 60), 18 * 60)
        XCTAssertEqual(settings.earnedBreak(for: 2 * 60), 60, "never less than a minute")
    }

    func testMinimumIsAnnouncedOnceAndFocusKeepsGoing() {
        var engine = TimerEngine()
        engine.startFocus(at: t0)

        XCTAssertEqual(engine.tick(at: at(24, 59)), [])
        XCTAssertEqual(engine.tick(at: at(25)), [.reachedMinimum])
        XCTAssertEqual(engine.tick(at: at(25, 1)), [])

        guard case .focusing(let session) = engine.phase else { return XCTFail("should still be focusing") }
        XCTAssertEqual(session.elapsed(at: at(40)), 40 * 60)
    }

    func testPausedTimeIsNotCounted() {
        var engine = TimerEngine()
        engine.startFocus(at: t0)
        engine.pause(at: at(10))
        XCTAssertEqual(engine.tick(at: at(19)), [], "the clock stands still while paused")
        engine.resume(at: at(20))

        XCTAssertEqual(engine.tick(at: at(34, 59)), [])
        XCTAssertEqual(engine.tick(at: at(35)), [.reachedMinimum])
    }

    func testTakeBreakParksThenBreaksThenReturnsToIdle() throws {
        var engine = TimerEngine()
        engine.startFocus(at: t0)
        _ = engine.tick(at: at(25))

        let record = try XCTUnwrap(engine.takeBreak(at: at(38, 12)))
        XCTAssertEqual(record.focused, 38 * 60 + 12)
        XCTAssertEqual(record.flowExtra, 13 * 60 + 12)
        guard case .parking(let parked) = engine.phase else { return XCTFail("should be parking") }
        XCTAssertEqual(parked.earnedBreak, 8 * 60)

        engine.startBreak(at: at(39))
        guard case .onBreak(let breakSession) = engine.phase else { return XCTFail("should be on break") }
        XCTAssertEqual(breakSession.remaining(at: at(40)), 7 * 60)

        XCTAssertEqual(engine.tick(at: at(46, 59)), [])
        XCTAssertEqual(engine.tick(at: at(47)), [.breakEnded])
        XCTAssertEqual(engine.phase, .idle)
    }

    func testCeilingNudgesAndRepeatsUntilSnoozedOrHeeded() {
        var engine = TimerEngine()
        engine.startFocus(at: t0)
        _ = engine.tick(at: at(25))

        XCTAssertEqual(engine.tick(at: at(90)), [.ceilingNudge(focused: 90 * 60)])
        XCTAssertEqual(engine.tick(at: at(95)), [])
        XCTAssertEqual(engine.tick(at: at(100)), [.ceilingNudge(focused: 100 * 60)])

        engine.snoozeCeiling(at: at(102))
        XCTAssertEqual(engine.tick(at: at(110)), [], "the earlier schedule is replaced by the snooze")
        XCTAssertEqual(engine.tick(at: at(112)), [.ceilingNudge(focused: 112 * 60)])
    }

    func testWrapUpEndsFocusAtTheDeadline() {
        var engine = TimerEngine()
        engine.startFocus(at: t0)
        _ = engine.tick(at: at(25))
        engine.wrapUp(at: at(40))

        XCTAssertEqual(engine.tick(at: at(44)), [])
        let events = engine.tick(at: at(46))
        XCTAssertEqual(events.first, .wrapUpEnded)
        guard case .sessionCompleted(let record) = events.last else { return XCTFail("expected a record") }
        XCTAssertEqual(record.focused, 45 * 60, "counted up to the deadline, not to the late tick")
        guard case .parking(let parked) = engine.phase else { return XCTFail("should be parking") }
        XCTAssertEqual(parked.earnedBreak, 9 * 60)
    }

    func testEndingAVeryShortSessionDiscardsIt() {
        var engine = TimerEngine()
        engine.startFocus(at: t0)
        XCTAssertNil(engine.endFocus(at: at(0, 30)))
        XCTAssertEqual(engine.phase, .idle)

        engine.startFocus(at: t0)
        XCTAssertEqual(engine.endFocus(at: at(12))?.focused, 12 * 60)
    }

    func testDurationFormatting() {
        XCTAssertEqual(DurationFormat.clock(38 * 60 + 12), "38:12")
        XCTAssertEqual(DurationFormat.clock(92 * 60), "92:00")
        XCTAssertEqual(DurationFormat.countdown(25 * 60 - 0.3), "25:00")
        XCTAssertEqual(DurationFormat.short(41 * 60), "41 min")
        XCTAssertEqual(DurationFormat.short(700 * 60), "11h 40m")
    }
}
