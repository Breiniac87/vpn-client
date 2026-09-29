import Foundation

public enum ServerProtocol: String, Codable, CaseIterable, Identifiable, Sendable {
    case vless = "VLESS"
    case trojan = "Trojan"
    case shadowsocks = "Shadowsocks"
    case customJson = "JSON"
    
    public var id: String { rawValue }
    
    public var badgeColorHex: String {
        switch self {
        case .vless: return "#00D2FF"     // Electric Cyan
        case .trojan: return "#FF007A"    // Neon Magenta
        case .shadowsocks: return "#FFAA00" // Neon Amber
        case .customJson: return "#A855F7"  // Purple
        }
    }
}

public struct VLESSDetails: Codable, Equatable, Hashable, Sendable {
    public var uuid: String
    public var flow: String?               // e.g. "xtls-rprx-vision"
    public var security: String            // e.g. "reality", "tls", "none"
    public var serverName: String?         // SNI
    public var publicKey: String?          // pbk for Reality
    public var shortId: String?            // sid for Reality
    public var fingerprint: String?        // e.g. "chrome", "firefox", "safari"
    public var spiderX: String?            // spx path
    public var transportType: String       // "tcp", "grpc", "ws"
    public var path: String?               // ws path or grpc serviceName
    public var hostHeader: String?         // ws host header
    
    public init(
        uuid: String,
        flow: String? = nil,
        security: String = "reality",
        serverName: String? = nil,
        publicKey: String? = nil,
        shortId: String? = nil,
        fingerprint: String? = "chrome",
        spiderX: String? = nil,
        transportType: String = "tcp",
        path: String? = nil,
        hostHeader: String? = nil
    ) {
        self.uuid = uuid
        self.flow = flow
        self.security = security
        self.serverName = serverName
        self.publicKey = publicKey
        self.shortId = shortId
        self.fingerprint = fingerprint
        self.spiderX = spiderX
        self.transportType = transportType
        self.path = path
        self.hostHeader = hostHeader
    }
}

public struct TrojanDetails: Codable, Equatable, Hashable, Sendable {
    public var password: String
    public var serverName: String?
    public var security: String
    public var transportType: String
    public var path: String?
    
    public init(
        password: String,
        serverName: String? = nil,
        security: String = "tls",
        transportType: String = "tcp",
        path: String? = nil
    ) {
        self.password = password
        self.serverName = serverName
        self.security = security
        self.transportType = transportType
        self.path = path
    }
}

public struct ShadowsocksDetails: Codable, Equatable, Hashable, Sendable {
    public var method: String
    public var password: String
    
    public init(method: String, password: String) {
        self.method = method
        self.password = password
    }
}

public struct ServerProfile: Identifiable, Codable, Equatable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var address: String
    public var port: Int
    public var protocolType: ServerProtocol
    
    // Details
    public var vlessDetails: VLESSDetails?
    public var trojanDetails: TrojanDetails?
    public var shadowsocksDetails: ShadowsocksDetails?
    public var rawJsonConfig: String?
    public var rawUri: String?
    
    // Metadata
    public var subscriptionId: UUID?
    public var pingMs: Int?
    public var lastTestedAt: Date?
    public var isFavorite: Bool
    public var createdAt: Date
    
    public init(
        id: UUID = UUID(),
        name: String,
        address: String,
        port: Int,
        protocolType: ServerProtocol,
        vlessDetails: VLESSDetails? = nil,
        trojanDetails: TrojanDetails? = nil,
        shadowsocksDetails: ShadowsocksDetails? = nil,
        rawJsonConfig: String? = nil,
        rawUri: String? = nil,
        subscriptionId: UUID? = nil,
        pingMs: Int? = nil,
        lastTestedAt: Date? = nil,
        isFavorite: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.port = port
        self.protocolType = protocolType
        self.vlessDetails = vlessDetails
        self.trojanDetails = trojanDetails
        self.shadowsocksDetails = shadowsocksDetails
        self.rawJsonConfig = rawJsonConfig
        self.rawUri = rawUri
        self.subscriptionId = subscriptionId
        self.pingMs = pingMs
        self.lastTestedAt = lastTestedAt
        self.isFavorite = isFavorite
        self.createdAt = createdAt
    }
    
    public var displayLocationOrHost: String {
        return "\(address):\(port)"
    }
    
    public var flagEmoji: String {
        var trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.contains("%"), let decoded = trimmed.removingPercentEncoding {
            trimmed = decoded
        }
        if let firstChar = trimmed.first {
            let scalars = firstChar.unicodeScalars
            let isFlag = scalars.contains(where: { (0x1F1E6...0x1F1FF).contains($0.value) })
            let isEmoji = scalars.contains(where: { $0.properties.isEmoji && !$0.isASCII })
            if isFlag || isEmoji {
                return String(firstChar)
            }
        }
        
        let n = (trimmed.removingPercentEncoding ?? trimmed).lowercased()
        if n.contains("nl") || n.contains("нидерланд") || n.contains("netherlands") || n.contains("amsterdam") { return "🇳🇱" }
        if n.contains("lv") || n.contains("латви") || n.contains("latvia") || n.contains("riga") { return "🇱🇻" }
        if n.contains("fi") || n.contains("финлянд") || n.contains("finland") || n.contains("helsinki") { return "🇫🇮" }
        if n.contains("us") || n.contains("сша") || n.contains("united states") || n.contains("usa") { return "🇺🇸" }
        if n.contains("de") || n.contains("герман") || n.contains("germany") || n.contains("frankfurt") { return "🇩🇪" }
        if n.contains("lt") || n.contains("литв") || n.contains("lithuania") || n.contains("vilnius") { return "🇱🇹" }
        if n.contains("gb") || n.contains("uk") || n.contains("британ") || n.contains("london") { return "🇬🇧" }
        if n.contains("se") || n.contains("швец") || n.contains("sweden") || n.contains("stockholm") { return "🇸🇪" }
        if n.contains("fr") || n.contains("франц") || n.contains("france") || n.contains("paris") { return "🇫🇷" }
        if n.contains("tr") || n.contains("турц") || n.contains("turkey") || n.contains("istanbul") { return "🇹🇷" }
        if n.contains("es") || n.contains("испан") || n.contains("spain") || n.contains("madrid") { return "🇪🇸" }
        if n.contains("pl") || n.contains("польш") || n.contains("poland") || n.contains("warsaw") { return "🇵🇱" }
        if n.contains("kz") || n.contains("казах") || n.contains("kazakhstan") || n.contains("almaty") { return "🇰🇿" }
        if n.contains("jp") || n.contains("япон") || n.contains("japan") || n.contains("tokyo") { return "🇯🇵" }
        if n.contains("sg") || n.contains("сингапур") || n.contains("singapore") { return "🇸🇬" }
        if n.contains("ch") || n.contains("швейцар") || n.contains("switzerland") || n.contains("zurich") { return "🇨🇭" }
        if n.contains("at") || n.contains("австри") || n.contains("austria") || n.contains("vienna") { return "🇦🇹" }
        if n.contains("ee") || n.contains("эстон") || n.contains("estonia") || n.contains("tallinn") { return "🇪🇪" }
        if n.contains("ge") || n.contains("грузи") || n.contains("georgia") || n.contains("tbilisi") { return "🇬🇪" }
        if n.contains("ua") || n.contains("украин") || n.contains("ukraine") || n.contains("kyiv") { return "🇺🇦" }
        if n.contains("eu") || n.contains("европ") || n.contains("hysteria") { return "🇪🇺" }
        return "🌐"
    }
    
    public var cleanDisplayName: String {
        var str = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if str.contains("%") {
            let decoded = str.removingPercentEncoding ?? str
            str = decoded.removingPercentEncoding ?? decoded
        }
        var modified = true
        while modified {
            modified = false
            str = str.trimmingCharacters(in: .whitespaces)
            if let firstChar = str.first {
                let scalars = firstChar.unicodeScalars
                let isFlag = scalars.contains(where: { (0x1F1E6...0x1F1FF).contains($0.value) })
                let isEmoji = scalars.contains(where: { $0.properties.isEmoji && !$0.isASCII })
                if isFlag || isEmoji {
                    str.removeFirst()
                    modified = true
                }
            }
        }
        str = str.trimmingCharacters(in: .whitespaces)
        
        // Remove trailing expiration/date tags like " | ⌛25-09-2026", " | ⏰25.09.2026", " | 25-09-2026"
        // so stale dates embedded in server remarks do not confuse the user.
        let datePattern = #"\s*\|\s*[⌛⏰⏳]?\s*\d{2}[.-]\d{2}[.-]\d{4}\s*$"#
        if let regex = try? NSRegularExpression(pattern: datePattern) {
            let range = NSRange(location: 0, length: (str as NSString).length)
            str = regex.stringByReplacingMatches(in: str, options: [], range: range, withTemplate: "")
        }
        
        let cleaned = str.trimmingCharacters(in: .whitespaces)
        return cleaned.isEmpty ? name : cleaned
    }
    
    public var protocolDetailsSubtitle: String {
        let jsonSuffix = rawJsonConfig != nil ? " | JSON" : ""
        switch protocolType {
        case .vless:
            let transport = vlessDetails?.transportType.uppercased() ?? "TCP"
            let sec = vlessDetails?.security.capitalized ?? "Reality"
            return "VLESS | \(transport) | \(sec)\(jsonSuffix)"
        case .trojan:
            return "Trojan | TLS\(jsonSuffix)"
        case .shadowsocks:
            let method = shadowsocksDetails?.method ?? "AEAD"
            return "Shadowsocks | \(method)\(jsonSuffix)"
        case .customJson:
            return "Custom JSON"
        }
    }
}
