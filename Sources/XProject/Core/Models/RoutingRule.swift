import Foundation

public enum RoutingTarget: String, Codable, CaseIterable, Identifiable {
    case proxy = "proxy"
    case direct = "direct"
    case block = "block"
    
    public var id: String { rawValue }
    
    public var localizedTitle: String {
        switch self {
        case .proxy: return "Через прокси"
        case .direct: return "Напрямую (Bypass)"
        case .block: return "Блокировать"
        }
    }
}

public struct RoutingRule: Identifiable, Codable, Equatable, Hashable {
    public var id: UUID
    public var value: String            // e.g. "geosite:openai", "instagram.com", "geoip:ru"
    public var target: RoutingTarget    // .proxy, .direct, .block
    public var isEnabled: Bool
    public var comment: String?
    
    public init(
        id: UUID = UUID(),
        value: String,
        target: RoutingTarget,
        isEnabled: Bool = true,
        comment: String? = nil
    ) {
        self.id = id
        self.value = value
        self.target = target
        self.isEnabled = isEnabled
        self.comment = comment
    }
    
    public var isGeoSite: Bool {
        value.lowercased().hasPrefix("geosite:")
    }
    
    public var isGeoIP: Bool {
        value.lowercased().hasPrefix("geoip:")
    }
}

public struct RoutingConfig: Codable, Equatable {
    public var mode: ProxyRoutingMode
    public var proxyRules: [RoutingRule]
    public var directRules: [RoutingRule]
    public var blockRules: [RoutingRule]
    public var fakeDnsEnabled: Bool
    public var domainStrategy: String // "IPIfNonMatch", "AsIs", "IPOnDemand"
    
    public init(
        mode: ProxyRoutingMode = .ruleBased,
        proxyRules: [RoutingRule] = [],
        directRules: [RoutingRule] = [],
        blockRules: [RoutingRule] = [],
        fakeDnsEnabled: Bool = false,
        domainStrategy: String = "IPIfNonMatch"
    ) {
        self.mode = mode
        self.proxyRules = proxyRules
        self.directRules = directRules
        self.blockRules = blockRules
        self.fakeDnsEnabled = fakeDnsEnabled
        self.domainStrategy = domainStrategy
    }
    
    private enum CodingKeys: String, CodingKey {
        case mode, proxyRules, directRules, blockRules, fakeDnsEnabled, domainStrategy
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.mode = try container.decodeIfPresent(ProxyRoutingMode.self, forKey: .mode) ?? .ruleBased
        self.proxyRules = try container.decodeIfPresent([RoutingRule].self, forKey: .proxyRules) ?? []
        self.directRules = try container.decodeIfPresent([RoutingRule].self, forKey: .directRules) ?? []
        self.blockRules = try container.decodeIfPresent([RoutingRule].self, forKey: .blockRules) ?? []
        self.fakeDnsEnabled = try container.decodeIfPresent(Bool.self, forKey: .fakeDnsEnabled) ?? false
        self.domainStrategy = try container.decodeIfPresent(String.self, forKey: .domainStrategy) ?? "IPIfNonMatch"
    }
    
    public static var defaultConfiguration: RoutingConfig {
        RoutingConfig(
            mode: .ruleBased,
            proxyRules: [
                RoutingRule(value: "geosite:openai", target: .proxy, comment: "ChatGPT / OpenAI"),
                RoutingRule(value: "geosite:anthropic", target: .proxy, comment: "Claude / Anthropic"),
                RoutingRule(value: "geosite:google-gemini", target: .proxy, comment: "Google Gemini AI"),
                RoutingRule(value: "domain:gemini.google.com", target: .proxy, comment: "Gemini Web"),
                RoutingRule(value: "domain:perplexity.ai", target: .proxy, comment: "Perplexity AI"),
                RoutingRule(value: "geosite:twitter", target: .proxy, comment: "X / Twitter"),
                RoutingRule(value: "geosite:instagram", target: .proxy, comment: "Instagram"),
                RoutingRule(value: "geosite:facebook", target: .proxy, comment: "Facebook & Meta"),
                RoutingRule(value: "geosite:youtube", target: .proxy, comment: "YouTube"),
                RoutingRule(value: "domain:rutracker.org", target: .proxy, comment: "RuTracker"),
                RoutingRule(value: "domain:notion.so", target: .proxy, comment: "Notion")
            ],
            directRules: [
                RoutingRule(value: "geoip:ru", target: .direct, comment: "Российские IP-адреса"),
                RoutingRule(value: "geoip:private", target: .direct, comment: "Локальная сеть (LAN)"),
                RoutingRule(value: "geosite:category-gov-ru", target: .direct, comment: "Госуслуги и гос. сайты"),
                RoutingRule(value: "geosite:yandex", target: .direct, comment: "Сервисы Яндекса"),
                RoutingRule(value: "geosite:vk", target: .direct, comment: "ВКонтакте и Mail.ru"),
                RoutingRule(value: "domain:sberbank.ru", target: .direct, comment: "Сбербанк и банки РФ")
            ],
            blockRules: [
                RoutingRule(value: "geosite:category-ads", target: .block, comment: "Блокировка рекламы и трекеров")
            ],
            fakeDnsEnabled: false,
            domainStrategy: "IPIfNonMatch"
        )
    }
}
