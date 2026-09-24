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
}
