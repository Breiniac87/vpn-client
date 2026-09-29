import XCTest
@testable import XProject

final class ConfigGeneratorTests: XCTestCase {
    
    func testVLESSRealityConfigGeneration() throws {
        let server = ServerProfile(
            name: "NL Reality",
            address: "1.2.3.4",
            port: 443,
            protocolType: .vless,
            vlessDetails: VLESSDetails(
                uuid: "a28b0561-269e-4e4b-97e3-059c1c4f5f5e",
                flow: "xtls-rprx-vision",
                security: "reality",
                serverName: "speedtest.net",
                publicKey: "j2y-jQZ3hP4x5F6L8a9b0c1d2e3f4g5h6i7j8k9l0m=",
                shortId: "6ba7b810",
                fingerprint: "chrome"
            )
        )
        
        let configJson = try XrayConfigGenerator.generateConfig(
            server: server,
            routing: .defaultConfiguration,
            settings: .standard
        )
        
        // Parse back as JSON to verify keys
        let data = configJson.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        
        // Verify inbounds
        let inbounds = json["inbounds"] as! [[String: Any]]
        XCTAssertEqual(inbounds.count, 2)
        XCTAssertEqual(inbounds[0]["protocol"] as? String, "socks")
        XCTAssertEqual(inbounds[0]["port"] as? Int, 10808)
        XCTAssertEqual(inbounds[1]["protocol"] as? String, "http")
        XCTAssertEqual(inbounds[1]["port"] as? Int, 10809)
        
        // Verify outbounds
        let outbounds = json["outbounds"] as! [[String: Any]]
        let proxy = outbounds.first(where: { ($0["tag"] as? String) == "proxy" })!
        XCTAssertEqual(proxy["protocol"] as? String, "vless")
        
        let streamSettings = proxy["streamSettings"] as! [String: Any]
        XCTAssertEqual(streamSettings["security"] as? String, "reality")
        
        let reality = streamSettings["realitySettings"] as! [String: Any]
        XCTAssertEqual(reality["serverName"] as? String, "speedtest.net")
        XCTAssertEqual(reality["publicKey"] as? String, "j2y-jQZ3hP4x5F6L8a9b0c1d2e3f4g5h6i7j8k9l0m=")
        XCTAssertEqual(reality["shortId"] as? String, "6ba7b810")
        
        // Verify routing
        let routing = json["routing"] as! [String: Any]
        let rules = routing["rules"] as! [[String: Any]]
        XCTAssertFalse(rules.isEmpty)
    }
    
    func testOfficialXrayBinaryValidation() throws {
        // Only run if official binary is present in workspace or system
        guard let binaryPath = XrayBinaryManager.locateBinary() else {
            print("⚠️ Skipping live binary test: xray executable not yet located.")
            return
        }
        
        let version = XrayBinaryManager.checkVersion()
        XCTAssertNotNil(version, "Xray version check should succeed")
        print("ℹ️ Testing with binary at \(binaryPath): \(version ?? "")")
        
        let server = ServerProfile(
            name: "NL Reality Valid",
            address: "1.2.3.4",
            port: 443,
            protocolType: .vless,
            vlessDetails: VLESSDetails(
                uuid: "a28b0561-269e-4e4b-97e3-059c1c4f5f5e",
                flow: "xtls-rprx-vision",
                security: "reality",
                serverName: "speedtest.net",
                publicKey: "oI7CDmF6T6g15MMInNEtC3TyoLc2PZ8EUc2R9lYOlEE",
                shortId: "6ba7b810",
                fingerprint: "chrome"
            )
        )
        
        let result = try XrayProcessManager.shared.testConfiguration(
            server: server,
            routing: .defaultConfiguration,
            settings: .standard
        )
        
        XCTAssertTrue(result.isValid, "Xray -test output: \(result.output)")
    }
    
    func testDialerProxyFragmentAndNoisesValidation() throws {
        var antiDpiSettings = AppSettings.standard
        antiDpiSettings.fragmentEnabled = true
        antiDpiSettings.fragmentPackets = "1-3"
        antiDpiSettings.fragmentLength = "50-100"
        antiDpiSettings.fragmentInterval = "10-20"
        antiDpiSettings.noiseEnabled = true
        antiDpiSettings.noiseType = "rand"
        antiDpiSettings.noisePacket = "50-100"
        antiDpiSettings.noiseDelay = "10-20"
        
        let server = ServerProfile(
            name: "NL Reality Anti-DPI",
            address: "1.2.3.4",
            port: 443,
            protocolType: .vless,
            vlessDetails: VLESSDetails(
                uuid: "a28b0561-269e-4e4b-97e3-059c1c4f5f5e",
                flow: "xtls-rprx-vision",
                security: "reality",
                serverName: "speedtest.net",
                publicKey: "oI7CDmF6T6g15MMInNEtC3TyoLc2PZ8EUc2R9lYOlEE",
                shortId: "6ba7b810",
                fingerprint: "chrome"
            )
        )
        
        let configJson = try XrayConfigGenerator.generateConfig(
            server: server,
            routing: .defaultConfiguration,
            settings: antiDpiSettings
        )
        
        let data = configJson.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let outbounds = json["outbounds"] as! [[String: Any]]
        
        // 1. Verify proxy outbound dialerProxy
        let proxy = outbounds.first(where: { ($0["tag"] as? String) == "proxy" })!
        let streamSettings = proxy["streamSettings"] as! [String: Any]
        let sockopt = streamSettings["sockopt"] as! [String: Any]
        XCTAssertEqual(sockopt["dialerProxy"] as? String, "anti-dpi-dialer")
        XCTAssertNil(proxy["fragment"])
        
        // 2. Verify anti-dpi-dialer outbound
        let dialer = outbounds.first(where: { ($0["tag"] as? String) == "anti-dpi-dialer" })!
        XCTAssertEqual(dialer["protocol"] as? String, "freedom")
        let settings = dialer["settings"] as! [String: Any]
        
        let fragment = settings["fragment"] as! [String: Any]
        XCTAssertEqual(fragment["packets"] as? String, "1-3")
        XCTAssertEqual(fragment["length"] as? String, "50-100")
        XCTAssertEqual(fragment["interval"] as? String, "10-20")
        
        let noises = settings["noises"] as! [[String: Any]]
        XCTAssertEqual(noises.count, 1)
        XCTAssertEqual(noises[0]["type"] as? String, "rand")
        XCTAssertEqual(noises[0]["packet"] as? String, "50-100")
        XCTAssertEqual(noises[0]["delay"] as? String, "10-20")
        
        // 3. Live binary test
        if XrayBinaryManager.locateBinary() != nil {
            let result = try XrayProcessManager.shared.testConfiguration(
                server: server,
                routing: .defaultConfiguration,
                settings: antiDpiSettings
            )
            XCTAssertTrue(result.isValid, "Xray -test with dialerProxy failed: \(result.output)")
        }
    }
    
    func testAllowLanConnectionsInboundListen() throws {
        let server = ServerProfile(
            name: "NL Node",
            address: "1.2.3.4",
            port: 443,
            protocolType: .vless,
            vlessDetails: VLESSDetails(uuid: "a28b0561-269e-4e4b-97e3-059c1c4f5f5e", serverName: "speedtest.net")
        )
        
        var localSettings = AppSettings.standard
        localSettings.allowLanConnections = false
        let localJson = try XrayConfigGenerator.generateConfig(server: server, routing: .defaultConfiguration, settings: localSettings)
        let localDict = try JSONSerialization.jsonObject(with: localJson.data(using: .utf8)!) as! [String: Any]
        let localInbounds = localDict["inbounds"] as! [[String: Any]]
        for inb in localInbounds {
            XCTAssertEqual(inb["listen"] as? String, "127.0.0.1")
        }
        
        var lanSettings = AppSettings.standard
        lanSettings.allowLanConnections = true
        let lanJson = try XrayConfigGenerator.generateConfig(server: server, routing: .defaultConfiguration, settings: lanSettings)
        let lanDict = try JSONSerialization.jsonObject(with: lanJson.data(using: .utf8)!) as! [String: Any]
        let lanInbounds = lanDict["inbounds"] as! [[String: Any]]
        for inb in lanInbounds {
            XCTAssertEqual(inb["listen"] as? String, "0.0.0.0")
        }
    }
    
    // MARK: - Stealth Profiles Strategy Pattern Tests
    
    func testCDNFrontingStrategyGeneration() throws {
        let server = ServerProfile(
            name: "CDN Fronting Node",
            address: "cdn.yandex.net",
            port: 443,
            protocolType: .vless,
            vlessDetails: VLESSDetails(
                uuid: "a28b0561-269e-4e4b-97e3-059c1c4f5f5e",
                serverName: "cdn.yandex.net",
                path: "/xhttp-path"
            )
        )
        
        var cdnSettings = AppSettings.standard
        cdnSettings.stealthProfile = .cdnFronting
        
        let configJson = try XrayConfigGenerator.generateConfig(
            server: server,
            routing: .defaultConfiguration,
            settings: cdnSettings
        )
        
        let data = configJson.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let outbounds = json["outbounds"] as! [[String: Any]]
        let proxy = outbounds.first(where: { ($0["tag"] as? String) == "proxy" })!
        
        let streamSettings = proxy["streamSettings"] as! [String: Any]
        XCTAssertEqual(streamSettings["network"] as? String, "xhttp")
        XCTAssertEqual(streamSettings["security"] as? String, "tls")
        XCTAssertNil(streamSettings["realitySettings"], "CDN Fronting must completely exclude Reality settings")
        
        let xhttpSettings = streamSettings["xhttpSettings"] as! [String: Any]
        XCTAssertEqual(xhttpSettings["host"] as? String, "cdn.yandex.net")
        XCTAssertEqual(xhttpSettings["path"] as? String, "/xhttp-path")
        
        // Official binary validation
        if XrayBinaryManager.locateBinary() != nil {
            let result = try XrayProcessManager.shared.testConfiguration(
                server: server,
                routing: .defaultConfiguration,
                settings: cdnSettings
            )
            XCTAssertTrue(result.isValid, "Xray -test with CDN Fronting (xhttp) failed: \(result.output)")
        }
    }
    
    func testWebRTCCamouflageStrategyGeneration() throws {
        let server = ServerProfile(
            name: "WebRTC Node",
            address: "1.2.3.4",
            port: 443,
            protocolType: .vless,
            vlessDetails: VLESSDetails(
                uuid: "a28b0561-269e-4e4b-97e3-059c1c4f5f5e",
                serverName: "speedtest.net"
            )
        )
        
        var webrtcSettings = AppSettings.standard
        webrtcSettings.stealthProfile = .webrtcCamouflage
        
        let configJson = try XrayConfigGenerator.generateConfig(
            server: server,
            routing: .defaultConfiguration,
            settings: webrtcSettings
        )
        
        let data = configJson.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let outbounds = json["outbounds"] as! [[String: Any]]
        let proxy = outbounds.first(where: { ($0["tag"] as? String) == "proxy" })!
        
        let streamSettings = proxy["streamSettings"] as! [String: Any]
        XCTAssertEqual(streamSettings["network"] as? String, "kcp")
        XCTAssertNotNil(streamSettings["kcpSettings"])
        
        // Official binary validation
        if XrayBinaryManager.locateBinary() != nil {
            let result = try XrayProcessManager.shared.testConfiguration(
                server: server,
                routing: .defaultConfiguration,
                settings: webrtcSettings
            )
            XCTAssertTrue(result.isValid, "Xray -test with WebRTC Camouflage failed: \(result.output)")
        }
    }
    
    func testStealthModifiersMicroSessionsAndAppSettingsShared() throws {
        let server = ServerProfile(
            name: "NL Node",
            address: "1.2.3.4",
            port: 443,
            protocolType: .vless,
            vlessDetails: VLESSDetails(uuid: "a28b0561-269e-4e4b-97e3-059c1c4f5f5e", serverName: "speedtest.net")
        )
        
        // Test enableMicroSessions modifier
        var microSettings = AppSettings.standard
        microSettings.enableMicroSessions = true
        
        let microJson = try XrayConfigGenerator.generateConfig(server: server, routing: .defaultConfiguration, settings: microSettings)
        let microDict = try JSONSerialization.jsonObject(with: microJson.data(using: .utf8)!) as! [String: Any]
        let microOutbounds = microDict["outbounds"] as! [[String: Any]]
        let microProxy = microOutbounds.first(where: { ($0["tag"] as? String) == "proxy" })!
        let microStream = microProxy["streamSettings"] as! [String: Any]
        let microSockopt = microStream["sockopt"] as! [String: Any]
        XCTAssertEqual(microSockopt["tcpKeepAliveInterval"] as? Int, 15)
        XCTAssertEqual(microSockopt["tcpNoDelay"] as? Bool, true)
        
        // Test AppSettings.shared driving outbound strategy
        AppSettings.shared.stealthProfile = .cdnFronting
        let sharedJson = try XrayConfigGenerator.generateConfig(server: server, routing: .defaultConfiguration, settings: .shared)
        let sharedDict = try JSONSerialization.jsonObject(with: sharedJson.data(using: .utf8)!) as! [String: Any]
        let sharedOutbounds = sharedDict["outbounds"] as! [[String: Any]]
        let sharedProxy = sharedOutbounds.first(where: { ($0["tag"] as? String) == "proxy" })!
        let sharedStream = sharedProxy["streamSettings"] as! [String: Any]
        XCTAssertEqual(sharedStream["network"] as? String, "xhttp")
        
        // Reset shared setting
        AppSettings.shared.stealthProfile = .standardReality
    }
    
    func testCDNFrontingWithCustomHostAndPath() throws {
        let server = ServerProfile(
            name: "Generic Server",
            address: "1.2.3.4",
            port: 443,
            protocolType: .vless,
            vlessDetails: VLESSDetails(
                uuid: "a28b0561-269e-4e4b-97e3-059c1c4f5f5e",
                serverName: "original.com",
                path: "/original-path"
            )
        )
        
        var customCdnSettings = AppSettings.standard
        customCdnSettings.stealthProfile = .cdnFronting
        customCdnSettings.cdnHost = "custom.cdn.cloudflare.net"
        customCdnSettings.cdnPath = "/custom-xhttp-endpoint"
        
        let configJson = try XrayConfigGenerator.generateConfig(
            server: server,
            routing: .defaultConfiguration,
            settings: customCdnSettings
        )
        
        let data = configJson.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let outbounds = json["outbounds"] as! [[String: Any]]
        let proxy = outbounds.first(where: { ($0["tag"] as? String) == "proxy" })!
        let streamSettings = proxy["streamSettings"] as! [String: Any]
        
        let tlsSettings = streamSettings["tlsSettings"] as! [String: Any]
        XCTAssertEqual(tlsSettings["serverName"] as? String, "custom.cdn.cloudflare.net")
        
        let xhttpSettings = streamSettings["xhttpSettings"] as! [String: Any]
        XCTAssertEqual(xhttpSettings["host"] as? String, "custom.cdn.cloudflare.net")
        XCTAssertEqual(xhttpSettings["path"] as? String, "/custom-xhttp-endpoint")
        
        // Official binary validation
        if XrayBinaryManager.locateBinary() != nil {
            let result = try XrayProcessManager.shared.testConfiguration(
                server: server,
                routing: .defaultConfiguration,
                settings: customCdnSettings
            )
            XCTAssertTrue(result.isValid, "Xray -test with custom CDN Fronting failed: \(result.output)")
        }
    }
    
    func testWebRTCCamouflageWithCustomSni() throws {
        let server = ServerProfile(
            name: "WebRTC Server",
            address: "1.2.3.4",
            port: 443,
            protocolType: .vless,
            vlessDetails: VLESSDetails(
                uuid: "a28b0561-269e-4e4b-97e3-059c1c4f5f5e",
                serverName: "original.com"
            )
        )
        
        var customWebRTCSettings = AppSettings.standard
        customWebRTCSettings.stealthProfile = .webrtcCamouflage
        customWebRTCSettings.webrtcSni = "webrtc.zoom.us"
        
        let configJson = try XrayConfigGenerator.generateConfig(
            server: server,
            routing: .defaultConfiguration,
            settings: customWebRTCSettings
        )
        
        let data = configJson.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let outbounds = json["outbounds"] as! [[String: Any]]
        let proxy = outbounds.first(where: { ($0["tag"] as? String) == "proxy" })!
        let streamSettings = proxy["streamSettings"] as! [String: Any]
        
        XCTAssertEqual(streamSettings["security"] as? String, "tls")
        let tlsSettings = streamSettings["tlsSettings"] as! [String: Any]
        XCTAssertEqual(tlsSettings["serverName"] as? String, "webrtc.zoom.us")
        
        // Official binary validation
        if XrayBinaryManager.locateBinary() != nil {
            let result = try XrayProcessManager.shared.testConfiguration(
                server: server,
                routing: .defaultConfiguration,
                settings: customWebRTCSettings
            )
            XCTAssertTrue(result.isValid, "Xray -test with custom WebRTC SNI failed: \(result.output)")
        }
    }
    
    func testLaunchAtLoginManagerSafeExecution() {
        // CLI / Test environment detection
        XCTAssertFalse(LaunchAtLoginManager.isRunningInAppBundle, "Tests should run outside .app bundle")
        XCTAssertFalse(LaunchAtLoginManager.isEnabled, "Should default to disabled when outside bundle")
        
        // safeSetEnabled should never crash or throw
        let resultTrue = LaunchAtLoginManager.safeSetEnabled(true)
        XCTAssertTrue(resultTrue)
        
        let resultFalse = LaunchAtLoginManager.safeSetEnabled(false)
        XCTAssertTrue(resultFalse)
    }
    
    func testAppSettingsCodableWithStealthFields() throws {
        var original = AppSettings.standard
        original.stealthProfile = .cdnFronting
        original.enableMicroSessions = true
        original.enablePortHopping = true
        original.cdnHost = "cdn.yandex.ru"
        original.cdnPath = "/stream"
        original.webrtcSni = "meet.google.com"
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AppSettings.self, from: data)
        
        XCTAssertEqual(decoded.stealthProfile, StealthProfile.cdnFronting)
        XCTAssertTrue(decoded.enableMicroSessions)
        XCTAssertTrue(decoded.enablePortHopping)
        XCTAssertEqual(decoded.cdnHost, "cdn.yandex.ru")
        XCTAssertEqual(decoded.cdnPath, "/stream")
        XCTAssertEqual(decoded.webrtcSni, "meet.google.com")
        
        // Verify FEAT-PERSIST-03: Backward compatibility with missing fields
        let minimalJson = """
        {
            "trafficMode": "tun",
            "routingMode": "rule_based"
        }
        """.data(using: .utf8)!
        
        let decodedMinimal = try decoder.decode(AppSettings.self, from: minimalJson)
        XCTAssertEqual(decodedMinimal.stealthProfile, StealthProfile.standardReality)
        XCTAssertFalse(decodedMinimal.enableMicroSessions)
        XCTAssertFalse(decodedMinimal.enablePortHopping)
        XCTAssertEqual(decodedMinimal.cdnHost, "")
        XCTAssertEqual(decodedMinimal.cdnPath, "/")
        XCTAssertEqual(decodedMinimal.webrtcSni, "")
    }
    
    // MARK: - Boundary & Negative QA Scenarios (DPI & Stealth)
    
    func testDPIBoundaryAndNegativeRanges() throws {
        let server = ServerProfile(
            name: "Reality DPI Edge",
            address: "1.2.3.4",
            port: 443,
            protocolType: .vless,
            vlessDetails: VLESSDetails(
                uuid: "a28b0561-269e-4e4b-97e3-059c1c4f5f5e",
                flow: "xtls-rprx-vision",
                security: "reality",
                serverName: "speedtest.net",
                publicKey: "oI7CDmF6T6g15MMInNEtC3TyoLc2PZ8EUc2R9lYOlEE",
                shortId: "6ba7b810",
                fingerprint: "chrome"
            )
        )
        
        // 1. Reversed range (e.g. 500-100) — Xray parses and accepts without syntax crash
        var reversedSettings = AppSettings.standard
        reversedSettings.fragmentEnabled = true
        reversedSettings.fragmentPackets = "1-3"
        reversedSettings.fragmentLength = "500-100"
        reversedSettings.fragmentInterval = "10-20"
        
        let reversedJson = try XrayConfigGenerator.generateConfig(
            server: server,
            routing: .defaultConfiguration,
            settings: reversedSettings
        )
        XCTAssertTrue(reversedJson.contains("\"length\" : \"500-100\"") || reversedJson.contains("\"length\": \"500-100\""))
        
        if XrayBinaryManager.locateBinary() != nil {
            let res = try XrayProcessManager.shared.testConfiguration(
                server: server,
                routing: .defaultConfiguration,
                settings: reversedSettings
            )
            XCTAssertTrue(res.isValid, "Xray-core handles reversed range 500-100 gracefully: \(res.output)")
        }
        
        // 2. Negative case: malformed fragmentPackets ("invalid")
        var invalidPacketSettings = AppSettings.standard
        invalidPacketSettings.fragmentEnabled = true
        invalidPacketSettings.fragmentPackets = "invalid"
        
        if XrayBinaryManager.locateBinary() != nil {
            let res = try XrayProcessManager.shared.testConfiguration(
                server: server,
                routing: .defaultConfiguration,
                settings: invalidPacketSettings
            )
            XCTAssertFalse(res.isValid, "Xray-core must reject non-range packet string")
            XCTAssertTrue(res.output.contains("invalid range") || res.output.contains("Failed to start"))
        }
        
        // 3. Negative case: invalid noise type
        var invalidNoiseSettings = AppSettings.standard
        invalidNoiseSettings.noiseEnabled = true
        invalidNoiseSettings.noiseType = "invalid_type"
        
        if XrayBinaryManager.locateBinary() != nil {
            let res = try XrayProcessManager.shared.testConfiguration(
                server: server,
                routing: .defaultConfiguration,
                settings: invalidNoiseSettings
            )
            XCTAssertFalse(res.isValid, "Xray-core must reject unsupported noise type")
            XCTAssertTrue(res.output.contains("only rand/str/hex/base64 are supported") || res.output.contains("Failed to start"))
        }
    }
    
    func testCDNFrontingBoundaryEdgeCases() throws {
        let server = ServerProfile(
            name: "CDN Boundary Node",
            address: "cdn.cloudflare.com",
            port: 443,
            protocolType: .vless,
            vlessDetails: VLESSDetails(uuid: "a28b0561-269e-4e4b-97e3-059c1c4f5f5e", serverName: "cdn.cloudflare.com")
        )
        
        // 1. Path without leading slash ("stream" instead of "/stream")
        var noSlashSettings = AppSettings.standard
        noSlashSettings.stealthProfile = .cdnFronting
        noSlashSettings.cdnHost = "cdn.cloudflare.com"
        noSlashSettings.cdnPath = "stream"
        
        let noSlashJson = try XrayConfigGenerator.generateConfig(server: server, routing: .defaultConfiguration, settings: noSlashSettings)
        let dict = try JSONSerialization.jsonObject(with: noSlashJson.data(using: .utf8)!) as! [String: Any]
        let outbounds = dict["outbounds"] as! [[String: Any]]
        let proxy = outbounds[0]
        let streamSettings = proxy["streamSettings"] as! [String: Any]
        let xhttpSettings = streamSettings["xhttpSettings"] as! [String: Any]
        XCTAssertEqual(xhttpSettings["path"] as? String, "stream")
        
        if XrayBinaryManager.locateBinary() != nil {
            let res = try XrayProcessManager.shared.testConfiguration(server: server, routing: .defaultConfiguration, settings: noSlashSettings)
            XCTAssertTrue(res.isValid, "Xray must accept non-leading slash path: \(res.output)")
        }
        
        // 2. Path with spaces and query parameters
        var specialPathSettings = AppSettings.standard
        specialPathSettings.stealthProfile = .cdnFronting
        specialPathSettings.cdnHost = "cdn.cloudflare.com"
        specialPathSettings.cdnPath = "/stream with space?foo=bar#tag"
        
        if XrayBinaryManager.locateBinary() != nil {
            let res = try XrayProcessManager.shared.testConfiguration(server: server, routing: .defaultConfiguration, settings: specialPathSettings)
            XCTAssertTrue(res.isValid, "Xray must accept path with query and spaces: \(res.output)")
        }
    }
    
    func testWebRTCCamouflageBoundaryEdgeCases() throws {
        let server = ServerProfile(
            name: "WebRTC Boundary Node",
            address: "1.2.3.4",
            port: 443,
            protocolType: .vless,
            vlessDetails: VLESSDetails(uuid: "a28b0561-269e-4e4b-97e3-059c1c4f5f5e")
        )
        
        // 1. IP address as SNI
        var ipSniSettings = AppSettings.standard
        ipSniSettings.stealthProfile = .webrtcCamouflage
        ipSniSettings.webrtcSni = "1.1.1.1"
        
        let ipJson = try XrayConfigGenerator.generateConfig(server: server, routing: .defaultConfiguration, settings: ipSniSettings)
        let ipDict = try JSONSerialization.jsonObject(with: ipJson.data(using: .utf8)!) as! [String: Any]
        let outbounds = ipDict["outbounds"] as! [[String: Any]]
        let proxy = outbounds[0]
        let streamSettings = proxy["streamSettings"] as! [String: Any]
        let tlsSettings = streamSettings["tlsSettings"] as! [String: Any]
        XCTAssertEqual(tlsSettings["serverName"] as? String, "1.1.1.1")
        
        if XrayBinaryManager.locateBinary() != nil {
            let res = try XrayProcessManager.shared.testConfiguration(server: server, routing: .defaultConfiguration, settings: ipSniSettings)
            XCTAssertTrue(res.isValid, "Xray must accept IP as SNI for WebRTC: \(res.output)")
        }
        
        // 2. Empty SNI -> security: "none"
        var emptySniSettings = AppSettings.standard
        emptySniSettings.stealthProfile = .webrtcCamouflage
        emptySniSettings.webrtcSni = ""
        
        let emptyJson = try XrayConfigGenerator.generateConfig(server: server, routing: .defaultConfiguration, settings: emptySniSettings)
        let emptyDict = try JSONSerialization.jsonObject(with: emptyJson.data(using: .utf8)!) as! [String: Any]
        let emptyOutbounds = emptyDict["outbounds"] as! [[String: Any]]
        let emptyStream = emptyOutbounds[0]["streamSettings"] as! [String: Any]
        XCTAssertEqual(emptyStream["security"] as? String, "none")
        XCTAssertNil(emptyStream["tlsSettings"])
        
        if XrayBinaryManager.locateBinary() != nil {
            let res = try XrayProcessManager.shared.testConfiguration(server: server, routing: .defaultConfiguration, settings: emptySniSettings)
            XCTAssertTrue(res.isValid, "Xray must accept WebRTC without TLS when SNI is empty: \(res.output)")
        }
    }
    
    func testAntiDpiIgnoredWhenStealthProfileNotStandardReality() throws {
        let server = ServerProfile(
            name: "Server With Reality and Flow",
            address: "1.2.3.4",
            port: 443,
            protocolType: .vless,
            vlessDetails: VLESSDetails(
                uuid: "a28b0561-269e-4e4b-97e3-059c1c4f5f5e",
                flow: "xtls-rprx-vision",
                security: "reality",
                serverName: "speedtest.net",
                publicKey: "oI7CDmF6T6g15MMInNEtC3TyoLc2PZ8EUc2R9lYOlEE",
                shortId: "6ba7b810"
            )
        )
        
        // Enable Fragment & Noise
        var settings = AppSettings.standard
        settings.fragmentEnabled = true
        settings.noiseEnabled = true
        
        // 1. CDN Fronting Profile: must ignore fragment and noise completely
        settings.stealthProfile = .cdnFronting
        settings.cdnHost = "cdn.yandex.net"
        
        let cdnJson = try XrayConfigGenerator.generateConfig(server: server, routing: .defaultConfiguration, settings: settings)
        let cdnDict = try JSONSerialization.jsonObject(with: cdnJson.data(using: .utf8)!) as! [String: Any]
        let cdnOutbounds = cdnDict["outbounds"] as! [[String: Any]]
        
        // Verify no anti-dpi-dialer outbound
        XCTAssertNil(cdnOutbounds.first(where: { ($0["tag"] as? String) == "anti-dpi-dialer" }))
        
        // Verify proxy outbound has no dialerProxy and no fragment
        let cdnProxy = cdnOutbounds[0]
        XCTAssertNil(cdnProxy["fragment"])
        let cdnStream = cdnProxy["streamSettings"] as! [String: Any]
        let cdnSockopt = cdnStream["sockopt"] as? [String: Any]
        XCTAssertNil(cdnSockopt?["dialerProxy"])
        
        if XrayBinaryManager.locateBinary() != nil {
            let res = try XrayProcessManager.shared.testConfiguration(server: server, routing: .defaultConfiguration, settings: settings)
            XCTAssertTrue(res.isValid, "Xray validation must succeed for CDN with fragment/noise enabled in settings: \(res.output)")
        }
        
        // 2. WebRTC Camouflage Profile: must ignore fragment and noise completely
        settings.stealthProfile = .webrtcCamouflage
        settings.webrtcSni = "webrtc.zoom.us"
        
        let webrtcJson = try XrayConfigGenerator.generateConfig(server: server, routing: .defaultConfiguration, settings: settings)
        let webrtcDict = try JSONSerialization.jsonObject(with: webrtcJson.data(using: .utf8)!) as! [String: Any]
        let webrtcOutbounds = webrtcDict["outbounds"] as! [[String: Any]]
        
        // Verify no anti-dpi-dialer outbound
        XCTAssertNil(webrtcOutbounds.first(where: { ($0["tag"] as? String) == "anti-dpi-dialer" }))
        
        // Verify proxy outbound has no dialerProxy and no fragment
        let webrtcProxy = webrtcOutbounds[0]
        XCTAssertNil(webrtcProxy["fragment"])
        let webrtcStream = webrtcProxy["streamSettings"] as! [String: Any]
        let webrtcSockopt = webrtcStream["sockopt"] as? [String: Any]
        XCTAssertNil(webrtcSockopt?["dialerProxy"])
        
        if XrayBinaryManager.locateBinary() != nil {
            let res = try XrayProcessManager.shared.testConfiguration(server: server, routing: .defaultConfiguration, settings: settings)
            XCTAssertTrue(res.isValid, "Xray validation must succeed for WebRTC with fragment/noise enabled in settings: \(res.output)")
        }
    }
    
    // MARK: - Advanced Anti-DPI & Stealth Tests
    
    func testQUICMasqueradeStrategyAndValidation() throws {
        let server = ServerProfile(
            name: "H3 QUIC Node",
            address: "quic.example.com",
            port: 443,
            protocolType: .vless,
            vlessDetails: VLESSDetails(
                uuid: "a28b0561-269e-4e4b-97e3-059c1c4f5f5e",
                flow: "xtls-rprx-vision",
                security: "tls",
                serverName: "quic.example.com"
            )
        )
        
        var settings = AppSettings.standard
        settings.stealthProfile = .quicMasquerade
        // Fragment/noise enabled in settings must be strictly stripped for QUIC Masquerade
        settings.fragmentEnabled = true
        settings.noiseEnabled = true
        
        let configJson = try XrayConfigGenerator.generateConfig(server: server, routing: .defaultConfiguration, settings: settings)
        let dict = try JSONSerialization.jsonObject(with: configJson.data(using: .utf8)!) as! [String: Any]
        let outbounds = dict["outbounds"] as! [[String: Any]]
        
        let proxyOutbound = outbounds[0]
        XCTAssertEqual(proxyOutbound["tag"] as? String, "proxy")
        XCTAssertEqual(proxyOutbound["protocol"] as? String, "vless")
        
        // Assert fragment is stripped
        XCTAssertNil(proxyOutbound["fragment"])
        
        // Assert flow is stripped from users
        let settingsObj = proxyOutbound["settings"] as! [String: Any]
        let vnext = settingsObj["vnext"] as! [[String: Any]]
        let users = vnext[0]["users"] as! [[String: Any]]
        XCTAssertNil(users[0]["flow"], "Flow must be stripped for XHTTP H3 transport")
        
        // Assert streamSettings network is xhttp and mode is stream-one (H3)
        let streamSettings = proxyOutbound["streamSettings"] as! [String: Any]
        XCTAssertEqual(streamSettings["network"] as? String, "xhttp")
        XCTAssertEqual(streamSettings["security"] as? String, "tls")
        
        let xhttpSettings = streamSettings["xhttpSettings"] as! [String: Any]
        XCTAssertEqual(xhttpSettings["mode"] as? String, "stream-one")
        
        // Validate with official Xray binary
        if XrayBinaryManager.locateBinary() != nil {
            let res = try XrayProcessManager.shared.testConfiguration(server: server, routing: .defaultConfiguration, settings: settings)
            XCTAssertTrue(res.isValid, "QUIC Masquerade config must pass official Xray validation: \(res.output)")
        }
    }
    
    func testProxyChainOutboundsWiringAndValidation() throws {
        let mainServer = ServerProfile(
            name: "Target Reality Server",
            address: "1.2.3.4",
            port: 443,
            protocolType: .vless,
            vlessDetails: VLESSDetails(
                uuid: "a28b0561-269e-4e4b-97e3-059c1c4f5f5e",
                security: "reality",
                serverName: "target.com",
                publicKey: "oI7CDmF6T6g15MMInNEtC3TyoLc2PZ8EUc2R9lYOlEE",
                shortId: "6ba7b810",
                fingerprint: "chrome"
            )
        )
        
        let relayServer = ServerProfile(
            name: "Relay Node",
            address: "5.6.7.8",
            port: 443,
            protocolType: .vless,
            vlessDetails: VLESSDetails(
                uuid: "b39c1672-370f-5f5c-a8f4-160d2d5f6f6f",
                security: "reality",
                serverName: "relay.com",
                publicKey: "oI7CDmF6T6g15MMInNEtC3TyoLc2PZ8EUc2R9lYOlEE",
                shortId: "abcd1234",
                fingerprint: "chrome"
            )
        )
        
        var settings = AppSettings.standard
        settings.proxyChainEnabled = true
        settings.proxyChainRelayId = relayServer.id
        
        let configJson = try XrayConfigGenerator.generateConfig(
            server: mainServer,
            routing: .defaultConfiguration,
            settings: settings,
            servers: [mainServer, relayServer]
        )
        
        let dict = try JSONSerialization.jsonObject(with: configJson.data(using: .utf8)!) as! [String: Any]
        let outbounds = dict["outbounds"] as! [[String: Any]]
        
        // Assert proxy outbound is chained to relay-outbound
        let proxyOutbound = outbounds[0]
        let streamSettings = proxyOutbound["streamSettings"] as! [String: Any]
        let sockopt = streamSettings["sockopt"] as! [String: Any]
        XCTAssertEqual(sockopt["dialerProxy"] as? String, "relay-outbound")
        
        // Assert relay outbound is present at index 1
        let relayOutbound = outbounds[1]
        XCTAssertEqual(relayOutbound["tag"] as? String, "relay-outbound")
        
        // Validate with official Xray binary
        if XrayBinaryManager.locateBinary() != nil {
            let res = try XrayProcessManager.shared.testConfiguration(
                server: mainServer,
                routing: .defaultConfiguration,
                settings: settings,
                servers: [mainServer, relayServer]
            )
            XCTAssertTrue(res.isValid, "Proxy chain config must pass official Xray validation: \(res.output)")
        }
    }
    
    func testStreamingMimicryHeadersInjection() throws {
        let server = ServerProfile(
            name: "Mimicry Server",
            address: "stream.example.com",
            port: 443,
            protocolType: .vless,
            vlessDetails: VLESSDetails(
                uuid: "a28b0561-269e-4e4b-97e3-059c1c4f5f5e",
                security: "tls",
                serverName: "stream.example.com"
            )
        )
        
        var settings = AppSettings.standard
        settings.stealthProfile = .quicMasquerade
        settings.streamingMimicryEnabled = true
        settings.streamingMimicryCdn = "video.cloudflare.com"
        
        let configJson = try XrayConfigGenerator.generateConfig(server: server, routing: .defaultConfiguration, settings: settings)
        let dict = try JSONSerialization.jsonObject(with: configJson.data(using: .utf8)!) as! [String: Any]
        let outbounds = dict["outbounds"] as! [[String: Any]]
        
        let streamSettings = outbounds[0]["streamSettings"] as! [String: Any]
        let xhttpSettings = streamSettings["xhttpSettings"] as! [String: Any]
        let headers = xhttpSettings["headers"] as! [String: String]
        
        XCTAssertTrue(headers["User-Agent"]?.contains("AppleCoreMedia") == true)
        XCTAssertEqual(xhttpSettings["host"] as? String, "video.cloudflare.com")
        XCTAssertNil(headers["Host"], "Host must not be inside headers map for XHTTP")
        XCTAssertTrue(headers["Accept"]?.contains("video/mp2t") == true)
        
        if XrayBinaryManager.locateBinary() != nil {
            let res = try XrayProcessManager.shared.testConfiguration(server: server, routing: .defaultConfiguration, settings: settings)
            XCTAssertTrue(res.isValid, "Streaming mimicry config must pass official Xray validation: \(res.output)")
        }
    }
    
    func testTemporalTrafficShapingNoiseInjection() throws {
        let server = ServerProfile(
            name: "Temporal Server",
            address: "temporal.example.com",
            port: 443,
            protocolType: .vless,
            vlessDetails: VLESSDetails(
                uuid: "a28b0561-269e-4e4b-97e3-059c1c4f5f5e",
                security: "tls",
                serverName: "temporal.example.com"
            )
        )
        
        for intensity in TemporalShapingIntensity.allCases {
            var settings = AppSettings.standard
            settings.stealthProfile = .quicMasquerade
            settings.temporalShapingEnabled = true
            settings.temporalShapingIntensity = intensity
            
            let configJson = try XrayConfigGenerator.generateConfig(server: server, routing: .defaultConfiguration, settings: settings)
            let dict = try JSONSerialization.jsonObject(with: configJson.data(using: .utf8)!) as! [String: Any]
            let outbounds = dict["outbounds"] as! [[String: Any]]
            
            // Check temporal shaping dialer exists
            let dialer = outbounds.first(where: { ($0["tag"] as? String) == "temporal-shaping-dialer" })
            XCTAssertNotNil(dialer, "temporal-shaping-dialer must be present for \(intensity)")
            
            let settingsObj = dialer?["settings"] as! [String: Any]
            let noises = settingsObj["noises"] as! [[String: Any]]
            XCTAssertEqual(noises[0]["delay"] as? String, intensity.noiseParameters.delay)
            XCTAssertEqual(noises[0]["packet"] as? String, intensity.noiseParameters.packet)
            
            // Check proxy is wired to dialerProxy
            let stream = outbounds[0]["streamSettings"] as! [String: Any]
            let sockopt = stream["sockopt"] as! [String: Any]
            XCTAssertEqual(sockopt["dialerProxy"] as? String, "temporal-shaping-dialer")
            
            if XrayBinaryManager.locateBinary() != nil {
                let res = try XrayProcessManager.shared.testConfiguration(server: server, routing: .defaultConfiguration, settings: settings)
                XCTAssertTrue(res.isValid, "Temporal shaping (\(intensity)) must pass official Xray validation: \(res.output)")
            }
        }
    }
}

