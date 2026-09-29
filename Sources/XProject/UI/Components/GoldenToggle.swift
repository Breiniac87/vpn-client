import SwiftUI

/// Фирменный золотисто-янтарный тумблер (переключатель/радиобаттон)
/// в точности по визуальному референсу пользователя: капсульный трек и овальный ползунок.
public struct GoldenToggle: View {
    @Binding public var isOn: Bool
    public var accentColor: Color?
    public var onToggle: ((Bool) -> Void)?
    @Environment(\.isEnabled) private var isEnabled: Bool
    
    public init(isOn: Binding<Bool>, accentColor: Color? = nil, onToggle: ((Bool) -> Void)? = nil) {
        self._isOn = isOn
        self.accentColor = accentColor
        self.onToggle = onToggle
    }
    
    public var body: some View {
        Button(action: {
            guard isEnabled else { return }
            withAnimation(.spring(response: 0.22, dampingFraction: 0.72)) {
                isOn.toggle()
            }
            onToggle?(isOn)
        }) {
            ZStack(alignment: isOn ? .trailing : .leading) {
                // Фоновый трек в форме капсулы
                Capsule(style: .continuous)
                    .fill(
                        isOn
                            ? LinearGradient(
                                colors: activeTrackColors,
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            : LinearGradient(
                                colors: [Color.white.opacity(0.14), Color.white.opacity(0.08)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(
                                isOn
                                    ? activeStrokeColor
                                    : Color.white.opacity(0.14),
                                lineWidth: 0.75
                            )
                    )
                    .frame(width: 38, height: 20)
                
                // Овальный ползунок (Thumb) цвета слоновой кости / теплого белого
                Capsule(style: .continuous)
                    .fill(Color(hex: "FFFDF5"))
                    .shadow(color: Color.black.opacity(isOn ? 0.25 : 0.32), radius: 2, x: 0, y: 1)
                    .frame(width: 22, height: 16)
                    .padding(.horizontal, 2)
            }
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1.0 : 0.45)
        .fixedSize()
    }
    
    private var activeTrackColors: [Color] {
        if let custom = accentColor {
            return [custom, custom.opacity(0.82)]
        }
        return [Color(hex: "F8C010"), Color(hex: "E8B010")]
    }
    
    private var activeStrokeColor: Color {
        if let custom = accentColor {
            return custom.opacity(0.7)
        }
        return Color(hex: "D89E08").opacity(0.7)
    }
}
