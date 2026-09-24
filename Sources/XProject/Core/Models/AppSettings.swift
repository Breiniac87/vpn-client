import Foundation

public struct AppSettings: Codable, Equatable {
    public var trafficMode: TrafficMode
    public var routingMode: ProxyRoutingMode
    public var socksPort: Int
    public var httpPort: Int
    public var dnsServer: String
    public var autoConnectOnLaunch: Bool
    public var autoUpdateSubscriptions: Bool
    public var lastSelectedServerId: UUID?
    public var lastSelectedServerName: String?
    public var lastSelectedServerKey: String?
    
    public init(
        trafficMode: TrafficMode = .tun,
        routingMode: ProxyRoutingMode = .ruleBased,
        socksPort: Int = 10808,
        httpPort: Int = 10809,
        dnsServer: String = "https://1.1.1.1/dns-query",
        autoConnectOnLaunch: Bool = false,
        autoUpdateSubscriptions: Bool = true,
        lastSelectedServerId: UUID? = nil,
        lastSelectedServerName: String? = nil,
        lastSelectedServerKey: String? = nil
    ) {
        self.trafficMode = trafficMode
        self.routingMode = routingMode
        self.socksPort = socksPort
        self.httpPort = httpPort
        self.dnsServer = dnsServer
        self.autoConnectOnLaunch = autoConnectOnLaunch
        self.autoUpdateSubscriptions = autoUpdateSubscriptions
        self.lastSelectedServerId = lastSelectedServerId
        self.lastSelectedServerName = lastSelectedServerName
        self.lastSelectedServerKey = lastSelectedServerKey
    }
    
    public static var standard: AppSettings {
        AppSettings(
            trafficMode: .tun,
            routingMode: .ruleBased,
            socksPort: 10808,
            httpPort: 10809,
            dnsServer: "https://1.1.1.1/dns-query",
            autoConnectOnLaunch: false,
            autoUpdateSubscriptions: true
        )
    }
    
    enum CodingKeys: String, CodingKey {
        case trafficMode
        case routingMode
        case socksPort
        case httpPort
        case dnsServer
        case autoConnectOnLaunch
        case autoUpdateSubscriptions
        case lastSelectedServerId
        case lastSelectedServerName
        case lastSelectedServerKey
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.trafficMode = try container.decodeIfPresent(TrafficMode.self, forKey: .trafficMode) ?? .tun
        self.routingMode = try container.decodeIfPresent(ProxyRoutingMode.self, forKey: .routingMode) ?? .ruleBased
        self.socksPort = try container.decodeIfPresent(Int.self, forKey: .socksPort) ?? 10808
        self.httpPort = try container.decodeIfPresent(Int.self, forKey: .httpPort) ?? 10809
        self.dnsServer = try container.decodeIfPresent(String.self, forKey: .dnsServer) ?? "https://1.1.1.1/dns-query"
        self.autoConnectOnLaunch = try container.decodeIfPresent(Bool.self, forKey: .autoConnectOnLaunch) ?? false
        self.autoUpdateSubscriptions = try container.decodeIfPresent(Bool.self, forKey: .autoUpdateSubscriptions) ?? true
        self.lastSelectedServerId = try container.decodeIfPresent(UUID.self, forKey: .lastSelectedServerId)
        self.lastSelectedServerName = try container.decodeIfPresent(String.self, forKey: .lastSelectedServerName)
        self.lastSelectedServerKey = try container.decodeIfPresent(String.self, forKey: .lastSelectedServerKey)
    }
}
