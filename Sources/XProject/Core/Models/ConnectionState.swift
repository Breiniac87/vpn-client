import Foundation
import SwiftUI

public enum ConnectionStatus: Equatable, Sendable {
    case disconnected
    case connecting
    case connected
    case disconnecting
    case error(String)
    
    public var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
    
    public var isBusy: Bool {
        switch self {
        case .connecting, .disconnecting:
            return true
        default:
            return false
        }
    }
    
    public var localizedDescription: String {
        switch self {
        case .disconnected:
            return "Отключено"
        case .connecting:
            return "Подключение..."
        case .connected:
            return "Подключено"
        case .disconnecting:
            return "Отключение..."
        case .error(let msg):
            return "Ошибка: \(msg)"
        }
    }
    
    public var statusColor: Color {
        switch self {
        case .disconnected:
            return Color.secondary
        case .connecting:
            return Color.orange
        case .connected:
            return Color(hex: "FFE600") // Brand Neon Yellow / Gold
        case .disconnecting:
            return Color.orange
        case .error:
            return Color.red
        }
    }
}
