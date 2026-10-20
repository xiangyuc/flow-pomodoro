import Foundation

public enum DurationFormat {
    /// "12:34". Minutes do not roll over into hours, so 92 minutes reads "92:00".
    public static func clock(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded(.down)))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    /// Like `clock`, but rounds up so a fresh 25-minute countdown reads "25:00".
    public static func countdown(_ interval: TimeInterval) -> String {
        clock(interval.rounded(.up))
    }

    /// "41 min", "1h 52m", "11h 40m".
    public static func short(_ interval: TimeInterval) -> String {
        let minutes = Int((interval / 60).rounded())
        if minutes < 60 { return "\(minutes) min" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }

    /// Whole minutes, rounded.
    public static func minutes(_ interval: TimeInterval) -> Int {
        Int((interval / 60).rounded())
    }
}
