import Foundation

public struct XrayConfigGenerator {
    
    /// Generates a valid complete Xray JSON configuration string
    public static func generateConfig(
        server: ServerProfile,
        routing: RoutingConfig,
        settings: AppSettings,
        servers: [ServerProfile] = []
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
        
        let listenAddress = settings.allowLanConnections ? "0.0.0.0" : "127.0.0.1"
        
        let inbounds: [[String: Any]] = [
            [
                "tag": "socks-in",
                "port": settings.socksPort,
                "listen": listenAddress,
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
                "listen": listenAddress,
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
        
        // MARK: - 3. Outbounds (Strategy Pattern)
        config["outbounds"] = try generateOutbounds(server: server, settings: settings, servers: servers)
        
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
    
    // MARK: - Outbounds Strategy Pattern (Stealth Profiles)
    
    /// Generates outbound configurations based on the selected Stealth Profile (Strategy Pattern)
    public static func generateOutbounds(server: ServerProfile, settings: AppSettings = .shared, servers: [ServerProfile] = []) throws -> [[String: Any]] {
        let profile = (settings.stealthProfile != .standardReality) ? settings.stealthProfile : AppSettings.shared.stealthProfile
        var outbounds: [[String: Any]]
        switch profile {
        case .standardReality:
            outbounds = try buildStandardRealityOutbounds(server: server, settings: settings)
        case .cdnFronting:
            outbounds = try buildCDNFrontingOutbounds(server: server, settings: settings)
        case .webrtcCamouflage:
            outbounds = try buildWebRTCOutbounds(server: server, settings: settings)
        case .quicMasquerade:
            outbounds = try buildQUICMasqueradeOutbounds(server: server, settings: settings)
        }
        
        // Proxy Chains: Insert relay outbound and wire dialerProxy on the proxy outbound
        if settings.proxyChainEnabled || AppSettings.shared.proxyChainEnabled {
            let relayId = settings.proxyChainRelayId ?? AppSettings.shared.proxyChainRelayId
            if let relayId = relayId,
               let relayServer = servers.first(where: { $0.id == relayId }),
               relayServer.id != server.id {
                var relayOutbound = try buildProxyOutbound(for: relayServer)
                relayOutbound["tag"] = "relay-outbound"
                
                // Wire the main proxy to route through the relay
                if var proxyOut = outbounds.first,
                   let proxyTag = proxyOut["tag"] as? String, proxyTag == "proxy" {
                    var streamSettings = (proxyOut["streamSettings"] as? [String: Any]) ?? [:]
                    var sockopt = (streamSettings["sockopt"] as? [String: Any]) ?? [:]
                    sockopt["dialerProxy"] = "relay-outbound"
                    streamSettings["sockopt"] = sockopt
                    proxyOut["streamSettings"] = streamSettings
                    outbounds[0] = proxyOut
                }
                
                // Insert relay outbound after the proxy outbound
                outbounds.insert(relayOutbound, at: 1)
            }
        }
        
        return outbounds
    }
    
    /// Strategy 1: Standard Reality with Chained Freedom DialerProxy (Anti-DPI Fragment + Noise Injection)
    public static func buildStandardRealityOutbounds(server: ServerProfile, settings: AppSettings = .shared) throws -> [[String: Any]] {
        var outbounds: [[String: Any]] = []
        var proxyOutbound = try buildProxyOutbound(for: server)
        
        let fragmentEnabled = settings.fragmentEnabled || (settings == .standard && AppSettings.shared.fragmentEnabled)
        let isStreamingActive = settings.streamingMimicryEnabled || (settings == .standard && AppSettings.shared.streamingMimicryEnabled)
        let noiseEnabled = (settings.noiseEnabled || (settings == .standard && AppSettings.shared.noiseEnabled)) && !isStreamingActive
        let isAntiDpiEnabled = fragmentEnabled || noiseEnabled
        let dialerTag = "anti-dpi-dialer"
        
        var streamSettings = (proxyOutbound["streamSettings"] as? [String: Any]) ?? [:]
        var sockopt = (streamSettings["sockopt"] as? [String: Any]) ?? [:]
        
        if isAntiDpiEnabled {
            sockopt["dialerProxy"] = dialerTag
            
            // Remove legacy direct fragment to avoid duplicate fragmentation
            if fragmentEnabled {
                proxyOutbound.removeValue(forKey: "fragment")
            }
        }
        
        // Modifiers: Micro-sessions & Port Hopping
        if settings.enableMicroSessions || AppSettings.shared.enableMicroSessions {
            sockopt["tcpKeepAliveInterval"] = 15
            sockopt["tcpNoDelay"] = true
        }
        
        if !sockopt.isEmpty {
            streamSettings["sockopt"] = sockopt
            proxyOutbound["streamSettings"] = streamSettings
        }
        
        outbounds.append(proxyOutbound)
        
        if isAntiDpiEnabled {
            var dialerSettings: [String: Any] = [
                "domainStrategy": "AsIs"
            ]
            
            if fragmentEnabled {
                let packets = settings.fragmentEnabled ? settings.fragmentPackets : AppSettings.shared.fragmentPackets
                let length = settings.fragmentEnabled ? settings.fragmentLength : AppSettings.shared.fragmentLength
                let interval = settings.fragmentEnabled ? settings.fragmentInterval : AppSettings.shared.fragmentInterval
                
                dialerSettings["fragment"] = [
                    "packets": packets,
                    "length": length,
                    "interval": interval
                ]
            }
            
            if noiseEnabled {
                let type = settings.noiseEnabled ? settings.noiseType : AppSettings.shared.noiseType
                let packet = settings.noiseEnabled ? settings.noisePacket : AppSettings.shared.noisePacket
                let delay = settings.noiseEnabled ? settings.noiseDelay : AppSettings.shared.noiseDelay
                
                dialerSettings["noises"] = [
                    [
                        "type": type,
                        "packet": packet,
                        "delay": delay
                    ]
                ]
            }
            
            outbounds.append([
                "tag": dialerTag,
                "protocol": "freedom",
                "settings": dialerSettings
            ])
        }
        
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
        
        return outbounds
    }
    
    /// Strategy 2: CDN Fronting via XHTTP transport over TLS (bypasses Reality/raw TCP filters)
    public static func buildCDNFrontingOutbounds(server: ServerProfile, settings: AppSettings = .shared) throws -> [[String: Any]] {
        var proxyOutbound = try buildProxyOutbound(for: server)
        
        // Anti-DPI (Fragment & Noise) parameters are strictly reserved for Standard Reality.
        // Forcibly ignore fragment and noise to prevent invalid or conflicting Xray transport configs.
        proxyOutbound.removeValue(forKey: "fragment")
        
        // Strip flow (Vision is incompatible with XHTTP/Splithttp transport)
        if var proxySettings = proxyOutbound["settings"] as? [String: Any],
           var vnext = proxySettings["vnext"] as? [[String: Any]] {
            for i in 0..<vnext.count {
                if var users = vnext[i]["users"] as? [[String: Any]] {
                    for j in 0..<users.count {
                        users[j].removeValue(forKey: "flow")
                    }
                    vnext[i]["users"] = users
                }
            }
            proxySettings["vnext"] = vnext
            proxyOutbound["settings"] = proxySettings
        }
        
        let customCdnHost = !settings.cdnHost.isEmpty ? settings.cdnHost : AppSettings.shared.cdnHost
        let hostHeader = !customCdnHost.isEmpty ? customCdnHost : (server.vlessDetails?.hostHeader ?? server.vlessDetails?.serverName ?? server.address)
        
        let customCdnPath = (!settings.cdnPath.isEmpty && settings.cdnPath != "/") ? settings.cdnPath : ((!AppSettings.shared.cdnPath.isEmpty && AppSettings.shared.cdnPath != "/") ? AppSettings.shared.cdnPath : nil)
        let path = customCdnPath ?? server.vlessDetails?.path ?? settings.cdnPath
        
        var streamSettings: [String: Any] = [
            "network": "xhttp",
            "security": "tls",
            "tlsSettings": [
                "serverName": hostHeader
            ],
            "xhttpSettings": [
                "path": path,
                "host": hostHeader,
                "mode": "auto"
            ]
        ]
        
        if settings.enableMicroSessions || AppSettings.shared.enableMicroSessions {
            var sockopt: [String: Any] = [:]
            sockopt["tcpKeepAliveInterval"] = 15
            sockopt["tcpNoDelay"] = true
            streamSettings["sockopt"] = sockopt
        }
        
        proxyOutbound["streamSettings"] = streamSettings
        
        return [
            proxyOutbound,
            [
                "tag": "direct",
                "protocol": "freedom",
                "settings": [
                    "domainStrategy": "AsIs"
                ]
            ],
            [
                "tag": "block",
                "protocol": "blackhole",
                "settings": [
                    "response": [
                        "type": "http"
                    ]
                ]
            ]
        ]
    }
    
    /// Strategy 3: WebRTC / Video Call Camouflage (UDP media stream emulation)
    public static func buildWebRTCOutbounds(server: ServerProfile, settings: AppSettings = .shared) throws -> [[String: Any]] {
        var proxyOutbound = try buildProxyOutbound(for: server)
        
        // Anti-DPI (Fragment & Noise) parameters are strictly reserved for Standard Reality.
        // Forcibly ignore fragment and noise to prevent invalid or conflicting Xray transport configs.
        proxyOutbound.removeValue(forKey: "fragment")
        
        // Strip flow (Vision is incompatible with UDP/KCP transport)
        if var proxySettings = proxyOutbound["settings"] as? [String: Any],
           var vnext = proxySettings["vnext"] as? [[String: Any]] {
            for i in 0..<vnext.count {
                if var users = vnext[i]["users"] as? [[String: Any]] {
                    for j in 0..<users.count {
                        users[j].removeValue(forKey: "flow")
                    }
                    vnext[i]["users"] = users
                }
            }
            proxySettings["vnext"] = vnext
            proxyOutbound["settings"] = proxySettings
        }
        
        let customSni = !settings.webrtcSni.isEmpty ? settings.webrtcSni : AppSettings.shared.webrtcSni
        let effectiveSni = !customSni.isEmpty ? customSni : (server.vlessDetails?.serverName ?? "")
        
        // Configure streamSettings for UDP media packet stream (kcp transport)
        var streamSettings: [String: Any] = [
            "network": "kcp",
            "security": effectiveSni.isEmpty ? "none" : "tls",
            "kcpSettings": [
                "mtu": 1350,
                "tti": 50,
                "uplinkCapacity": 100,
                "downlinkCapacity": 100,
                "congestion": false
            ]
        ]
        
        if !effectiveSni.isEmpty {
            streamSettings["tlsSettings"] = [
                "serverName": effectiveSni
            ]
        }
        
        if settings.enableMicroSessions || AppSettings.shared.enableMicroSessions {
            var sockopt: [String: Any] = [:]
            sockopt["tcpKeepAliveInterval"] = 10
            streamSettings["sockopt"] = sockopt
        }
        
        proxyOutbound["streamSettings"] = streamSettings
        
        return [
            proxyOutbound,
            [
                "tag": "direct",
                "protocol": "freedom",
                "settings": [
                    "domainStrategy": "AsIs"
                ]
            ],
            [
                "tag": "block",
                "protocol": "blackhole",
                "settings": [
                    "response": [
                        "type": "http"
                    ]
                ]
            ]
        ]
    }
    
    /// Strategy 4: HTTP/3 QUIC Masquerade via XHTTP stream-one H3 (full TCP bypass over UDP)
    public static func buildQUICMasqueradeOutbounds(server: ServerProfile, settings: AppSettings = .shared) throws -> [[String: Any]] {
        var proxyOutbound = try buildProxyOutbound(for: server)
        
        // Anti-DPI (Fragment & Noise) are strictly reserved for Standard Reality.
        proxyOutbound.removeValue(forKey: "fragment")
        
        // Strip flow (Vision is incompatible with XHTTP transport)
        if var proxySettings = proxyOutbound["settings"] as? [String: Any],
           var vnext = proxySettings["vnext"] as? [[String: Any]] {
            for i in 0..<vnext.count {
                if var users = vnext[i]["users"] as? [[String: Any]] {
                    for j in 0..<users.count {
                        users[j].removeValue(forKey: "flow")
                    }
                    vnext[i]["users"] = users
                }
            }
            proxySettings["vnext"] = vnext
            proxyOutbound["settings"] = proxySettings
        }
        
        let hostHeader = server.vlessDetails?.hostHeader ?? server.vlessDetails?.serverName ?? server.address
        
        var xhttpSettings: [String: Any] = [
            "path": server.vlessDetails?.path ?? "/h3-stream",
            "host": hostHeader,
            "mode": "stream-one" // H3 QUIC streaming mode
        ]
        
        var sni = hostHeader
        
        // Streaming Mimicry: inject AppleCoreMedia User-Agent headers
        if settings.streamingMimicryEnabled || AppSettings.shared.streamingMimicryEnabled {
            let cdnDomain = !settings.streamingMimicryCdn.isEmpty ? settings.streamingMimicryCdn : AppSettings.shared.streamingMimicryCdn
            if !cdnDomain.isEmpty {
                xhttpSettings["host"] = cdnDomain
                sni = cdnDomain
            }
            xhttpSettings["headers"] = [
                "User-Agent": "AppleCoreMedia/1.0.0.21G72 (Macintosh; Intel Mac OS X 14_6_1)",
                "Accept": "video/mp2t,application/vnd.apple.mpegurl,application/dash+xml"
            ]
        }
        
        var streamSettings: [String: Any] = [
            "network": "xhttp",
            "security": "tls",
            "tlsSettings": [
                "serverName": sni
            ],
            "xhttpSettings": xhttpSettings
        ]
        
        if settings.enableMicroSessions || AppSettings.shared.enableMicroSessions {
            var sockopt: [String: Any] = [:]
            sockopt["tcpKeepAliveInterval"] = 15
            sockopt["tcpNoDelay"] = true
            streamSettings["sockopt"] = sockopt
        }
        
        proxyOutbound["streamSettings"] = streamSettings
        
        var outbounds: [[String: Any]] = [proxyOutbound]
        
        // Temporal Shaping: add freedom dialer with intensity-based noise for jitter
        if settings.temporalShapingEnabled || AppSettings.shared.temporalShapingEnabled {
            let intensity = settings.temporalShapingEnabled ? settings.temporalShapingIntensity : AppSettings.shared.temporalShapingIntensity
            let params = intensity.noiseParameters
            let temporalDialer: [String: Any] = [
                "tag": "temporal-shaping-dialer",
                "protocol": "freedom",
                "settings": [
                    "domainStrategy": "AsIs",
                    "noises": [
                        [
                            "type": "rand",
                            "packet": params.packet,
                            "delay": params.delay
                        ]
                    ]
                ]
            ]
            
            // Wire the proxy outbound through the temporal shaping dialer
            if var proxyOut = outbounds.first {
                var stream = (proxyOut["streamSettings"] as? [String: Any]) ?? [:]
                var sockopt = (stream["sockopt"] as? [String: Any]) ?? [:]
                // Only set if not already using a different dialer (e.g. proxy chain)
                if sockopt["dialerProxy"] == nil {
                    sockopt["dialerProxy"] = "temporal-shaping-dialer"
                    stream["sockopt"] = sockopt
                    proxyOut["streamSettings"] = stream
                    outbounds[0] = proxyOut
                }
            }
            
            outbounds.append(temporalDialer)
        }
        
        outbounds.append([
            "tag": "direct",
            "protocol": "freedom",
            "settings": [
                "domainStrategy": "AsIs"
            ]
        ])
        outbounds.append([
            "tag": "block",
            "protocol": "blackhole",
            "settings": [
                "response": [
                    "type": "http"
                ]
            ]
        ])
        
        return outbounds
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
