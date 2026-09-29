import SwiftUI

/// Нативная радиокнопка в точности по референсу macOS (System Settings / Оформление)
/// - Выбранное состояние: сплошной акцентный круг (Neon Yellow #FFE600) с черной точкой в центре.
/// - Невыбранное состояние: приглушенный темно-серый круг без внутренней точки.
/// - Плавная пружинная анимация появления точки и смены цвета.
public struct MacRadioButton: View {
    public let isSelected: Bool
    public var accentColor: Color = ModernMacTheme.neonYellow
    public var action: () -> Void
    
    public init(
        isSelected: Bool,
        accentColor: Color = ModernMacTheme.neonYellow,
        action: @escaping () -> Void
    ) {
        self.isSelected = isSelected
        self.accentColor = accentColor
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            ZStack {
                // Внешний круг (акцентный или приглушенный серый)
                Circle()
                    .fill(
                        isSelected
                            ? accentColor
                            : Color.white.opacity(0.18)
                    )
                    .frame(width: 14, height: 14)
                    .overlay(
                        Circle()
                            .strokeBorder(
                                isSelected
                                    ? accentColor.opacity(0.8)
                                    : Color.white.opacity(0.15),
                                lineWidth: 0.5
                            )
                    )
                    .shadow(color: Color.black.opacity(isSelected ? 0.35 : 0.2), radius: 1, x: 0, y: 0.5)
                
                // Внутренняя черная точка в центре (появляется при выборе)
                Circle()
                    .fill(Color.black)
                    .frame(width: 5, height: 5)
                    .opacity(isSelected ? 1.0 : 0.0)
                    .scaleEffect(isSelected ? 1.0 : 0.2)
            }
            .frame(width: 20, height: 20)
            .contentShape(Rectangle())
            .animation(.spring(response: 0.22, dampingFraction: 0.72), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}
