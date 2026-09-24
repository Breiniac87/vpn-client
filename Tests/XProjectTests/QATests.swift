import XCTest
@testable import XProject

final class QATests: XCTestCase {
    
    // MARK: - QA Scenario 1: IPv6 and Complex Host Formats
    func testIPv6ShadowsocksParsing() throws {
        // "aes-128-gcm:password" in base64 is "YWVzLTEyOC1nY206cGFzc3dvcmQ="
        let ipv6Link = "ss://YWVzLTEyOC1nY206cGFzc3dvcmQ=@[2001:db8::1]:8388#IPv6%20Node"
        let profile = try ShadowsocksParser.parse(urlString: ipv6Link)
        
        XCTAssertEqual(profile.address, "2001:db8::1")
        XCTAssertEqual(profile.port, 8388)
        XCTAssertEqual(profile.name, "IPv6 Node")
    }
    
    // MARK: - QA Scenario 2: Multi-line and Wrapped Base64 Subscriptions
    func testBase64WithMIMELineBreaks() {
        let rawLinks = "vless://uuid@node.com:443#N1\r\nvless://uuid@node.com:443#N2"
        let base64 = rawLinks.data(using: .utf8)!.base64EncodedString()
        
        // Inject spaces, newlines, tabs
        let wrapped = "  " + base64.prefix(10) + "\r\n  " + base64.dropFirst(10) + "\n\t  "
        
        let decoded = ShadowsocksParser.decodeBase64Safe(wrapped)
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded, rawLinks)
    }
    
    // MARK: - QA Scenario 3: Port Boundary Validation
    func testPortBoundaries() {
        let invalidPortHigh = "vless://uuid@host.com:70000#BadPort"
        XCTAssertThrowsError(try VLESSParser.parse(urlString: invalidPortHigh))
        
        let invalidPortNegative = "vless://uuid@host.com:-1#BadPort"
        XCTAssertThrowsError(try VLESSParser.parse(urlString: invalidPortNegative))
    }
    
    // MARK: - QA Scenario 4: Adversarial and Fuzzed Inputs
    func testAdversarialMalformedLinks() {
        let testCases = [
            "",
            "   ",
            "http://not-a-vpn.com",
            "vless://",
            "vless://@:443",
            "trojan://",
            "ss://invalid-base64-content!@#$%",
            "vless://uuid-without-host:443",
            "{\nincomplete json"
        ]
        
        for input in testCases {
            XCTAssertThrowsError(try URLSchemeParser.parseSingleLink(input), "Input '\(input)' should fail gracefully without crashing")
        }
    }
    
    // MARK: - QA Scenario 5: Atomic Persistence Round-trip
    @MainActor
    func testAtomicPersistenceResilience() {
        let appState = AppState()
        let testId = UUID()
        let testProfile = ServerProfile(
            id: testId,
            name: "QA Stress Server",
            address: "qa.test.net",
            port: 443,
            protocolType: .vless,
            pingMs: 12
        )
        
        appState.addServer(testProfile)
        appState.saveServers()
        
        // Re-read directly from disk
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let fileUrl = support.appendingPathComponent("XProject/servers.json")
        let data = try? Data(contentsOf: fileUrl)
        XCTAssertNotNil(data)
        
        let decoded = try? JSONDecoder().decode([ServerProfile].self, from: data!)
        XCTAssertNotNil(decoded)
        XCTAssertTrue(decoded?.contains(where: { $0.id == testId }) == true)
        
        // Clean up test profile
        appState.deleteServer(id: testId)
    }
}
