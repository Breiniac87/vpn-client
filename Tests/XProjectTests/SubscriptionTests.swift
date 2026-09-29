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
    
    func testExpirationDateParsingSecondsAndMilliseconds() {
        // Standard Unix seconds: 1792940424 -> 2026-10-25 15:00:24 UTC
        let dateSec = SubscriptionManager.parseExpirationDate("1792940424")
        XCTAssertNotNil(dateSec)
        XCTAssertEqual(Int(dateSec!.timeIntervalSince1970), 1792940424)
        
        // Milliseconds (13 digits): 1792940424000
        let dateMs = SubscriptionManager.parseExpirationDate("1792940424000")
        XCTAssertNotNil(dateMs)
        XCTAssertEqual(Int(dateMs!.timeIntervalSince1970), 1792940424)
    }
    
    func testExpirationDateParsingFormats() {
        // ISO8601
        let isoDate = SubscriptionManager.parseExpirationDate("2026-10-25T15:00:24Z")
        XCTAssertNotNil(isoDate)
        
        // dd.MM.yyyy
        let d1 = SubscriptionManager.parseExpirationDate("25.10.2026")
        XCTAssertNotNil(d1)
        
        // dd-MM-yyyy
        let d2 = SubscriptionManager.parseExpirationDate("25-10-2026")
        XCTAssertNotNil(d2)
    }
    
    func testExtractDateFromTextRemark() {
        let remark1 = "🇬🇧⛓️3X-GB-6 | ⌛25-09-2026"
        let d1 = SubscriptionManager.extractDateFromText(remark1)
        XCTAssertNotNil(d1)
        
        let cal = Calendar.current
        let comp = cal.dateComponents([.year, .month, .day], from: d1!)
        XCTAssertEqual(comp.year, 2026)
        XCTAssertEqual(comp.month, 9)
        XCTAssertEqual(comp.day, 25)
    }
    
    func testCleanDisplayNameStripsTrailingDateTag() {
        let server = ServerProfile(
            name: "🇬🇧⛓️3X-GB-6 | ⌛25-09-2026",
            address: "46.149.68.147",
            port: 8448,
            protocolType: .vless
        )
        XCTAssertEqual(server.cleanDisplayName, "3X-GB-6")
        
        let serverDot = ServerProfile(
            name: "🇪🇪3X-EE-1 | 25.10.2026",
            address: "46.149.68.147",
            port: 9447,
            protocolType: .vless
        )
        XCTAssertEqual(serverDot.cleanDisplayName, "3X-EE-1")
    }
    
    func testSubscriptionDaysRemainingAndFormattedString() {
        let now = Date()
        let calendar = Calendar.current
        
        // 30 days in future
        let futureDate = calendar.date(byAdding: .day, value: 30, to: now)!
        let subFuture = Subscription(
            name: "Test Sub",
            urlString: "https://example.com/sub",
            expireDate: futureDate
        )
        XCTAssertEqual(subFuture.daysRemaining, 30)
        XCTAssertFalse(subFuture.isExpired)
        XCTAssertTrue(subFuture.formattedExpireDate.contains("30 дн."))
        
        // Expired yesterday
        let pastDate = calendar.date(byAdding: .day, value: -1, to: now)!
        let subPast = Subscription(
            name: "Expired Sub",
            urlString: "https://example.com/sub",
            expireDate: pastDate
        )
        XCTAssertTrue(subPast.isExpired)
        XCTAssertTrue(subPast.formattedExpireDate.hasPrefix("Истекла:"))
    }
    
    func testUrlNormalizationAndEquivalence() {
        let u1 = "https://3dh.pro/vpn/9/Router/eac6adc7c167f1bc"
        let u2 = "https://3dh.pro/vpn/9/Router/eac6adc7c167f1bc/"
        let u3 = "HTTPS://3DH.PRO/vpn/9/Router/eac6adc7c167f1bc#Router"
        let u4 = "https://3dh.pro/vpn/9/Router/eac6adc7c167f1bc?t=1790349875"
        
        let norm1 = Subscription.normalizeUrl(u1)
        let norm2 = Subscription.normalizeUrl(u2)
        let norm3 = Subscription.normalizeUrl(u3)
        let norm4 = Subscription.normalizeUrl(u4)
        
        XCTAssertEqual(norm1, "https://3dh.pro/vpn/9/Router/eac6adc7c167f1bc")
        XCTAssertEqual(norm1, norm2)
        XCTAssertEqual(norm1, norm3)
        XCTAssertEqual(norm1, norm4)
        
        let sub = Subscription(name: "Router. 🔑ПИН: s64s", urlString: u1)
        XCTAssertTrue(sub.isSameSubscription(as: u2))
        XCTAssertTrue(sub.isSameSubscription(as: u3))
        XCTAssertTrue(sub.isSameSubscription(as: u4))
        // Domain mirror test (3dh.pro vs 3dh.live with same path token)
        XCTAssertTrue(sub.isSameSubscription(as: "https://3dh.live/vpn/9/Router/eac6adc7c167f1bc"))
    }
    
    @MainActor
    func testUpsertSubscriptionPreventsDuplicates() {
        let appState = AppState()
        appState.subscriptions = []
        appState.servers = []
        let subId1 = UUID()
        let server1 = ServerProfile(name: "Node 1", address: "1.1.1.1", port: 443, protocolType: .vless)
        
        // 1. Initial insert
        appState.upsertSubscription(
            id: subId1,
            name: "My Provider",
            urlString: "https://provider.com/sub",
            servers: [server1]
        )
        XCTAssertEqual(appState.subscriptions.count, 1)
        XCTAssertEqual(appState.servers.count, 1)
        
        // 2. Second insert with slight URL variance (trailing slash + fragment) and different UUID
        let subId2 = UUID()
        let server2 = ServerProfile(name: "Node 1 Updated", address: "1.1.1.1", port: 443, protocolType: .vless)
        appState.upsertSubscription(
            id: subId2,
            name: "My Provider",
            urlString: "https://provider.com/sub/#fragment",
            servers: [server2]
        )
        
        // Must NOT create a second subscription!
        XCTAssertEqual(appState.subscriptions.count, 1, "Duplicate subscription must not be added to subscriptions list")
        XCTAssertEqual(appState.servers.count, 1, "Duplicate servers must be updated in-place")
        XCTAssertEqual(appState.servers.first?.name, "Node 1 Updated")
    }
    
    @MainActor
    func testDeduplicateAllMergesExistingDuplicates() {
        let appState = AppState()
        let id1 = UUID()
        let id2 = UUID()
        
        let sub1 = Subscription(id: id1, name: "Sub A", urlString: "https://example.com/api/token")
        let sub2 = Subscription(id: id2, name: "Sub A", urlString: "https://example.com/api/token/")
        appState.subscriptions = [sub1, sub2]
        
        var s1 = ServerProfile(name: "Server A", address: "10.0.0.1", port: 443, protocolType: .vless)
        s1.subscriptionId = id1
        var s2 = ServerProfile(name: "Server A", address: "10.0.0.1", port: 443, protocolType: .vless)
        s2.subscriptionId = id2
        appState.servers = [s1, s2]
        
        XCTAssertEqual(appState.subscriptions.count, 2)
        XCTAssertEqual(appState.servers.count, 2)
        
        appState.deduplicateAll()
        
        XCTAssertEqual(appState.subscriptions.count, 1)
        XCTAssertEqual(appState.servers.count, 1)
        XCTAssertEqual(appState.servers.first?.subscriptionId, appState.subscriptions.first?.id)
    }
}
