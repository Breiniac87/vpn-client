import Foundation

public struct TrojanParser {
    public static func parse(urlString: String) throws -> ServerProfile {
        let cleanUrl = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanUrl.lowercased().hasPrefix("trojan://") else {
            throw ParserError.invalidScheme("Ожидался протокол trojan://")
        }
        
        guard !cleanUrl.contains("\n") && !cleanUrl.contains("\r") else {
            throw ParserError.malformedUrl("Ссылка Trojan не должна содержать переносы строк")
        }
        
        guard let url = URL(string: cleanUrl) else {
            throw ParserError.malformedUrl("Некорректный синтаксис ссылки Trojan")
        }
        
        guard let password = url.user, !password.isEmpty else {
            throw ParserError.missingField("Пароль Trojan отсутствует")
        }
        
        guard let host = url.host, !host.isEmpty else {
            throw ParserError.missingField("Хост сервера отсутствует")
        }
        
        let port = url.port ?? 443
        guard (1...65535).contains(port) else {
            throw ParserError.malformedUrl("Недопустимый порт: \(port)")
        }
        
        var name = "\(host):\(port)"
        if let hashIdx = cleanUrl.firstIndex(of: "#") {
            let rawFragment = String(cleanUrl[cleanUrl.index(after: hashIdx)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !rawFragment.isEmpty {
                let decoded = rawFragment.removingPercentEncoding ?? rawFragment
                let clean = (decoded.removingPercentEncoding ?? decoded).trimmingCharacters(in: .whitespacesAndNewlines)
                if !clean.isEmpty {
                    name = clean
                }
            }
        } else if let frag = url.fragment?.trimmingCharacters(in: .whitespacesAndNewlines), !frag.isEmpty {
            let decoded = frag.removingPercentEncoding ?? frag
            let clean = (decoded.removingPercentEncoding ?? decoded).trimmingCharacters(in: .whitespacesAndNewlines)
            if !clean.isEmpty {
                name = clean
            }
        }
        
        var sni: String?
        var security = "tls"
        var transport = "tcp"
        var path: String?
        
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems {
            for item in queryItems {
                let val = item.value ?? ""
                switch item.name.lowercased() {
                case "sni", "peer":
                    sni = val
                case "security":
                    security = val
                case "type":
                    transport = val
                case "path":
                    path = val
                default:
                    break
                }
            }
        }
        
        let trojan = TrojanDetails(
            password: password,
            serverName: sni ?? host,
            security: security,
            transportType: transport,
            path: path
        )
        
        return ServerProfile(
            name: name,
            address: host,
            port: port,
            protocolType: .trojan,
            trojanDetails: trojan,
            rawUri: cleanUrl
        )
    }
}
