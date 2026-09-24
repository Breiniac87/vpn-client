import Foundation

public struct VLESSParser {
    public static func parse(urlString: String) throws -> ServerProfile {
        let cleanUrl = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanUrl.lowercased().hasPrefix("vless://") else {
            throw ParserError.invalidScheme("Ожидался протокол vless://")
        }
        
        guard !cleanUrl.contains("\n") && !cleanUrl.contains("\r") else {
            throw ParserError.malformedUrl("Ссылка VLESS не должна содержать переносы строк")
        }
        
        // Format: vless://uuid@host:port?query#name
        guard let url = URL(string: cleanUrl) else {
            throw ParserError.malformedUrl("Некорректный синтаксис ссылки VLESS")
        }
        
        guard let uuid = url.user, !uuid.isEmpty else {
            throw ParserError.missingField("UUID пользователя отсутствует")
        }
        
        guard let host = url.host, !host.isEmpty else {
            throw ParserError.missingField("Хост сервера отсутствует")
        }
        
        let port = url.port ?? 443
        
        // Extract server name from URL fragment with reliable percent decoding
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
        
        // Parse query parameters
        var flow: String?
        var security: String = "none"
        var sni: String?
        var pbk: String?
        var sid: String?
        var fp: String? = "chrome"
        var spx: String?
        var type: String = "tcp"
        var path: String?
        var hostHeader: String?
        
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems {
            for item in queryItems {
                let val = item.value ?? ""
                switch item.name.lowercased() {
                case "security":
                    security = val
                case "flow":
                    flow = val
                case "sni":
                    sni = val
                case "pbk":
                    pbk = val
                case "sid":
                    sid = val
                case "fp":
                    fp = val
                case "spx":
                    spx = val
                case "type":
                    type = val
                case "path":
                    path = val
                case "host":
                    hostHeader = val
                case "servicename":
                    path = val // gRPC serviceName often passed as serviceName or path
                default:
                    break
                }
            }
        }
        
        let vless = VLESSDetails(
            uuid: uuid,
            flow: flow,
            security: security,
            serverName: sni ?? host,
            publicKey: pbk,
            shortId: sid,
            fingerprint: fp,
            spiderX: spx,
            transportType: type,
            path: path,
            hostHeader: hostHeader
        )
        
        return ServerProfile(
            name: name,
            address: host,
            port: port,
            protocolType: .vless,
            vlessDetails: vless,
            rawUri: cleanUrl
        )
    }
}

public enum ParserError: LocalizedError {
    case invalidScheme(String)
    case malformedUrl(String)
    case missingField(String)
    case invalidBase64(String)
    case unsupportedProtocol(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidScheme(let msg): return "Неверная схема: \(msg)"
        case .malformedUrl(let msg): return "Ошибка URL: \(msg)"
        case .missingField(let msg): return "Отсутствует обязательное поле: \(msg)"
        case .invalidBase64(let msg): return "Некорректная Base64 строка: \(msg)"
        case .unsupportedProtocol(let msg): return "Неподдерживаемый протокол: \(msg)"
        }
    }
}
