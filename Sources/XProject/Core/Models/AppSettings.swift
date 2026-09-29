import Foundation
import SwiftUI

/// Pluggable anti-censorship routing strategies / camouflage profiles
public enum StealthProfile: String, CaseIterable, Identifiable, Codable {
    case standardReality = "Standard Reality"
    case cdnFronting = "CDN Fronting (XHTTP)"
    case webrtcCamouflage = "WebRTC Camouflage"
    case quicMasquerade = "HTTP/3 QUIC Masquerade"
    
    public var id: String { self.rawValue }
    
    /// Human-readable description of the profile's mechanism
    public var profileDescription: String {
        switch self {
        case .standardReality:
            return "Классический Reality с маскировкой под TLS 1.3 и фрагментацией."
        case .cdnFronting:
            return "Пропуск трафика через CDN по протоколу XHTTP."
        case .webrtcCamouflage:
            return "Маскировка под P2P аудио/видеозвонки WebRTC поверх mKCP."
        case .quicMasquerade:
            return "Инкапсуляция в HTTP/3 QUIC (UDP) через XHTTP stream-one H3."
        }
    }
}

/// Intensity levels for temporal traffic shaping (jitter & packet size randomization)
public enum TemporalShapingIntensity: String, CaseIterable, Identifiable, Codable {
    case mild = "Мягкий (низкий оверхед)"
    case dynamic = "Динамический (рекомендуется)"
    case aggressive = "Агрессивный (максимальный джиттер)"
    
    public var id: String { self.rawValue }
    
    /// Returns noise parameters (delay, packet) for the Freedom dialer
    public var noiseParameters: (delay: String, packet: String) {
        switch self {
        case .mild: return (delay: "10-25", packet: "50-100")
        case .dynamic: return (delay: "15-45", packet: "80-160")
        case .aggressive: return (delay: "20-80", packet: "120-280")
        }
    }
}

/// Observable AppStorage-backed wrapper for SwiftUI integration as specified in advanced_stealth_profiles_plan.md
public final class AppSettingsStorage: ObservableObject {
    public static let shared = AppSettingsStorage()
    
    @AppStorage("stealthProfile") public var stealthProfile: StealthProfile = .standardReality
    @AppStorage("enableMicroSessions") public var enableMicroSessions: Bool = false
    @AppStorage("enablePortHopping") public var enablePortHopping: Bool = false
    @AppStorage("cdnHost") public var cdnHost: String = ""
    @AppStorage("cdnPath") public var cdnPath: String = "/"
    @AppStorage("webrtcSni") public var webrtcSni: String = ""
}

public struct AppSettings: Codable, Equatable {
    public static var shared: AppSettings = .standard
    
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
    
    // Launch at login & LAN sharing
    public var launchAtLogin: Bool
    public var allowLanConnections: Bool
    
    // DPI: Fragment & Noise settings
    public var fragmentEnabled: Bool
    public var fragmentPackets: String // "tlshello" or "1-3"
    public var fragmentLength: String  // "100-200" or "50-100"
    public var fragmentInterval: String // "10-20"
    
    public var noiseEnabled: Bool
    public var noiseType: String       // "rand", "base64", "str"
    public var noisePacket: String     // "50-100"
    public var noiseDelay: String      // "10-20"
    
    // Stealth Profiles & Modifiers
    public var stealthProfile: StealthProfile {
        didSet {
            UserDefaults.standard.set(stealthProfile.rawValue, forKey: "stealthProfile")
        }
    }
    public var enableMicroSessions: Bool {
        didSet {
            UserDefaults.standard.set(enableMicroSessions, forKey: "enableMicroSessions")
        }
    }
    public var enablePortHopping: Bool {
        didSet {
            UserDefaults.standard.set(enablePortHopping, forKey: "enablePortHopping")
        }
    }
    
    // Profile Custom Configuration (CDN Fronting & WebRTC Camouflage)
    public var cdnHost: String {
        didSet {
            UserDefaults.standard.set(cdnHost, forKey: "cdnHost")
        }
    }
    public var cdnPath: String {
        didSet {
            UserDefaults.standard.set(cdnPath, forKey: "cdnPath")
        }
    }
    public var webrtcSni: String {
        didSet {
            UserDefaults.standard.set(webrtcSni, forKey: "webrtcSni")
        }
    }
    
    // MARK: - Connection Guard & Failover
    public var autoReconnectEnabled: Bool
    public var maxReconnectAttempts: Int      // 1...10
    public var autoFallbackEnabled: Bool
    public var fallbackFailThreshold: Int     // 1...5
    public var killSwitchEnabled: Bool
    
    // MARK: - Advanced Anti-DPI & Stealth
    public var proxyChainEnabled: Bool
    public var proxyChainRelayId: UUID?
    public var streamingMimicryEnabled: Bool
    public var streamingMimicryCdn: String    // CDN domain for User-Agent masquerade
    public var temporalShapingEnabled: Bool
    public var temporalShapingIntensity: TemporalShapingIntensity
    
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
        lastSelectedServerKey: String? = nil,
        launchAtLogin: Bool = false,
        allowLanConnections: Bool = false,
        fragmentEnabled: Bool = false,
        fragmentPackets: String = "tlshello",
        fragmentLength: String = "100-200",
        fragmentInterval: String = "10-20",
        noiseEnabled: Bool = false,
        noiseType: String = "rand",
        noisePacket: String = "50-100",
        noiseDelay: String = "10-20",
        stealthProfile: StealthProfile = .standardReality,
        enableMicroSessions: Bool = false,
        enablePortHopping: Bool = false,
        cdnHost: String = "",
        cdnPath: String = "/",
        webrtcSni: String = "",
        autoReconnectEnabled: Bool = true,
        maxReconnectAttempts: Int = 5,
        autoFallbackEnabled: Bool = true,
        fallbackFailThreshold: Int = 2,
        killSwitchEnabled: Bool = false,
        proxyChainEnabled: Bool = false,
        proxyChainRelayId: UUID? = nil,
        streamingMimicryEnabled: Bool = false,
        streamingMimicryCdn: String = "video.cloudflare.com",
        temporalShapingEnabled: Bool = false,
        temporalShapingIntensity: TemporalShapingIntensity = .dynamic
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
        self.launchAtLogin = launchAtLogin
        self.allowLanConnections = allowLanConnections
        self.fragmentEnabled = fragmentEnabled
        self.fragmentPackets = fragmentPackets
        self.fragmentLength = fragmentLength
        self.fragmentInterval = fragmentInterval
        self.noiseEnabled = noiseEnabled
        self.noiseType = noiseType
        self.noisePacket = noisePacket
        self.noiseDelay = noiseDelay
        self.stealthProfile = stealthProfile
        self.enableMicroSessions = enableMicroSessions
        self.enablePortHopping = enablePortHopping
        self.cdnHost = cdnHost
        self.cdnPath = cdnPath
        self.webrtcSni = webrtcSni
        self.autoReconnectEnabled = autoReconnectEnabled
        self.maxReconnectAttempts = maxReconnectAttempts
        self.autoFallbackEnabled = autoFallbackEnabled
        self.fallbackFailThreshold = fallbackFailThreshold
        self.killSwitchEnabled = killSwitchEnabled
        self.proxyChainEnabled = proxyChainEnabled
        self.proxyChainRelayId = proxyChainRelayId
        self.streamingMimicryEnabled = streamingMimicryEnabled
        self.streamingMimicryCdn = streamingMimicryCdn
        self.temporalShapingEnabled = temporalShapingEnabled
        self.temporalShapingIntensity = temporalShapingIntensity
    }
    
    public static var standard: AppSettings {
        AppSettings(
            trafficMode: .tun,
            routingMode: .ruleBased,
            socksPort: 10808,
            httpPort: 10809,
            dnsServer: "https://1.1.1.1/dns-query",
            autoConnectOnLaunch: false,
            autoUpdateSubscriptions: true,
            launchAtLogin: false,
            allowLanConnections: false,
            fragmentEnabled: false,
            fragmentPackets: "tlshello",
            fragmentLength: "100-200",
            fragmentInterval: "10-20",
            noiseEnabled: false,
            noiseType: "rand",
            noisePacket: "50-100",
            noiseDelay: "10-20",
            stealthProfile: .standardReality,
            enableMicroSessions: false,
            enablePortHopping: false,
            cdnHost: "",
            cdnPath: "/",
            webrtcSni: "",
            autoReconnectEnabled: true,
            maxReconnectAttempts: 5,
            autoFallbackEnabled: true,
            fallbackFailThreshold: 2,
            killSwitchEnabled: false,
            proxyChainEnabled: false,
            proxyChainRelayId: nil,
            streamingMimicryEnabled: false,
            streamingMimicryCdn: "video.cloudflare.com",
            temporalShapingEnabled: false,
            temporalShapingIntensity: .dynamic
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
        case launchAtLogin
        case allowLanConnections
        case fragmentEnabled
        case fragmentPackets
        case fragmentLength
        case fragmentInterval
        case noiseEnabled
        case noiseType
        case noisePacket
        case noiseDelay
        case stealthProfile
        case enableMicroSessions
        case enablePortHopping
        case cdnHost
        case cdnPath
        case webrtcSni
        case autoReconnectEnabled
        case maxReconnectAttempts
        case autoFallbackEnabled
        case fallbackFailThreshold
        case killSwitchEnabled
        case proxyChainEnabled
        case proxyChainRelayId
        case streamingMimicryEnabled
        case streamingMimicryCdn
        case temporalShapingEnabled
        case temporalShapingIntensity
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
        self.launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        self.allowLanConnections = try container.decodeIfPresent(Bool.self, forKey: .allowLanConnections) ?? false
        self.fragmentEnabled = try container.decodeIfPresent(Bool.self, forKey: .fragmentEnabled) ?? false
        self.fragmentPackets = try container.decodeIfPresent(String.self, forKey: .fragmentPackets) ?? "tlshello"
        self.fragmentLength = try container.decodeIfPresent(String.self, forKey: .fragmentLength) ?? "100-200"
        self.fragmentInterval = try container.decodeIfPresent(String.self, forKey: .fragmentInterval) ?? "10-20"
        self.noiseEnabled = try container.decodeIfPresent(Bool.self, forKey: .noiseEnabled) ?? false
        self.noiseType = try container.decodeIfPresent(String.self, forKey: .noiseType) ?? "rand"
        self.noisePacket = try container.decodeIfPresent(String.self, forKey: .noisePacket) ?? "50-100"
        self.noiseDelay = try container.decodeIfPresent(String.self, forKey: .noiseDelay) ?? "10-20"
        self.stealthProfile = try container.decodeIfPresent(StealthProfile.self, forKey: .stealthProfile) ?? .standardReality
        self.enableMicroSessions = try container.decodeIfPresent(Bool.self, forKey: .enableMicroSessions) ?? false
        self.enablePortHopping = try container.decodeIfPresent(Bool.self, forKey: .enablePortHopping) ?? false
        self.cdnHost = try container.decodeIfPresent(String.self, forKey: .cdnHost) ?? ""
        self.cdnPath = try container.decodeIfPresent(String.self, forKey: .cdnPath) ?? "/"
        self.webrtcSni = try container.decodeIfPresent(String.self, forKey: .webrtcSni) ?? ""
        self.autoReconnectEnabled = try container.decodeIfPresent(Bool.self, forKey: .autoReconnectEnabled) ?? true
        self.maxReconnectAttempts = try container.decodeIfPresent(Int.self, forKey: .maxReconnectAttempts) ?? 5
        self.autoFallbackEnabled = try container.decodeIfPresent(Bool.self, forKey: .autoFallbackEnabled) ?? true
        self.fallbackFailThreshold = try container.decodeIfPresent(Int.self, forKey: .fallbackFailThreshold) ?? 2
        self.killSwitchEnabled = try container.decodeIfPresent(Bool.self, forKey: .killSwitchEnabled) ?? false
        self.proxyChainEnabled = try container.decodeIfPresent(Bool.self, forKey: .proxyChainEnabled) ?? false
        self.proxyChainRelayId = try container.decodeIfPresent(UUID.self, forKey: .proxyChainRelayId)
        self.streamingMimicryEnabled = try container.decodeIfPresent(Bool.self, forKey: .streamingMimicryEnabled) ?? false
        self.streamingMimicryCdn = try container.decodeIfPresent(String.self, forKey: .streamingMimicryCdn) ?? "video.cloudflare.com"
        self.temporalShapingEnabled = try container.decodeIfPresent(Bool.self, forKey: .temporalShapingEnabled) ?? false
        self.temporalShapingIntensity = try container.decodeIfPresent(TemporalShapingIntensity.self, forKey: .temporalShapingIntensity) ?? .dynamic
    }
}
