import SwiftUI

/// The timer dial: a progress ring over faint tree-ring grain (focus) or ripples (break),
/// with an optional outer ring that grows through flow time toward the ceiling.
struct RingDial<Content: View>: View {
    enum Texture {
        case wood
        case water
    }

    var progress: Double
    var color: Color
    var outerProgress: Double?
    var texture: Texture = .wood
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            switch texture {
            case .wood:
                Circle().stroke(Theme.grain, lineWidth: 1).frame(width: 122, height: 122).offset(x: 1, y: -1)
                Circle().stroke(Theme.grain, lineWidth: 1).frame(width: 96, height: 96).offset(x: -1, y: 1)
            case .water:
                ForEach([122.0, 94.0, 66.0], id: \.self) { size in
                    Circle().stroke(Theme.ripple.opacity(size / 122), lineWidth: 1).frame(width: size, height: size)
                }
            }

            ring(progress: progress, color: color, diameter: 148)

            if let outerProgress {
                ring(progress: outerProgress, color: Theme.leaf, diameter: 168)
            }

            content
        }
        .frame(width: 176, height: 176)
    }

    private func ring(progress: Double, color: Color, diameter: CGFloat) -> some View {
        ZStack {
            Circle().stroke(Theme.track, lineWidth: 3)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: diameter, height: diameter)
    }
}

/// Big serif time with a small caption under it.
struct TimerReadout: View {
    var time: String
    var caption: String

    var body: some View {
        VStack(spacing: 0) {
            Text(time)
                .font(.timer(46))
                .contentTransition(.identity)
            Text(caption).font(.system(size: 12)).foregroundStyle(Theme.inkSecondary)
        }
    }
}

/// "Focus" with a dot, or "In flow" with a leaf.
struct StateTitle: View {
    enum Marker {
        case dot(Color)
        case leaf
    }

    var title: String
    var marker: Marker

    var body: some View {
        HStack(spacing: 8) {
            switch marker {
            case .dot(let color):
                Circle().fill(color).frame(width: 8, height: 8)
            case .leaf:
                LeafShape().fill(Theme.moss).frame(width: 12, height: 12)
            }
            Text(title).font(.system(size: 13, weight: .semibold))
        }
    }
}

struct HeaderDetail: View {
    var text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12))
            .monospacedDigit()
            .foregroundStyle(Theme.inkSecondary)
    }
}

/// An eyebrow label over the parked note ("Pick up from", "Up next").
struct NoteBlock: View {
    var title: String
    var note: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .medium))
                .tracking(0.5)
                .foregroundStyle(Theme.inkSecondary)
            Text(note)
                .font(.system(size: 14))
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct InfoRow: View {
    var label: String
    var value: String
    var emphasized = false

    var body: some View {
        HStack {
            Text(label).foregroundStyle(Theme.inkSecondary)
            Spacer()
            Text(value)
                .fontWeight(emphasized ? .medium : .regular)
                .monospacedDigit()
        }
        .font(.system(size: 13))
    }
}

struct IconButton: View {
    var systemName: String
    var label: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.inkSecondary)
        .accessibilityLabel(label)
        .help(label)
    }
}

struct PillButtonStyle: ButtonStyle {
    enum Kind {
        case primary(Color)
        case secondary
        case quiet
    }

    var kind: Kind

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .frame(maxWidth: .infinity, minHeight: 44)
            .foregroundStyle(foreground)
            .background(Capsule().fill(background))
            .contentShape(Capsule())
            .opacity(configuration.isPressed ? 0.8 : 1)
    }

    private var foreground: Color {
        switch kind {
        case .primary: return .white
        case .secondary: return Theme.ink
        case .quiet: return Theme.inkSecondary
        }
    }

    private var background: Color {
        switch kind {
        case .primary(let color): return color
        case .secondary: return Theme.buttonSecondary
        case .quiet: return .clear
        }
    }
}

extension ButtonStyle where Self == PillButtonStyle {
    static func pill(_ kind: PillButtonStyle.Kind) -> PillButtonStyle {
        PillButtonStyle(kind: kind)
    }
}

struct LeafShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        path.move(to: CGPoint(x: rect.minX + w * 0.08, y: rect.minY + h * 0.92))
        path.addCurve(
            to: CGPoint(x: rect.minX + w * 0.92, y: rect.minY + h * 0.08),
            control1: CGPoint(x: rect.minX + w * 0.08, y: rect.minY + h * 0.42),
            control2: CGPoint(x: rect.minX + w * 0.42, y: rect.minY + h * 0.08)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + w * 0.08, y: rect.minY + h * 0.92),
            control1: CGPoint(x: rect.minX + w * 0.92, y: rect.minY + h * 0.58),
            control2: CGPoint(x: rect.minX + w * 0.58, y: rect.minY + h * 0.92)
        )
        path.closeSubpath()
        return path
    }
}
