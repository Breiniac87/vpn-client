import XCTest
@testable import XProject

final class NetworkTests: XCTestCase {
    
    func testNetworkServicesDetection() {
        let services = SystemProxyManager.shared.getActiveNetworkServices()
        XCTAssertFalse(services.isEmpty, "macOS system should have at least one active network service (e.g. Wi-Fi or Ethernet)")
        print("ℹ️ Detected network services: \(services)")
    }
    
    func testRealTcpLatencyMeasurement() async {
        // Measure real TCP handshake to Cloudflare DNS port 443
        let ping = await LatencyTester.measureLatency(host: "1.1.1.1", port: 443, timeoutSeconds: 3.0)
        
        if let ms = ping {
            XCTAssertGreaterThan(ms, 0, "Ping latency should be positive milliseconds")
            XCTAssertLessThan(ms, 2000, "Ping latency should be reasonable")
            print("ℹ️ Real measured TCP latency to 1.1.1.1:443 = \(ms) ms")
        } else {
            print("⚠️ Network unreachable or DNS filtered in test environment")
        }
    }
    
    func testTUNManagerToggle() {
        let tun = TUNManager.shared
        XCTAssertFalse(tun.isActive)
        
        tun.startTun(socksPort: 10808) { level, msg in
            print("TUN log [\(level)]: \(msg)")
        }
        XCTAssertTrue(tun.isActive)
        
        tun.stopTun()
        XCTAssertFalse(tun.isActive)
    }
}
