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
}
