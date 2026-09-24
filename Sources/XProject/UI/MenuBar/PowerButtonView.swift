import SwiftUI
import AppKit

public struct PowerButtonView: View {
    let status: ConnectionStatus
    let action: () -> Void
    
    @State private var isHovered: Bool = false
    @State private var isPressed: Bool = false
    @State private var pulseAnimation: Bool = false
    
    private let buttonSize: CGFloat = 84
    
    public init(status: ConnectionStatus, action: @escaping () -> Void) {
        self.status = status
        self.action = action
    }
    
    public var body: some View {
        Button(action: {
            // macOS haptic feedback
            NSHapticFeedbackManager.defaultPerformer.perform(
                .generic,
                performanceTime: .default
            )
            action()
        }) {
            ZStack {
                // MARK: - Ambient Radial Halo (constant layout frame to prevent jumping)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                ModernMacTheme.neonYellow.opacity(0.38),
                                ModernMacTheme.neonYellow.opacity(0.0)
                            ],
                            center: .center,
                            startRadius: buttonSize * 0.25,
                            endRadius: buttonSize * 0.72
                        )
                    )
                    .frame(width: buttonSize + 36, height: buttonSize + 36)
                    .blur(radius: 8)
                    .opacity(status == .connected ? 1.0 : 0.0)
                    .animation(ModernMacTheme.smoothSpring, value: status)
                
                if status == .connecting {
                    Circle()
                        .stroke(Color.orange.opacity(0.4), lineWidth: 3)
                        .frame(width: buttonSize + (pulseAnimation ? 24 : 8),
                               height: buttonSize + (pulseAnimation ? 24 : 8))
                        .scaleEffect(pulseAnimation ? 1.08 : 0.95)
                        .opacity(pulseAnimation ? 0.0 : 0.8)
                        .animation(
                            .easeInOut(duration: 1.2).repeatForever(autoreverses: false),
                            value: pulseAnimation
                        )
                }
                
                // MARK: - Outer Glass Ring
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: buttonSize, height: buttonSize)
                    .overlay(
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: rimColors,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(
                        color: shadowColor,
                        radius: status == .connected ? 18 : 6,
                        x: 0,
                        y: status == .connected ? 0 : 3
                    )
                
                // MARK: - Core Button Disc
                Circle()
                    .fill(coreGradient)
                    .frame(width: buttonSize - 12, height: buttonSize - 12)
                    .overlay(
                        Circle()
                            .strokeBorder(
                                Color.white.opacity(status == .connected ? 0.3 : 0.08),
                                lineWidth: 0.5
                            )
                    )
                
                // MARK: - Power Icon
                Image(systemName: "power")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(iconGradient)
                    .shadow(
                        color: status == .connected ? Color.black.opacity(0.3) : Color.clear,
                        radius: 2,
                        x: 0,
                        y: 1
                    )
                    .rotationEffect(.degrees(status == .connecting ? 180 : 0))
                    .animation(
                        status == .connecting
                            ? .linear(duration: 2).repeatForever(autoreverses: false)
                            : ModernMacTheme.smoothSpring,
                        value: status
                    )
            }
            .frame(width: buttonSize + 36, height: buttonSize + 36)
            .scaleEffect(isPressed ? 0.94 : (isHovered ? 1.03 : 1.0))
            .animation(ModernMacTheme.smoothSpring, value: isHovered)
            .animation(ModernMacTheme.smoothSpring, value: isPressed)
        }
        .frame(width: buttonSize + 36, height: buttonSize + 36)
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .onAppear {
            if status == .connecting {
                pulseAnimation = true
            }
        }
        .onChange(of: status) { _, newStatus in
            pulseAnimation = (newStatus == .connecting)
        }
    }
    
    // MARK: - Dynamic Aesthetics
    
    private var shadowColor: Color {
        switch status {
        case .connected:
            return ModernMacTheme.neonYellow.opacity(0.65)
        case .connecting:
            return Color.orange.opacity(0.4)
        case .disconnected, .disconnecting, .error:
            return Color.black.opacity(0.3)
        }
    }
    
    private var rimColors: [Color] {
        switch status {
        case .connected:
            return [
                ModernMacTheme.neonYellow,
                ModernMacTheme.neonYellow.opacity(0.35)
            ]
        case .connecting:
            return [
                Color.orange,
                Color.orange.opacity(0.4)
            ]
        case .disconnected, .disconnecting, .error:
            return [
                Color.white.opacity(isHovered ? 0.35 : 0.18),
                Color.white.opacity(0.04)
            ]
        }
    }
    
    private var coreGradient: LinearGradient {
        switch status {
        case .connected:
            return LinearGradient(
                colors: [
                    ModernMacTheme.neonYellow,
                    Color(hex: "DCA800")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .connecting:
            return LinearGradient(
                colors: [
                    Color.orange.opacity(0.85),
                    Color.orange.opacity(0.55)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .disconnected, .disconnecting, .error:
            return LinearGradient(
                colors: [
                    Color.white.opacity(isHovered ? 0.14 : 0.08),
                    Color.white.opacity(isHovered ? 0.06 : 0.02)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private var iconGradient: LinearGradient {
        switch status {
        case .connected:
            return LinearGradient(
                colors: [
                    Color(hex: "08090D"),
                    Color(hex: "181B24")
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .connecting:
            return LinearGradient(
                colors: [Color.white, Color.white.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .disconnected, .disconnecting, .error:
            return LinearGradient(
                colors: [
                    Color.secondary.opacity(isHovered ? 1.0 : 0.7),
                    Color.secondary.opacity(isHovered ? 0.8 : 0.5)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}
