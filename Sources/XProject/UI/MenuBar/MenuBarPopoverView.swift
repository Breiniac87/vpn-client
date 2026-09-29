import SwiftUI

public struct MenuBarPopoverView: View {
    @Bindable var appState: AppState
    let onOpenPreferences: () -> Void
    let onQuit: () -> Void
    
    public init(
        appState: AppState,
        onOpenPreferences: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.appState = appState
        self.onOpenPreferences = onOpenPreferences
        self.onQuit = onQuit
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            // MARK: - Header
            HStack {
                HStack(spacing: 8) {
                    BrandedAppLogoBadge(size: 22)
                    
                    Text("X-project")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                
                Spacer()
                
                // Auto-connect Quick Toggle
                HStack(spacing: 5) {
                    Text("Автозапуск")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                    
                    GoldenToggle(isOn: $appState.settings.autoConnectOnLaunch)
                }
                .help("Автоматически подключаться к VPN при запуске приложения")
                
                Spacer()
                
                // Status Pill
                HStack(spacing: 5) {
                    Circle()
                        .fill(appState.connectionStatus.statusColor)
                        .frame(width: 6, height: 6)
                        .neonGlow(color: appState.connectionStatus.statusColor, radius: 4, isActive: appState.connectionStatus == .connected)
                    
                    Text(appState.connectionStatus.localizedDescription)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3.5)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.06))
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5))
                )
            }
            .padding(.horizontal, 6)
            .padding(.top, 2)
            
            // MARK: - Hero Power Button & Status
            VStack(spacing: 6) {
                PowerButtonView(status: appState.connectionStatus) {
                    withAnimation(ModernMacTheme.bouncySpring) {
                        appState.toggleConnection()
                    }
                }
                
                VStack(spacing: 2) {
                    Text(appState.connectionStatus == .connected ? "ПОДКЛЮЧЕНО" : (appState.connectionStatus.isBusy ? "ПОДКЛЮЧЕНИЕ..." : "ОТКЛЮЧЕН"))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .tracking(1.0)
                        .foregroundStyle(
                            appState.connectionStatus == .connected
                                ? ModernMacTheme.neonYellow
                                : (appState.connectionStatus.isBusy ? ModernMacTheme.cyanAccent : .white.opacity(0.75))
                        )
                    
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 9))
                        Text(appState.connectionStatus == .connected ? appState.formattedUptime : "00:00:00")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                    }
                    .foregroundStyle(.white.opacity(0.6))
                    .opacity(appState.connectionStatus == .connected ? 1.0 : 0.0)
                    .animation(ModernMacTheme.smoothSpring, value: appState.connectionStatus)
                }
                .frame(height: 32)
            }
            .padding(.vertical, 2)
            
            
            // MARK: - Subscription Banner (Happ Style)
            if let activeSub = appState.subscriptions.first {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(ModernMacTheme.cyanAccent)
                        
                        Text(activeSub.name)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Button(action: {
                            Task {
                                await SubscriptionManager.shared.updateAllSubscriptions(in: appState)
                            }
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 10))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                        .help("Обновить подписку")
                    }
                    
                    HStack {
                        if !activeSub.formattedTraffic.isEmpty {
                            Text(activeSub.formattedTraffic)
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        Spacer()
                        if !activeSub.formattedExpireDate.isEmpty {
                            Text(activeSub.formattedExpireDate)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(activeSub.isExpired ? .red.opacity(0.85) : ModernMacTheme.cyanAccent)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.6)
                        )
                )
            }
            
            // MARK: - Direct Interactive Server Selector
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("СЕРВЕРЫ")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.5))
                    
                    Text("\(appState.servers.count)")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.white.opacity(0.08)))
                        .foregroundStyle(.white.opacity(0.7))
                    
                    Spacer()
                    
                    Button(action: {
                        appState.pingAllServers()
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 9))
                            Text("Пинг")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.white.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white.opacity(0.7))
                    .help("Проверить пинг всех серверов")
                }
                .padding(.horizontal, 4)
                
                if appState.servers.isEmpty {
                    VStack(spacing: 6) {
                        Text("Нет добавленных серверов")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.6))
                        Button("Открыть главное окно") {
                            onOpenPreferences()
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(ModernMacTheme.cyanAccent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.03))
                    )
                } else {
                    let serverCount = appState.servers.count
                    let calculatedHeight = min(CGFloat(max(serverCount, 1)) * 44.0, 185.0)
                    
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(spacing: 4) {
                            ForEach(appState.servers) { server in
                                MenuBarServerRow(
                                    server: server,
                                    isSelected: server.id == appState.selectedServer?.id,
                                    isConnected: appState.connectionStatus == .connected && server.id == appState.selectedServer?.id,
                                    onSelect: {
                                        withAnimation(ModernMacTheme.smoothSpring) {
                                            appState.selectServer(id: server.id)
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.trailing, 2)
                    }
                    .frame(height: calculatedHeight)
                }
            }
            

            
            // MARK: - Live Traffic Telemetry (when connected)
            if appState.connectionStatus == .connected {
                HStack(spacing: 16) {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(ModernMacTheme.neonGreen)
                        Text(formatBytes(appState.bytesIn))
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                    
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(ModernMacTheme.cyanAccent)
                        Text(formatBytes(appState.bytesOut))
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                        )
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            Divider()
                .opacity(0.18)
            
            // MARK: - Footer Actions
            HStack(spacing: 8) {
                MenuBarFooterActionButton(
                    title: "Главное",
                    iconName: "macwindow",
                    action: onOpenPreferences
                )
                
                MenuBarFooterActionButton(
                    title: "Настройки",
                    iconName: "gearshape.fill",
                    action: {
                        SettingsWindowController.shared.show(appState: appState)
                    }
                )
                
                MenuBarFooterActionButton(
                    title: "Выход",
                    iconName: "power",
                    isDestructive: true,
                    action: onQuit
                )
                .keyboardShortcut("q", modifiers: .command)
            }
            .padding(.top, 2)
        }
        .padding(14)
        .frame(width: 350)
        .background(
            ZStack {
                LinearGradient(
                    colors: [
                        ModernMacTheme.darkBackgroundTop,
                        ModernMacTheme.darkBackgroundMid,
                        ModernMacTheme.darkBackgroundBottom
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(ModernMacTheme.borderCard, lineWidth: 1.0)
            }
        )
    }
    
    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

// MARK: - Menu Bar Footer Action Button (Icon-Only, High Precision Compact)
struct MenuBarFooterActionButton: View {
    let title: String
    let iconName: String
    var isDestructive: Bool = false
    let action: () -> Void
    
    @State private var isHovered = false
    
    private var iconColor: Color {
        if isDestructive {
            return isHovered ? ModernMacTheme.redDanger : Color.white.opacity(0.75)
        } else {
            return isHovered ? Color.white : Color.white.opacity(0.8)
        }
    }
    
    private var backgroundColor: Color {
        if isDestructive {
            return isHovered ? ModernMacTheme.redDanger.opacity(0.18) : Color.white.opacity(0.06)
        } else {
            return isHovered ? Color.white.opacity(0.12) : Color.white.opacity(0.06)
        }
    }
    
    private var borderColor: Color {
        if isDestructive {
            return isHovered ? ModernMacTheme.redDanger.opacity(0.4) : Color.white.opacity(0.14)
        } else {
            return isHovered ? Color.white.opacity(0.28) : Color.white.opacity(0.14)
        }
    }
    
    var body: some View {
        Button(action: action) {
            Image(systemName: iconName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(maxWidth: .infinity)
                .frame(height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(backgroundColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(borderColor, lineWidth: 0.8)
                        )
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(title)
        .onHover { h in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovered = h
            }
        }
    }
}
