import Foundation
import SwiftUI
import AppKit

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

struct IconBadgeView: View {
    let size: CGFloat
    let neonYellow = Color(hex: "FFE600")
    
    var body: some View {
        let cornerRadius = size * 0.224
        let borderWidth = max(1.0, size * 0.025)
        let shadowRadius = max(3.0, size * 0.06)
        
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color(hex: "08090D"))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(neonYellow.opacity(0.35), lineWidth: borderWidth)
                )
            
            ZStack {
                Image(systemName: "shield.fill")
                    .font(.system(size: size * 0.58, weight: .bold))
                    .foregroundStyle(neonYellow)
                
                Text("X")
                    .font(.system(size: size * 0.35, weight: .black, design: .rounded))
                    .foregroundStyle(Color(hex: "08090D"))
                    .offset(y: -size * 0.02)
            }
            .shadow(color: neonYellow.opacity(0.6), radius: shadowRadius)
        }
        .frame(width: size, height: size)
    }
}

@MainActor
func renderPNG(pixelSize: Int) -> Data? {
    let view = IconBadgeView(size: CGFloat(pixelSize))
        .frame(width: CGFloat(pixelSize), height: CGFloat(pixelSize))
    let renderer = ImageRenderer(content: view)
    renderer.scale = 1.0
    guard let nsImage = renderer.nsImage,
          let tiff = nsImage.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else {
        return nil
    }
    return png
}

let sema = DispatchSemaphore(value: 0)

DispatchQueue.main.async {
    let fileManager = FileManager.default
    let iconsetPath = "Resources/AppIcon.iconset"
    try? fileManager.removeItem(atPath: iconsetPath)
    try? fileManager.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)
    
    let specs: [(name: String, px: Int)] = [
        ("icon_16x16.png", 16),
        ("icon_16x16@2x.png", 32),
        ("icon_32x32.png", 32),
        ("icon_32x32@2x.png", 64),
        ("icon_128x128.png", 128),
        ("icon_128x128@2x.png", 256),
        ("icon_256x256.png", 256),
        ("icon_256x256@2x.png", 512),
        ("icon_512x512.png", 512),
        ("icon_512x512@2x.png", 1024)
    ]
    
    for spec in specs {
        guard let data = renderPNG(pixelSize: spec.px) else {
            print("Failed to render \(spec.name)")
            continue
        }
        let url = URL(fileURLWithPath: "\(iconsetPath)/\(spec.name)")
        try? data.write(to: url)
        print("Generated \(spec.name) (\(spec.px)x\(spec.px))")
    }
    
    if let fullData = renderPNG(pixelSize: 1024) {
        try? fullData.write(to: URL(fileURLWithPath: "Resources/AppIcon.png"))
        print("Generated Resources/AppIcon.png (1024x1024)")
    }
    
    sema.signal()
}

while sema.wait(timeout: .now() + 0.1) == .timedOut {
    RunLoop.main.run(mode: .default, before: .distantPast)
}
print("Done rendering iconset!")
