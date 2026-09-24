import Foundation

public enum ProxyRoutingMode: String, Codable, CaseIterable, Identifiable {
    case ruleBased = "rule_based"
    case global = "global"
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .ruleBased:
            return "По правилам (Split)"
        case .global:
            return "Глобальный (Весь трафик)"
        }
    }
    
    public var subtitle: String {
        switch self {
        case .ruleBased:
            return "Списки прокси и прямых доменов"
        case .global:
            return "Весь трафик идет через выбранный сервер"
        }
    }
    
    public var iconName: String {
        switch self {
        case .ruleBased:
            return "point.topleft.and.bottomright.filled.curvepath"
        case .global:
            return "globe.americas.fill"
        }
    }
}

public enum TrafficMode: String, Codable, CaseIterable, Identifiable {
    case tun = "tun"
    case systemProxy = "system_proxy"
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .tun:
            return "TUN интерфейс (VPN)"
        case .systemProxy:
            return "Системный прокси"
        }
    }
    
    public var subtitle: String {
        switch self {
        case .tun:
            return "Перехватывает 100% системного трафика всех приложений"
        case .systemProxy:
            return "Настраивает системный HTTP/SOCKS5 прокси без TUN-интерфейса"
        }
    }
    
    public var iconName: String {
        switch self {
        case .tun:
            return "shield.checkered"
        case .systemProxy:
            return "network.badge.shield.half.filled"
        }
    }
}
