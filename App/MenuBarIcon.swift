import AppKit

/// Draws the menu bar item: a 16 pt icon plus the time, as one image.
///
/// The time is drawn here rather than passed to SwiftUI as `Text`, because a MenuBarExtra
/// label drops font modifiers like `.monospacedDigit()`, and proportional digits make
/// the item jitter every second.
enum MenuBarIcon {
    enum Kind: Equatable {
        /// One ring.
        case idle
        /// Ring with a pie that empties as the minimum approaches. `remaining` is 0...1.
        case focus(remaining: Double)
        /// Moss dot shown for a few seconds when the minimum is reached.
        case cue
        /// Tree rings: past the minimum, still counting up.
        case flow
        /// Ripples: on a break.
        case rest
    }

    private static let iconSize: CGFloat = 16
    private static let gap: CGFloat = 4

    /// All kinds but the cue are template images, so macOS tints them for light and dark menu bars.
    static func image(for kind: Kind, text: String? = nil) -> NSImage {
        let font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.menuBarFont(ofSize: 0).pointSize, weight: .regular)
        // Template images only use alpha; the cue keeps real colors, so its text follows the menu bar appearance.
        let textColor = kind == .cue ? NSColor.labelColor : NSColor.black
        let title = text.map { NSAttributedString(string: $0, attributes: [.font: font, .foregroundColor: textColor]) }
        let titleSize = title?.size() ?? .zero

        let width = iconSize + (title == nil ? 0 : gap + ceil(titleSize.width))
        let height = max(iconSize, ceil(titleSize.height))

        let image = NSImage(size: NSSize(width: width, height: height), flipped: false) { rect in
            drawIcon(kind, in: NSRect(x: 0, y: (rect.height - iconSize) / 2, width: iconSize, height: iconSize))
            title?.draw(at: NSPoint(x: iconSize + gap, y: (rect.height - titleSize.height) / 2))
            return true
        }
        image.isTemplate = kind != .cue
        return image
    }

    private static func drawIcon(_ kind: Kind, in rect: NSRect) {
        let center = NSPoint(x: rect.midX, y: rect.midY)
        NSColor.black.set()

        switch kind {
        case .idle:
            ring(center: center, radius: 6).stroke()

        case .focus(let remaining):
            ring(center: center, radius: 6).stroke()
            // Quantize so the image only changes a few dozen times per session.
            let fraction = (min(max(remaining, 0), 1) * 48).rounded() / 48
            if fraction >= 1 {
                circle(center: center, radius: 4.25).fill()
            } else if fraction > 0 {
                let wedge = NSBezierPath()
                wedge.move(to: center)
                wedge.appendArc(withCenter: center, radius: 4.25, startAngle: 90, endAngle: 90 - 360 * fraction, clockwise: true)
                wedge.close()
                wedge.fill()
            }

        case .cue:
            cueColor().setFill()
            circle(center: center, radius: 6.5).fill()

        case .flow:
            ring(center: center, radius: 6.25).stroke()
            circle(center: center, radius: 3).fill()

        case .rest:
            for offset in [-2.5, 2.5] {
                let y = center.y + offset
                let wave = NSBezierPath()
                wave.lineWidth = 1.5
                wave.lineCapStyle = .round
                wave.move(to: NSPoint(x: rect.minX + 2, y: y))
                wave.curve(
                    to: NSPoint(x: rect.minX + 8, y: y),
                    controlPoint1: NSPoint(x: rect.minX + 4, y: y + 2.4),
                    controlPoint2: NSPoint(x: rect.minX + 6, y: y + 2.4)
                )
                wave.curve(
                    to: NSPoint(x: rect.minX + 14, y: y),
                    controlPoint1: NSPoint(x: rect.minX + 10, y: y - 2.4),
                    controlPoint2: NSPoint(x: rect.minX + 12, y: y - 2.4)
                )
                wave.stroke()
            }
        }
    }

    /// Moss reads well on a light menu bar but sinks into a dark one, so use the brighter leaf green there.
    /// The image is drawn on demand, so this follows the menu bar's own appearance.
    private static func cueColor() -> NSColor {
        let isDark = NSAppearance.currentDrawing().bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        return isDark ? Theme.leafNSColor : Theme.mossNSColor
    }

    private static func circle(center: NSPoint, radius: CGFloat) -> NSBezierPath {
        NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }

    private static func ring(center: NSPoint, radius: CGFloat) -> NSBezierPath {
        let path = circle(center: center, radius: radius)
        path.lineWidth = 1.5
        return path
    }
}
