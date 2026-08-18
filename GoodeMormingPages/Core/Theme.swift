import AppKit
import SwiftUI

/// Ensō's own two palettes. The light ground is a cool near-white; the dark one
/// pairs charcoal with a warm parchment rather than white, which is why long
/// sessions in the dark don't glare.
///
/// The greens are the word-goal colour. One green cannot hold its contrast
/// against both grounds, so there are two.
struct Theme {
    let page: Color
    let ink: Color
    let goalMet: Color

    /// AppKit equivalents, for the text view and caret.
    let pageNS: NSColor
    let inkNS: NSColor

    static let light = Theme(
        page: Color(hex: 0xFAFAFA),
        ink: Color(hex: 0x333333),
        goalMet: Color(hex: 0x2F6F4E),
        pageNS: NSColor(hex: 0xFAFAFA),
        inkNS: NSColor(hex: 0x333333)
    )

    static let dark = Theme(
        page: Color(hex: 0x212121),
        ink: Color(hex: 0xE3DAC4),
        goalMet: Color(hex: 0x7FB894),
        pageNS: NSColor(hex: 0x212121),
        inkNS: NSColor(hex: 0xE3DAC4)
    )

    static func forScheme(_ scheme: ColorScheme) -> Theme {
        scheme == .dark ? .dark : .light
    }

    /// The colour of the goal line.
    ///
    /// Green once you have arrived, and it stays green for the session --
    /// `hasHitGoal` is latched, so deleting a word does not take the morning
    /// back off you.
    func goalBarColor(hasHitGoal: Bool) -> Color {
        hasHitGoal ? goalMet : ink
    }
}

extension Appearance {
    /// What to hand `preferredColorScheme`. `nil` means "leave it to macOS".
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    /// The scheme to actually draw with, given what the system is currently on.
    ///
    /// The editor resolves this itself rather than reading the environment back
    /// out after `preferredColorScheme`, so the scrims and the caret can never
    /// be a frame behind the ground they have to match exactly.
    func resolved(system: ColorScheme) -> ColorScheme {
        colorScheme ?? system
    }
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

/// EB Garamond if it has been vendored into the bundle, Iowan Old Style if not
/// (it ships with macOS), and the system serif as a last resort.
enum Typeface {
    static func editor(size: CGFloat = Metrics.baseFontSize) -> NSFont {
        for name in ["EBGaramond-Regular", "EB Garamond", "Iowan Old Style"] {
            if let font = NSFont(name: name, size: size) { return font }
        }
        return NSFont.systemFont(ofSize: size)
    }
}
