import Charts
import FlowCore
import SwiftUI

struct StatsView: View {
    @Environment(AppModel.self) private var model
    @State private var range: StatsRange = .week
    @State private var selectedLabel: String?

    var body: some View {
        let summary = model.summary(for: range)

        VStack(alignment: .leading, spacing: 26) {
            header(summary)
            tiles(summary)

            HStack(alignment: .bottom, spacing: 28) {
                VStack(spacing: 10) {
                    TreeRings(records: summary.records)
                        .frame(width: 180, height: 180)
                    Text("\(summary.sessionCount) \(summary.sessionCount == 1 ? "ring" : "rings"), one per session.\nWide gaps are long sessions.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.inkSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(width: 180)

                chart(summary)
            }

            Spacer(minLength: 0)

            HStack(alignment: .top, spacing: 10) {
                LeafShape().fill(Theme.moss).frame(width: 14, height: 14).padding(.top, 3)
                Text(StatsCalculator.insight(for: summary))
                    .font(.system(size: 14))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 18)
            .overlay(alignment: .top) {
                Rectangle().fill(Theme.hairline).frame(height: 1)
            }
        }
        .padding(EdgeInsets(top: 12, leading: 32, bottom: 32, trailing: 32))
        .frame(width: 560, height: 580)
        .background(Theme.ground)
        .foregroundStyle(Theme.ink)
        .environment(\.colorScheme, .light)
    }

    // MARK: Header and tiles

    private func header(_ summary: StatsSummary) -> some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.display(28))
                Text(subtitle(summary.interval))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.inkSecondary)
            }
            Spacer()
            Picker("Range", selection: $range) {
                ForEach(StatsRange.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 200)
        }
    }

    private var title: String {
        switch range {
        case .day: return "Today"
        case .week: return "This week"
        case .month: return "This month"
        }
    }

    private func subtitle(_ interval: DateInterval) -> String {
        switch range {
        case .day:
            return interval.start.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
        case .week:
            let formatter = DateIntervalFormatter()
            formatter.dateTemplate = "MMMd"
            return formatter.string(from: interval.start, to: interval.end.addingTimeInterval(-1))
        case .month:
            return interval.start.formatted(.dateTime.month(.wide).year())
        }
    }

    private func tiles(_ summary: StatsSummary) -> some View {
        HStack(alignment: .top, spacing: 16) {
            tile(DurationFormat.short(summary.totalFocused), "focused")
            tile("\(summary.sessionCount)", summary.sessionCount == 1 ? "session" : "sessions")
            tile(DurationFormat.short(summary.averageSession), "average session")
        }
    }

    private func tile(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.timer(30))
            Text(label).font(.system(size: 12)).foregroundStyle(Theme.inkSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Chart

    private func chart(_ summary: StatsSummary) -> some View {
        let minimum = DurationFormat.minutes(summary.records.first?.minimum ?? model.engine.settings.minimumFocus)
        let showValues = summary.buckets.count <= 10
        let maxMinutes = summary.buckets.map { $0.total / 60 }.max() ?? 0
        let selected = summary.buckets.first { $0.label == selectedLabel }
        let visible = Set(xAxisLabels(summary))

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                legendItem(Theme.moss, "First \(minimum) min")
                legendItem(Theme.leaf, "Flow past \(minimum)")
            }

            Chart {
                ForEach(summary.buckets) { bucket in
                    BarMark(x: .value("Period", bucket.label), y: .value("Minutes", bucket.base / 60), width: .ratio(0.55))
                        .foregroundStyle(Theme.moss)
                    BarMark(x: .value("Period", bucket.label), y: .value("Minutes", bucket.extra / 60), width: .ratio(0.55))
                        .foregroundStyle(Theme.leaf)
                        .annotation(position: .top, spacing: 4) {
                            if showValues && bucket.total > 0 {
                                Text(String(format: "%.1fh", bucket.total / 3600))
                                    .font(.system(size: 11))
                                    .monospacedDigit()
                                    .foregroundStyle(Theme.ink)
                            }
                        }
                }

                if let selected {
                    RuleMark(x: .value("Period", selected.label))
                        .foregroundStyle(Theme.inkSecondary.opacity(0.25))
                        .annotation(position: .top, spacing: 0, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                            tooltip(selected, minimum: minimum)
                        }
                }
            }
            .chartXSelection(value: $selectedLabel)
            .chartYScale(domain: 0...max(60, maxMinutes * 1.2))
            .chartYAxis {
                AxisMarks(position: .leading, values: .stride(by: 60)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        .foregroundStyle(Theme.hairline)
                    AxisValueLabel {
                        Text("\(Int((value.as(Double.self) ?? 0) / 60))h")
                    }
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.inkSecondary)
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    let label = value.as(String.self) ?? ""
                    // Every category gets a mark; hidden ones draw an empty label.
                    AxisValueLabel(collisionResolution: .disabled) {
                        Text(visible.contains(label) ? label : "")
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.inkSecondary)
                }
            }
            .frame(height: 210)
        }
    }

    /// Month view has ~30 bars, so label only every fifth day.
    private func xAxisLabels(_ summary: StatsSummary) -> [String] {
        guard summary.buckets.count > 10 else { return summary.buckets.map(\.label) }
        return summary.buckets.enumerated()
            .filter { $0.offset % 5 == 0 }
            .map(\.element.label)
    }

    private func legendItem(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 10, height: 10)
            Text(label)
        }
        .font(.system(size: 12))
        .foregroundStyle(Theme.inkSecondary)
    }

    private func tooltip(_ bucket: StatsBucket, minimum: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(bucket.label).font(.system(size: 11, weight: .semibold))
            Text("\(DurationFormat.short(bucket.base)) in the first \(minimum)")
            Text("\(DurationFormat.short(bucket.extra)) in flow")
        }
        .font(.system(size: 11))
        .foregroundStyle(Theme.ink)
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.hairline, lineWidth: 1))
    }
}

/// One ring per session, spaced by session length, like the growth rings in a tree.
struct TreeRings: View {
    let records: [SessionRecord]

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let outer = min(size.width, size.height) / 2

            context.fill(circle(center, outer), with: .color(Theme.wood))

            let total = records.reduce(0) { $0 + $1.focused }
            var cumulative: TimeInterval = 0
            // The last session's ring is drawn as the bark.
            for (index, record) in records.enumerated().dropLast() where total > 0 {
                cumulative += record.focused
                let radius = 6 + (outer - 10) * CGFloat(cumulative / total)
                // A slight, stable wobble so the rings look grown rather than drawn.
                let wobble = CGFloat((index * 37) % 7 - 3) * 0.15
                let ringCenter = CGPoint(x: center.x + wobble, y: center.y - wobble)
                context.stroke(circle(ringCenter, radius), with: .color(Theme.woodRing), lineWidth: 1.1)
            }

            context.stroke(circle(center, outer - 4), with: .color(Theme.bark), lineWidth: 2.5)
            context.fill(circle(center, 2.5), with: .color(Theme.woodRing))
        }
        .accessibilityElement()
        .accessibilityLabel("\(records.count) tree rings, one per session. Wider gaps mean longer sessions.")
    }

    private func circle(_ center: CGPoint, _ radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }
}
