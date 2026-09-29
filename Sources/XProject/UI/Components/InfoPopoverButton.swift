import SwiftUI

/// Интерактивная пиктограмма (i) с поддержкой быстрого тултипа при наведении
/// и развернутого поповера с рекомендациями при клике (в стиле macOS System Settings).
public struct InfoPopoverButton: View {
    public let title: String
    public let summary: String
    public var details: String? = nil
    public var recommendation: String? = nil
    
    @State private var isShowingPopover: Bool = false
    @State private var isHovered: Bool = false
    
    public init(
        title: String,
        summary: String,
        details: String? = nil,
        recommendation: String? = nil
    ) {
        self.title = title
        self.summary = summary
        self.details = details
        self.recommendation = recommendation
    }
    
    public var body: some View {
        Button(action: {
            isShowingPopover.toggle()
        }) {
            Image(systemName: isHovered ? "info.circle.fill" : "info.circle")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isHovered ? ModernMacTheme.cyanAccent : Color.white.opacity(0.4))
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(summary)
        .onHover { hovering in
            isHovered = hovering
        }
        .popover(isPresented: $isShowingPopover, arrowEdge: .trailing) {
            VStack(alignment: .leading, spacing: 10) {
                // Заголовок
                HStack(spacing: 6) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(ModernMacTheme.cyanAccent)
                        .font(.system(size: 13, weight: .bold))
                    
                    Text(title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                }
                
                // Основное краткое назначение
                Text(summary)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                
                // Детальное пояснение (опционально)
                if let details = details, !details.isEmpty {
                    Text(details)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                // Практическая рекомендация (опционально)
                if let rec = recommendation, !rec.isEmpty {
                    HStack(spacing: 5) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(ModernMacTheme.neonYellow)
                        Text(rec)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(ModernMacTheme.neonYellow.opacity(0.9))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(ModernMacTheme.neonYellow.opacity(0.12))
                            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(ModernMacTheme.neonYellow.opacity(0.3), lineWidth: 0.5))
                    )
                }
            }
            .padding(14)
            .frame(width: 280)
            .background(Color(hex: "151720"))
        }
    }
}
