import Foundation

/// Data structure matching the Happ routing schema used in `Happ-proxy/routing_generator`
public struct HappRoutingScheme: Codable, Equatable, Sendable {
    public var name: String
    public var globalProxy: Bool
    public var remoteDNSType: String?
    public var remoteDNSDomain: String?
    public var remoteDNSIP: String?
    public var domesticDNSType: String?
    public var domesticDNSDomain: String?
    public var domesticDNSIP: String?
    public var geoipUrl: String?
    public var geositeUrl: String?
    public var lastUpdated: String?
    public var directSites: [String]
    public var directIp: [String]
    public var proxySites: [String]
    public var proxyIp: [String]
    public var blockSites: [String]
    public var blockIp: [String]
    public var domainStrategy: String
    public var fakeDNS: Bool
    
    public init(
        name: String = "X-project Scheme",
        globalProxy: Bool = false,
        remoteDNSType: String? = "DoH",
        remoteDNSDomain: String? = "cloudflare-dns.com",
        remoteDNSIP: String? = "1.1.1.1",
        domesticDNSType: String? = "DoH",
        domesticDNSDomain: String? = nil,
        domesticDNSIP: String? = "77.88.8.8",
        geoipUrl: String? = nil,
        geositeUrl: String? = nil,
        lastUpdated: String? = nil,
        directSites: [String] = [],
        directIp: [String] = [],
        proxySites: [String] = [],
        proxyIp: [String] = [],
        blockSites: [String] = [],
        blockIp: [String] = [],
        domainStrategy: String = "IPIfNonMatch",
        fakeDNS: Bool = false
    ) {
        self.name = name
        self.globalProxy = globalProxy
        self.remoteDNSType = remoteDNSType
        self.remoteDNSDomain = remoteDNSDomain
        self.remoteDNSIP = remoteDNSIP
        self.domesticDNSType = domesticDNSType
        self.domesticDNSDomain = domesticDNSDomain
        self.domesticDNSIP = domesticDNSIP
        self.geoipUrl = geoipUrl
        self.geositeUrl = geositeUrl
        self.lastUpdated = lastUpdated
        self.directSites = directSites
        self.directIp = directIp
        self.proxySites = proxySites
        self.proxyIp = proxyIp
        self.blockSites = blockSites
        self.blockIp = blockIp
        self.domainStrategy = domainStrategy
        self.fakeDNS = fakeDNS
    }
    
    private enum CodingKeys: String, CodingKey {
        case Name
        case GlobalProxy
        case RemoteDNSType
        case RemoteDNSDomain
        case RemoteDNSIP
        case DomesticDNSType
        case DomesticDNSDomain
        case DomesticDNSIP
        case Geoipurl
        case Geositeurl
        case LastUpdated
        case DirectSites
        case DirectIp
        case ProxySites
        case ProxyIp
        case BlockSites
        case BlockIp
        case DomainStrategy
        case FakeDNS
    }
    
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.name = (try? c.decodeIfPresent(String.self, forKey: .Name)) ?? "Happ Scheme"
        
        // Handle GlobalProxy as String ("true"/"false") or Bool
        if let boolVal = try? c.decodeIfPresent(Bool.self, forKey: .GlobalProxy) {
            self.globalProxy = boolVal
        } else if let strVal = try? c.decodeIfPresent(String.self, forKey: .GlobalProxy) {
            self.globalProxy = (strVal.lowercased() == "true")
        } else {
            self.globalProxy = false
        }
        
        self.remoteDNSType = try? c.decodeIfPresent(String.self, forKey: .RemoteDNSType)
        self.remoteDNSDomain = try? c.decodeIfPresent(String.self, forKey: .RemoteDNSDomain)
        self.remoteDNSIP = try? c.decodeIfPresent(String.self, forKey: .RemoteDNSIP)
        self.domesticDNSType = try? c.decodeIfPresent(String.self, forKey: .DomesticDNSType)
        self.domesticDNSDomain = try? c.decodeIfPresent(String.self, forKey: .DomesticDNSDomain)
        self.domesticDNSIP = try? c.decodeIfPresent(String.self, forKey: .DomesticDNSIP)
        self.geoipUrl = try? c.decodeIfPresent(String.self, forKey: .Geoipurl)
        self.geositeUrl = try? c.decodeIfPresent(String.self, forKey: .Geositeurl)
        self.lastUpdated = try? c.decodeIfPresent(String.self, forKey: .LastUpdated)
        
        self.directSites = (try? c.decodeIfPresent([String].self, forKey: .DirectSites)) ?? []
        self.directIp = (try? c.decodeIfPresent([String].self, forKey: .DirectIp)) ?? []
        self.proxySites = (try? c.decodeIfPresent([String].self, forKey: .ProxySites)) ?? []
        self.proxyIp = (try? c.decodeIfPresent([String].self, forKey: .ProxyIp)) ?? []
        self.blockSites = (try? c.decodeIfPresent([String].self, forKey: .BlockSites)) ?? []
        self.blockIp = (try? c.decodeIfPresent([String].self, forKey: .BlockIp)) ?? []
        
        self.domainStrategy = (try? c.decodeIfPresent(String.self, forKey: .DomainStrategy)) ?? "IPIfNonMatch"
        
        // Handle FakeDNS as String ("true"/"false") or Bool
        if let boolVal = try? c.decodeIfPresent(Bool.self, forKey: .FakeDNS) {
            self.fakeDNS = boolVal
        } else if let strVal = try? c.decodeIfPresent(String.self, forKey: .FakeDNS) {
            self.fakeDNS = (strVal.lowercased() == "true")
        } else {
            self.fakeDNS = false
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(name, forKey: .Name)
        try c.encode(globalProxy ? "true" : "false", forKey: .GlobalProxy)
        try c.encodeIfPresent(remoteDNSType, forKey: .RemoteDNSType)
        try c.encodeIfPresent(remoteDNSDomain, forKey: .RemoteDNSDomain)
        try c.encodeIfPresent(remoteDNSIP, forKey: .RemoteDNSIP)
        try c.encodeIfPresent(domesticDNSType, forKey: .DomesticDNSType)
        try c.encodeIfPresent(domesticDNSDomain, forKey: .DomesticDNSDomain)
        try c.encodeIfPresent(domesticDNSIP, forKey: .DomesticDNSIP)
        try c.encodeIfPresent(geoipUrl, forKey: .Geoipurl)
        try c.encodeIfPresent(geositeUrl, forKey: .Geositeurl)
        try c.encodeIfPresent(lastUpdated, forKey: .LastUpdated)
        try c.encode(directSites, forKey: .DirectSites)
        try c.encode(directIp, forKey: .DirectIp)
        try c.encode(proxySites, forKey: .ProxySites)
        try c.encode(proxyIp, forKey: .ProxyIp)
        try c.encode(blockSites, forKey: .BlockSites)
        try c.encode(blockIp, forKey: .BlockIp)
        try c.encode(domainStrategy, forKey: .DomainStrategy)
        try c.encode(fakeDNS ? "true" : "false", forKey: .FakeDNS)
    }
    
    public var hasMeaningfulData: Bool {
        return !directSites.isEmpty || !proxySites.isEmpty || !blockSites.isEmpty || !directIp.isEmpty || !proxyIp.isEmpty || !blockIp.isEmpty
    }
}

/// Data structure matching the V2RayTUN routing document format (`v2rayTun://import_route/...`)
public struct V2RayTunRoutingDoc: Codable {
    public var domainStrategy: String?
    public var domainMatcher: String?
    public var id: String?
    public var name: String?
    public var rules: [V2RayTunRule]?
    
    public struct V2RayTunRule: Codable {
        public var domain: [String]?
        public var ip: [String]?
        public var protocolType: [String]?
        public var outboundTag: String?
        public var name: String?
        
        enum CodingKeys: String, CodingKey {
            case domain
            case ip
            case protocolType = "protocol"
            case outboundTag
            case name = "__name__"
        }
    }
}

// MARK: - Happ & V2RayTUN Routing Codec
public struct HappRoutingCodec {
    
    /// Converts a current `RoutingConfig` into a `HappRoutingScheme`
    public static func buildScheme(from config: RoutingConfig, name: String = "X-project Scheme") -> HappRoutingScheme {
        var directSites: [String] = []
        var directIp: [String] = []
        for rule in config.directRules where rule.isEnabled {
            let val = rule.value.trimmingCharacters(in: .whitespacesAndNewlines)
            if val.lowercased().hasPrefix("geoip:") || isIP(val) {
                directIp.append(val)
            } else {
                directSites.append(val)
            }
        }
        
        var proxySites: [String] = []
        var proxyIp: [String] = []
        for rule in config.proxyRules where rule.isEnabled {
            let val = rule.value.trimmingCharacters(in: .whitespacesAndNewlines)
            if val.lowercased().hasPrefix("geoip:") || isIP(val) {
                proxyIp.append(val)
            } else {
                proxySites.append(val)
            }
        }
        
        var blockSites: [String] = []
        var blockIp: [String] = []
        for rule in config.blockRules where rule.isEnabled {
            let val = rule.value.trimmingCharacters(in: .whitespacesAndNewlines)
            if val.lowercased().hasPrefix("geoip:") || isIP(val) {
                blockIp.append(val)
            } else {
                blockSites.append(val)
            }
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let timestamp = formatter.string(from: Date())
        
        return HappRoutingScheme(
            name: name,
            globalProxy: config.mode == .global,
            remoteDNSType: "DoH",
            remoteDNSDomain: "cloudflare-dns.com",
            remoteDNSIP: "1.1.1.1",
            domesticDNSType: "DoH",
            domesticDNSDomain: nil,
            domesticDNSIP: "77.88.8.8",
            geoipUrl: nil,
            geositeUrl: nil,
            lastUpdated: timestamp,
            directSites: directSites,
            directIp: directIp,
            proxySites: proxySites,
            proxyIp: proxyIp,
            blockSites: blockSites,
            blockIp: blockIp,
            domainStrategy: config.domainStrategy,
            fakeDNS: config.fakeDnsEnabled
        )
    }
    
    /// Exports the configuration as pretty-printed JSON string
    public static func exportJson(from config: RoutingConfig, name: String = "X-project Scheme") throws -> String {
        let scheme = buildScheme(from: config, name: name)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(scheme)
        guard let str = String(data: data, encoding: .utf8) else {
            throw ParserError.malformedUrl("Не удалось сформировать JSON схемы Happ")
        }
        return str
    }
    
    /// Exports the configuration as Base64 encoded string
    public static func exportBase64(from config: RoutingConfig, name: String = "X-project Scheme") throws -> String {
        let scheme = buildScheme(from: config, name: name)
        let encoder = JSONEncoder()
        let data = try encoder.encode(scheme)
        return data.base64EncodedString()
    }
    
    /// Exports the configuration as `happ://routing/add/<base64>` deep-link URL
    public static func exportHappUrl(from config: RoutingConfig, name: String = "X-project Scheme") throws -> String {
        let base64 = try exportBase64(from: config, name: name)
        return "happ://routing/add/" + base64
    }
    
    /// Exports the configuration as `v2rayTun://import_route/<base64>` deep-link URL
    public static func exportV2RayTunUrl(from config: RoutingConfig, name: String = "X-project Scheme") throws -> String {
        let base64 = try exportBase64(from: config, name: name)
        return "v2rayTun://import_route/" + base64
    }
    
    /// Decodes a scheme from a URL (`happ://`, `incy://`, `v2rayTun://`), Base64 string, or raw JSON
    public static func decode(from input: String) throws -> HappRoutingScheme {
        var cleanInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 0. Unwrap web relay URL wrappers (e.g. https://r.far.ovh/?url=happ%3A%2F%2F...)
        if cleanInput.lowercased().contains("?url=") {
            if let components = URLComponents(string: cleanInput),
               let queryItem = components.queryItems?.first(where: { $0.name == "url" }),
               let targetUrl = queryItem.value {
                cleanInput = targetUrl
            }
        }
        
        // 1. Strip common routing deep-link prefixes
        let prefixes = [
            "happ://routing/onadd/",
            "happ://routing/add/",
            "happ://routing/",
            "incy://routing/onadd/",
            "incy://routing/add/",
            "incy://routing/",
            "v2raytun://import_route/",
            "v2rayTun://import_route/"
        ]
        for p in prefixes {
            if cleanInput.lowercased().hasPrefix(p.lowercased()) {
                cleanInput = String(cleanInput.dropFirst(p.count))
                break
            }
        }
        
        // 2. Try parsing directly as raw JSON
        if let directData = cleanInput.data(using: .utf8),
           let scheme = decodeData(directData) {
            return scheme
        }
        
        // 3. Try Base64 decoding
        var base64Clean = cleanInput.replacingOccurrences(of: "\n", with: "").replacingOccurrences(of: "\r", with: "")
        let remainder = base64Clean.count % 4
        if remainder > 0 {
            base64Clean.append(String(repeating: "=", count: 4 - remainder))
        }
        
        if let decodedData = Data(base64Encoded: base64Clean),
           let scheme = decodeData(decodedData) {
            return scheme
        }
        
        // 4. Try URL decoding if percent-encoded
        if let unescaped = cleanInput.removingPercentEncoding,
           let unescapedData = Data(base64Encoded: unescaped),
           let scheme = decodeData(unescapedData) {
            return scheme
        }
        
        throw ParserError.unsupportedProtocol("Не удалось распознать формат схемы маршрутизации (поддерживаются Happ, INCY, V2RayTUN, Base64 и JSON)")
    }
    
    // MARK: - Multi-schema Decoder Helper
    private static func decodeData(_ data: Data) -> HappRoutingScheme? {
        // 1. If payload contains "rules", try V2RayTun format first
        if let str = String(data: data, encoding: .utf8), str.contains("\"rules\"") {
            if let scheme = parseV2RayTunScheme(from: data) {
                return scheme
            }
        }
        
        // 2. Try Happ schema (must have meaningful data)
        if let scheme = try? JSONDecoder().decode(HappRoutingScheme.self, from: data),
           scheme.hasMeaningfulData {
            return scheme
        }
        
        // 3. Fallback to V2RayTun
        if let scheme = parseV2RayTunScheme(from: data) {
            return scheme
        }
        
        return nil
    }
    
    // MARK: - V2RayTun Schema Parser
    private static func parseV2RayTunScheme(from data: Data) -> HappRoutingScheme? {
        guard let doc = try? JSONDecoder().decode(V2RayTunRoutingDoc.self, from: data),
              let rules = doc.rules, !rules.isEmpty else { return nil }
        
        var directSites: [String] = []
        var directIp: [String] = []
        var proxySites: [String] = []
        var proxyIp: [String] = []
        var blockSites: [String] = []
        var blockIp: [String] = []
        
        for rule in rules {
            let tag = rule.outboundTag?.lowercased() ?? ""
            if let domains = rule.domain {
                for d in domains {
                    if tag == "proxy" { proxySites.append(d) }
                    else if tag == "block" { blockSites.append(d) }
                    else if tag == "direct" && d.lowercased() != "geosite:private" { directSites.append(d) }
                }
            }
            if let ips = rule.ip {
                for ip in ips {
                    if tag == "proxy" { proxyIp.append(ip) }
                    else if tag == "block" { blockIp.append(ip) }
                    else if tag == "direct" && ip.lowercased() != "geoip:private" { directIp.append(ip) }
                }
            }
        }
        
        return HappRoutingScheme(
            name: doc.name ?? "V2RayTUN Scheme",
            globalProxy: false,
            directSites: directSites,
            directIp: directIp,
            proxySites: proxySites,
            proxyIp: proxyIp,
            blockSites: blockSites,
            blockIp: blockIp,
            domainStrategy: doc.domainStrategy ?? "IPIfNonMatch",
            fakeDNS: false
        )
    }
    
    /// Applies the imported scheme into `RoutingConfig`, either merging or replacing existing rules
    public static func apply(scheme: HappRoutingScheme, to config: inout RoutingConfig, merge: Bool) {
        if !merge {
            config.proxyRules.removeAll()
            config.directRules.removeAll()
            config.blockRules.removeAll()
        }
        
        // Apply Proxy rules
        for item in scheme.proxySites where !item.isEmpty {
            if !config.proxyRules.contains(where: { $0.value.lowercased() == item.lowercased() }) {
                config.proxyRules.append(RoutingRule(value: item, target: .proxy, comment: "Happ Import"))
            }
        }
        for item in scheme.proxyIp where !item.isEmpty {
            if !config.proxyRules.contains(where: { $0.value.lowercased() == item.lowercased() }) {
                config.proxyRules.append(RoutingRule(value: item, target: .proxy, comment: "Happ Import IP"))
            }
        }
        
        // Apply Direct rules
        for item in scheme.directSites where !item.isEmpty {
            if !config.directRules.contains(where: { $0.value.lowercased() == item.lowercased() }) {
                config.directRules.append(RoutingRule(value: item, target: .direct, comment: "Happ Import Bypass"))
            }
        }
        for item in scheme.directIp where !item.isEmpty {
            if !config.directRules.contains(where: { $0.value.lowercased() == item.lowercased() }) {
                config.directRules.append(RoutingRule(value: item, target: .direct, comment: "Happ Import IP"))
            }
        }
        
        // Apply Block rules
        for item in scheme.blockSites where !item.isEmpty {
            if !config.blockRules.contains(where: { $0.value.lowercased() == item.lowercased() }) {
                config.blockRules.append(RoutingRule(value: item, target: .block, comment: "Happ Import Block"))
            }
        }
        for item in scheme.blockIp where !item.isEmpty {
            if !config.blockRules.contains(where: { $0.value.lowercased() == item.lowercased() }) {
                config.blockRules.append(RoutingRule(value: item, target: .block, comment: "Happ Import Block IP"))
            }
        }
        
        // Update general settings
        if scheme.globalProxy {
            config.mode = .global
        } else if !merge {
            config.mode = .ruleBased
        }
        
        config.fakeDnsEnabled = scheme.fakeDNS
        if !scheme.domainStrategy.isEmpty {
            config.domainStrategy = scheme.domainStrategy
        }
    }
    
    private static func isIP(_ str: String) -> Bool {
        let parts = str.components(separatedBy: "/")
        let ipPart = parts[0]
        var sin = sockaddr_in()
        var sin6 = sockaddr_in6()
        return inet_pton(AF_INET, ipPart, &sin.sin_addr) == 1 || inet_pton(AF_INET6, ipPart, &sin6.sin6_addr) == 1
    }
}
