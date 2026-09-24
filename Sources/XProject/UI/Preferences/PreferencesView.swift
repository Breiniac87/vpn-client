import SwiftUI

public enum PreferencesTab: String, CaseIterable, Identifiable {
    case servers = "servers"
    case routing = "routing"
    case network = "network"
    case logs = "logs"
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .servers: return "Подписки/Серверы"
        case .routing: return "Маршрутизация"
        case .network: return "Сеть"
        case .logs: return "Журналы"
        }
    }
    
    public var iconName: String {
        switch self {
        case .servers: return "server.rack"
        case .routing: return "point.topleft.and.bottomright.filled.curvepath"
        case .network: return "shield.checkered"
        case .logs: return "terminal"
        }
    }
}

public struct PreferencesView: View {
    @Bindable var appState: AppState
    @State private var selectedTab: PreferencesTab = .servers
    
    var onScanScreenQR: (() -> Void)?
    var onImportClipboard: (() -> Void)?
    var onImportJsonFile: (() -> Void)?
    
    public init(
        appState: AppState,
        onScanScreenQR: (() -> Void)? = nil,
        onImportClipboard: (() -> Void)? = nil,
        onImportJsonFile: (() -> Void)? = nil
    ) {
        self.appState = appState
        self.onScanScreenQR = onScanScreenQR
        self.onImportClipboard = onImportClipboard
        self.onImportJsonFile = onImportJsonFile
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - Native-style Segmented Toolbar
            HStack(spacing: 12) {
                ForEach(PreferencesTab.allCases) { tab in
                    Button(action: {
                        withAnimation(ModernMacTheme.smoothSpring) {
                            selectedTab = tab
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: tab.iconName)
                                .font(.system(size: 13, weight: .semibold))
                            Text(tab.title)
                                .font(.system(size: 13, weight: .medium))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(selectedTab == tab ? Color.white.opacity(0.12) : Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(selectedTab == tab ? Color.white.opacity(0.15) : Color.clear, lineWidth: 0.5)
                                )
                        )
                        .foregroundStyle(selectedTab == tab ? Color.primary : Color.secondary)
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
            
            Divider()
                .opacity(0.4)
            
            // MARK: - Tab Content
            Group {
                switch selectedTab {
                case .servers:
                    ServersTab(
                        appState: appState,
                        onScanScreenQR: onScanScreenQR,
                        onImportClipboard: onImportClipboard,
                        onImportJsonFile: onImportJsonFile
                    )
                case .routing:
                    RoutingTab(appState: appState)
                case .network:
                    NetworkTab(appState: appState)
                case .logs:
                    LogsTab(appState: appState)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            Divider()
                .opacity(0.3)
            
            // MARK: - Bottom Control & Connection Bar
            BottomControlBarView(appState: appState)
        }
        .frame(width: 720, height: 550)
        .background(
            VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow)
        )
    }
}

// MARK: - Bottom Control & Connection Bar
struct BottomControlBarView: View {
    @Bindable var appState: AppState
    
    var body: some View {
        HStack(spacing: 16) {
            // 1. Status Indicator & Info
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(appState.connectionStatus.statusColor.opacity(0.2))
                        .frame(width: 32, height: 32)
                    
                    Circle()
                        .fill(appState.connectionStatus.statusColor)
                        .frame(width: 12, height: 12)
                        .neonGlow(color: appState.connectionStatus.statusColor, radius: 6, isActive: appState.connectionStatus == .connected)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(appState.connectionStatus.localizedDescription)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.primary)
                        
                        if appState.connectionStatus == .connected {
                            Text("• \(appState.formattedUptime)")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(ModernMacTheme.cyanAccent)
                        }
                    }
                    
                    if let server = appState.selectedServer {
                        Text("Сервер: \(server.name)")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else {
                        Text("Сервер не выбран")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // 2. Active Ping & Traffic counters
            if appState.connectionStatus == .connected {
                HStack(spacing: 10) {
                    if let ping = appState.activePing {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(ping < 80 ? ModernMacTheme.neonGreen : (ping < 160 ? .orange : .red))
                                .frame(width: 6, height: 6)
                            Text("\(ping) ms")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.primary)
                        }
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(ModernMacTheme.neonGreen)
                        Text(formatBytes(appState.bytesIn))
                            .font(.system(size: 10, design: .monospaced))
                    }
                    .foregroundStyle(.secondary)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(ModernMacTheme.cyanAccent)
                        Text(formatBytes(appState.bytesOut))
                            .font(.system(size: 10, design: .monospaced))
                    }
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.05))
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5))
                )
            }
            
            // 3. Tactile Launch / Power Button
            Button(action: {
                withAnimation(ModernMacTheme.bouncySpring) {
                    appState.toggleConnection()
                }
            }) {
                HStack(spacing: 8) {
                    if appState.connectionStatus == .connecting || appState.connectionStatus == .disconnecting {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 14, height: 14)
                    } else {
                        Image(systemName: "power")
                            .font(.system(size: 13, weight: .bold))
                    }
                    
                    Text(buttonTitle)
                        .font(.system(size: 13, weight: .semibold))
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(appState.connectionStatus == .connected ? ModernMacTheme.neonGreen : Color.white.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(appState.connectionStatus == .connected ? ModernMacTheme.neonGreen : Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
                .foregroundStyle(appState.connectionStatus == .connected ? Color.black : Color.primary)
                .neonGlow(color: ModernMacTheme.neonGreen, radius: 8, isActive: appState.connectionStatus == .connected)
            }
            .buttonStyle(.plain)
            .disabled(appState.selectedServer == nil)
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.6))
    }
    
    private var buttonTitle: String {
        switch appState.connectionStatus {
        case .connected: return "Отключить"
        case .connecting: return "Подключение..."
        case .disconnecting: return "Отключение..."
        case .disconnected, .error: return "Подключить"
        }
    }
    
    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

// AppKit VisualEffectView wrapper
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
