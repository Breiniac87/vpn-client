import SwiftUI

// MARK: - Branded App Logo Badge (Exact Branded Icon from User Image)
public struct BrandedAppLogoBadge: View {
    public var size: CGFloat = 24
    
    public init(size: CGFloat = 24) {
        self.size = size
    }
    
    public var body: some View {
        if let image = loadAppIcon() {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            fallbackBadge
        }
    }
    
    private func loadAppIcon() -> NSImage? {
        if let path = Bundle.main.path(forResource: "AppIcon", ofType: "png"),
           let img = NSImage(contentsOfFile: path) {
            return img
        }
        if let path = Bundle.main.path(forResource: "AppIcon", ofType: "icns"),
           let img = NSImage(contentsOfFile: path) {
            return img
        }
        if let img = NSImage(contentsOfFile: "Resources/AppIcon.png") {
            return img
        }
        return nil
    }
    
    private var fallbackBadge: some View {
        let cornerRadius = size * 0.224
        let borderWidth = max(0.8, size * 0.025)
        let shadowRadius = max(3.0, size * 0.06)
        
        return ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color(hex: "08090D"))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(ModernMacTheme.neonYellow.opacity(0.35), lineWidth: borderWidth)
                )
            
            ZStack {
                Image(systemName: "shield.fill")
                    .font(.system(size: size * 0.58, weight: .bold))
                    .foregroundStyle(ModernMacTheme.neonYellow)
                
                Text("X")
                    .font(.system(size: size * 0.35, weight: .black, design: .rounded))
                    .foregroundStyle(Color(hex: "08090D"))
                    .offset(y: -size * 0.02)
            }
            .shadow(color: ModernMacTheme.neonYellow.opacity(0.6), radius: shadowRadius)
        }
        .frame(width: size, height: size)
    }
}
