import Foundation

public enum StatsRange: String, CaseIterable, Identifiable, Sendable {
    case day = "Day"
    case week = "Week"
    case month = "Month"

    public var id: String { rawValue }
}

/// One bar in the stats chart: a session (day view) or a calendar day (week and month views).
public struct StatsBucket: Identifiable, Equatable, Sendable {
    public var start: Date
    public var label: String
    public var base: TimeInterval
    public var extra: TimeInterval

    public var id: Date { start }
    public var total: TimeInterval { base + extra }
}

public struct StatsSummary: Equatable, Sendable {
    public var range: StatsRange
    public var interval: DateInterval
    /// Sessions in the range, oldest first.
    public var records: [SessionRecord]
    public var buckets: [StatsBucket]

    public var totalFocused: TimeInterval { records.reduce(0) { $0 + $1.focused } }
    public var sessionCount: Int { records.count }
    public var averageSession: TimeInterval { records.isEmpty ? 0 : totalFocused / Double(records.count) }
    public var pastMinimumCount: Int { records.filter(\.ranPastMinimum).count }
    public var longest: SessionRecord? { records.max { $0.focused < $1.focused } }
}

public enum StatsCalculator {
    public static func summary(
        of records: [SessionRecord],
        range: StatsRange,
        now: Date,
        calendar: Calendar = .current
    ) -> StatsSummary {
        let interval = self.interval(for: range, containing: now, calendar: calendar)
        let inRange = records
            .filter { $0.startedAt >= interval.start && $0.startedAt < interval.end }
            .sorted { $0.startedAt < $1.startedAt }

        let buckets: [StatsBucket]
        switch range {
        case .day:
            let formatter = makeFormatter(template: "jmm", calendar: calendar)
            buckets = inRange.map {
                StatsBucket(start: $0.startedAt, label: formatter.string(from: $0.startedAt), base: $0.base, extra: $0.flowExtra)
            }
        case .week, .month:
            let formatter = makeFormatter(template: range == .week ? "EEE" : "d", calendar: calendar)
            var result: [StatsBucket] = []
            var day = interval.start
            while day < interval.end {
                guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                let sessions = inRange.filter { $0.startedAt >= day && $0.startedAt < next }
                result.append(StatsBucket(
                    start: day,
                    label: formatter.string(from: day),
                    base: sessions.reduce(0) { $0 + $1.base },
                    extra: sessions.reduce(0) { $0 + $1.flowExtra }
                ))
                day = next
            }
            buckets = result
        }

        return StatsSummary(range: range, interval: interval, records: inRange, buckets: buckets)
    }

    /// One-line takeaway, e.g. "9 of 17 sessions ran past 25 minutes. Your longest was 77 minutes, on Wednesday morning."
    public static func insight(for summary: StatsSummary, calendar: Calendar = .current) -> String {
        guard let longest = summary.longest else {
            return "No sessions yet. Your first ring is one start away."
        }
        let noun = summary.sessionCount == 1 ? "session" : "sessions"
        let minimum = DurationFormat.minutes(longest.minimum)
        var text = "\(summary.pastMinimumCount) of \(summary.sessionCount) \(noun) ran past \(minimum) minutes."
        let longestMinutes = DurationFormat.minutes(longest.focused)
        switch summary.range {
        case .day:
            text += " Your longest was \(longestMinutes) minutes."
        case .week:
            let weekday = makeFormatter(template: "EEEE", calendar: calendar).string(from: longest.startedAt)
            text += " Your longest was \(longestMinutes) minutes, on \(weekday) \(partOfDay(longest.startedAt, calendar: calendar))."
        case .month:
            let date = makeFormatter(template: "MMMd", calendar: calendar).string(from: longest.startedAt)
            text += " Your longest was \(longestMinutes) minutes, on \(date)."
        }
        return text
    }

    public static func interval(for range: StatsRange, containing date: Date, calendar: Calendar) -> DateInterval {
        let component: Calendar.Component
        switch range {
        case .day: component = .day
        case .week: component = .weekOfYear
        case .month: component = .month
        }
        return calendar.dateInterval(of: component, for: date) ?? DateInterval(start: date, duration: 0)
    }

    private static func partOfDay(_ date: Date, calendar: Calendar) -> String {
        switch calendar.component(.hour, from: date) {
        case ..<12: return "morning"
        case ..<17: return "afternoon"
        default: return "evening"
        }
    }

    private static func makeFormatter(template: String, calendar: Calendar) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = calendar.locale ?? .current
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter
    }
}
