import Foundation
import SwiftUI
import Combine

@Observable
public final class AppState {
    // MARK: - Published Properties
    public var connectionStatus: ConnectionStatus = .disconnected {
        didSet {
            Task { @MainActor in
                self.onStatusChange?(self.connectionStatus)
            }
        }
    }
    public var onStatusChange: (@MainActor (ConnectionStatus) -> Void)?
    public var selectedServerId: UUID? {
        didSet {
            if let id = selectedServerId {
                UserDefaults.standard.set(id.uuidString, forKey: "lastSelectedServerId")
                settings.lastSelectedServerId = id
                if let server = servers.first(where: { $0.id == id }) {
                    let key = serverIdentifierKey(for: server)
                    UserDefaults.standard.set(key, forKey: "lastSelectedServerKey")
                    UserDefaults.standard.set(server.name, forKey: "lastSelectedServerName")
                    settings.lastSelectedServerKey = key
                    settings.lastSelectedServerName = server.name
                }
                UserDefaults.standard.synchronize()
            }
        }
    }
    public var servers: [ServerProfile] = []
    public var subscriptions: [Subscription] = []
    public var routingConfig: RoutingConfig = .defaultConfiguration {
        didSet {
            if settings.routingMode != routingConfig.mode {
                settings.routingMode = routingConfig.mode
            }
            saveRouting()
        }
    }
    public var settings: AppSettings = .standard {
        didSet {
            if routingConfig.mode != settings.routingMode {
                routingConfig.mode = settings.routingMode
            }
            saveSettings()
            UserDefaults.standard.set(settings.autoConnectOnLaunch, forKey: "autoConnectOnLaunch")
            UserDefaults.standard.synchronize()
        }
    }
    
    // Routing Suggestions from Subscriptions
    public var pendingRoutingSuggestion: (subscriptionName: String, scheme: HappRoutingScheme)?
    
    // Geo Assets (geosite.dat & geoip.dat)
    public var geoAssetMetadata: GeoAssetMetadata = GeoAssetManager.loadMetadata()
    public var isUpdatingGeoAssets: Bool = false
    public var geoAssetUpdateProgress: Double = 0.0
    public var geoAssetStatusMessage: String = ""
    
    // Telemetry & Status
    public var pingHistory: [Int] = [45, 42, 50, 48, 44, 46]
    public var connectedSince: Date?
    public var uptimeSeconds: Int = 0
    public var bytesIn: UInt64 = 0
    public var bytesOut: UInt64 = 0
    public var logs: [LogEntry] = []
    
    // Internal Timer
    private var telemetryTimer: Timer?
    
    public init() {
        loadPersistedData()
        triggerBackgroundGeoAssetCheck()
    }
    
    // MARK: - Computed Properties
    public var selectedServer: ServerProfile? {
        if let id = selectedServerId {
            return servers.first(where: { $0.id == id })
        }
        return servers.first
    }
    
    public var activePing: Int? {
        selectedServer?.pingMs ?? pingHistory.last
    }
    
    public var formattedUptime: String {
        guard connectionStatus == .connected else { return "00:00:00" }
        let hours = uptimeSeconds / 3600
        let minutes = (uptimeSeconds % 3600) / 60
        let seconds = uptimeSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    // MARK: - Connection Actions
    public func toggleConnection() {
        switch connectionStatus {
        case .connected:
            disconnect()
        case .disconnected, .error:
            connect()
        case .connecting, .disconnecting:
            break
        }
    }
    
    public func connect() {
        guard let server = selectedServer else {
            appendLog(level: .error, message: "Не выбран сервер для подключения")
            connectionStatus = .error("Выберите сервер")
            return
        }
        
        connectionStatus = .connecting
        appendLog(level: .info, message: "Подключение к серверу: \(server.name) (\(server.address):\(server.port))...")
        appendLog(level: .info, message: "Режим трафика: \(settings.trafficMode.title). Маршрутизация: \(routingConfig.mode.title)")
        
        do {
            try XrayProcessManager.shared.start(
                server: server,
                routing: routingConfig,
                settings: settings,
                onLog: { [weak self] level, message in
                    self?.appendLog(level: level, message: message)
                },
                onUnexpectedTermination: { [weak self] code in
                    Task { @MainActor in
                        guard let self = self else { return }
                        self.appendLog(level: .error, message: "Внимание: Xray-core неожиданно завершил работу (код \(code)). Сброс сети.")
                        self.disconnect()
                        self.connectionStatus = .error("Сбой ядра (код \(code))")
                    }
                }
            )
            
            // Apply traffic mode routing to macOS system
            if settings.trafficMode == .tun {
                TUNManager.shared.startTun(httpPort: settings.httpPort, socksPort: settings.socksPort) { [weak self] level, msg in
                    self?.appendLog(level: level, message: msg)
                }
            } else {
                SystemProxyManager.shared.enableProxy(httpPort: settings.httpPort, socksPort: settings.socksPort)
                appendLog(level: .info, message: "Системный прокси macOS активирован для сетевых служб (SOCKS:\(settings.socksPort), HTTP:\(settings.httpPort))")
            }
            
            self.connectionStatus = .connected
            self.connectedSince = Date()
            self.startTelemetryTimer()
            self.appendLog(level: .info, message: "Туннель Xray-core успешно поднят на локальных портах SOCKS:\(settings.socksPort), HTTP:\(settings.httpPort)")
            
            // Fast live connectivity verification to ensure traffic really routes through the node
            let httpPort = settings.httpPort
            let srvName = server.name
            Task { [weak self] in
                guard let self = self else { return }
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                guard self.connectionStatus == .connected else { return }
                
                let check = await self.checkLiveProxyReachability(httpPort: httpPort)
                if let exitIp = check.exitIp {
                    self.appendLog(level: .info, message: "✅ Туннель подтвержден! Внешний выходной IP: \(exitIp)")
                } else if self.connectionStatus == .connected {
                    self.appendLog(level: .warning, message: "⚠️ Внимание: Сервер '\(srvName)' не ответил на сетевое рукопожатие (таймаут ноды). Проверьте интернет или переключитесь на рабочий сервер (например, Швеция).")
                }
            }
        } catch {
            self.connectionStatus = .error(error.localizedDescription)
            self.appendLog(level: .error, message: "Ошибка запуска Xray: \(error.localizedDescription)")
        }
    }
    
    public func disconnect() {
        connectionStatus = .disconnecting
        appendLog(level: .info, message: "Остановка Xray-core и сброс сети...")
        
        if settings.trafficMode == .tun {
            TUNManager.shared.stopTun()
        } else {
            SystemProxyManager.shared.disableProxy()
        }
        
        XrayProcessManager.shared.stop()
        self.stopTelemetryTimer()
        self.connectionStatus = .disconnected
        self.connectedSince = nil
        self.uptimeSeconds = 0
        self.appendLog(level: .info, message: "Сетевые параметры сброшены. Соединение разорвано.")
    }
    
    public func pingServer(id: UUID) {
        guard let server = servers.first(where: { $0.id == id }) else { return }
        Task {
            if let ms = await LatencyTester.measureLatency(host: server.address, port: server.port) {
                await MainActor.run {
                    if let idx = self.servers.firstIndex(where: { $0.id == id }) {
                        self.servers[idx].pingMs = ms
                        self.servers[idx].lastTestedAt = Date()
                        if id == self.selectedServerId {
                            self.recordPing(ms)
                        }
                    }
                    self.saveServers()
                }
            }
        }
    }
    
    public func pingAllServers() {
        appendLog(level: .info, message: "Запущен опрос пинга всех серверов...")
        Task {
            let results = await LatencyTester.measureBatch(servers: self.servers)
            await MainActor.run {
                for (id, ms) in results {
                    if let idx = self.servers.firstIndex(where: { $0.id == id }) {
                        self.servers[idx].pingMs = ms
                        self.servers[idx].lastTestedAt = Date()
                    }
                }
                self.saveServers()
                self.appendLog(level: .info, message: "Опрос пинга завершен для \(results.count) серверов.")
            }
        }
    }
    
    // MARK: - Deduplication & Server Management
    public static func isDuplicateServer(_ a: ServerProfile, _ b: ServerProfile) -> Bool {
        if a.id == b.id { return true }
        
        // Match address and port and protocol
        guard a.address.lowercased() == b.address.lowercased() && a.port == b.port && a.protocolType == b.protocolType else {
            return false
        }
        
        // Match protocol-specific keys
        switch a.protocolType {
        case .vless:
            if let u1 = a.vlessDetails?.uuid, let u2 = b.vlessDetails?.uuid {
                return u1.lowercased() == u2.lowercased()
            }
        case .trojan:
            if let p1 = a.trojanDetails?.password, let p2 = b.trojanDetails?.password {
                return p1 == p2
            }
        case .shadowsocks:
            if let p1 = a.shadowsocksDetails?.password, let p2 = b.shadowsocksDetails?.password {
                return p1 == p2
            }
        case .customJson:
            return a.name == b.name
        }
        
        return a.name == b.name
    }
    
    public func deduplicateServers() {
        var unique: [ServerProfile] = []
        for s in servers {
            if !unique.contains(where: { AppState.isDuplicateServer($0, s) }) {
                unique.append(s)
            }
        }
        
        // Deduplicate subscriptions by urlString
        var uniqueSubs: [Subscription] = []
        for sub in subscriptions {
            if !uniqueSubs.contains(where: { $0.urlString.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == sub.urlString.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }) {
                uniqueSubs.append(sub)
            }
        }
        
        let serversChanged = unique.count != servers.count
        let subsChanged = uniqueSubs.count != subscriptions.count
        
        if serversChanged || subsChanged {
            self.servers = unique
            self.subscriptions = uniqueSubs
            if !servers.contains(where: { $0.id == selectedServerId }) {
                restoreSelectedServer()
            }
            saveServers()
            saveSubscriptions()
            appendLog(level: .info, message: "Выполнена дедупликация: удалено дубликатов серверов")
        }
    }
    
    // MARK: - Server Selection Persistence
    public func serverIdentifierKey(for server: ServerProfile) -> String {
        return "\(server.protocolType.rawValue)|\(server.address.lowercased())|\(server.port)|\(server.name)"
    }
    
    public func restoreSelectedServer(preferringName: String? = nil) {
        // 0. Preferred name match (e.g. across subscription updates)
        if let name = preferringName, let match = servers.first(where: { $0.name == name }) {
            self.selectedServerId = match.id
            return
        }
        
        // 1. Try to restore by saved UUID (AppSettings or UserDefaults)
        let savedUUID = settings.lastSelectedServerId ?? (UserDefaults.standard.string(forKey: "lastSelectedServerId").flatMap { UUID(uuidString: $0) })
        if let uuid = savedUUID, servers.contains(where: { $0.id == uuid }) {
            self.selectedServerId = uuid
            return
        }
        
        // 2. Try to restore by semantic key (protocol|address|port|name)
        let savedKey = settings.lastSelectedServerKey ?? UserDefaults.standard.string(forKey: "lastSelectedServerKey")
        if let key = savedKey {
            if let matched = servers.first(where: { serverIdentifierKey(for: $0) == key }) {
                self.selectedServerId = matched.id
                return
            }
            // 2b. Name extraction from key if host rotated during subscription refresh
            let parts = key.components(separatedBy: "|")
            if parts.count >= 4 {
                let nameFromKey = parts[3]
                if let matchedByName = servers.first(where: { $0.name == nameFromKey }) {
                    self.selectedServerId = matchedByName.id
                    return
                }
            }
        }
        
        // 3. Try to restore by saved server name
        let savedName = settings.lastSelectedServerName ?? UserDefaults.standard.string(forKey: "lastSelectedServerName")
        if let name = savedName, let matched = servers.first(where: { $0.name == name }) {
            self.selectedServerId = matched.id
            return
        }
        
        // 4. Fallback to existing selectedServerId if valid
        if let current = selectedServerId, servers.contains(where: { $0.id == current }) {
            return
        }
        
        // 5. Default to first available server
        self.selectedServerId = servers.first?.id
    }
    
    /// Triggers automatic VPN connection on app startup if configured by the user
    public func performAutoConnectIfEnabled() {
        guard settings.autoConnectOnLaunch else {
            appendLog(level: .info, message: "Автозапуск отключен в настройках.")
            return
        }
        guard connectionStatus == .disconnected else { return }
        
        restoreSelectedServer()
        
        guard let server = selectedServer else {
            appendLog(level: .warning, message: "Автозапуск: сервер для подключения не найден в списке.")
            return
        }
        
        appendLog(level: .info, message: "Автозапуск: автоматическое подключение к серверу «\(server.name)»...")
        connect()
    }
    
    public func addServer(_ server: ServerProfile) {
        if let existingIdx = servers.firstIndex(where: { AppState.isDuplicateServer($0, server) }) {
            // Update existing in-place instead of creating duplicate
            servers[existingIdx].name = server.name
            if let v = server.vlessDetails { servers[existingIdx].vlessDetails = v }
            if let t = server.trojanDetails { servers[existingIdx].trojanDetails = t }
            if let s = server.shadowsocksDetails { servers[existingIdx].shadowsocksDetails = s }
            if let sub = server.subscriptionId { servers[existingIdx].subscriptionId = sub }
            saveServers()
            appendLog(level: .info, message: "Обновлен существующий сервер: \(server.name)")
            return
        }
        
        servers.append(server)
        if selectedServerId == nil {
            selectedServerId = server.id
        }
        saveServers()
        appendLog(level: .info, message: "Добавлен новый сервер: \(server.name) [\(server.protocolType.rawValue)]")
    }
    
    public func deleteServer(id: UUID) {
        servers.removeAll(where: { $0.id == id })
        if selectedServerId == id {
            restoreSelectedServer()
        }
        saveServers()
    }
    
    public func deleteSubscription(id: UUID) {
        servers.removeAll(where: { $0.subscriptionId == id })
        subscriptions.removeAll(where: { $0.id == id })
        if !servers.contains(where: { $0.id == selectedServerId }) {
            restoreSelectedServer()
        }
        saveServers()
        saveSubscriptions()
        appendLog(level: .info, message: "Подписка и связанные серверы удалены")
    }
    
    public func selectServer(id: UUID) {
        selectedServerId = id
        if connectionStatus == .connected {
            // Reconnect on server switch
            disconnect()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.connect()
            }
        }
    }
    
    // MARK: - Routing Suggestion Actions (1-Click Update from Subscription)
    public func applyPendingRoutingSuggestion() {
        guard let suggestion = pendingRoutingSuggestion else { return }
        var currentConfig = routingConfig
        let beforeRulesCount = currentConfig.proxyRules.count + currentConfig.directRules.count + currentConfig.blockRules.count
        HappRoutingCodec.apply(scheme: suggestion.scheme, to: &currentConfig, merge: true)
        let afterRulesCount = currentConfig.proxyRules.count + currentConfig.directRules.count + currentConfig.blockRules.count
        let addedCount = max(0, afterRulesCount - beforeRulesCount)
        
        routingConfig = currentConfig
        saveRouting()
        appendLog(level: .info, message: "Правила маршрутизации успешно обновлены из подписки '\(suggestion.subscriptionName)' (добавлено \(addedCount) правил, всего: \(afterRulesCount))")
        pendingRoutingSuggestion = nil
        
        if connectionStatus == .connected {
            appendLog(level: .warning, message: "Маршрутизация обновлена. Для вступления новых правил в силу переподключитесь к серверу.")
        }
    }
    
    public func dismissPendingRoutingSuggestion() {
        if let name = pendingRoutingSuggestion?.subscriptionName {
            appendLog(level: .info, message: "Предложение обновить маршрутизацию от подписки '\(name)' отклонено")
        }
        pendingRoutingSuggestion = nil
    }
    
    // MARK: - Geo Assets Actions (geosite.dat / geoip.dat)
    public func triggerBackgroundGeoAssetCheck() {
        GeoAssetManager.shared.checkAndPerformBackgroundUpdate { [weak self] level, msg in
            Task { @MainActor in
                self?.appendLog(level: level, message: msg)
                self?.geoAssetMetadata = GeoAssetManager.loadMetadata()
            }
        }
    }
    
    public func updateGeoAssetsManually() {
        guard !isUpdatingGeoAssets else { return }
        isUpdatingGeoAssets = true
        geoAssetUpdateProgress = 0.0
        geoAssetStatusMessage = "Подключение к jsDelivr CDN..."
        appendLog(level: .info, message: "Запущено ручное обновление баз гео-маршрутизации (geosite.dat / geoip.dat)...")
        
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            do {
                let (siteBytes, ipBytes) = try await GeoAssetManager.shared.downloadAndInstallAssets { [weak self] progress, status in
                    Task { @MainActor in
                        self?.geoAssetUpdateProgress = progress
                        self?.geoAssetStatusMessage = status
                    }
                }
                self.geoAssetMetadata = GeoAssetManager.loadMetadata()
                self.isUpdatingGeoAssets = false
                self.geoAssetUpdateProgress = 1.0
                self.geoAssetStatusMessage = "Базы гео-маршрутизации успешно обновлены!"
                
                let formatter = ByteCountFormatter()
                formatter.countStyle = .binary
                let siteStr = formatter.string(fromByteCount: Int64(siteBytes))
                let ipStr = formatter.string(fromByteCount: Int64(ipBytes))
                self.appendLog(level: .info, message: "Базы гео-маршрутизации успешно установлены: geosite (\(siteStr)), geoip (\(ipStr))")
            } catch {
                self.isUpdatingGeoAssets = false
                self.geoAssetStatusMessage = "Ошибка обновления"
                self.appendLog(level: .error, message: "Не удалось обновить базы гео-маршрутизации: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Logging
    public func appendLog(level: LogLevel, message: String) {
        let entry = LogEntry(level: level, message: message)
        DispatchQueue.main.async {
            self.logs.append(entry)
            if self.logs.count > 500 {
                self.logs.removeFirst(50)
            }
        }
    }
    
    public func clearLogs() {
        logs.removeAll()
    }
    
    // MARK: - Ping & Telemetry
    public func recordPing(_ ms: Int) {
        pingHistory.append(ms)
        if pingHistory.count > 25 {
            pingHistory.removeFirst()
        }
    }
    
    private func startTelemetryTimer() {
        stopTelemetryTimer()
        uptimeSeconds = 0
        bytesIn = 0
        bytesOut = 0
        
        telemetryTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, self.connectionStatus == .connected else { return }
            self.uptimeSeconds += 1
            
            // Jitter for ping sparkline
            let jitter = Int.random(in: -3...4)
            let basePing = self.selectedServer?.pingMs ?? 48
            let current = max(15, basePing + jitter)
            self.recordPing(current)
            
            self.bytesIn += UInt64.random(in: 1024...45000)
            self.bytesOut += UInt64.random(in: 512...12000)
        }
    }
    
    private func stopTelemetryTimer() {
        telemetryTimer?.invalidate()
        telemetryTimer = nil
    }
    
    // MARK: - Persistence (JSON storage in Application Support)
    private var dataFolderURL: URL {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let dir = paths[0].appendingPathComponent("XProject", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    public func saveServers() {
        let url = dataFolderURL.appendingPathComponent("servers.json")
        if let data = try? JSONEncoder().encode(servers) {
            try? data.write(to: url, options: .atomic)
        }
    }
    
    public func saveSubscriptions() {
        let url = dataFolderURL.appendingPathComponent("subscriptions.json")
        if let data = try? JSONEncoder().encode(subscriptions) {
            try? data.write(to: url, options: .atomic)
        }
    }
    
    public func saveRouting() {
        let url = dataFolderURL.appendingPathComponent("routing.json")
        if let data = try? JSONEncoder().encode(routingConfig) {
            try? data.write(to: url, options: .atomic)
        }
    }
    
    public func saveSettings() {
        let url = dataFolderURL.appendingPathComponent("settings.json")
        if let data = try? JSONEncoder().encode(settings) {
            try? data.write(to: url, options: .atomic)
        }
    }
    
    private func loadPersistedData() {
        // 1. Load Settings
        var settingsLoaded = false
        let settingsUrl = dataFolderURL.appendingPathComponent("settings.json")
        if let data = try? Data(contentsOf: settingsUrl),
           let st = try? JSONDecoder().decode(AppSettings.self, from: data) {
            self.settings = st
            settingsLoaded = true
        }
        
        // Ensure UserDefaults fallback parity for autoConnectOnLaunch ONLY if settings.json was not present
        if !settingsLoaded, UserDefaults.standard.object(forKey: "autoConnectOnLaunch") != nil {
            let udAuto = UserDefaults.standard.bool(forKey: "autoConnectOnLaunch")
            self.settings.autoConnectOnLaunch = udAuto
        } else if settingsLoaded {
            // Keep UserDefaults synchronized with settings.json
            UserDefaults.standard.set(self.settings.autoConnectOnLaunch, forKey: "autoConnectOnLaunch")
        }
        
        // 2. Load Routing
        let routingUrl = dataFolderURL.appendingPathComponent("routing.json")
        if let data = try? Data(contentsOf: routingUrl),
           let config = try? JSONDecoder().decode(RoutingConfig.self, from: data) {
            self.routingConfig = config
        }
        
        // Ensure routing mode parity
        if self.settings.routingMode != self.routingConfig.mode {
            self.settings.routingMode = self.routingConfig.mode
            saveSettings()
        }
        
        // 3. Load Subscriptions
        let subsUrl = dataFolderURL.appendingPathComponent("subscriptions.json")
        if let data = try? Data(contentsOf: subsUrl),
           let list = try? JSONDecoder().decode([Subscription].self, from: data) {
            self.subscriptions = list
        }
        
        // 4. Load Servers
        let serversUrl = dataFolderURL.appendingPathComponent("servers.json")
        if let data = try? Data(contentsOf: serversUrl),
           let list = try? JSONDecoder().decode([ServerProfile].self, from: data) {
            // Remove mock demo servers if they were previously saved
            let filtered = list.filter { !$0.address.hasSuffix(".xproject.network") }
            self.servers = filtered
            if filtered.count != list.count {
                saveServers()
            }
        }
        
        // 5. Restore previously selected server using all available identifiers
        restoreSelectedServer()
        
        // 6. Deduplicate servers
        deduplicateServers()
    }
    
    /// Probes the local proxy tunnel to confirm that internet traffic is successfully routing through the selected node
    public func checkLiveProxyReachability(httpPort: Int) async -> (reachable: Bool, exitIp: String?) {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
                process.arguments = ["-s", "-m", "4", "-x", "http://127.0.0.1:\(httpPort)", "https://api.ipify.org"]
                let pipe = Pipe()
                process.standardOutput = pipe
                do {
                    try process.run()
                    process.waitUntilExit()
                    if process.terminationStatus == 0 {
                        let data = pipe.fileHandleForReading.readDataToEndOfFile()
                        if let str = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !str.isEmpty {
                            continuation.resume(returning: (true, str))
                            return
                        }
                    }
                } catch {}
                continuation.resume(returning: (false, nil))
            }
        }
    }
}
