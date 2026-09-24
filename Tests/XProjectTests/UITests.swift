import XCTest
import SwiftUI
@testable import XProject

final class UITests: XCTestCase {
    
    func testConnectionStatusProperties() {
        let disconnected = ConnectionStatus.disconnected
        XCTAssertFalse(disconnected.isConnected)
        XCTAssertFalse(disconnected.isBusy)
        XCTAssertEqual(disconnected.localizedDescription, "Отключено")
        
        let connecting = ConnectionStatus.connecting
        XCTAssertFalse(connecting.isConnected)
        XCTAssertTrue(connecting.isBusy)
        XCTAssertEqual(connecting.localizedDescription, "Подключение...")
        
        let connected = ConnectionStatus.connected
        XCTAssertTrue(connected.isConnected)
        XCTAssertFalse(connected.isBusy)
        XCTAssertEqual(connected.localizedDescription, "Подключено")
        
        let disconnecting = ConnectionStatus.disconnecting
        XCTAssertFalse(disconnecting.isConnected)
        XCTAssertTrue(disconnecting.isBusy)
        XCTAssertEqual(disconnecting.localizedDescription, "Отключение...")
    }
    
    func testServerProtocolBadges() {
        XCTAssertEqual(ServerProtocol.vless.badgeColorHex, "#00D2FF")
        XCTAssertEqual(ServerProtocol.trojan.badgeColorHex, "#FF007A")
        XCTAssertEqual(ServerProtocol.shadowsocks.badgeColorHex, "#FFAA00")
        XCTAssertEqual(ServerProtocol.customJson.badgeColorHex, "#A855F7")
    }
    
    func testSparklineGeometryNormalization() {
        let shapeEmpty = SparklineShape(dataPoints: [], isClosed: false)
        let pathEmpty = shapeEmpty.path(in: CGRect(x: 0, y: 0, width: 100, height: 40))
        XCTAssertTrue(pathEmpty.isEmpty)
        
        let shapeData = SparklineShape(dataPoints: [0.1, 0.4, 0.8, 0.5, 0.9], isClosed: true)
        let pathData = shapeData.path(in: CGRect(x: 0, y: 0, width: 200, height: 40))
        XCTAssertFalse(pathData.isEmpty)
    }
    
    @MainActor
    func testDynamicIconChangeOnStatusTransition() {
        let appState = AppState()
        let coordinator = MenuBarCoordinator(appState: appState)
        
        var receivedStatus: ConnectionStatus?
        appState.onStatusChange = { status in
            receivedStatus = status
            coordinator.updateIcon()
        }
        
        appState.connectionStatus = .connecting
        XCTAssertEqual(receivedStatus, .connecting)
        
        appState.connectionStatus = .connected
        XCTAssertEqual(receivedStatus, .connected)
        
        appState.connectionStatus = .disconnected
        XCTAssertEqual(receivedStatus, .disconnected)
    }
}
