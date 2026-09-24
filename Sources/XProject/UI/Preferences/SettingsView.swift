import SwiftUI

public enum SettingsTab: String, CaseIterable, Identifiable {
    case routing = "routing"
    case network = "network"
    case logs = "logs"
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .routing: return "Маршрутизация"
        case .network: return "Сеть и DNS"
        case .logs: return "Журналы Xray"
        }
    }
    
    public var icon: String {
        switch self {
        case .routing: return "point.topleft.and.bottomright.filled.curvepath"
        case .network: return "network"
        case .logs: return "terminal"
        }
    }
}

public struct SettingsContainerView: View {
    @Bindable var appState: AppState
    @State private var selectedTab: SettingsTab
    var onClose: () -> Void
    
    public init(appState: AppState, initialTab: SettingsTab = .routing, onClose: @escaping () -> Void) {
        self.appState = appState
        self._selectedTab = State(initialValue: initialTab)
        self.onClose = onClose
    }
    
    public var body: some View {
        ZStack {
            // Background Apple HIG Dark Gradient
            LinearGradient(
                colors: [
                    ModernMacTheme.darkBackgroundTop,
                    ModernMacTheme.darkBackgroundMid,
                    ModernMacTheme.darkBackgroundBottom
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // MARK: - Window Header Bar
                HStack(spacing: 14) {
                    // Title & Badge (Clean single line, never wraps)
                    HStack(spacing: 8) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(ModernMacTheme.cyanAccent)
                        
                        Text("Настройки")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    
                    Spacer()
                    
                    // Centered Tab Buttons
                    HStack(spacing: 6) {
                        ForEach(SettingsTab.allCases) { tab in
                            Button(action: {
                                withAnimation(ModernMacTheme.smoothSpring) {
                                    selectedTab = tab
                                }
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: tab.icon)
                                        .font(.system(size: 11, weight: .semibold))
                                    Text(tab.title)
                                        .font(.system(size: 12, weight: selectedTab == tab ? .bold : .medium))
                                        .lineLimit(1)
                                        .fixedSize(horizontal: true, vertical: false)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(selectedTab == tab ? ModernMacTheme.cyanAccent.opacity(0.2) : Color.white.opacity(0.04))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .strokeBorder(selectedTab == tab ? ModernMacTheme.cyanAccent.opacity(0.5) : Color.clear, lineWidth: 1)
                                        )
                                )
                                .foregroundStyle(selectedTab == tab ? ModernMacTheme.cyanAccent : .white.opacity(0.65))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    Spacer()
                    
                    // Done / Close Button
                    Button(action: onClose) {
                        HStack(spacing: 5) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                            Text("Готово")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.white.opacity(0.08))
                                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5))
                        )
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .layoutPriority(2)
                    .keyboardShortcut(.defaultAction)
                }
                .frame(height: 52)
                .padding(.horizontal, 18)
                .background(Color.white.opacity(0.02))
                
                Divider()
                    .opacity(0.15)
                
                // MARK: - Tab Content Area (Fully Resizable)
                Group {
                    switch selectedTab {
                    case .routing:
                        RoutingTab(appState: appState)
                    case .network:
                        NetworkTab(appState: appState)
                    case .logs:
                        LogsTab(appState: appState)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 720, minHeight: 520)
        .tint(ModernMacTheme.cyanAccent)
    }
}
