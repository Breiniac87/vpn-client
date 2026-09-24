import Foundation

public struct SubscriptionFetchResult: Sendable {
    public var servers: [ServerProfile]
    public var uploadBytes: UInt64?
    public var downloadBytes: UInt64?
    public var totalBytes: UInt64?
    public var expireDate: Date?
    public var profileTitle: String?
    public var updateIntervalHours: Int?
    public var suggestedRoutingScheme: HappRoutingScheme?
    
    public init(
        servers: [ServerProfile],
        uploadBytes: UInt64? = nil,
        downloadBytes: UInt64? = nil,
        totalBytes: UInt64? = nil,
        expireDate: Date? = nil,
        profileTitle: String? = nil,
        updateIntervalHours: Int? = nil,
        suggestedRoutingScheme: HappRoutingScheme? = nil
    ) {
        self.servers = servers
        self.uploadBytes = uploadBytes
        self.downloadBytes = downloadBytes
        self.totalBytes = totalBytes
        self.expireDate = expireDate
        self.profileTitle = profileTitle
        self.updateIntervalHours = updateIntervalHours
        self.suggestedRoutingScheme = suggestedRoutingScheme
    }
}

public final class SubscriptionManager: Sendable {
    public static let shared = SubscriptionManager()
    
    private let urlSession: URLSession
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 35.0
        config.timeoutIntervalForResource = 60.0
        self.urlSession = URLSession(configuration: config)
    }
    
    /// Decodes header values that may be Base64-encoded, percent-encoded, or Latin-1 wrapped UTF-8
    public static func decodeHeaderValue(_ rawVal: String) -> String? {
        var str = rawVal.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !str.isEmpty else { return nil }
        
        // 1. Check for "base64:" prefix (common in Marzban, 3X-UI, V2Ray panels)
        if str.lowercased().hasPrefix("base64:") {
            let b64 = String(str.dropFirst(7)).trimmingCharacters(in: .whitespacesAndNewlines)
            if let safeDecoded = ShadowsocksParser.decodeBase64Safe(b64) {
                str = safeDecoded.trimmingCharacters(in: .whitespacesAndNewlines)
            } else if let data = Data(base64Encoded: b64), let utf8Str = String(data: data, encoding: .utf8) {
                str = utf8Str.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        // 2. Check for percent encoding
        if let decoded = str.removingPercentEncoding, decoded != str {
            str = decoded
        }
        
        // 3. Check if encoded as Latin-1 bytes of UTF-8 string (URLSession HTTP header behavior)
        if let latinData = str.data(using: .isoLatin1), let utf8 = String(data: latinData, encoding: .utf8), !utf8.isEmpty {
            if utf8 != str && utf8.count < str.count {
                str = utf8
            }
        }
        
        // 4. Clean leading gear emojis if present so name is clean and consistent
        // e.g. "⚙️ Router. 🔑ПИН: s64s" -> "Router. 🔑ПИН: s64s"
        str = str.replacingOccurrences(of: "^[⚙️⚙\\s]+", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        return str.isEmpty ? nil : str
    }
    
    /// Extracts subscription title from URL fragment or query parameter
    public static func extractTitleFromUrl(_ urlString: String) -> String? {
        // Check fragment after #
        if let hashIdx = urlString.firstIndex(of: "#") {
            let frag = String(urlString[urlString.index(after: hashIdx)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !frag.isEmpty {
                let decoded = frag.removingPercentEncoding ?? frag
                let clean = decoded.replacingOccurrences(of: "^[⚙️⚙\\s]+", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !clean.isEmpty { return clean }
            }
        }
        
        // Check query items (?name= or ?title=)
        if let url = URL(string: urlString), let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            if let titleItem = components.queryItems?.first(where: { $0.name.lowercased() == "name" || $0.name.lowercased() == "title" }),
               let val = titleItem.value, !val.isEmpty {
                let clean = val.replacingOccurrences(of: "^[⚙️⚙\\s]+", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !clean.isEmpty { return clean }
            }
        }
        
        return nil
    }
    
    /// Fetches subscription with parsed traffic quota, expiration date, and profile title
    public func fetchSubscriptionWithUserInfo(from urlString: String, subscriptionId: UUID) async throws -> SubscriptionFetchResult {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw ParserError.malformedUrl("Некорректный URL подписки: \(urlString)")
        }
        
        var request = URLRequest(url: url)
        request.setValue("Happ/3.6.0 (iPhone; iOS 18.0; Scale/3.00)", forHTTPHeaderField: "User-Agent")
        
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            // Automatic retry once on timeout or transient network drop
            if let urlError = error as? URLError,
               [URLError.timedOut, URLError.cannotConnectToHost, URLError.networkConnectionLost].contains(urlError.code) {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s pause
                (data, response) = try await urlSession.data(for: request)
            } else {
                throw error
            }
        }
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw ParserError.malformedUrl("Сервер подписки вернул статус HTTP \(status)")
        }
        
        // Parse HTTP headers
        var uploadBytes: UInt64?
        var downloadBytes: UInt64?
        var totalBytes: UInt64?
        var expireDate: Date?
        var profileTitle: String?
        var updateIntervalHours: Int?
        var suggestedRoutingScheme: HappRoutingScheme?
        
        for (key, val) in httpResponse.allHeaderFields {
            guard let strKey = key as? String, let headerVal = val as? String else { continue }
            let lowerKey = strKey.lowercased()
            
            if lowerKey == "subscription-userinfo" {
                let parts = headerVal.split(separator: ";")
                for part in parts {
                    let kv = part.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
                    if kv.count == 2 {
                        let k = kv[0].lowercased()
                        let v = kv[1]
                        if k == "upload", let u = UInt64(v) { uploadBytes = u }
                        else if k == "download", let d = UInt64(v) { downloadBytes = d }
                        else if k == "total", let t = UInt64(v) { totalBytes = t }
                        else if k == "expire", let e = TimeInterval(v), e > 0 {
                            expireDate = Date(timeIntervalSince1970: e)
                        }
                    }
                }
            } else if lowerKey == "profile-title" {
                if let decoded = Self.decodeHeaderValue(headerVal) {
                    profileTitle = decoded
                }
            } else if lowerKey == "announce" && profileTitle == nil {
                if let decoded = Self.decodeHeaderValue(headerVal) {
                    profileTitle = decoded
                }
            } else if (lowerKey == "x-profile-title" || lowerKey == "profile-name" || lowerKey == "subscription-title") && profileTitle == nil {
                if let decoded = Self.decodeHeaderValue(headerVal) {
                    profileTitle = decoded
                }
            } else if lowerKey == "profile-update-interval" {
                if let hours = Int(headerVal.trimmingCharacters(in: .whitespacesAndNewlines)) {
                    updateIntervalHours = hours
                }
            } else if lowerKey == "routing" || lowerKey == "x-routing" {
                var raw = headerVal.trimmingCharacters(in: .whitespacesAndNewlines)
                if raw.hasPrefix("\"") && raw.hasSuffix("\"") && raw.count >= 2 {
                    raw = String(raw.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
                }
                if raw.lowercased().hasPrefix("base64:") {
                    raw = String(raw.dropFirst(7)).trimmingCharacters(in: .whitespacesAndNewlines)
                }
                if let scheme = try? HappRoutingCodec.decode(from: raw) {
                    suggestedRoutingScheme = scheme
                }
            }
        }
        
        // Fallback to URL fragment or query if not in headers
        if profileTitle == nil {
            profileTitle = Self.extractTitleFromUrl(urlString)
        }
        
        guard let rawString = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) else {
            throw ParserError.invalidBase64("Не удалось прочитать текстовый ответ от сервера подписки")
        }
        
        // Check if content is Base64 encoded (common for v2ray/xray subscriptions)
        let decodedContent: String
        let trimmedRaw = rawString.trimmingCharacters(in: .whitespacesAndNewlines)
        if (trimmedRaw.hasPrefix("[") && trimmedRaw.hasSuffix("]")) || (trimmedRaw.hasPrefix("{") && trimmedRaw.hasSuffix("}")) {
            decodedContent = trimmedRaw
        } else if let decoded = ShadowsocksParser.decodeBase64Safe(rawString) {
            decodedContent = decoded
        } else {
            decodedContent = rawString
        }
        
        // If profile title still nil, inspect decoded content header lines (e.g. #profile-title: ...)
        if profileTitle == nil {
            let lines = decodedContent.components(separatedBy: .newlines)
            for line in lines.prefix(5) {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.lowercased().hasPrefix("#profile-title:") || trimmed.lowercased().hasPrefix("//profile-title:") {
                    let raw = String(trimmed.dropFirst(15))
                    if let decoded = Self.decodeHeaderValue(raw) {
                        profileTitle = decoded
                        break
                    }
                }
            }
        }
        
        var servers = URLSchemeParser.parseContent(decodedContent)
        if servers.isEmpty && decodedContent != rawString {
            servers = URLSchemeParser.parseContent(rawString)
        }
        
        // Tag servers with this subscription ID
        for i in 0..<servers.count {
            servers[i].subscriptionId = subscriptionId
        }
        
        return SubscriptionFetchResult(
            servers: servers,
            uploadBytes: uploadBytes,
            downloadBytes: downloadBytes,
            totalBytes: totalBytes,
            expireDate: expireDate,
            profileTitle: profileTitle,
            updateIntervalHours: updateIntervalHours,
            suggestedRoutingScheme: suggestedRoutingScheme
        )
    }
    
    /// Legacy fetch wrapper returning server profiles
    public func fetchSubscription(from urlString: String, subscriptionId: UUID) async throws -> [ServerProfile] {
        let result = try await fetchSubscriptionWithUserInfo(from: urlString, subscriptionId: subscriptionId)
        return result.servers
    }
    
    /// Updates all subscriptions in AppState
    public func updateAllSubscriptions(in appState: AppState) async {
        appState.appendLog(level: .info, message: "Запущено фоновое обновление подписок...")
        var totalFetched = 0
        
        for sub in appState.subscriptions {
            do {
                let result = try await fetchSubscriptionWithUserInfo(from: sub.urlString, subscriptionId: sub.id)
                await MainActor.run {
                    guard !result.servers.isEmpty else {
                        appState.appendLog(level: .warning, message: "Подписка '\(sub.name)' вернула 0 серверов. Существующие серверы сохранены.")
                        if let idx = appState.subscriptions.firstIndex(where: { $0.id == sub.id }) {
                            if let u = result.uploadBytes { appState.subscriptions[idx].uploadBytes = u }
                            if let d = result.downloadBytes { appState.subscriptions[idx].downloadBytes = d }
                            if let t = result.totalBytes { appState.subscriptions[idx].totalBytes = t }
                            if let exp = result.expireDate { appState.subscriptions[idx].expireDate = exp }
                            appState.saveSubscriptions()
                        }
                        return
                    }
                    
                    let prevSelectedName = appState.selectedServer?.name
                    // Remove old servers belonging to this subscription
                    appState.servers.removeAll(where: { $0.subscriptionId == sub.id })
                    // Append new
                    appState.servers.append(contentsOf: result.servers)
                    appState.restoreSelectedServer(preferringName: prevSelectedName)
                    
                    // Update subscription info
                    if let idx = appState.subscriptions.firstIndex(where: { $0.id == sub.id }) {
                        if let title = result.profileTitle, !title.isEmpty {
                            appState.subscriptions[idx].name = title
                        }
                        appState.subscriptions[idx].lastUpdated = Date()
                        appState.subscriptions[idx].serverCount = result.servers.count
                        if let u = result.uploadBytes { appState.subscriptions[idx].uploadBytes = u }
                        if let d = result.downloadBytes { appState.subscriptions[idx].downloadBytes = d }
                        if let t = result.totalBytes { appState.subscriptions[idx].totalBytes = t }
                        if let exp = result.expireDate { appState.subscriptions[idx].expireDate = exp }
                        if let h = result.updateIntervalHours { appState.subscriptions[idx].updateIntervalHours = h }
                    }
                    
                    // Check for server suggested routing rules
                    if let scheme = result.suggestedRoutingScheme {
                        appState.pendingRoutingSuggestion = (subscriptionName: sub.name, scheme: scheme)
                        appState.appendLog(level: .info, message: "Подписка '\(sub.name)' передала правила маршрутизации. Доступно быстрое обновление в 1 клик.")
                    }
                    
                    appState.saveServers()
                    appState.saveSubscriptions()
                }
                totalFetched += result.servers.count
                appState.appendLog(level: .info, message: "Подписка '\(sub.name)' обновлена: загружено \(result.servers.count) серверов")
            } catch {
                appState.appendLog(level: .error, message: "Ошибка обновления подписки '\(sub.name)': \(error.localizedDescription)")
            }
        }
        
        appState.appendLog(level: .info, message: "Обновление подписок завершено. Всего активных серверов: \(appState.servers.count)")
    }
}
