import SwiftUI

/// Контейнер группы настроек в стиле macOS System Settings (Inset Grouped)
public struct SettingsCardGroup<Content: View>: View {
    public let title: String?
    public let subtitle: String?
    public let content: Content
    
    public init(
        title: String? = nil,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title = title {
                HStack {
                    Text(title)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.55))
                    
                    Spacer()
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.35))
                    }
                }
                .padding(.horizontal, 4)
            }
            
            VStack(spacing: 0) {
                content
            }
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                    )
            )
        }
    }
}

/// Стандартизированная строка настройки фиксированной высоты (~38-42px)
public struct SettingsRowView<Control: View>: View {
    public let icon: String?
    public let iconColor: Color
    public let title: String
    public let badge: String?
    public let badgeColor: Color
    public let info: (title: String, summary: String, details: String?, recommendation: String?)?
    public let control: Control
    
    public init(
        icon: String? = nil,
        iconColor: Color = ModernMacTheme.cyanAccent,
        title: String,
        badge: String? = nil,
        badgeColor: Color = ModernMacTheme.neonGreen,
        info: (title: String, summary: String, details: String?, recommendation: String?)? = nil,
        @ViewBuilder control: () -> Control
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.badge = badge
        self.badgeColor = badgeColor
        self.info = info
        self.control = control()
    }
    
    public var body: some View {
        HStack(spacing: 10) {
            // Иконка параметра
            if let icon = icon {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 24, height: 24)
                    
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(iconColor)
                }
            }
            
            // Название параметра и опциональный бейдж
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                
                if let badge = badge {
                    Text(badge)
                        .font(.system(size: 8, weight: .heavy, design: .monospaced))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(Capsule().fill(badgeColor.opacity(0.2)))
                        .foregroundStyle(badgeColor)
                }
            }
            
            Spacer()
            
            // Интерактивный элемент управления
            control
            
            // Пиктограмма (i) с тултипом и поповером
            if let info = info {
                InfoPopoverButton(
                    title: info.title,
                    summary: info.summary,
                    details: info.details,
                    recommendation: info.recommendation
                )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(minHeight: 38)
    }
}
