import AppKit
import SwiftUI

/// Moss, wood and water. Values match the design canvas.
enum Theme {
    static let ground = Color(hex: 0xF5F2EA)
    static let surface = Color(hex: 0xFBFAF6)
    static let ink = Color(hex: 0x1F2A22)
    static let inkSecondary = Color(hex: 0x5E6B60)
    static let hairline = Color(hex: 0xE3DDCF)
    static let track = Color(hex: 0xE0D9C9)
    static let grain = Color(hex: 0xE6DFD0)
    static let buttonSecondary = Color(hex: 0xEBE6DA)

    /// Focus.
    static let moss = Color(hex: 0x46752F)
    static let mossTint = Color(hex: 0xDFE8D3)
    /// Flow time past the minimum.
    static let leaf = Color(hex: 0x9CBF63)
    /// Breaks.
    static let water = Color(hex: 0x3D6475)
    static let ripple = Color(hex: 0xD5E1E4)

    /// Tree-ring illustration on the stats page.
    static let wood = Color(hex: 0xEDE4CF)
    static let woodRing = Color(hex: 0x8B7552)
    static let bark = Color(hex: 0x6E5B3E)

    static let mossNSColor = NSColor(hex: 0x46752F)
    static let groundNSColor = NSColor(hex: 0xF5F2EA)
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

extension Font {
    /// Light serif numerals (New York) for timers and stats.
    static func timer(_ size: CGFloat) -> Font {
        .system(size: size, weight: .light, design: .serif).monospacedDigit()
    }

    /// Serif headings.
    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .serif)
    }
}
