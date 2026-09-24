import Foundation

public struct JSONConfigParser {
    
    /// Parses a JSON string which may be either an array of Xray configs `[{...}, {...}]` or a single config `{...}`
    public static func parseContent(_ jsonString: String) -> [ServerProfile] {
        let trimmed = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        
        guard let data = trimmed.data(using: .utf8) else { return [] }
        
        // 1. Try parsing as an array of objects
        if let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            return jsonArray.compactMap { parseServerConfig($0) }
        }
        
        // 2. Try parsing as a single object
        if let jsonObj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let profile = parseServerConfig(jsonObj) {
                return [profile]
            }
        }
        
        return []
    }
    
    /// Parses a single Xray configuration dictionary (or outbound object) into a ServerProfile
    public static func parseServerConfig(_ config: [String: Any]) -> ServerProfile? {
        // Look for server remarks or tag
        let remarks = (config["remarks"] as? String)
            ?? (config["ps"] as? String)
            ?? (config["name"] as? String)
            ?? (config["tag"] as? String)
            ?? "Xray Server"
        
        // Find proxy outbound
        var targetOutbound: [String: Any]?
        
        if let outbounds = config["outbounds"] as? [[String: Any]] {
            // Priority 1: outbound with tag "proxy"
            if let proxy = outbounds.first(where: { ($0["tag"] as? String)?.lowercased() == "proxy" }) {
                targetOutbound = proxy
            } else {
                // Priority 2: first outbound that is not freedom, blackhole, direct, or block
                targetOutbound = outbounds.first(where: {
                    let proto = ($0["protocol"] as? String)?.lowercased() ?? ""
                    let tag = ($0["tag"] as? String)?.lowercased() ?? ""
                    return !["freedom", "blackhole", "direct", "block"].contains(proto) &&
                           !["direct", "block", "bypass"].contains(tag)
                }) ?? outbounds.first
            }
        } else if config["protocol"] != nil {
            // The dictionary itself is an outbound definition
            targetOutbound = config
        }
        
        guard let outbound = targetOutbound,
              let protocolRaw = outbound["protocol"] as? String else {
            return nil
        }
        
        let protocolLower = protocolRaw.lowercased()
        let streamSettings = outbound["streamSettings"] as? [String: Any] ?? [:]
        let network = (streamSettings["network"] as? String)?.lowercased() ?? "tcp"
        let security = (streamSettings["security"] as? String)?.lowercased() ?? "none"
        
        // Serialized element config string for preserving DPI fragment settings
        let elementJsonString: String? = {
            if let d = try? JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted, .sortedKeys]),
               let str = String(data: d, encoding: .utf8) {
                return str
            }
            return nil
        }()
        
        // MARK: - VLESS
        if protocolLower == "vless" {
            guard let settings = outbound["settings"] as? [String: Any],
                  let vnext = (settings["vnext"] as? [[String: Any]])?.first,
                  let address = vnext["address"] as? String,
                  let port = vnext["port"] as? Int,
                  let user = (vnext["users"] as? [[String: Any]])?.first,
                  let uuid = user["id"] as? String else {
                return nil
            }
            
            let flow = (user["flow"] as? String)?.isEmpty == false ? user["flow"] as? String : nil
            
            var serverName: String?
            var publicKey: String?
            var shortId: String?
            var fingerprint: String?
            var spiderX: String?
            var path: String?
            var hostHeader: String?
            
            if security == "reality", let realitySettings = streamSettings["realitySettings"] as? [String: Any] {
                serverName = realitySettings["serverName"] as? String
                publicKey = realitySettings["publicKey"] as? String
                shortId = realitySettings["shortId"] as? String
                fingerprint = realitySettings["fingerprint"] as? String
                spiderX = realitySettings["spiderX"] as? String
            } else if security == "tls", let tlsSettings = streamSettings["tlsSettings"] as? [String: Any] {
                serverName = tlsSettings["serverName"] as? String
                fingerprint = tlsSettings["fingerprint"] as? String
            }
            
            if network == "grpc", let grpcSettings = streamSettings["grpcSettings"] as? [String: Any] {
                path = grpcSettings["serviceName"] as? String
            } else if network == "ws", let wsSettings = streamSettings["wsSettings"] as? [String: Any] {
                path = wsSettings["path"] as? String
                if let headers = wsSettings["headers"] as? [String: Any] {
                    hostHeader = headers["Host"] as? String
                }
            }
            
            let vlessDetails = VLESSDetails(
                uuid: uuid,
                flow: flow,
                security: security,
                serverName: serverName,
                publicKey: publicKey,
                shortId: shortId,
                fingerprint: fingerprint,
                spiderX: spiderX,
                transportType: network,
                path: path,
                hostHeader: hostHeader
            )
            
            let rawUri = buildVlessUri(
                uuid: uuid,
                address: address,
                port: port,
                remarks: remarks,
                details: vlessDetails
            )
            
            return ServerProfile(
                name: remarks,
                address: address,
                port: port,
                protocolType: .vless,
                vlessDetails: vlessDetails,
                rawJsonConfig: elementJsonString,
                rawUri: rawUri
            )
        }
        
        // MARK: - Trojan
        if protocolLower == "trojan" {
            guard let settings = outbound["settings"] as? [String: Any],
                  let servers = settings["servers"] as? [[String: Any]],
                  let firstServer = servers.first,
                  let address = firstServer["address"] as? String,
                  let port = firstServer["port"] as? Int,
                  let password = firstServer["password"] as? String else {
                return nil
            }
            
            var serverName: String?
            var path: String?
            
            if let tlsSettings = streamSettings["tlsSettings"] as? [String: Any] {
                serverName = tlsSettings["serverName"] as? String
            }
            if network == "grpc", let grpcSettings = streamSettings["grpcSettings"] as? [String: Any] {
                path = grpcSettings["serviceName"] as? String
            } else if network == "ws", let wsSettings = streamSettings["wsSettings"] as? [String: Any] {
                path = wsSettings["path"] as? String
            }
            
            let trojanDetails = TrojanDetails(
                password: password,
                serverName: serverName,
                security: security.isEmpty ? "tls" : security,
                transportType: network,
                path: path
            )
            
            let rawUri = buildTrojanUri(
                password: password,
                address: address,
                port: port,
                remarks: remarks,
                details: trojanDetails
            )
            
            return ServerProfile(
                name: remarks,
                address: address,
                port: port,
                protocolType: .trojan,
                trojanDetails: trojanDetails,
                rawJsonConfig: elementJsonString,
                rawUri: rawUri
            )
        }
        
        // MARK: - Shadowsocks
        if protocolLower == "shadowsocks" {
            guard let settings = outbound["settings"] as? [String: Any],
                  let servers = settings["servers"] as? [[String: Any]],
                  let firstServer = servers.first,
                  let address = firstServer["address"] as? String,
                  let port = firstServer["port"] as? Int,
                  let method = firstServer["method"] as? String,
                  let password = firstServer["password"] as? String else {
                return nil
            }
            
            let ssDetails = ShadowsocksDetails(method: method, password: password)
            let rawUri = buildShadowsocksUri(
                method: method,
                password: password,
                address: address,
                port: port,
                remarks: remarks
            )
            
            return ServerProfile(
                name: remarks,
                address: address,
                port: port,
                protocolType: .shadowsocks,
                shadowsocksDetails: ssDetails,
                rawJsonConfig: elementJsonString,
                rawUri: rawUri
            )
        }
        
        // MARK: - Fallback to Custom JSON
        var host = "127.0.0.1"
        var port = 443
        if let settings = outbound["settings"] as? [String: Any] {
            if let vnext = (settings["vnext"] as? [[String: Any]])?.first {
                host = (vnext["address"] as? String) ?? host
                port = (vnext["port"] as? Int) ?? port
            } else if let servers = (settings["servers"] as? [[String: Any]])?.first {
                host = (servers["address"] as? String) ?? host
                port = (servers["port"] as? Int) ?? port
            }
        }
        
        return ServerProfile(
            name: remarks,
            address: host,
            port: port,
            protocolType: .customJson,
            rawJsonConfig: elementJsonString
        )
    }
    
    // MARK: - URI Helpers
    private static func buildVlessUri(uuid: String, address: String, port: Int, remarks: String, details: VLESSDetails) -> String {
        var params: [String] = []
        params.append("type=\(details.transportType)")
        params.append("security=\(details.security)")
        if let flow = details.flow, !flow.isEmpty {
            params.append("flow=\(flow)")
        }
        if let sni = details.serverName, !sni.isEmpty {
            params.append("sni=\(sni)")
        }
        if let pbk = details.publicKey, !pbk.isEmpty {
            params.append("pbk=\(pbk)")
        }
        if let sid = details.shortId, !sid.isEmpty {
            params.append("sid=\(sid)")
        }
        if let fp = details.fingerprint, !fp.isEmpty {
            params.append("fp=\(fp)")
        }
        if let spx = details.spiderX, !spx.isEmpty {
            params.append("spx=\(spx.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? spx)")
        }
        if details.transportType == "grpc", let serviceName = details.path, !serviceName.isEmpty {
            params.append("serviceName=\(serviceName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? serviceName)")
        } else if details.transportType == "ws", let path = details.path, !path.isEmpty {
            params.append("path=\(path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? path)")
            if let host = details.hostHeader, !host.isEmpty {
                params.append("host=\(host)")
            }
        }
        
        let query = params.isEmpty ? "" : "?" + params.joined(separator: "&")
        let fragment = remarks.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) ?? remarks
        return "vless://\(uuid)@\(address):\(port)\(query)#\(fragment)"
    }
    
    private static func buildTrojanUri(password: String, address: String, port: Int, remarks: String, details: TrojanDetails) -> String {
        var params: [String] = []
        params.append("type=\(details.transportType)")
        params.append("security=\(details.security)")
        if let sni = details.serverName, !sni.isEmpty {
            params.append("sni=\(sni)")
        }
        if details.transportType == "grpc", let serviceName = details.path, !serviceName.isEmpty {
            params.append("serviceName=\(serviceName)")
        } else if details.transportType == "ws", let path = details.path, !path.isEmpty {
            params.append("path=\(path)")
        }
        
        let query = params.isEmpty ? "" : "?" + params.joined(separator: "&")
        let fragment = remarks.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) ?? remarks
        return "trojan://\(password)@\(address):\(port)\(query)#\(fragment)"
    }
    
    private static func buildShadowsocksUri(method: String, password: String, address: String, port: Int, remarks: String) -> String {
        let auth = "\(method):\(password)"
        let b64Auth = auth.data(using: .utf8)?.base64EncodedString() ?? ""
        let fragment = remarks.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) ?? remarks
        return "ss://\(b64Auth)@\(address):\(port)#\(fragment)"
    }
}
