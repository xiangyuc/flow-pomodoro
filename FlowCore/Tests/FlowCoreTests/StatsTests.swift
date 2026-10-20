import XCTest
import FlowCore

final class StatsTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.firstWeekday = 2 // Monday
        return calendar
    }()

    /// 2026-10-14 is a Wednesday; its week runs Mon Oct 12 – Sun Oct 18.
    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    private func record(_ day: Int, _ hour: Int, minutes: Double) -> SessionRecord {
        SessionRecord(startedAt: date(day, hour), focused: minutes * 60, minimum: 25 * 60)
    }

    func testWeekBucketsSplitMinimumAndFlow() {
        let records = [
            record(12, 9, minutes: 25),
            record(12, 14, minutes: 52),
            record(14, 10, minutes: 77),
            record(19, 9, minutes: 40) // next week
        ]
        let summary = StatsCalculator.summary(of: records, range: .week, now: date(14, 12), calendar: calendar)

        XCTAssertEqual(summary.buckets.count, 7)
        XCTAssertEqual(summary.buckets.map(\.label), ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"])
        XCTAssertEqual(summary.sessionCount, 3)
        XCTAssertEqual(summary.totalFocused, 154 * 60)
        XCTAssertEqual(summary.pastMinimumCount, 2)

        XCTAssertEqual(summary.buckets[0].base, 50 * 60)
        XCTAssertEqual(summary.buckets[0].extra, 27 * 60)
        XCTAssertEqual(summary.buckets[2].base, 25 * 60)
        XCTAssertEqual(summary.buckets[2].extra, 52 * 60)
        XCTAssertEqual(summary.buckets[1].total, 0)

        XCTAssertEqual(
            StatsCalculator.insight(for: summary, calendar: calendar),
            "2 of 3 sessions ran past 25 minutes. Your longest was 77 minutes, on Wednesday morning."
        )
    }

    func testDayHasOneBucketPerSession() {
        let records = [record(14, 9, minutes: 30), record(14, 15, minutes: 25), record(13, 9, minutes: 60)]
        let summary = StatsCalculator.summary(of: records, range: .day, now: date(14, 18), calendar: calendar)

        XCTAssertEqual(summary.buckets.count, 2)
        XCTAssertEqual(summary.averageSession, 27.5 * 60)
        XCTAssertEqual(summary.longest?.focused, 30 * 60)
    }

    func testMonthHasOneBucketPerDay() {
        let summary = StatsCalculator.summary(of: [], range: .month, now: date(14, 12), calendar: calendar)
        XCTAssertEqual(summary.buckets.count, 31)
        XCTAssertEqual(StatsCalculator.insight(for: summary, calendar: calendar), "No sessions yet. Your first ring is one start away.")
    }

    func testHistoryRoundTrips() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("history.json")
        let store = HistoryStore(url: url)
        XCTAssertEqual(store.load(), [])

        let records = [record(14, 9, minutes: 38)]
        try store.save(records)
        XCTAssertEqual(store.load(), records)
    }
}
