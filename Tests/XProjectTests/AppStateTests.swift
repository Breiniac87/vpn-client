import XCTest
@testable import XProject

final class AppStateTests: XCTestCase {
    
    private var origRoutingData: Data?
    private var origSettingsData: Data?
    private var routingUrl: URL?
    private var settingsUrl: URL?
    
    override func setUp() {
        super.setUp()
        if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.appendingPathComponent("XProject") {
            routingUrl = appSupport.appendingPathComponent("routing.json")
            settingsUrl = appSupport.appendingPathComponent("settings.json")
            if let rUrl = routingUrl { origRoutingData = try? Data(contentsOf: rUrl) }
            if let sUrl = settingsUrl { origSettingsData = try? Data(contentsOf: sUrl) }
            
            // Clean state for tests
            if let rUrl = routingUrl { try? FileManager.default.removeItem(at: rUrl) }
            if let sUrl = settingsUrl { try? FileManager.default.removeItem(at: sUrl) }
        }
    }
    
    override func tearDown() {
        if let rUrl = routingUrl, let data = origRoutingData {
            try? data.write(to: rUrl, options: .atomic)
        }
        if let sUrl = settingsUrl, let data = origSettingsData {
            try? data.write(to: sUrl, options: .atomic)
        }
        super.tearDown()
    }
    
    @MainActor
    func testAppStateInitialization() {
        let appState = AppState()
        
        // Check default states
        XCTAssertEqual(appState.connectionStatus, .disconnected)
        XCTAssertEqual(appState.routingConfig.mode, .ruleBased)
        XCTAssertEqual(appState.settings.trafficMode, .tun)
        XCTAssertEqual(appState.settings.socksPort, 10808)
        XCTAssertEqual(appState.settings.httpPort, 10809)
        
        if !appState.servers.isEmpty {
            XCTAssertNotNil(appState.selectedServer)
        } else {
            XCTAssertNil(appState.selectedServer)
        }
    }
    
    @MainActor
    func testServerSelectionAndSwitching() {
        let appState = AppState()
        if appState.servers.count < 2 {
            let s1 = ServerProfile(name: "Test S1", address: "1.1.1.1", port: 443, protocolType: .vless)
            let s2 = ServerProfile(name: "Test S2", address: "1.1.1.2", port: 443, protocolType: .vless)
            appState.servers.append(contentsOf: [s1, s2])
        }
        guard appState.servers.count >= 2 else {
            XCTFail("Expected at least 2 sample servers")
            return
        }
        
        let secondServer = appState.servers[1]
        appState.selectServer(id: secondServer.id)
        
        XCTAssertEqual(appState.selectedServerId, secondServer.id)
        XCTAssertEqual(appState.selectedServer?.id, secondServer.id)
    }
    
    @MainActor
    func testLoggingMechanism() {
        let appState = AppState()
        appState.clearLogs()
        XCTAssertTrue(appState.logs.isEmpty)
        
        appState.appendLog(level: .info, message: "Тестовое сообщение 1")
        appState.appendLog(level: .warning, message: "Предупреждение сети")
        appState.appendLog(level: .error, message: "Ошибка подключения")
        
        let exp = expectation(description: "Logs added on main queue")
        DispatchQueue.main.async {
            XCTAssertEqual(appState.logs.count, 3)
            XCTAssertEqual(appState.logs[0].level, .info)
            XCTAssertEqual(appState.logs[1].level, .warning)
            XCTAssertEqual(appState.logs[2].level, .error)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }
    
    @MainActor
    func testPingTelemetryRecording() {
        let appState = AppState()
        
        // Record multiple pings
        for ping in 10...40 {
            appState.recordPing(ping)
        }
        
        // Verify buffer limit (max 25)
        XCTAssertLessThanOrEqual(appState.pingHistory.count, 25)
        XCTAssertEqual(appState.pingHistory.last, 40)
    }
    
    @MainActor
    func testAutoFallbackPicksLowestPingServer() async {
        let appState = AppState()
        
        let server1 = ServerProfile(name: "Server 1", address: "1.1.1.1", port: 443, protocolType: .vless, pingMs: 150)
        let server2 = ServerProfile(name: "Server 2 (Best)", address: "2.2.2.2", port: 443, protocolType: .vless, pingMs: 35)
        let server3 = ServerProfile(name: "Server 3 (Worst)", address: "3.3.3.3", port: 443, protocolType: .vless, pingMs: 300)
        
        appState.servers = [server1, server2, server3]
        appState.selectedServerId = server1.id
        
        // Trigger auto-fallback
        await appState.triggerAutoFallback()
        
        // Assert it selected server2 with ping 35ms
        XCTAssertEqual(appState.selectedServerId, server2.id)
        XCTAssertEqual(appState.selectedServer?.name, "Server 2 (Best)")
    }
    
    @MainActor
    func testUpdateServerAndManualProfile() {
        let appState = AppState()
        let original = ServerProfile(
            name: "Initial Manual Server",
            address: "192.168.1.100",
            port: 443,
            protocolType: .vless,
            vlessDetails: VLESSDetails(uuid: "11111111-2222-3333-4444-555555555555", security: "reality", serverName: "old.com")
        )
        appState.addServer(original)
        appState.selectServer(id: original.id)
        
        let initialCount = appState.servers.count
        
        // Update server details
        var modified = original
        modified.name = "Updated VLESS Reality NL"
        modified.address = "192.168.1.200"
        modified.port = 8443
        modified.vlessDetails?.serverName = "new.sni.com"
        
        appState.updateServer(modified)
        
        // Verify server count did not grow
        XCTAssertEqual(appState.servers.count, initialCount)
        
        // Verify in-place update
        let fetched = appState.servers.first(where: { $0.id == original.id })
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.name, "Updated VLESS Reality NL")
        XCTAssertEqual(fetched?.address, "192.168.1.200")
        XCTAssertEqual(fetched?.port, 8443)
        XCTAssertEqual(fetched?.vlessDetails?.serverName, "new.sni.com")
        
        // Verify selected server stays valid
        XCTAssertEqual(appState.selectedServer?.id, original.id)
        XCTAssertEqual(appState.selectedServer?.name, "Updated VLESS Reality NL")
    }
    
    func testExitIpInfoModelCreation() {
        let nl = ExitIpInfo(ip: "185.220.101.5", countryCode: "NL")
        XCTAssertEqual(nl.ip, "185.220.101.5")
        XCTAssertEqual(nl.countryCode, "NL")
        XCTAssertEqual(nl.flagEmoji, "🇳🇱")
        XCTAssertFalse(nl.countryName.isEmpty)
        
        let us = ExitIpInfo(ip: "1.1.1.1", countryCode: "us")
        XCTAssertEqual(us.countryCode, "US")
        XCTAssertEqual(us.flagEmoji, "🇺🇸")
        
        // Codable serialization test
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        XCTAssertNoThrow({
            let data = try encoder.encode(nl)
            let decoded = try decoder.decode(ExitIpInfo.self, from: data)
            XCTAssertEqual(decoded, nl)
            XCTAssertEqual(decoded.flagEmoji, "🇳🇱")
        })
    }
    
    @MainActor
    func testAppStateExitIpInfoLifecycle() {
        let appState = AppState()
        XCTAssertNil(appState.exitIpInfo)
        XCTAssertFalse(appState.isCheckingExitIp)
        
        // Simulate setting exitIpInfo while connected
        appState.connectionStatus = .connected
        appState.exitIpInfo = ExitIpInfo(ip: "194.26.29.112", countryCode: "SE")
        appState.isCheckingExitIp = true
        
        XCTAssertNotNil(appState.exitIpInfo)
        XCTAssertEqual(appState.exitIpInfo?.flagEmoji, "🇸🇪")
        
        // Disconnecting must completely purge exitIpInfo and reset checking flag
        appState.disconnect()
        XCTAssertNil(appState.exitIpInfo)
        XCTAssertFalse(appState.isCheckingExitIp)
    }
    
    func testCloudflareTraceParsingLogic() {
        let sampleTrace = """
        fl=71f112
        h=1.1.1.1
        ip=185.220.101.5
        ts=1727623700.123
        visit_scheme=https
        uag=curl/8.7.1
        colo=AMS
        sliver=none
        http=http/2
        loc=NL
        tls=TLSv1.3
        sni=plaintext
        warp=off
        gateway=off
        rbi=off
        kex=X25519
        """
        
        var ipVal: String?
        var locVal: String?
        let lines = sampleTrace.components(separatedBy: "\n")
        for line in lines {
            let parts = line.split(separator: "=", maxSplits: 1).map(String.init)
            if parts.count == 2 {
                let key = parts[0].trimmingCharacters(in: .whitespaces)
                let val = parts[1].trimmingCharacters(in: .whitespaces)
                if key == "ip" { ipVal = val }
                if key == "loc" { locVal = val }
            }
        }
        
        XCTAssertEqual(ipVal, "185.220.101.5")
        XCTAssertEqual(locVal, "NL")
        
        if let ip = ipVal, let loc = locVal {
            let info = ExitIpInfo(ip: ip, countryCode: loc)
            XCTAssertEqual(info.ip, "185.220.101.5")
            XCTAssertEqual(info.countryCode, "NL")
            XCTAssertEqual(info.flagEmoji, "🇳🇱")
        } else {
            XCTFail("Failed to parse trace parameters")
        }
    }
}

