import XCTest
@testable import XProject

final class ParserTests: XCTestCase {
    
    // MARK: - VLESS Reality Testing
    func testVlessRealityParsing() throws {
        let vlessUrl = "vless://a28b0561-269e-4e4b-97e3-059c1c4f5f5e@nl-ams.fastnode.org:443?security=reality&sni=speedtest.net&pbk=j2y-jQZ3hP4x5F6L8a9b0c1d2e3f4g5h6i7j8k9l0m=&sid=6ba7b810&fp=chrome&type=tcp&flow=xtls-rprx-vision#Netherlands%20Reality%20VIP"
        
        let profile = try URLSchemeParser.parseSingleLink(vlessUrl)
        
        XCTAssertEqual(profile.protocolType, .vless)
        XCTAssertEqual(profile.name, "Netherlands Reality VIP")
        XCTAssertEqual(profile.address, "nl-ams.fastnode.org")
        XCTAssertEqual(profile.port, 443)
        
        let details = try XCTUnwrap(profile.vlessDetails)
        XCTAssertEqual(details.uuid, "a28b0561-269e-4e4b-97e3-059c1c4f5f5e")
        XCTAssertEqual(details.security, "reality")
        XCTAssertEqual(details.serverName, "speedtest.net")
        XCTAssertEqual(details.publicKey, "j2y-jQZ3hP4x5F6L8a9b0c1d2e3f4g5h6i7j8k9l0m=")
        XCTAssertEqual(details.shortId, "6ba7b810")
        XCTAssertEqual(details.fingerprint, "chrome")
        XCTAssertEqual(details.flow, "xtls-rprx-vision")
        XCTAssertEqual(details.transportType, "tcp")
    }
    
    // MARK: - Trojan TLS Testing
    func testTrojanParsing() throws {
        let trojanUrl = "trojan://secretpassword123@de-fra.trojan-node.io:8443?security=tls&sni=my-cdn.com&type=tcp#Germany%20Trojan"
        
        let profile = try URLSchemeParser.parseSingleLink(trojanUrl)
        
        XCTAssertEqual(profile.protocolType, .trojan)
        XCTAssertEqual(profile.name, "Germany Trojan")
        XCTAssertEqual(profile.address, "de-fra.trojan-node.io")
        XCTAssertEqual(profile.port, 8443)
        
        let details = try XCTUnwrap(profile.trojanDetails)
        XCTAssertEqual(details.password, "secretpassword123")
        XCTAssertEqual(details.serverName, "my-cdn.com")
        XCTAssertEqual(details.security, "tls")
    }
    
    // MARK: - Shadowsocks SIP002 Testing
    func testShadowsocksSIP002Parsing() throws {
        // "aes-256-gcm:my-secure-password" in base64 is "YWVzLTI1Ni1nY206bXktc2VjdXJlLXBhc3N3b3Jk"
        let ssUrl = "ss://YWVzLTI1Ni1nY206bXktc2VjdXJlLXBhc3N3b3Jk@jp-tyo.shadowsocks.org:8388#Japan%20Tokyo%20SS"
        
        let profile = try URLSchemeParser.parseSingleLink(ssUrl)
        
        XCTAssertEqual(profile.protocolType, .shadowsocks)
        XCTAssertEqual(profile.name, "Japan Tokyo SS")
        XCTAssertEqual(profile.address, "jp-tyo.shadowsocks.org")
        XCTAssertEqual(profile.port, 8388)
        
        let details = try XCTUnwrap(profile.shadowsocksDetails)
        XCTAssertEqual(details.method, "aes-256-gcm")
        XCTAssertEqual(details.password, "my-secure-password")
    }
    
    // MARK: - JSON Config Parsing
    func testJsonConfigParsing() throws {
        let jsonString = """
        {
            "tag": "Custom Server Node",
            "outbounds": [
                {
                    "protocol": "vless",
                    "settings": {
                        "vnext": [
                            {
                                "address": "custom.node.io",
                                "port": 443
                            }
                        ]
                    }
                }
            ]
        }
        """
        
        let profile = try URLSchemeParser.parseRawJson(jsonString)
        XCTAssertEqual(profile.name, "Custom Server Node")
        XCTAssertEqual(profile.address, "custom.node.io")
        XCTAssertEqual(profile.port, 443)
        XCTAssertEqual(profile.protocolType, .vless)
    }
    
    // MARK: - Multi-Link Parsing
    func testMultiLinkParsing() {
        let text = """
        vless://uuid1@host1.com:443?security=none#Node1
        trojan://pass2@host2.com:443#Node2
        invalid-link-line
        ss://YWVzLTEyOC1nY206cGFzc3dvcmQ=@host3.com:8388#Node3
        """
        
        let profiles = URLSchemeParser.parseMultipleLinks(text)
        XCTAssertEqual(profiles.count, 3)
        XCTAssertEqual(profiles[0].name, "Node1")
        XCTAssertEqual(profiles[1].name, "Node2")
        XCTAssertEqual(profiles[2].name, "Node3")
    }
}
