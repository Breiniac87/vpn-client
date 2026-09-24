import Foundation
import SwiftUI

public enum LogLevel: String, Codable, CaseIterable {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARN"
    case error = "ERROR"
    
    public var color: Color {
        switch self {
        case .debug: return .secondary
        case .info: return Color(red: 0.2, green: 0.7, blue: 1.0)
        case .warning: return .orange
        case .error: return .red
        }
    }
}

public struct LogEntry: Identifiable, Equatable {
    public let id: UUID
    public let timestamp: Date
    public let level: LogLevel
    public let message: String
    
    public init(id: UUID = UUID(), timestamp: Date = Date(), level: LogLevel = .info, message: String) {
        self.id = id
        self.timestamp = timestamp
        self.level = level
        self.message = message
    }
    
    public var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: timestamp)
    }
}
