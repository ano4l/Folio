import SwiftUI
import UIKit

/// Apple HIG semantic palette. Every token is a *dynamic* color so the app
/// adapts automatically to Light Mode, Dark Mode, and Increase Contrast
/// without any per-view branching.
enum AppColors {
    // Accents — matched to Apple's system accent hues in both appearances.
    static let teal = Color.dynamic(light: 0x007AFF, dark: 0x0A84FF)          // System Blue
    static let tealAccent = Color.dynamic(light: 0x30B0C7, dark: 0x40C8E0)     // SF Cyan
    static let tealLight = Color.dynamic(light: 0xE5F1FF, dark: 0x0A2540)
    static let navy = Color.dynamic(light: 0x5856D6, dark: 0x7D7AFF)           // System Indigo
    static let navyLight = Color.dynamic(light: 0xEEEEFF, dark: 0x1E1D42)
    static let purple = Color.dynamic(light: 0xAF52DE, dark: 0xBF5AF2)         // System Purple
    static let purpleLight = Color.dynamic(light: 0xF7ECFB, dark: 0x2E1B38)
    static let success = Color.dynamic(light: 0x34C759, dark: 0x30D158)        // System Green
    static let successLight = Color.dynamic(light: 0xE8F9ED, dark: 0x0E2C18)
    static let danger = Color.dynamic(light: 0xFF3B30, dark: 0xFF453A)         // System Red
    static let dangerLight = Color.dynamic(light: 0xFFEBEA, dark: 0x3A1512)
    static let warning = Color.dynamic(light: 0xFF9500, dark: 0xFF9F0A)        // System Orange
    static let warningLight = Color.dynamic(light: 0xFFF4E5, dark: 0x3A2409)

    // Text and surfaces — mapped to Apple's system semantic colors so that
    // vibrancy, contrast settings, and elevation behave natively.
    static let ink = Color(uiColor: .label)
    static let slate = Color(uiColor: .secondaryLabel)
    static let paper = Color(uiColor: .systemGroupedBackground)
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
    static let elevated = Color(uiColor: .tertiarySystemGroupedBackground)
    static let line = Color(uiColor: .separator)
}

extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }

    /// Builds a trait-reactive color that resolves per appearance.
    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(rgbHex: dark)
                : UIColor(rgbHex: light)
        })
    }
}

extension UIColor {
    convenience init(rgbHex: UInt32) {
        self.init(
            red: CGFloat((rgbHex >> 16) & 0xFF) / 255.0,
            green: CGFloat((rgbHex >> 8) & 0xFF) / 255.0,
            blue: CGFloat(rgbHex & 0xFF) / 255.0,
            alpha: 1.0
        )
    }
}

/// Dynamic Type aware typography. Using relative sizing keeps the SF Pro
/// optical hierarchy while still scaling for every accessibility text size.
enum AppFont {
    static func headlineLarge() -> Font { .system(.largeTitle, design: .default).weight(.bold) }
    static func headlineMedium() -> Font { .system(.title2, design: .default).weight(.bold) }
    static func headlineSmall() -> Font { .system(.headline, design: .default).weight(.semibold) }
    static func bodyLarge() -> Font { .system(.body) }
    static func bodyMedium() -> Font { .system(.subheadline) }
    static func labelSmall() -> Font { .system(.caption).weight(.medium) }

    /// Fixed-metric variants for compact chrome (badges, docks) that must not
    /// break layout at the largest accessibility sizes.
    static func chrome(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
}
