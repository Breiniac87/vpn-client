import Foundation

public struct URLSchemeParser {
    
    /// Universal content parser: handles single links, multi-line links, Base64 subscriptions, and JSON arrays/objects
    public static func parseContent(_ raw: String) -> [ServerProfile] {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        
        // 1. Check if the content is a JSON Array or JSON Object directly
        if (trimmed.hasPrefix("[") && trimmed.hasSuffix("]")) || (trimmed.hasPrefix("{") && trimmed.hasSuffix("}")) {
            let jsonProfiles = JSONConfigParser.parseContent(trimmed)
            if !jsonProfiles.isEmpty {
                return jsonProfiles
            }
        }
        
        // 2. Check if content is Base64 encoded (does not contain protocol scheme separator ://)
        if !trimmed.contains("://"), let decoded = ShadowsocksParser.decodeBase64Safe(trimmed) {
            let decodedTrimmed = decoded.trimmingCharacters(in: .whitespacesAndNewlines)
            if (decodedTrimmed.hasPrefix("[") && decodedTrimmed.hasSuffix("]")) ||
               (decodedTrimmed.hasPrefix("{") && decodedTrimmed.hasSuffix("}")) {
                let jsonProfiles = JSONConfigParser.parseContent(decodedTrimmed)
                if !jsonProfiles.isEmpty {
                    return jsonProfiles
                }
            }
            let base64Profiles = parseMultipleLinks(decodedTrimmed)
            if !base64Profiles.isEmpty {
                return base64Profiles
            }
        }
        
        // 3. Try parsing as a single link ONLY if there are no newline characters
        if !trimmed.contains("\n") && !trimmed.contains("\r") {
            if let single = try? parseSingleLink(trimmed) {
                return [single]
            }
        }
        
        // 4. Default: parse as multi-line links
        return parseMultipleLinks(trimmed)
    }
    
    public static func parseSingleLink(_ raw: String) throws -> ServerProfile {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.contains("\n") && !trimmed.contains("\r") else {
            throw ParserError.malformedUrl("Одиночная ссылка не должна содержать переносы строк")
        }
        
        if trimmed.lowercased().hasPrefix("vless://") {
            return try VLESSParser.parse(urlString: trimmed)
        } else if trimmed.lowercased().hasPrefix("trojan://") {
            return try TrojanParser.parse(urlString: trimmed)
        } else if trimmed.lowercased().hasPrefix("ss://") {
            return try ShadowsocksParser.parse(urlString: trimmed)
        } else if trimmed.hasPrefix("{") && trimmed.hasSuffix("}") {
            return try parseRawJson(trimmed)
        } else {
            throw ParserError.unsupportedProtocol("Неизвестный формат протокола. Поддерживаются vless://, trojan://, ss:// или JSON.")
        }
    }
    
    public static func parseMultipleLinks(_ text: String) -> [ServerProfile] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // If content is actually a JSON array of configs, parse directly with JSONConfigParser
        if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
            let jsonProfiles = JSONConfigParser.parseContent(trimmed)
            if !jsonProfiles.isEmpty {
                return jsonProfiles
            }
        }
        
        var profiles: [ServerProfile] = []
        let lines = text.components(separatedBy: .newlines)
        
        for line in lines {
            let lineTrimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !lineTrimmed.isEmpty else { continue }
            if let profile = try? parseSingleLink(lineTrimmed) {
                profiles.append(profile)
            }
        }
        return profiles
    }
    
    public static func parseRawJson(_ jsonString: String) throws -> ServerProfile {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ParserError.malformedUrl("Невалидный JSON")
        }
        
        if let parsed = JSONConfigParser.parseServerConfig(json) {
            return parsed
        }
        
        // Fallback if generic dictionary
        let remarks = (json["remarks"] as? String) ?? (json["tag"] as? String) ?? "Imported JSON Config"
        var host = "127.0.0.1"
        var port = 443
        var proto = ServerProtocol.customJson
        
        if let outbounds = json["outbounds"] as? [[String: Any]], let first = outbounds.first {
            if let p = first["protocol"] as? String {
                switch p.lowercased() {
                case "vless": proto = .vless
                case "trojan": proto = .trojan
                case "shadowsocks": proto = .shadowsocks
                default: proto = .customJson
                }
            }
            if let settings = first["settings"] as? [String: Any],
               let vnext = (settings["vnext"] as? [[String: Any]])?.first {
                host = (vnext["address"] as? String) ?? host
                port = (vnext["port"] as? Int) ?? port
            }
        }
        
        return ServerProfile(
            name: remarks,
            address: host,
            port: port,
            protocolType: proto,
            rawJsonConfig: jsonString
        )
    }
}
