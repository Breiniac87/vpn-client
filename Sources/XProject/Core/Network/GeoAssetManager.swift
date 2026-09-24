import Foundation

/// Metadata tracking the version, file sizes, and last update date of local geo assets
public struct GeoAssetMetadata: Codable, Equatable, Sendable {
    public var lastUpdated: Date?
    public var geositeBytes: Int
    public var geoipBytes: Int
    public var source: String
    
    public init(
        lastUpdated: Date? = nil,
        geositeBytes: Int = 0,
        geoipBytes: Int = 0,
        source: String = "DigneZzZ/routing (jsDelivr)"
    ) {
        self.lastUpdated = lastUpdated
        self.geositeBytes = geositeBytes
        self.geoipBytes = geoipBytes
        self.source = source
    }
}

/// Service managing manual and silent daily background updates of geosite.dat and geoip.dat
public final class GeoAssetManager: Sendable {
    public static let shared = GeoAssetManager()
    
    // Primary fast CDN in CIS and GitHub fallback
    private let geositePrimaryUrl = "https://cdn.jsdelivr.net/gh/DigneZzZ/routing@main/v2ray/geosite.dat"
    private let geoipPrimaryUrl = "https://cdn.jsdelivr.net/gh/DigneZzZ/routing@main/v2ray/geoip.dat"
    
    private let geositeFallbackUrl = "https://raw.githubusercontent.com/DigneZzZ/routing/main/v2ray/geosite.dat"
    private let geoipFallbackUrl = "https://raw.githubusercontent.com/DigneZzZ/routing/main/v2ray/geoip.dat"
    
    private let urlSession: URLSession
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 45.0
        self.urlSession = URLSession(configuration: config)
    }
    
    /// Target directory for dynamic assets: ~/Library/Application Support/XProject/assets
    public static var assetsDirectoryURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("XProject/assets", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    public static var metadataURL: URL {
        assetsDirectoryURL.appendingPathComponent("metadata.json")
    }
    
    public static func loadMetadata() -> GeoAssetMetadata {
        if let data = try? Data(contentsOf: metadataURL),
           let meta = try? JSONDecoder().decode(GeoAssetMetadata.self, from: data) {
            return meta
        }
        return GeoAssetMetadata()
    }
    
    public static func saveMetadata(_ meta: GeoAssetMetadata) {
        if let data = try? JSONEncoder().encode(meta) {
            try? data.write(to: metadataURL, options: .atomic)
        }
    }
    
    /// Downloads fresh geosite.dat and geoip.dat and saves them to ~/Library/Application Support/XProject/assets
    public func downloadAndInstallAssets(
        progress: (@Sendable (Double, String) -> Void)? = nil
    ) async throws -> (geositeBytes: Int, geoipBytes: Int) {
        let dir = Self.assetsDirectoryURL
        
        progress?(0.15, "Загрузка geosite.dat с jsDelivr CDN...")
        let geositeData = try await downloadData(primary: geositePrimaryUrl, fallback: geositeFallbackUrl)
        guard geositeData.count > 50_000 else {
            throw ParserError.malformedUrl("Файл geosite.dat повреждён или имеет некорректный размер (\(geositeData.count) байт)")
        }
        
        progress?(0.55, "Загрузка geoip.dat с jsDelivr CDN...")
        let geoipData = try await downloadData(primary: geoipPrimaryUrl, fallback: geoipFallbackUrl)
        guard geoipData.count > 50_000 else {
            throw ParserError.malformedUrl("Файл geoip.dat повреждён или имеет некорректный размер (\(geoipData.count) байт)")
        }
        
        progress?(0.9, "Установка баз гео-маршрутизации...")
        let geositeDest = dir.appendingPathComponent("geosite.dat")
        let geoipDest = dir.appendingPathComponent("geoip.dat")
        
        try geositeData.write(to: geositeDest, options: .atomic)
        try geoipData.write(to: geoipDest, options: .atomic)
        
        let meta = GeoAssetMetadata(
            lastUpdated: Date(),
            geositeBytes: geositeData.count,
            geoipBytes: geoipData.count,
            source: "DigneZzZ/routing (jsDelivr)"
        )
        Self.saveMetadata(meta)
        
        progress?(1.0, "Базы успешно обновлены!")
        return (geositeData.count, geoipData.count)
    }
    
    private func downloadData(primary: String, fallback: String) async throws -> Data {
        if let url = URL(string: primary) {
            do {
                let (data, res) = try await urlSession.data(from: url)
                if let http = res as? HTTPURLResponse, (200...299).contains(http.statusCode), !data.isEmpty {
                    return data
                }
            } catch {
                // Try fallback on network/timeout error
            }
        }
        
        guard let fbUrl = URL(string: fallback) else {
            throw ParserError.malformedUrl("Некорректный резервный адрес: \(fallback)")
        }
        let (data, res) = try await urlSession.data(from: fbUrl)
        guard let http = res as? HTTPURLResponse, (200...299).contains(http.statusCode), !data.isEmpty else {
            throw ParserError.malformedUrl("Не удалось скачать гео-базы с серверов")
        }
        return data
    }
    
    /// Performs silent background update check once per day.
    /// If failed: writes to log file silently without showing any UI popups, and will re-attempt on next day startup.
    public func checkAndPerformBackgroundUpdate(onLog: @escaping @Sendable (LogLevel, String) -> Void) {
        let key = "last_geo_update_attempt_day"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayString = formatter.string(from: Date())
        
        let lastAttempt = UserDefaults.standard.string(forKey: key)
        if lastAttempt == todayString {
            // Already attempted today, do not spam
            return
        }
        
        UserDefaults.standard.set(todayString, forKey: key)
        
        Task.detached(priority: .background) { [weak self] in
            guard let self = self else { return }
            do {
                let (geositeBytes, geoipBytes) = try await self.downloadAndInstallAssets()
                let formatter = ByteCountFormatter()
                formatter.countStyle = .binary
                let siteStr = formatter.string(fromByteCount: Int64(geositeBytes))
                let ipStr = formatter.string(fromByteCount: Int64(geoipBytes))
                onLog(.info, "✅ [Фоновое обновление] Базы гео-маршрутизации успешно обновлены (geosite: \(siteStr), geoip: \(ipStr), источник: DigneZzZ/routing)")
            } catch {
                // As requested: silent log without any user disturbance
                onLog(.warning, "ℹ️ [Фоновое обновление] Загрузка гео-баз не удалась: \(error.localizedDescription). Повторная попытка будет выполнена при следующем запуске.")
            }
        }
    }
}
