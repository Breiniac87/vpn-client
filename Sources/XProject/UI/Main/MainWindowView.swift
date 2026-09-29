import SwiftUI
import AppKit

public struct MainWindowView: View {
    @Bindable var appState: AppState
    
    @State private var showingAddSubscriptionSheet = false
    @State private var showingAddManualSheet = false
    @State private var editingServer: ServerProfile? = nil
    @State private var collapsedSubscriptionIds = Set<UUID>()
    @State private var isPingingActiveConnection = false
    
    // Callbacks for screen QR scan and clipboard
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
    
    // Standalone servers not belonging to any subscription
    private var standaloneServers: [ServerProfile] {
        appState.servers.filter { $0.subscriptionId == nil }
    }
    
    public var body: some View {
        ZStack {
            // MARK: - Rich Obsidian Apple HIG Dark Background
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
                // MARK: - Top Navigation Header
                topHeaderBar
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 4)
                
                // MARK: - Hero Power Button Section (Outside ScrollView: glow is NEVER clipped)
                heroPowerSection
                    .padding(.top, 4)
                    .padding(.bottom, 6)
                
                // MARK: - Scrollable Content
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 12) {
                        // 1-Click Routing Suggestion Banner (if offered by refreshed subscription)
                        if let suggestion = appState.pendingRoutingSuggestion {
                            routingSuggestionBanner(suggestion: suggestion)
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .scale(scale: 0.95)),
                                    removal: .opacity
                                ))
                        }
                        
                        // Standalone servers section (if any)
                        if !standaloneServers.isEmpty {
                            standaloneServersSection
                        }
                        
                        // Grouped subscriptions cards
                        if !appState.subscriptions.isEmpty {
                            subscriptionGroupsSection
                        }
                        
                        // Live Traffic Telemetry (when connected)
                        liveTrafficTelemetrySection
                        
                        // Empty state when no servers at all
                        if appState.servers.isEmpty && appState.subscriptions.isEmpty {
                            emptyServersPlaceholder
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
            }
        }
        .frame(width: 400, height: 720)
        .sheet(isPresented: $showingAddSubscriptionSheet) {
            SubscriptionSheetView(appState: appState)
        }
        .sheet(isPresented: $showingAddManualSheet) {
            ManualServerSheetView(appState: appState)
        }
        .sheet(item: $editingServer) { server in
            ManualServerSheetView(appState: appState, serverToEdit: server)
        }
    }
    
    // MARK: - Top Header Bar (Compact & Transparent)
    private var topHeaderBar: some View {
        HStack {
            // Brand Logo + Title
            HStack(spacing: 8) {
                BrandedAppLogoBadge(size: 22)
                
                Text("X-project")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            
            Spacer()
            
            HStack(spacing: 9) {
                // 1. Надпись «Автозапуск» с фирменным золотистым переключателем
                HStack(spacing: 6) {
                    Text("Автозапуск")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                    
                    GoldenToggle(isOn: $appState.settings.autoConnectOnLaunch)
                }
                .help("Автоматически подключаться к VPN при запуске приложения")
                
                // 2. Иконка шестерёнки (Настройки)
                Button(action: {
                    SettingsWindowController.shared.show(appState: appState, initialTab: .routing)
                }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.white.opacity(0.04)))
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5))
                }
                .buttonStyle(.plain)
                .help("Настройки приложения")
                
                // 3. Иконка плюсика (самый правый элемент, без стрелочки вниз и лишних отступов)
                Menu {
                    Button(action: handleImportClipboard) {
                        Label("Вставить ссылку из буфера", systemImage: "doc.on.clipboard")
                    }
                    Button(action: { showingAddSubscriptionSheet = true }) {
                        Label("Добавить подписку по URL...", systemImage: "antenna.radiowaves.left.and.right")
                    }
                    Button(action: handleScanScreenQR) {
                        Label("Сканировать QR-код с экрана", systemImage: "qrcode.viewfinder")
                    }
                    Button(action: handleImportJsonFile) {
                        Label("Импортировать JSON...", systemImage: "doc.badge.plus")
                    }
                    Divider()
                    Button(action: { showingAddManualSheet = true }) {
                        Label("Добавить вручную...", systemImage: "slider.horizontal.3")
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.white.opacity(0.04)))
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5))
                }
                .menuIndicator(.hidden)
                .menuStyle(.borderlessButton)
                .frame(width: 28, height: 28)
                .fixedSize()
                .help("Добавить сервер или подписку")
            }
        }
    }
    
    // MARK: - 1-Click Routing Suggestion Banner
    private func routingSuggestionBanner(suggestion: (subscriptionName: String, scheme: HappRoutingScheme)) -> some View {
        let proxyCount = suggestion.scheme.proxySites.count + suggestion.scheme.proxyIp.count
        let directCount = suggestion.scheme.directSites.count + suggestion.scheme.directIp.count
        
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [ModernMacTheme.cyanAccent.opacity(0.35), Color.blue.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)
                        .overlay(Circle().strokeBorder(ModernMacTheme.cyanAccent.opacity(0.5), lineWidth: 1))
                    
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(ModernMacTheme.cyanAccent)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("НОВАЯ МАРШРУТИЗАЦИЯ")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(ModernMacTheme.cyanAccent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(ModernMacTheme.cyanAccent.opacity(0.15)))
                        
                        Spacer()
                        
                        Button(action: {
                            withAnimation(ModernMacTheme.smoothSpring) {
                                appState.dismissPendingRoutingSuggestion()
                            }
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white.opacity(0.5))
                                .padding(4)
                        }
                        .buttonStyle(.plain)
                        .help("Отклонить предложение")
                    }
                    
                    Text("Обновить правила из «\(suggestion.subscriptionName)»?")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text("Сервер передал оптимизированный маршрут (\(proxyCount) прокси, \(directCount) напрямую).")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            HStack(spacing: 8) {
                Button(action: {
                    withAnimation(ModernMacTheme.smoothSpring) {
                        appState.applyPendingRoutingSuggestion()
                    }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text("Применить в 1 клик")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(
                        LinearGradient(
                            colors: [ModernMacTheme.cyanAccent, Color(red: 0.0, green: 0.55, blue: 0.9)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .foregroundStyle(.black)
                    .shadow(color: ModernMacTheme.cyanAccent.opacity(0.3), radius: 4, y: 2)
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    withAnimation(ModernMacTheme.smoothSpring) {
                        appState.dismissPendingRoutingSuggestion()
                    }
                }) {
                    Text("Отклонить")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.white.opacity(0.06))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 10/255.0, green: 24/255.0, blue: 45/255.0).opacity(0.95),
                            Color(red: 14/255.0, green: 18/255.0, blue: 38/255.0).opacity(0.95)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [ModernMacTheme.cyanAccent.opacity(0.5), Color.blue.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: ModernMacTheme.cyanAccent.opacity(0.15), radius: 10, y: 4)
    }
    
    // MARK: - Hero Power Button Section (Matching Popover Design)
    private var heroPowerSection: some View {
        VStack(spacing: 6) {
            PowerButtonView(status: appState.connectionStatus) {
                withAnimation(ModernMacTheme.bouncySpring) {
                    appState.toggleConnection()
                }
            }
            
            VStack(spacing: 2) {
                Text(appState.connectionStatus == .connected ? "ПОДКЛЮЧЕНО" : (appState.connectionStatus.isBusy ? "ПОДКЛЮЧЕНИЕ..." : "ОТКЛЮЧЕН"))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .tracking(1.0)
                    .foregroundStyle(
                        appState.connectionStatus == .connected
                            ? ModernMacTheme.neonYellow
                            : (appState.connectionStatus.isBusy ? ModernMacTheme.cyanAccent : .white.opacity(0.75))
                    )
                
                // Keep uptime in layout with opacity so height never collapses when disconnected!
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
            .frame(height: 34)
            
            // Subtitle ping & host pill (or test button)
            Button(action: testCurrentConnection) {
                HStack(spacing: 5) {
                    if isPingingActiveConnection {
                        ProgressView()
                            .controlSize(.mini)
                        Text("Измерение...")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                    } else if let ping = appState.activePing, appState.connectionStatus == .connected {
                        Circle()
                            .fill(ping < 80 ? ModernMacTheme.neonYellow : (ping < 160 ? .orange : .red))
                            .frame(width: 5, height: 5)
                        Text("\(ping) ms • \(appState.selectedServer?.address ?? "")")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(ModernMacTheme.neonYellow)
                    } else if appState.connectionStatus == .connected {
                        Circle()
                            .fill(ModernMacTheme.neonYellow)
                            .frame(width: 5, height: 5)
                        Text(appState.selectedServer?.address ?? "Защищенное соединение")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.7))
                    } else {
                        Image(systemName: "bolt.horizontal.circle")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.5))
                        Text("Проверить текущее соединение")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .frame(height: 24)
                .background(Capsule().fill(Color.white.opacity(0.04)))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            .disabled(isPingingActiveConnection || appState.selectedServer == nil)
        }
        .padding(.vertical, 2)
    }
    
    // MARK: - Standalone Servers Section
    private var standaloneServersSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("СЕРВЕРЫ")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.5))
                
                Text("\(standaloneServers.count)")
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
            
            VStack(spacing: 4) {
                ForEach(standaloneServers) { server in
                    MenuBarServerRow(
                        server: server,
                        isSelected: server.id == appState.selectedServerId,
                        isConnected: appState.connectionStatus == .connected && server.id == appState.selectedServerId,
                        onSelect: {
                            withAnimation(ModernMacTheme.smoothSpring) {
                                appState.selectServer(id: server.id)
                            }
                        },
                        onDoubleClick: {
                            if appState.selectedServerId != server.id {
                                appState.selectServer(id: server.id)
                            }
                            appState.connect()
                        },
                        onPing: {
                            appState.pingServer(id: server.id)
                        },
                        onEdit: {
                            editingServer = server
                        },
                        onDelete: {
                            appState.deleteServer(id: server.id)
                        }
                    )
                }
            }
        }
    }
    
    // MARK: - Subscription Groups Section (Happ Plus Style)
    private var subscriptionGroupsSection: some View {
        VStack(spacing: 16) {
            ForEach(appState.subscriptions) { sub in
                SubscriptionGroupCard(
                    subscription: sub,
                    servers: appState.servers.filter { $0.subscriptionId == sub.id },
                    selectedServerId: appState.selectedServerId,
                    isConnected: appState.connectionStatus == .connected,
                    isCollapsed: collapsedSubscriptionIds.contains(sub.id),
                    onToggleCollapse: {
                        withAnimation(ModernMacTheme.smoothSpring) {
                            if collapsedSubscriptionIds.contains(sub.id) {
                                collapsedSubscriptionIds.remove(sub.id)
                            } else {
                                collapsedSubscriptionIds.insert(sub.id)
                            }
                        }
                    },
                    onRefresh: {
                        Task {
                            await SubscriptionManager.shared.updateAllSubscriptions(in: appState)
                        }
                    },
                    onPingGroup: {
                        let groupServers = appState.servers.filter { $0.subscriptionId == sub.id }
                        Task {
                            let results = await LatencyTester.measureBatch(servers: groupServers)
                            await MainActor.run {
                                for (id, ms) in results {
                                    if let idx = appState.servers.firstIndex(where: { $0.id == id }) {
                                        appState.servers[idx].pingMs = ms
                                    }
                                }
                                appState.saveServers()
                            }
                        }
                    },
                    onSelectServer: { sId in
                        withAnimation(ModernMacTheme.smoothSpring) {
                            appState.selectServer(id: sId)
                        }
                    },
                    onDoubleClickServer: { sId in
                        if appState.selectedServerId != sId {
                            appState.selectServer(id: sId)
                        }
                        appState.connect()
                    },
                    onPingServer: { sId in
                        appState.pingServer(id: sId)
                    },
                    onEditServer: { s in
                        editingServer = s
                    },
                    onDeleteServer: { sId in
                        appState.deleteServer(id: sId)
                    },
                    onDeleteSubscription: {
                        withAnimation(ModernMacTheme.smoothSpring) {
                            appState.deleteSubscription(id: sub.id)
                        }
                    }
                )
            }
        }
    }
    
    // MARK: - Live Traffic Telemetry (when connected)
    @ViewBuilder
    private var liveTrafficTelemetrySection: some View {
        if appState.connectionStatus == .connected {
            HStack(spacing: 16) {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(ModernMacTheme.neonYellow)
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
    }
    
    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    // MARK: - Empty State
    private var emptyServersPlaceholder: some View {
        VStack(spacing: 14) {
            Image(systemName: "server.rack")
                .font(.system(size: 38))
                .foregroundStyle(ModernMacTheme.cyanAccent)
            
            Text("Нет добавленных серверов")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
            
            Text("Вставьте ссылку на сервер или подписку из буфера обмена, либо отсканируйте QR-код.")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
            
            Button(action: handleImportClipboard) {
                Label("Вставить из буфера", systemImage: "doc.on.clipboard")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(ModernMacTheme.neonGreen))
                    .foregroundStyle(.black)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(hex: "121634").opacity(0.6))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5))
        )
    }
    
    // MARK: - Actions
    private func testCurrentConnection() {
        guard let server = appState.selectedServer else { return }
        isPingingActiveConnection = true
        Task {
            if let ms = await LatencyTester.measureLatency(host: server.address, port: server.port) {
                await MainActor.run {
                    appState.recordPing(ms)
                    if let idx = appState.servers.firstIndex(where: { $0.id == server.id }) {
                        appState.servers[idx].pingMs = ms
                    }
                    isPingingActiveConnection = false
                }
            } else {
                await MainActor.run {
                    isPingingActiveConnection = false
                }
            }
        }
    }
    
    private func handleImportClipboard() {
        if let onImportClipboard = onImportClipboard {
            onImportClipboard()
        } else {
            ImportCoordinator.shared.importFromClipboard(into: appState)
        }
    }
    
    private func handleScanScreenQR() {
        if let onScanScreenQR = onScanScreenQR {
            onScanScreenQR()
        } else {
            ImportCoordinator.shared.scanScreenQR(into: appState)
        }
    }
    
    private func handleImportJsonFile() {
        if let onImportJsonFile = onImportJsonFile {
            onImportJsonFile()
        } else {
            ImportCoordinator.shared.importJsonFile(into: appState)
        }
    }
}

// MARK: - Subscription Group Card (Happ Plus Style)
struct SubscriptionGroupCard: View {
    let subscription: Subscription
    let servers: [ServerProfile]
    let selectedServerId: UUID?
    let isConnected: Bool
    let isCollapsed: Bool
    
    let onToggleCollapse: () -> Void
    let onRefresh: () -> Void
    let onPingGroup: () -> Void
    let onSelectServer: (UUID) -> Void
    let onDoubleClickServer: (UUID) -> Void
    let onPingServer: (UUID) -> Void
    var onEditServer: ((ServerProfile) -> Void)? = nil
    let onDeleteServer: (UUID) -> Void
    let onDeleteSubscription: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Group Header Card
            VStack(spacing: isCollapsed ? 0 : 12) {
                HStack(alignment: .center) {
                    // Subscription antenna icon badge + Name
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(ModernMacTheme.cyanAccent.opacity(0.15))
                                .frame(width: isCollapsed ? 28 : 30, height: isCollapsed ? 28 : 30)
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .font(.system(size: isCollapsed ? 12 : 13, weight: .bold))
                                .foregroundStyle(ModernMacTheme.cyanAccent)
                        }
                        
                        VStack(alignment: .leading, spacing: isCollapsed ? 0 : 3) {
                            Text(subscription.name)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            
                            if !isCollapsed {
                                Text(subscription.formattedLastUpdated)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Group Action buttons (Enhanced size & glass background)
                    HStack(spacing: 6) {
                        HeaderIconButton(
                            icon: "arrow.clockwise",
                            help: "Обновить подписку",
                            action: onRefresh
                        )
                        
                        HeaderIconButton(
                            icon: "gauge.with.needle",
                            help: "Замерить пинг серверов",
                            action: onPingGroup
                        )
                        
                        Menu {
                            Button(action: copySubscriptionUrl) {
                                Label("Скопировать ссылку", systemImage: "doc.on.doc")
                            }
                            Divider()
                            Button(role: .destructive, action: onDeleteSubscription) {
                                Label("Удалить подписку", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white.opacity(0.85))
                                .frame(width: 28, height: 28)
                                .background(
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .fill(Color.white.opacity(0.08))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.8)
                                )
                        }
                        .menuStyle(.borderlessButton)
                        .help("Действия с подпиской")
                        
                        HeaderIconButton(
                            icon: isCollapsed ? "chevron.down" : "chevron.up",
                            help: isCollapsed ? "Развернуть список" : "Свернуть список",
                            action: onToggleCollapse
                        )
                    }
                }
                
                // Traffic Progress Bar & Expiration (only visible when expanded)
                if !isCollapsed {
                    VStack(spacing: 5) {
                        HStack {
                            Image(systemName: "info.circle")
                                .font(.system(size: 10))
                                .foregroundStyle(.white.opacity(0.5))
                            
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.white.opacity(0.12))
                                        .frame(height: 5)
                                    
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [ModernMacTheme.cyanAccent, ModernMacTheme.neonYellow],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: max(8, geo.size.width * CGFloat(subscription.trafficProgress)), height: 5)
                                }
                            }
                            .frame(height: 5)
                        }
                        
                        HStack {
                            Text(subscription.formattedTraffic.isEmpty ? "\(servers.count) серверов" : subscription.formattedTraffic)
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.65))
                            
                            Spacer()
                            
                            if !subscription.formattedExpireDate.isEmpty {
                                Text(subscription.formattedExpireDate)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.white.opacity(0.55))
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, isCollapsed ? 8 : 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(ModernMacTheme.cardSurfaceHeader)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.8)
                    )
            )
            
            // Server rows inside group (clean radio selector, matching popover)
            if !isCollapsed {
                VStack(spacing: 4) {
                    ForEach(servers) { server in
                        MenuBarServerRow(
                            server: server,
                            isSelected: server.id == selectedServerId,
                            isConnected: isConnected && server.id == selectedServerId,
                            onSelect: { onSelectServer(server.id) },
                            onDoubleClick: { onDoubleClickServer(server.id) },
                            onPing: { onPingServer(server.id) },
                            onEdit: { onEditServer?(server) },
                            onDelete: { onDeleteServer(server.id) }
                        )
                    }
                }
                .padding(.horizontal, 4)
                .padding(.top, 6)
                .padding(.bottom, 6)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(ModernMacTheme.cardSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(ModernMacTheme.borderCard, lineWidth: 1.0)
                )
                .shadow(color: Color.black.opacity(0.4), radius: 8, x: 0, y: 3)
        )
    }
    
    private func copySubscriptionUrl() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(subscription.urlString, forType: .string)
    }
}

// MARK: - Header Icon Button Component
private struct HeaderIconButton: View {
    let icon: String
    let help: String
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isHovered ? .white : .white.opacity(0.8))
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(isHovered ? Color.white.opacity(0.14) : Color.white.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(isHovered ? Color.white.opacity(0.25) : Color.white.opacity(0.12), lineWidth: 0.8)
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(help)
    }
}




