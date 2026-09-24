import SwiftUI
import AppKit

public struct ServersTab: View {
    @Bindable var appState: AppState
    @State private var showingAddManualSheet = false
    @State private var showingSubscriptionSheet = false
    @State private var searchText = ""
    @State private var isPingingAll = false
    
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
    
    private var filteredServers: [ServerProfile] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return appState.servers }
        let query = trimmed.lowercased()
        return appState.servers.filter {
            $0.name.lowercased().contains(query) ||
            $0.address.lowercased().contains(query) ||
            $0.protocolType.rawValue.lowercased().contains(query)
        }
    }
    
    private var duplicateCount: Int {
        var seen = Set<String>()
        var count = 0
        for s in appState.servers {
            let key = "\(s.protocolType.rawValue):\(s.address.lowercased()):\(s.port)"
            if seen.contains(key) {
                count += 1
            } else {
                seen.insert(key)
            }
        }
        return count
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            // MARK: - Toolbar Controls
            HStack(spacing: 8) {
                Menu {
                    Button(action: handleImportClipboard) {
                        Label("Вставить ссылку из буфера (vless/trojan/ss/URL)", systemImage: "doc.on.clipboard")
                    }
                    .keyboardShortcut("v", modifiers: .command)
                    
                    Button(action: handleScanScreenQR) {
                        Label("Сканировать QR-код с экрана Mac", systemImage: "qrcode.viewfinder")
                    }
                    
                    Button(action: handleImportJsonFile) {
                        Label("Импортировать JSON конфигурацию...", systemImage: "doc.badge.plus")
                    }
                    
                    Divider()
                    
                    Button(action: { showingSubscriptionSheet = true }) {
                        Label("Добавить подписку по URL...", systemImage: "antenna.radiowaves.left.and.right")
                    }
                    
                    Button(action: { showingAddManualSheet = true }) {
                        Label("Добавить сервер вручную...", systemImage: "slider.horizontal.3")
                    }
                } label: {
                    Label("Добавить", systemImage: "plus")
                }
                .menuStyle(.borderedButton)
                
                Button(action: { showingSubscriptionSheet = true }) {
                    Label("Подписки (\(appState.subscriptions.count))", systemImage: "antenna.radiowaves.left.and.right")
                }
                
                // Deduplication chip if duplicates exist
                if duplicateCount > 0 {
                    Button(action: {
                        withAnimation(ModernMacTheme.smoothSpring) {
                            appState.deduplicateServers()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                            Text("Очистить дубликаты (\(duplicateCount))")
                        }
                        .foregroundStyle(.orange)
                    }
                    .buttonStyle(.bordered)
                }
                
                Spacer()
                
                Button(action: pingAllServers) {
                    if isPingingAll {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 14, height: 14)
                    } else {
                        Label("Проверить пинг", systemImage: "bolt.horizontal.fill")
                    }
                }
                .disabled(isPingingAll || appState.servers.isEmpty)
            }
            .padding(.horizontal, 2)
            
            // MARK: - Search Bar (when servers are available)
            if !appState.servers.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    
                    TextField("Поиск по названию или IP-адресу...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Text("\(filteredServers.count) из \(appState.servers.count)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                        )
                )
            }
            
            // MARK: - Servers Table / List
            if appState.servers.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "server.rack")
                        .font(.system(size: 44))
                        .foregroundStyle(ModernMacTheme.cyanAccent)
                    
                    Text("Нет добавленных серверов")
                        .font(.title3.bold())
                    
                    Text("Скопируйте ссылку на сервер или подписку и нажмите «Вставить из буфера», либо отсканируйте QR с экрана.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 420)
                    
                    HStack(spacing: 12) {
                        Button(action: handleImportClipboard) {
                            Label("Вставить из буфера", systemImage: "doc.on.clipboard")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(ModernMacTheme.neonGreen)
                        .foregroundStyle(.black)
                        
                        Button(action: { showingSubscriptionSheet = true }) {
                            Label("URL подписки", systemImage: "antenna.radiowaves.left.and.right")
                        }
                        .buttonStyle(.bordered)
                        
                        Button(action: handleScanScreenQR) {
                            Label("QR с экрана", systemImage: "qrcode.viewfinder")
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.top, 6)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .glassCard()
            } else {
                List {
                    ForEach(filteredServers) { server in
                        ServerRowView(
                            server: server,
                            isSelected: server.id == appState.selectedServerId,
                            isConnected: appState.connectionStatus == .connected && appState.selectedServerId == server.id,
                            onSelect: {
                                withAnimation(ModernMacTheme.smoothSpring) {
                                    appState.selectServer(id: server.id)
                                }
                            },
                            onConnect: {
                                if appState.selectedServerId != server.id {
                                    appState.selectServer(id: server.id)
                                }
                                appState.toggleConnection()
                            },
                            onPing: {
                                appState.pingServer(id: server.id)
                            },
                            onDelete: {
                                withAnimation(ModernMacTheme.smoothSpring) {
                                    appState.deleteServer(id: server.id)
                                }
                            }
                        )
                        .listRowInsets(EdgeInsets(top: 3, leading: 2, bottom: 3, trailing: 2))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                )
            }
        }
        .padding(18)
        .sheet(isPresented: $showingSubscriptionSheet) {
            SubscriptionSheetView(appState: appState)
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
    
    private func pingAllServers() {
        isPingingAll = true
        appState.pingAllServers()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            isPingingAll = false
        }
    }
}

// MARK: - Modern Mac Server Row View (No ugly yellow highlight!)
struct ServerRowView: View {
    let server: ServerProfile
    let isSelected: Bool
    let isConnected: Bool
    let onSelect: () -> Void
    let onConnect: () -> Void
    let onPing: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            leadingIndicators
            serverInfo
            Spacer()
            trailingControls
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 10)
        .background(rowBackground)
        .onHover { h in isHovered = h }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            onSelect()
            onConnect()
        }
        .onTapGesture(count: 1) {
            onSelect()
        }
        .contextMenu {
            Button(action: onConnect) {
                Label(isConnected ? "Отключить" : "Подключить", systemImage: isConnected ? "stop.fill" : "play.fill")
            }
            Button(action: onPing) {
                Label("Проверить пинг", systemImage: "bolt.fill")
            }
            Button(action: copyLink) {
                Label("Скопировать ссылку", systemImage: "doc.on.doc")
            }
            Divider()
            Button(role: .destructive, action: onDelete) {
                Label("Удалить", systemImage: "trash")
            }
        }
    }
    
    @ViewBuilder
    private var leadingIndicators: some View {
        // Neon accent left bar
        RoundedRectangle(cornerRadius: 2)
            .fill(isSelected ? (isConnected ? ModernMacTheme.neonGreen : ModernMacTheme.cyanAccent) : Color.clear)
            .frame(width: 3, height: 28)
        
        // Radio check
        Image(systemName: isConnected ? "bolt.circle.fill" : (isSelected ? "checkmark.circle.fill" : "circle"))
            .font(.system(size: 16))
            .foregroundStyle(isConnected ? ModernMacTheme.neonGreen : (isSelected ? ModernMacTheme.cyanAccent : .secondary))
            .onTapGesture(perform: onSelect)
        
        // Protocol Badge
        Text(server.protocolType.rawValue)
            .font(.system(size: 10, weight: .heavy))
            .foregroundStyle(Color(hex: server.protocolType.badgeColorHex))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color(hex: server.protocolType.badgeColorHex).opacity(0.2))
            )
    }
    
    @ViewBuilder
    private var serverInfo: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(server.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                if isConnected {
                    Text("АКТИВЕН")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(ModernMacTheme.neonGreen))
                }
            }
            
            // Format without localized space grouping "8 444" -> "8444"
            Text(verbatim: "\(server.address):\(server.port)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }
    
    @ViewBuilder
    private var trailingControls: some View {
        // Ping button
        Button(action: onPing) {
            if let ping = server.pingMs {
                HStack(spacing: 4) {
                    Circle()
                        .fill(ping < 80 ? ModernMacTheme.neonGreen : (ping < 160 ? .orange : .red))
                        .frame(width: 6, height: 6)
                    Text("\(ping) ms")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "bolt")
                        .font(.system(size: 10))
                    Text("—")
                        .font(.system(size: 11, design: .monospaced))
                }
                .foregroundStyle(.secondary.opacity(0.8))
            }
        }
        .buttonStyle(.plain)
        .help("Проверить пинг")
        
        // Power Connect button
        Button(action: onConnect) {
            Image(systemName: isConnected ? "stop.circle.fill" : "play.circle.fill")
                .font(.system(size: 15))
                .foregroundStyle(isConnected ? ModernMacTheme.neonGreen : (isHovered || isSelected ? Color.primary : Color.secondary.opacity(0.6)))
        }
        .buttonStyle(.plain)
        .help(isConnected ? "Отключить" : "Подключить")
        
        // Delete button
        Button(action: onDelete) {
            Image(systemName: "trash")
                .font(.system(size: 12))
                .foregroundStyle(.secondary.opacity(0.8))
        }
        .buttonStyle(.plain)
        .help("Удалить")
    }
    
    @ViewBuilder
    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(isSelected ? Color.white.opacity(0.08) : (isHovered ? Color.white.opacity(0.04) : Color.white.opacity(0.015)))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        isSelected ? (isConnected ? ModernMacTheme.neonGreen.opacity(0.4) : ModernMacTheme.cyanAccent.opacity(0.35)) : Color.white.opacity(0.04),
                        lineWidth: isSelected ? 1 : 0.5
                    )
            )
    }
    
    private func copyLink() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("\(server.protocolType.rawValue.lowercased())://\(server.address):\(server.port)#\(server.name)", forType: .string)
    }
}

// MARK: - Subscription modal sheet
struct SubscriptionSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var appState: AppState
    @State private var nameText = ""
    @State private var urlText = ""
    @State private var isDownloading = false
    @State private var isUpdatingAll = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Управление подписками")
                    .font(.headline)
                Spacer()
                Button("Закрыть") { dismiss() }
            }
            
            // Add subscription box
            VStack(alignment: .leading, spacing: 10) {
                Text("Добавить ссылку на подписку:")
                    .font(.subheadline.bold())
                
                TextField("Название подписки (например: My Fast VPN)", text: $nameText)
                    .textFieldStyle(.roundedBorder)
                
                TextField("URL подписки (https://...)", text: $urlText)
                    .textFieldStyle(.roundedBorder)
                
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                
                HStack {
                    Button(action: addSubscription) {
                        if isDownloading {
                            ProgressView()
                                .controlSize(.small)
                                .frame(width: 14, height: 14)
                            Text("Загрузка серверов...")
                        } else {
                            Label("Скачать и сохранить подписку", systemImage: "arrow.down.circle.fill")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(ModernMacTheme.neonGreen)
                    .foregroundStyle(.black)
                    .disabled(urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isDownloading)
                    
                    Spacer()
                    
                    if !appState.subscriptions.isEmpty {
                        Button(action: refreshAll) {
                            if isUpdatingAll {
                                ProgressView()
                                    .controlSize(.small)
                                    .frame(width: 14, height: 14)
                            } else {
                                Label("Обновить все", systemImage: "arrow.clockwise")
                            }
                        }
                        .disabled(isUpdatingAll || isDownloading)
                    }
                }
            }
            .padding(14)
            .glassCard()
            
            // Existing subscriptions
            if appState.subscriptions.isEmpty {
                VStack(spacing: 6) {
                    Text("Нет активных подписок")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 80)
            } else {
                List {
                    ForEach(appState.subscriptions) { sub in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(sub.name).font(.system(size: 13, weight: .semibold))
                                Text(sub.urlString).font(.system(size: 11)).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(sub.serverCount) серв.")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Button(action: {
                                appState.servers.removeAll(where: { $0.subscriptionId == sub.id })
                                appState.subscriptions.removeAll(where: { $0.id == sub.id })
                                appState.saveServers()
                                appState.saveSubscriptions()
                            }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(height: 160)
            }
        }
        .padding(20)
        .frame(width: 500)
    }
    
    private func addSubscription() {
        let trimmed = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        // Check if this subscription already exists
        let existing = appState.subscriptions.first(where: {
            $0.urlString.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == trimmed.lowercased()
        })
        let subId = existing?.id ?? UUID()
        
        isDownloading = true
        errorMessage = nil
        
        Task {
            do {
                let result = try await SubscriptionManager.shared.fetchSubscriptionWithUserInfo(from: trimmed, subscriptionId: subId)
                await MainActor.run {
                    guard !result.servers.isEmpty else {
                        isDownloading = false
                        self.errorMessage = "По указанному адресу не найдено активных серверов."
                        return
                    }
                    
                    let effectiveName: String
                    if !nameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        effectiveName = nameText.trimmingCharacters(in: .whitespacesAndNewlines)
                    } else if let title = result.profileTitle, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        effectiveName = title.trimmingCharacters(in: .whitespacesAndNewlines)
                    } else if let existingName = existing?.name {
                        effectiveName = existingName
                    } else {
                        effectiveName = "Подписка #\(appState.subscriptions.count + 1)"
                    }
                    
                    // Remove old servers for this subscription
                    appState.servers.removeAll(where: { $0.subscriptionId == subId })
                    
                    if let idx = appState.subscriptions.firstIndex(where: { $0.id == subId }) {
                        appState.subscriptions[idx].name = effectiveName
                        appState.subscriptions[idx].lastUpdated = Date()
                        appState.subscriptions[idx].serverCount = result.servers.count
                        appState.subscriptions[idx].uploadBytes = result.uploadBytes
                        appState.subscriptions[idx].downloadBytes = result.downloadBytes
                        appState.subscriptions[idx].totalBytes = result.totalBytes
                        appState.subscriptions[idx].expireDate = result.expireDate
                        if let h = result.updateIntervalHours {
                            appState.subscriptions[idx].updateIntervalHours = h
                        }
                    } else {
                        let sub = Subscription(
                            id: subId,
                            name: effectiveName,
                            urlString: trimmed,
                            lastUpdated: Date(),
                            serverCount: result.servers.count,
                            uploadBytes: result.uploadBytes,
                            downloadBytes: result.downloadBytes,
                            totalBytes: result.totalBytes,
                            expireDate: result.expireDate,
                            updateIntervalHours: result.updateIntervalHours ?? 6
                        )
                        appState.subscriptions.append(sub)
                    }
                    
                    for s in result.servers {
                        appState.addServer(s)
                    }
                    
                    if let scheme = result.suggestedRoutingScheme {
                        appState.pendingRoutingSuggestion = (subscriptionName: effectiveName, scheme: scheme)
                    }
                    
                    if appState.selectedServerId == nil {
                        appState.selectedServerId = result.servers.first?.id
                    }
                    appState.saveServers()
                    appState.saveSubscriptions()
                    appState.appendLog(level: .info, message: "Подписка '\(effectiveName)' успешно загружена: \(result.servers.count) серверов")
                    isDownloading = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isDownloading = false
                    self.errorMessage = "Ошибка: \(error.localizedDescription)"
                    appState.appendLog(level: .error, message: "Ошибка загрузки подписки: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func refreshAll() {
        isUpdatingAll = true
        Task {
            await SubscriptionManager.shared.updateAllSubscriptions(in: appState)
            await MainActor.run {
                isUpdatingAll = false
            }
        }
    }
}
