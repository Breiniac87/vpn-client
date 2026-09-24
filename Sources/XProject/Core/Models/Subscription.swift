import Foundation

public struct Subscription: Identifiable, Codable, Equatable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var urlString: String
    public var lastUpdated: Date?
    public var autoUpdateOnLaunch: Bool
    public var serverCount: Int
    public var rawContent: String?
    
    // Quota & expiration (from Subscription-Userinfo header)
    public var uploadBytes: UInt64?
    public var downloadBytes: UInt64?
    public var totalBytes: UInt64?
    public var expireDate: Date?
    public var updateIntervalHours: Int? = 6
    public var isCollapsed: Bool = false
    
    public init(
        id: UUID = UUID(),
        name: String,
        urlString: String,
        lastUpdated: Date? = nil,
        autoUpdateOnLaunch: Bool = true,
        serverCount: Int = 0,
        rawContent: String? = nil,
        uploadBytes: UInt64? = nil,
        downloadBytes: UInt64? = nil,
        totalBytes: UInt64? = nil,
        expireDate: Date? = nil,
        updateIntervalHours: Int? = 6,
        isCollapsed: Bool = false
    ) {
        self.id = id
        self.name = name
        self.urlString = urlString
        self.lastUpdated = lastUpdated
        self.autoUpdateOnLaunch = autoUpdateOnLaunch
        self.serverCount = serverCount
        self.rawContent = rawContent
        self.uploadBytes = uploadBytes
        self.downloadBytes = downloadBytes
        self.totalBytes = totalBytes
        self.expireDate = expireDate
        self.updateIntervalHours = updateIntervalHours
        self.isCollapsed = isCollapsed
    }
    
    // MARK: - Computed Properties
    public var usedBytes: UInt64 {
        (uploadBytes ?? 0) + (downloadBytes ?? 0)
    }
    
    public var trafficProgress: Double {
        guard let total = totalBytes, total > 0 else { return 0.0 }
        let progress = Double(usedBytes) / Double(total)
        return min(max(progress, 0.0), 1.0)
    }
    
    public var formattedTraffic: String {
        guard let total = totalBytes, total > 0 else {
            return "\(formatBytes(usedBytes))"
        }
        return "\(formatBytes(usedBytes)) / \(formatBytes(total))"
    }
    
    public var formattedExpireDate: String {
        guard let exp = expireDate else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        return "Истекает: \(formatter.string(from: exp))"
    }
    
    public var formattedLastUpdated: String {
        guard let date = lastUpdated else { return "Не обновлялась" }
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy HH:mm"
        let hours = updateIntervalHours ?? 6
        return "\(formatter.string(from: date)) | Автообновление - \(hours) ч."
    }
    
    private func formatBytes(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / (1024 * 1024 * 1024)
        if gb >= 1024 {
            let tb = gb / 1024
            return String(format: "%.1f TB", tb)
        }
        if gb >= 1 {
            return String(format: "%.0f GB", gb)
        }
        let mb = Double(bytes) / (1024 * 1024)
        return String(format: "%.0f MB", mb)
    }
}
