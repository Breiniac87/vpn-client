import XCTest
@testable import XProject

final class AppStateTests: XCTestCase {
    
    @MainActor
    func testAppStateInitialization() {
        let appState = AppState()
        
        // Check default states
        XCTAssertEqual(appState.connectionStatus, .disconnected)
        XCTAssertFalse(appState.servers.isEmpty, "Default sample servers should be seeded on empty state")
        XCTAssertNotNil(appState.selectedServer)
        XCTAssertEqual(appState.routingConfig.mode, .ruleBased)
        XCTAssertEqual(appState.settings.trafficMode, .tun)
        XCTAssertEqual(appState.settings.socksPort, 10808)
        XCTAssertEqual(appState.settings.httpPort, 10809)
    }
    
    @MainActor
    func testServerSelectionAndSwitching() {
        let appState = AppState()
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
}
