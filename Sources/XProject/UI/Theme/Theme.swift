import SwiftUI
import AppKit

public struct ModernMacTheme {
    // MARK: - Modern Apple HIG Colors (macOS / iOS Dark Mode Aesthetic)
    public static let darkBackgroundTop = Color(hex: "111319")
    public static let darkBackgroundMid = Color(hex: "151720")
    public static let darkBackgroundBottom = Color(hex: "0C0D12")
    
    public static let cardSurface = Color(hex: "181B24")
    public static let cardSurfaceHeader = Color(hex: "202430")
    public static let cardSurfaceElevated = Color(hex: "252A38")
    
    public static let neonGreen = Color(red: 0.0, green: 0.98, blue: 0.45)
    public static let neonGreenGlow = Color(red: 0.0, green: 1.0, blue: 0.5, opacity: 0.4)
    public static let neonGreenSubtle = Color(red: 0.0, green: 0.98, blue: 0.45, opacity: 0.12)
    
    public static let deepDark = Color(hex: "101116")
    public static let cardBackground = Color(hex: "181B24").opacity(0.92)
    public static let cardHover = Color.white.opacity(0.06)
    
    public static let cyanAccent = Color(red: 0.0, green: 0.85, blue: 1.0)
    public static let orangeWarning = Color(red: 1.0, green: 0.62, blue: 0.1)
    public static let redDanger = Color(red: 1.0, green: 0.28, blue: 0.35)
    
    // MARK: - Neon Brand Accents
    public static let neonYellow = Color(hex: "FFE600")
    public static let neonYellowGlow = Color(hex: "FFE600").opacity(0.4)
    public static let neonYellowSubtle = Color(hex: "FFE600").opacity(0.12)
    
    // MARK: - Hairline & Card Borders
    public static let borderCard = Color.white.opacity(0.15)
    public static let borderHairline = Color.white.opacity(0.12)
    public static let borderSubtle = Color.white.opacity(0.06)
    
    // MARK: - Springs & Animations
    public static let springResponse: Double = 0.35
    public static let springDamping: Double = 0.72
    
    public static var smoothSpring: Animation {
        .spring(response: springResponse, dampingFraction: springDamping)
    }
    
    public static var bouncySpring: Animation {
        .spring(response: 0.4, dampingFraction: 0.6)
    }
}

// MARK: - View Modifiers for Glassmorphism
public struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 14
    var padding: CGFloat = 12
    var borderColor: Color = ModernMacTheme.borderHairline
    
    public func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(borderColor, lineWidth: 0.5)
                    )
                    .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 4)
            )
    }
}

public extension View {
    func glassCard(cornerRadius: CGFloat = 14, padding: CGFloat = 12, borderColor: Color = ModernMacTheme.borderHairline) -> some View {
        self.modifier(GlassCardModifier(cornerRadius: cornerRadius, padding: padding, borderColor: borderColor))
    }
    
    func neonGlow(color: Color = ModernMacTheme.neonGreen, radius: CGFloat = 16, isActive: Bool = true) -> some View {
        self.shadow(color: isActive ? color.opacity(0.55) : Color.clear, radius: radius, x: 0, y: 0)
    }
}

// MARK: - Color Hex Extension
public extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
