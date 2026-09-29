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
    
    public var daysRemaining: Int? {
        guard let exp = expireDate else { return nil }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let end = calendar.startOfDay(for: exp)
        let components = calendar.dateComponents([.day], from: start, to: end)
        return components.day
    }
    
    public var isExpired: Bool {
        guard let exp = expireDate else { return false }
        return exp < Date()
    }
    
    public var formattedExpireDate: String {
        guard let exp = expireDate else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        let dateStr = formatter.string(from: exp)
        
        if let days = daysRemaining {
            if days < 0 {
                return "Истекла: \(dateStr)"
            } else if days == 0 {
                return "Истекает сегодня"
            } else if days == 1 {
                return "Истекает завтра"
            } else {
                return "Истекает: \(dateStr) (\(days) дн.)"
            }
        }
        return "Истекает: \(dateStr)"
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
    
    // MARK: - Canonical URL Normalization & Deduplication
    
    /// Normalizes a subscription URL string for reliable comparison and deduplication:
    /// - Strips fragments (#...)
    /// - Normalizes scheme and host to lowercase
    /// - Strips trailing slashes
    /// - Strips dynamic cache-busting query items (?t=..., ?_t=..., etc.)
    public static func normalizeUrl(_ raw: String) -> String {
        var str = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !str.isEmpty else { return "" }
        
        // Strip fragment (#...)
        if let hashIdx = str.firstIndex(of: "#") {
            str = String(str[..<hashIdx]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        if let components = URLComponents(string: str) {
            let scheme = components.scheme?.lowercased() ?? "https"
            let host = components.host?.lowercased() ?? ""
            let portStr = components.port != nil ? ":\(components.port!)" : ""
            var path = components.percentEncodedPath
            
            while path.count > 1 && path.hasSuffix("/") {
                path.removeLast()
            }
            
            var queryStr = ""
            if let queryItems = components.queryItems, !queryItems.isEmpty {
                let filteredItems = queryItems
                    .filter { !["_t", "t", "ts", "timestamp", "rand", "_"].contains($0.name.lowercased()) }
                    .sorted(by: { $0.name < $1.name })
                if !filteredItems.isEmpty {
                    var qc = URLComponents()
                    qc.queryItems = filteredItems
                    if let q = qc.percentEncodedQuery, !q.isEmpty {
                        queryStr = "?\(q)"
                    }
                }
            }
            
            return "\(scheme)://\(host)\(portStr)\(path)\(queryStr)"
        }
        
        while str.count > 1 && str.hasSuffix("/") {
            str.removeLast()
        }
        return str.lowercased()
    }
    
    /// Checks if another subscription or URL represents the same subscription entity
    public func isSameSubscription(as otherUrl: String, otherName: String? = nil) -> Bool {
        let normSelf = Self.normalizeUrl(urlString)
        let normOther = Self.normalizeUrl(otherUrl)
        
        if normSelf == normOther {
            return true
        }
        
        // Check if path & token match across domain mirrors (e.g. 3dh.pro vs 3dh.live)
        if let u1 = URL(string: normSelf), let u2 = URL(string: normOther) {
            if u1.path == u2.path && !u1.path.isEmpty && u1.path != "/" {
                return true
            }
        }
        
        // If names are non-generic and identical, consider them the same
        if let oName = otherName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !oName.isEmpty && !oName.starts(with: "Подписка #") {
            let sName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !sName.isEmpty && !sName.starts(with: "Подписка #") && sName.lowercased() == oName.lowercased() {
                return true
            }
        }
        
        return false
    }
}
