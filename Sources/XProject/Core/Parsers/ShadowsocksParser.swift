import Foundation

public struct ShadowsocksParser {
    public static func parse(urlString: String) throws -> ServerProfile {
        let cleanUrl = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanUrl.lowercased().hasPrefix("ss://") else {
            throw ParserError.invalidScheme("Ожидался протокол ss://")
        }
        
        guard !cleanUrl.contains("\n") && !cleanUrl.contains("\r") else {
            throw ParserError.malformedUrl("Ссылка Shadowsocks не должна содержать переносы строк")
        }
        
        let withoutScheme = String(cleanUrl.dropFirst(5)) // drops "ss://"
        
        // Extract tag / name (#Name)
        let parts = withoutScheme.components(separatedBy: "#")
        let linkPart = parts[0]
        var name = "Shadowsocks Server"
        if parts.count > 1 {
            let rawName = parts.dropFirst().joined(separator: "#").trimmingCharacters(in: .whitespacesAndNewlines)
            let decoded = rawName.removingPercentEncoding ?? rawName
            let clean = (decoded.removingPercentEncoding ?? decoded).trimmingCharacters(in: .whitespacesAndNewlines)
            if !clean.isEmpty {
                name = clean
            }
        }
        
        if linkPart.contains("@") {
            // Format 1: ss://BASE64(method:password)@host:port
            let atParts = linkPart.components(separatedBy: "@")
            let encodedUserInfo = atParts[0]
            let hostAndPort = atParts[1]
            
            guard let decodedUserInfo = decodeBase64Safe(encodedUserInfo) else {
                throw ParserError.invalidBase64("Не удалось декодировать учетные данные Shadowsocks")
            }
            
            let userParts = decodedUserInfo.components(separatedBy: ":")
            guard userParts.count >= 2 else {
                throw ParserError.missingField("Неверный формат method:password")
            }
            let method = userParts[0]
            let password = userParts.dropFirst().joined(separator: ":")
            
            let (host, port) = try parseHostAndPort(hostAndPort)
            
            return ServerProfile(
                name: name,
                address: host,
                port: port,
                protocolType: .shadowsocks,
                shadowsocksDetails: ShadowsocksDetails(method: method, password: password),
                rawUri: cleanUrl
            )
        } else {
            // Format 2: ss://BASE64(method:password@host:port)
            guard let decoded = decodeBase64Safe(linkPart) else {
                throw ParserError.invalidBase64("Не удалось декодировать ссылку Shadowsocks")
            }
            
            guard let atIndex = decoded.lastIndex(of: "@") else {
                throw ParserError.missingField("Отсутствует разделитель @ в ссылке Shadowsocks")
            }
            
            let userPart = String(decoded[..<atIndex])
            let hostAndPort = String(decoded[decoded.index(after: atIndex)...])
            
            let userParts = userPart.components(separatedBy: ":")
            guard userParts.count >= 2 else {
                throw ParserError.missingField("Неверный формат method:password")
            }
            let method = userParts[0]
            let password = userParts.dropFirst().joined(separator: ":")
            
            let (host, port) = try parseHostAndPort(hostAndPort)
            
            return ServerProfile(
                name: name,
                address: host,
                port: port,
                protocolType: .shadowsocks,
                shadowsocksDetails: ShadowsocksDetails(method: method, password: password),
                rawUri: cleanUrl
            )
        }
    }
    
    private static func parseHostAndPort(_ string: String) throws -> (String, Int) {
        // Strip query items if any
        let clean = string.components(separatedBy: "?")[0]
        
        // Handle IPv6 enclosed in brackets: e.g. [2001:db8::1]:8388
        if clean.contains("[") && clean.contains("]") {
            guard let closeBracket = clean.lastIndex(of: "]"),
                  let colonIndex = clean.range(of: ":", range: closeBracket..<clean.endIndex)?.lowerBound else {
                throw ParserError.malformedUrl("Неверный формат IPv6 host:port (\(string))")
            }
            let host = String(clean[..<closeBracket].dropFirst()) // drops '['
            let portStr = String(clean[clean.index(after: colonIndex)...])
            guard let port = Int(portStr), (1...65535).contains(port) else {
                throw ParserError.malformedUrl("Недопустимый порт: \(portStr)")
            }
            return (host, port)
        }
        
        // Standard IPv4 or hostname: e.g. example.com:8388 or 1.2.3.4:8388
        guard let lastColon = clean.lastIndex(of: ":") else {
            throw ParserError.malformedUrl("Отсутствует порт (\(string))")
        }
        let host = String(clean[..<lastColon])
        let portStr = String(clean[clean.index(after: lastColon)...])
        guard !host.isEmpty, let port = Int(portStr), (1...65535).contains(port) else {
            throw ParserError.malformedUrl("Неверный формат host:port (\(string))")
        }
        return (host, port)
    }
    
    public static func decodeBase64Safe(_ string: String) -> String? {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Pad with '=' if needed
        let mod4 = base64.count % 4
        if mod4 != 0 {
            base64 += String(repeating: "=", count: 4 - mod4)
        }
        
        guard let data = Data(base64Encoded: base64, options: .ignoreUnknownCharacters) else { return nil }
        return String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii)
    }
}
