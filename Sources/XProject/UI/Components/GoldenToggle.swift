import SwiftUI

/// Фирменный золотисто-янтарный тумблер (переключатель/радиобаттон)
/// в точности по визуальному референсу пользователя: капсульный трек и овальный ползунок.
public struct GoldenToggle: View {
    @Binding public var isOn: Bool
    public var onToggle: ((Bool) -> Void)?
    
    public init(isOn: Binding<Bool>, onToggle: ((Bool) -> Void)? = nil) {
        self._isOn = isOn
        self.onToggle = onToggle
    }
    
    public var body: some View {
        Button(action: {
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
                                colors: [Color(hex: "F8C010"), Color(hex: "E8B010")],
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
                                    ? Color(hex: "D89E08").opacity(0.7)
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
        .fixedSize()
    }
}
