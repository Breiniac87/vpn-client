import XCTest
@testable import XProject

final class StorageTests: XCTestCase {
    
    func testServerProfileSerialization() throws {
        let original = ServerProfile(
            name: "Test Reality Node",
            address: "1.2.3.4",
            port: 443,
            protocolType: .vless,
            vlessDetails: VLESSDetails(
                uuid: UUID().uuidString,
                flow: "xtls-rprx-vision",
                security: "reality",
                serverName: "test.com",
                publicKey: "sample-pubkey",
                shortId: "sample-sid",
                fingerprint: "chrome"
            ),
            pingMs: 45
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(original)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ServerProfile.self, from: data)
        
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.address, original.address)
        XCTAssertEqual(decoded.port, original.port)
        XCTAssertEqual(decoded.protocolType, .vless)
        XCTAssertEqual(decoded.vlessDetails?.security, "reality")
        XCTAssertEqual(decoded.vlessDetails?.flow, "xtls-rprx-vision")
        XCTAssertEqual(decoded.pingMs, 45)
    }
    
    func testRoutingConfigSerialization() throws {
        let config = RoutingConfig.defaultConfiguration
        
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(RoutingConfig.self, from: data)
        
        XCTAssertEqual(decoded.mode, config.mode)
        XCTAssertEqual(decoded.proxyRules.count, config.proxyRules.count)
        XCTAssertEqual(decoded.directRules.count, config.directRules.count)
    }
    
    func testAppSettingsBackwardCompatibility() throws {
        let legacyJson = """
        {
          "trafficMode": "tun",
          "routingMode": "rule_based",
          "socksPort": 10808,
          "httpPort": 10809,
          "dnsServer": "https://1.1.1.1/dns-query",
          "autoConnectOnLaunch": true,
          "autoUpdateSubscriptions": false,
          "lastSelectedServerId": "A28B0561-269E-4E4B-97E3-059C1C4F5F5E",
          "lastSelectedServerName": "Legacy Node",
          "lastSelectedServerKey": "legacy-key"
        }
        """
        
        let data = legacyJson.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)
        
        // Assert legacy fields preserved
        XCTAssertEqual(decoded.trafficMode, .tun)
        XCTAssertEqual(decoded.routingMode, .ruleBased)
        XCTAssertEqual(decoded.socksPort, 10808)
        XCTAssertEqual(decoded.httpPort, 10809)
        XCTAssertEqual(decoded.dnsServer, "https://1.1.1.1/dns-query")
        XCTAssertEqual(decoded.autoConnectOnLaunch, true)
        XCTAssertEqual(decoded.autoUpdateSubscriptions, false)
        XCTAssertEqual(decoded.lastSelectedServerId, UUID(uuidString: "A28B0561-269E-4E4B-97E3-059C1C4F5F5E"))
        XCTAssertEqual(decoded.lastSelectedServerName, "Legacy Node")
        XCTAssertEqual(decoded.lastSelectedServerKey, "legacy-key")
        
        // Assert defaults for newly introduced v2.0 fields
        XCTAssertFalse(decoded.launchAtLogin)
        XCTAssertFalse(decoded.allowLanConnections)
        XCTAssertFalse(decoded.fragmentEnabled)
        XCTAssertEqual(decoded.fragmentPackets, "tlshello")
        XCTAssertEqual(decoded.fragmentLength, "100-200")
        XCTAssertEqual(decoded.fragmentInterval, "10-20")
        XCTAssertFalse(decoded.noiseEnabled)
        XCTAssertEqual(decoded.noiseType, "rand")
        XCTAssertEqual(decoded.noisePacket, "50-100")
        XCTAssertEqual(decoded.noiseDelay, "10-20")
        
        // Assert defaults for Connection Guard & Advanced Anti-DPI
        XCTAssertTrue(decoded.autoReconnectEnabled)
        XCTAssertEqual(decoded.maxReconnectAttempts, 5)
        XCTAssertTrue(decoded.autoFallbackEnabled)
        XCTAssertEqual(decoded.fallbackFailThreshold, 2)
        XCTAssertFalse(decoded.killSwitchEnabled)
        XCTAssertFalse(decoded.proxyChainEnabled)
        XCTAssertNil(decoded.proxyChainRelayId)
        XCTAssertFalse(decoded.streamingMimicryEnabled)
        XCTAssertEqual(decoded.streamingMimicryCdn, "video.cloudflare.com")
        XCTAssertFalse(decoded.temporalShapingEnabled)
        XCTAssertEqual(decoded.temporalShapingIntensity, .dynamic)
        
        // Roundtrip serialization
        var modified = decoded
        modified.fragmentEnabled = true
        modified.noiseEnabled = true
        let encoded = try JSONEncoder().encode(modified)
        let roundtrip = try JSONDecoder().decode(AppSettings.self, from: encoded)
        XCTAssertEqual(roundtrip, modified)
    }
    
    // MARK: - Stress Testing: Stealth Profiles & AppSettingsStorage
    
    func testStealthProfilesStorageStressAndParity() throws {
        // Backup original state in UserDefaults
        let origProfile = UserDefaults.standard.string(forKey: "stealthProfile")
        let origMicro = UserDefaults.standard.object(forKey: "enableMicroSessions")
        let origPortHop = UserDefaults.standard.object(forKey: "enablePortHopping")
        let origHost = UserDefaults.standard.string(forKey: "cdnHost")
        let origPath = UserDefaults.standard.string(forKey: "cdnPath")
        let origSni = UserDefaults.standard.string(forKey: "webrtcSni")
        
        defer {
            UserDefaults.standard.set(origProfile, forKey: "stealthProfile")
            UserDefaults.standard.set(origMicro, forKey: "enableMicroSessions")
            UserDefaults.standard.set(origPortHop, forKey: "enablePortHopping")
            UserDefaults.standard.set(origHost, forKey: "cdnHost")
            UserDefaults.standard.set(origPath, forKey: "cdnPath")
            UserDefaults.standard.set(origSni, forKey: "webrtcSni")
            UserDefaults.standard.synchronize()
        }
        
        let storage = AppSettingsStorage.shared
        let profiles = StealthProfile.allCases
        
        for i in 0..<100 {
            let targetProfile = profiles[i % profiles.count]
            let micro = (i % 2 == 0)
            let portHop = (i % 3 == 0)
            let host = "edge-\(i).cdnfront.net"
            let path = "/stream/\(i)"
            let sni = "call-\(i).webrtc.zoom.us"
            
            // 1. Mutate via AppSettings.shared
            AppSettings.shared.stealthProfile = targetProfile
            AppSettings.shared.enableMicroSessions = micro
            AppSettings.shared.enablePortHopping = portHop
            AppSettings.shared.cdnHost = host
            AppSettings.shared.cdnPath = path
            AppSettings.shared.webrtcSni = sni
            
            // 2. Verify UserDefaults synchronization immediately
            XCTAssertEqual(UserDefaults.standard.string(forKey: "stealthProfile"), targetProfile.rawValue)
            XCTAssertEqual(UserDefaults.standard.bool(forKey: "enableMicroSessions"), micro)
            XCTAssertEqual(UserDefaults.standard.bool(forKey: "enablePortHopping"), portHop)
            XCTAssertEqual(UserDefaults.standard.string(forKey: "cdnHost"), host)
            XCTAssertEqual(UserDefaults.standard.string(forKey: "cdnPath"), path)
            XCTAssertEqual(UserDefaults.standard.string(forKey: "webrtcSni"), sni)
            
            // 3. Mutate via AppSettingsStorage
            let nextProfile = profiles[(i + 1) % profiles.count]
            storage.stealthProfile = nextProfile
            XCTAssertEqual(storage.stealthProfile, nextProfile)
            
            // 4. JSON Serialization Stress Roundtrip under churn
            let data = try JSONEncoder().encode(AppSettings.shared)
            let decoded = try JSONDecoder().decode(AppSettings.self, from: data)
            XCTAssertEqual(decoded.stealthProfile, targetProfile)
            XCTAssertEqual(decoded.cdnHost, host)
            XCTAssertEqual(decoded.webrtcSni, sni)
        }
    }
}
