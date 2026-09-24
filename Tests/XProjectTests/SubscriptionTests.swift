import XCTest
@testable import XProject

final class SubscriptionTests: XCTestCase {
    
    func testBase64SubscriptionDecoding() {
        let line1 = "vless://11111111-2222-3333-4444-555555555555@sub1.node.com:443?security=none#Sub%20Node%201"
        let line2 = "trojan://password123@sub2.node.com:443#Sub%20Node%202"
        let combined = "\(line1)\n\(line2)"
        
        let base64Data = combined.data(using: .utf8)!.base64EncodedString()
        
        // Test safe decode
        let decoded = ShadowsocksParser.decodeBase64Safe(base64Data)
        XCTAssertEqual(decoded, combined)
        
        let parsedServers = URLSchemeParser.parseMultipleLinks(decoded!)
        XCTAssertEqual(parsedServers.count, 2)
        XCTAssertEqual(parsedServers[0].name, "Sub Node 1")
        XCTAssertEqual(parsedServers[0].protocolType, .vless)
        XCTAssertEqual(parsedServers[1].name, "Sub Node 2")
        XCTAssertEqual(parsedServers[1].protocolType, .trojan)
    }
    
    func testUrlSafeBase64WithoutPadding() {
        let text = "vless://a-b-c@safe.node.com:443#Safe%20Node"
        // Base64 with potential padding stripped
        var base64 = text.data(using: .utf8)!.base64EncodedString()
        while base64.hasSuffix("=") {
            base64.removeLast()
        }
        
        let decoded = ShadowsocksParser.decodeBase64Safe(base64)
        XCTAssertEqual(decoded, text)
    }
    
    @MainActor
    func testSubscriptionServerReplacementInAppState() {
        let appState = AppState()
        let subId = UUID()
        
        let initialManualServer = ServerProfile(
            name: "My Custom Server",
            address: "manual.node.com",
            port: 443,
            protocolType: .vless
        )
        appState.servers = [initialManualServer]
        
        // Add subscription servers
        var subServer1 = ServerProfile(
            name: "Sub Node A",
            address: "sub-a.node.com",
            port: 443,
            protocolType: .vless
        )
        subServer1.subscriptionId = subId
        appState.servers.append(subServer1)
        
        XCTAssertEqual(appState.servers.count, 2)
        
        // Simulate update of subscription: new list fetched
        let newFetchedServers = [
            ServerProfile(name: "Sub Node B", address: "sub-b.node.com", port: 443, protocolType: .trojan, subscriptionId: subId),
            ServerProfile(name: "Sub Node C", address: "sub-c.node.com", port: 443, protocolType: .shadowsocks, subscriptionId: subId)
        ]
        
        // Remove old subscription servers, keep manual
        appState.servers.removeAll(where: { $0.subscriptionId == subId })
        appState.servers.append(contentsOf: newFetchedServers)
        
        XCTAssertEqual(appState.servers.count, 3)
        XCTAssertTrue(appState.servers.contains(where: { $0.name == "My Custom Server" }))
        XCTAssertTrue(appState.servers.contains(where: { $0.name == "Sub Node B" }))
        XCTAssertTrue(appState.servers.contains(where: { $0.name == "Sub Node C" }))
        XCTAssertFalse(appState.servers.contains(where: { $0.name == "Sub Node A" }))
    }
}
