import Foundation
import AppKit
import UniformTypeIdentifiers

@MainActor
public final class ImportCoordinator {
    public static let shared = ImportCoordinator()
    
    private init() {}
    
    /// Import from macOS system clipboard (supports vless, trojan, ss, Base64, raw JSON, and http/https subscription URLs)
    public func importFromClipboard(into appState: AppState) {
        var rawText = NSPasteboard.general.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Also check if clipboard contains an NSURL object
        if rawText == nil || rawText!.isEmpty {
            if let urls = NSPasteboard.general.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
               let firstUrl = urls.first {
                rawText = firstUrl.absoluteString
            }
        }
        
        guard let text = rawText, !text.isEmpty else {
            showNotification(
                title: "Буфер обмена пуст",
                message: "Скопируйте ссылку (vless://, trojan://, ss:// или URL подписки https://...) и попробуйте снова."
            )
            return
        }
        
        // 1. Check if the clipboard content is a Web / Subscription URL (http:// or https://)
        if text.lowercased().hasPrefix("http://") || text.lowercased().hasPrefix("https://") || text.lowercased().hasPrefix("sub://") {
            let cleanUrl = text.lowercased().hasPrefix("sub://") ? "https://" + text.dropFirst(6) : text
            importSubscriptionUrl(cleanUrl, into: appState)
            return
        }
        
        // 2. Universal parser for JSON array, JSON object, single link, or multiple links
        let parsedServers = URLSchemeParser.parseContent(text)
        if !parsedServers.isEmpty {
            for s in parsedServers { appState.addServer(s) }
            if parsedServers.count == 1 {
                let s = parsedServers[0]
                showNotification(title: "Сервер добавлен", message: "Успешно добавлен: \(s.name) [\(s.protocolType.rawValue)]")
            } else {
                showNotification(title: "Импорт завершен", message: "Импортировано \(parsedServers.count) серверов из буфера обмена.")
            }
            return
        }
        
        // If nothing matched, show a clear message
        showNotification(
            title: "Неподдерживаемый формат",
            message: "В буфере обмена не найдено поддерживаемых ссылок (vless://, trojan://, ss://, URL подписки https:// или JSON)."
        )
    }
    
    /// Imports a subscription from an HTTP/HTTPS URL
    public func importSubscriptionUrl(_ urlString: String, into appState: AppState) {
        let trimmedUrl = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Deduplicate subscription if already present
        let existingSub = appState.subscriptions.first(where: {
            $0.urlString.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == trimmedUrl.lowercased()
        })
        let subId = existingSub?.id ?? UUID()
        
        appState.appendLog(level: .info, message: "Загрузка подписки по URL: \(trimmedUrl)...")
        
        Task { @MainActor in
            do {
                let result = try await SubscriptionManager.shared.fetchSubscriptionWithUserInfo(from: trimmedUrl, subscriptionId: subId)
                guard !result.servers.isEmpty else {
                    showNotification(
                        title: "Подписка пуста",
                        message: "По указанному адресу не найдено активных серверов или конфигураций."
                    )
                    return
                }
                
                let titleCandidate = result.profileTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
                let effectiveName: String
                if let candidate = titleCandidate, !candidate.isEmpty {
                    effectiveName = candidate
                } else if let existing = existingSub?.name, !existing.starts(with: "Подписка #") {
                    effectiveName = existing
                } else {
                    effectiveName = "Подписка #\(appState.subscriptions.count + 1)"
                }
                
                // Remove existing servers belonging to this subscription to prevent duplicates
                appState.servers.removeAll(where: { $0.subscriptionId == subId })
                
                if let existingIndex = appState.subscriptions.firstIndex(where: { $0.id == subId }) {
                    if let candidate = titleCandidate, !candidate.isEmpty {
                        appState.subscriptions[existingIndex].name = candidate
                    }
                    appState.subscriptions[existingIndex].lastUpdated = Date()
                    appState.subscriptions[existingIndex].serverCount = result.servers.count
                    appState.subscriptions[existingIndex].uploadBytes = result.uploadBytes
                    appState.subscriptions[existingIndex].downloadBytes = result.downloadBytes
                    appState.subscriptions[existingIndex].totalBytes = result.totalBytes
                    appState.subscriptions[existingIndex].expireDate = result.expireDate
                    if let h = result.updateIntervalHours {
                        appState.subscriptions[existingIndex].updateIntervalHours = h
                    }
                } else {
                    let subscription = Subscription(
                        id: subId,
                        name: effectiveName,
                        urlString: trimmedUrl,
                        lastUpdated: Date(),
                        serverCount: result.servers.count,
                        uploadBytes: result.uploadBytes,
                        downloadBytes: result.downloadBytes,
                        totalBytes: result.totalBytes,
                        expireDate: result.expireDate,
                        updateIntervalHours: result.updateIntervalHours ?? 6
                    )
                    appState.subscriptions.append(subscription)
                }
                
                for s in result.servers {
                    appState.addServer(s)
                }
                appState.restoreSelectedServer()
                
                // If the subscription server returned a routing: "<base64>" header, offer 1-click update
                if let scheme = result.suggestedRoutingScheme {
                    appState.pendingRoutingSuggestion = (subscriptionName: effectiveName, scheme: scheme)
                    appState.appendLog(level: .info, message: "Подписка '\(effectiveName)' передала правила маршрутизации. Доступно быстрое обновление в 1 клик.")
                }
                
                appState.saveServers()
                appState.saveSubscriptions()
                
                showNotification(
                    title: "Подписка обновлена!",
                    message: "Успешно загружено \(result.servers.count) серверов из подписки '\(effectiveName)'."
                )
            } catch {
                showNotification(
                    title: "Ошибка загрузки подписки",
                    message: "Не удалось загрузить данные по URL: \(error.localizedDescription)"
                )
            }
        }
    }
    
    /// Scan active Mac screen for any visible QR code and import
    public func scanScreenQR(into appState: AppState) {
        Task { @MainActor in
            do {
                let qrPayload = try await ScreenQRScanner.scanScreen()
                
                // If QR contains a web URL
                if qrPayload.lowercased().hasPrefix("http://") || qrPayload.lowercased().hasPrefix("https://") {
                    self.importSubscriptionUrl(qrPayload, into: appState)
                    return
                }
                
                let server = try URLSchemeParser.parseSingleLink(qrPayload)
                appState.addServer(server)
                showNotification(title: "QR-код распознан!", message: "Добавлен сервер: \(server.name)")
            } catch {
                showNotification(title: "Сканирование экрана", message: error.localizedDescription)
            }
        }
    }
    
    /// Open file dialog for .json configuration
    public func importJsonFile(into appState: AppState) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [UTType.json]
        panel.title = "Выберите файл конфигурации JSON"
        
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let data = try Data(contentsOf: url)
                guard let jsonStr = String(data: data, encoding: .utf8) else {
                    throw ParserError.malformedUrl("Не удалось прочесть UTF-8 файл")
                }
                var server = try URLSchemeParser.parseRawJson(jsonStr)
                let filename = url.deletingPathExtension().lastPathComponent
                if server.name == "Imported JSON Config" {
                    server.name = filename
                }
                appState.addServer(server)
                showNotification(title: "JSON импортирован", message: "Конфигурация '\(server.name)' добавлена.")
            } catch {
                showNotification(title: "Ошибка чтения JSON", message: error.localizedDescription)
            }
        }
    }
    
    private func showNotification(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
