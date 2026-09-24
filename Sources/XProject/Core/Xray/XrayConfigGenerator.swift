import Foundation

public struct XrayConfigGenerator {
    
    /// Generates a valid complete Xray JSON configuration string
    public static func generateConfig(
        server: ServerProfile,
        routing: RoutingConfig,
        settings: AppSettings
    ) throws -> String {
        var config: [String: Any] = [:]
        
        // MARK: - 1. Logging
        config["log"] = [
            "loglevel": "warning",
            "access": "none"
        ]
        
        // MARK: - 2. Inbounds (SOCKS5 + HTTP)
        let destOverride: [String] = routing.fakeDnsEnabled
            ? ["http", "tls", "quic", "fakedns"]
            : ["http", "tls", "quic"]
        
        let inbounds: [[String: Any]] = [
            [
                "tag": "socks-in",
                "port": settings.socksPort,
                "listen": "127.0.0.1",
                "protocol": "socks",
                "sniffing": [
                    "enabled": true,
                    "destOverride": destOverride,
                    "metadataOnly": false,
                    "routeOnly": true
                ],
                "settings": [
                    "auth": "noauth",
                    "udp": true
                ]
            ],
            [
                "tag": "http-in",
                "port": settings.httpPort,
                "listen": "127.0.0.1",
                "protocol": "http",
                "sniffing": [
                    "enabled": true,
                    "destOverride": destOverride,
                    "metadataOnly": false,
                    "routeOnly": true
                ]
            ]
        ]
        config["inbounds"] = inbounds
        
        // MARK: - 3. Outbounds
        var outbounds: [[String: Any]] = []
        
        // Primary Proxy Outbound
        let proxyOutbound = try buildProxyOutbound(for: server)
        outbounds.append(proxyOutbound)
        
        // Direct Outbound
        outbounds.append([
            "tag": "direct",
            "protocol": "freedom",
            "settings": [
                "domainStrategy": "AsIs"
            ]
        ])
        
        // Block Outbound
        outbounds.append([
            "tag": "block",
            "protocol": "blackhole",
            "settings": [
                "response": [
                    "type": "http"
                ]
            ]
        ])
        
        config["outbounds"] = outbounds
        
        // MARK: - 4. FakeDNS (if enabled)
        if routing.fakeDnsEnabled {
            config["fakedns"] = [
                [
                    "ipPool": "198.18.0.0/15",
                    "poolSize": 65535
                ]
            ]
        }
        
        // MARK: - 5. Routing Section
        config["routing"] = buildRoutingSection(routing: routing)
        
        // MARK: - 6. DNS
        var dnsServers: [String] = []
        if routing.fakeDnsEnabled {
            dnsServers.append("fakedns")
        }
        dnsServers.append(contentsOf: [
            settings.dnsServer,
            "1.1.1.1",
            "8.8.8.8",
            "localhost"
        ])
        
        config["dns"] = [
            "servers": dnsServers
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted, .sortedKeys])
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw ParserError.malformedUrl("Не удалось сериализовать конфигурацию Xray в JSON")
        }
        
        return jsonString
    }
    
    // MARK: - Outbound Builders
    private static func buildProxyOutbound(for server: ServerProfile) throws -> [String: Any] {
        if let rawJson = server.rawJsonConfig,
           let data = rawJson.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let rawOutbounds = obj["outbounds"] as? [[String: Any]] {
                var selectedProxy: [String: Any]?
                if let proxy = rawOutbounds.first(where: { ($0["tag"] as? String)?.lowercased() == "proxy" }) {
                    selectedProxy = proxy
                } else if let proxy = rawOutbounds.first(where: {
                    let proto = ($0["protocol"] as? String)?.lowercased() ?? ""
                    let tag = ($0["tag"] as? String)?.lowercased() ?? ""
                    return !["freedom", "blackhole", "direct", "block"].contains(proto) &&
                           !["direct", "block", "bypass"].contains(tag)
                }) {
                    selectedProxy = proxy
                } else if let first = rawOutbounds.first {
                    selectedProxy = first
                }
                
                if var proxy = selectedProxy {
                    proxy["tag"] = "proxy"
                    // Ensure VLESS users always have "encryption": "none" for Xray validation
                    if let proto = proxy["protocol"] as? String, proto.lowercased() == "vless",
                       var settings = proxy["settings"] as? [String: Any],
                       var vnext = settings["vnext"] as? [[String: Any]] {
                        for i in 0..<vnext.count {
                            if var users = vnext[i]["users"] as? [[String: Any]] {
                                for j in 0..<users.count {
                                    if users[j]["encryption"] == nil || (users[j]["encryption"] as? String)?.isEmpty == true {
                                        users[j]["encryption"] = "none"
                                    }
                                }
                                vnext[i]["users"] = users
                            }
                        }
                        settings["vnext"] = vnext
                        proxy["settings"] = settings
                    }
                    return proxy
                }
            } else if obj["protocol"] != nil {
                var outbound = obj
                outbound["tag"] = "proxy"
                return outbound
            }
        }
        
        switch server.protocolType {
        case .vless:
            guard let vless = server.vlessDetails else {
                throw ParserError.missingField("Отсутствуют параметры VLESS")
            }
            var userDict: [String: Any] = [
                "id": vless.uuid,
                "encryption": "none"
            ]
            if let flow = vless.flow, !flow.isEmpty {
                userDict["flow"] = flow
            }
            
            var outbound: [String: Any] = [
                "tag": "proxy",
                "protocol": "vless",
                "settings": [
                    "vnext": [
                        [
                            "address": server.address,
                            "port": server.port,
                            "users": [userDict]
                        ]
                    ]
                ]
            ]
            
            var streamSettings: [String: Any] = [
                "network": vless.transportType,
                "security": vless.security
            ]
            
            if vless.security == "reality" {
                let realitySettings: [String: Any] = [
                    "show": false,
                    "fingerprint": vless.fingerprint ?? "chrome",
                    "serverName": vless.serverName ?? server.address,
                    "publicKey": vless.publicKey ?? "",
                    "shortId": vless.shortId ?? "",
                    "spiderX": vless.spiderX ?? ""
                ]
                streamSettings["realitySettings"] = realitySettings
            } else if vless.security == "tls" {
                streamSettings["tlsSettings"] = [
                    "serverName": vless.serverName ?? server.address,
                    "fingerprint": vless.fingerprint ?? "chrome"
                ]
            }
            
            if vless.transportType == "ws", let path = vless.path {
                streamSettings["wsSettings"] = [
                    "path": path,
                    "headers": [
                        "Host": vless.hostHeader ?? vless.serverName ?? server.address
                    ]
                ]
            } else if vless.transportType == "grpc", let serviceName = vless.path {
                streamSettings["grpcSettings"] = [
                    "serviceName": serviceName,
                    "multiMode": true
                ]
            }
            
            outbound["streamSettings"] = streamSettings
            return outbound
            
        case .trojan:
            guard let trojan = server.trojanDetails else {
                throw ParserError.missingField("Отсутствуют параметры Trojan")
            }
            return [
                "tag": "proxy",
                "protocol": "trojan",
                "settings": [
                    "servers": [
                        [
                            "address": server.address,
                            "port": server.port,
                            "password": trojan.password
                        ]
                    ]
                ],
                "streamSettings": [
                    "network": trojan.transportType,
                    "security": trojan.security,
                    "tlsSettings": [
                        "serverName": trojan.serverName ?? server.address
                    ]
                ]
            ]
            
        case .shadowsocks:
            guard let ss = server.shadowsocksDetails else {
                throw ParserError.missingField("Отсутствуют параметры Shadowsocks")
            }
            return [
                "tag": "proxy",
                "protocol": "shadowsocks",
                "settings": [
                    "servers": [
                        [
                            "address": server.address,
                            "port": server.port,
                            "method": ss.method,
                            "password": ss.password,
                            "uot": true
                        ]
                    ]
                ]
            ]
            
        case .customJson:
            return [
                "tag": "proxy",
                "protocol": "freedom",
                "settings": [:]
            ]
        }
    }
    
    // MARK: - Routing Section Builder
    private static func buildRoutingSection(routing: RoutingConfig) -> [String: Any] {
        var rules: [[String: Any]] = []
        
        // 1. Always direct private local IPs
        rules.append([
            "type": "field",
            "outboundTag": "direct",
            "ip": ["geoip:private"]
        ])
        
        // 2. Direct bootstrap DNS to prevent resolution deadlocks
        rules.append([
            "type": "field",
            "outboundTag": "direct",
            "port": "53"
        ])
        rules.append([
            "type": "field",
            "outboundTag": "direct",
            "ip": ["1.1.1.1", "1.0.0.1", "8.8.8.8", "8.8.4.4"]
        ])
        
        if routing.mode == .global {
            // Global mode: All TCP and UDP traffic goes to proxy
            rules.append([
                "type": "field",
                "outboundTag": "proxy",
                "network": "tcp,udp"
            ])
        } else {
            // Rule-based mode (Split Tunneling)
            
            // 1. BitTorrent Protection (Direct routing for torrent protocol to protect VPS from DMCA / bans)
            rules.append([
                "type": "field",
                "outboundTag": "direct",
                "protocol": ["bittorrent"]
            ])
            
            // 2. Block Rules (Ads / Trackers / Malware / Telemetry) - Evaluated FIRST
            var blockDomains: [String] = []
            var blockIPs: [String] = []
            
            for rule in routing.blockRules where rule.isEnabled {
                let v = rule.value.trimmingCharacters(in: .whitespacesAndNewlines)
                if v.lowercased().hasPrefix("geoip:") || isIPorCIDR(v) {
                    blockIPs.append(v)
                } else {
                    let norm = (v.lowercased() == "geosite:category-ads-all") ? "geosite:category-ads" : v
                    blockDomains.append(norm)
                }
            }
            
            if !blockDomains.isEmpty {
                rules.append([
                    "type": "field",
                    "outboundTag": "block",
                    "domain": adaptDomainRules(blockDomains)
                ])
            }
            if !blockIPs.isEmpty {
                rules.append([
                    "type": "field",
                    "outboundTag": "block",
                    "ip": blockIPs
                ])
            }
            
            // 3. Proxy Rules (Banned RU sites, AI, YouTube, Discord, Crypto) - Must precede broad Direct rules
            var proxyDomains: [String] = []
            var proxyIPs: [String] = []
            
            for rule in routing.proxyRules where rule.isEnabled {
                let v = rule.value.trimmingCharacters(in: .whitespacesAndNewlines)
                if v.lowercased().hasPrefix("geoip:") || isIPorCIDR(v) {
                    proxyIPs.append(v)
                } else {
                    proxyDomains.append(v)
                }
            }
            
            if !proxyDomains.isEmpty {
                rules.append([
                    "type": "field",
                    "outboundTag": "proxy",
                    "domain": adaptDomainRules(proxyDomains)
                ])
            }
            if !proxyIPs.isEmpty {
                rules.append([
                    "type": "field",
                    "outboundTag": "proxy",
                    "ip": proxyIPs
                ])
            }
            
            // 4. Direct Rules (Russian Services, Apple, Microsoft, geoip:ru)
            var directDomains: [String] = []
            var directIPs: [String] = []
            
            for rule in routing.directRules where rule.isEnabled {
                let v = rule.value.trimmingCharacters(in: .whitespacesAndNewlines)
                if v.lowercased().hasPrefix("geoip:") || isIPorCIDR(v) {
                    directIPs.append(v)
                } else {
                    directDomains.append(v)
                }
            }
            
            if !directDomains.isEmpty {
                rules.append([
                    "type": "field",
                    "outboundTag": "direct",
                    "domain": adaptDomainRules(directDomains)
                ])
            }
            if !directIPs.isEmpty {
                rules.append([
                    "type": "field",
                    "outboundTag": "direct",
                    "ip": directIPs
                ])
            }
        }
        
        return [
            "domainStrategy": routing.domainStrategy,
            "domainMatcher": "hybrid",
            "rules": rules
        ]
    }
    
    /// Adapts geosite category tags seamlessly between Loyalsoldier and DigneZzZ routing databases
    private static func adaptDomainRules(_ rules: [String]) -> [String] {
        guard let assetDir = XrayBinaryManager.locateAssetDirectory() else { return rules }
        let geositePath = assetDir + "/geosite.dat"
        let isDigneZzZ = (try? FileManager.default.attributesOfItem(atPath: geositePath)[.size] as? Int ?? 0) ?? 0 < 2_000_000
        
        var result: [String] = []
        for raw in rules {
            let lower = raw.lowercased()
            if isDigneZzZ {
                // Adapting rules for DigneZzZ curated meta-categories
                if lower == "geosite:openai" || lower == "geosite:anthropic" || lower == "geosite:google-gemini" || lower == "geosite:chatgpt" {
                    if !result.contains("geosite:ai-core") { result.append("geosite:ai-core") }
                    if lower == "geosite:openai" {
                        result.append("domain:openai.com")
                        result.append("domain:chatgpt.com")
                    } else if lower == "geosite:anthropic" {
                        result.append("domain:anthropic.com")
                        result.append("domain:claude.ai")
                    } else if lower == "geosite:google-gemini" {
                        result.append("domain:gemini.google.com")
                    }
                } else if lower == "geosite:twitter" {
                    result.append("domain:twitter.com")
                    result.append("domain:x.com")
                } else if lower == "geosite:instagram" {
                    result.append("domain:instagram.com")
                } else if lower == "geosite:facebook" {
                    result.append("domain:facebook.com")
                } else if lower == "geosite:category-gov-ru" || lower == "geosite:yandex" || lower == "geosite:vk" {
                    if !result.contains("geosite:category-ru") { result.append("geosite:category-ru") }
                } else if lower.hasPrefix("geosite:category-ads") {
                    result.append("domain:adservice.google.com")
                } else {
                    result.append(raw)
                }
            } else {
                // Adapting rules for Loyalsoldier database
                if lower == "geosite:ai-core" {
                    result.append("geosite:openai")
                    result.append("geosite:anthropic")
                } else if lower == "geosite:category-ru" {
                    result.append("geosite:category-gov-ru")
                    result.append("geosite:yandex")
                    result.append("geosite:vk")
                } else if lower == "geosite:category-ads" {
                    result.append("geosite:category-ads-all")
                } else {
                    result.append(raw)
                }
            }
        }
        return Array(Set(result)).sorted()
    }
    
    private static func isIPorCIDR(_ str: String) -> Bool {
        let parts = str.components(separatedBy: "/")
        let ipPart = parts[0]
        var sin = sockaddr_in()
        return inet_pton(AF_INET, ipPart, &sin.sin_addr) == 1
    }
}
