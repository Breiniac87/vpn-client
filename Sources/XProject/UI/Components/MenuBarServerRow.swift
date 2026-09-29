import SwiftUI

// MARK: - Shared Clean Server Row Component (Used in Popover & Main Window)
public struct MenuBarServerRow: View {
    public let server: ServerProfile
    public let isSelected: Bool
    public let isConnected: Bool
    public let onSelect: () -> Void
    public var onDoubleClick: (() -> Void)?
    public var onPing: (() -> Void)?
    public var onEdit: (() -> Void)?
    public var onDelete: (() -> Void)?
    
    @State private var isHovered = false
    
    public init(
        server: ServerProfile,
        isSelected: Bool,
        isConnected: Bool,
        onSelect: @escaping () -> Void,
        onDoubleClick: (() -> Void)? = nil,
        onPing: (() -> Void)? = nil,
        onEdit: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil
    ) {
        self.server = server
        self.isSelected = isSelected
        self.isConnected = isConnected
        self.onSelect = onSelect
        self.onDoubleClick = onDoubleClick
        self.onPing = onPing
        self.onEdit = onEdit
        self.onDelete = onDelete
    }
    
    public var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                // Radio/Check indicator (Yellow if connected, Cyan if selected, subtle ring if not)
                ZStack {
                    Circle()
                        .strokeBorder(
                            isSelected
                                ? (isConnected ? ModernMacTheme.neonYellow : ModernMacTheme.cyanAccent)
                                : Color.white.opacity(0.25),
                            lineWidth: 1.5
                        )
                        .frame(width: 14, height: 14)
                    
                    if isSelected {
                        Circle()
                            .fill(isConnected ? ModernMacTheme.neonYellow : ModernMacTheme.cyanAccent)
                            .frame(width: 8, height: 8)
                            .shadow(
                                color: isConnected
                                    ? ModernMacTheme.neonYellow.opacity(0.8)
                                    : ModernMacTheme.cyanAccent.opacity(0.8),
                                radius: 3
                            )
                    }
                }
                
                // Country flag emoji
                Text(server.flagEmoji)
                    .font(.system(size: 14))
                
                // Server name & protocol badge
                VStack(alignment: .leading, spacing: 2) {
                    Text(server.cleanDisplayName)
                        .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                        .foregroundStyle(isSelected ? .white : .white.opacity(0.85))
                        .lineLimit(1)
                    
                    HStack(spacing: 4) {
                        Text(server.protocolType.rawValue)
                            .font(.system(size: 8, weight: .heavy))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color(hex: server.protocolType.badgeColorHex).opacity(0.25))
                            )
                            .foregroundStyle(Color(hex: server.protocolType.badgeColorHex))
                        
                        Text(verbatim: "\(server.address):\(server.port)")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.5))
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // Ping latency pill
                if let ping = server.pingMs {
                    Text("\(ping) ms")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(pingColor(for: ping))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(pingColor(for: ping).opacity(0.15))
                        )
                } else {
                    Text("-- ms")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        isSelected
                            ? (isConnected ? ModernMacTheme.neonYellow.opacity(0.15) : ModernMacTheme.cyanAccent.opacity(0.15))
                            : (isHovered ? Color.white.opacity(0.08) : Color.white.opacity(0.03))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(
                                isSelected
                                    ? (isConnected ? ModernMacTheme.neonYellow.opacity(0.6) : ModernMacTheme.cyanAccent.opacity(0.6))
                                    : (isHovered ? Color.white.opacity(0.15) : Color.clear),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { h in isHovered = h }
        .simultaneousGesture(
            TapGesture(count: 2).onEnded {
                onDoubleClick?()
            }
        )
        .contextMenu {
            Button(action: onSelect) {
                Label("Выбрать сервер", systemImage: "checkmark.circle")
            }
            if let onDoubleClick = onDoubleClick {
                Button(action: onDoubleClick) {
                    Label("Подключиться", systemImage: "power")
                }
            }
            if let onPing = onPing {
                Button(action: onPing) {
                    Label("Проверить задержку", systemImage: "bolt")
                }
            }
            Button(action: {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString("\(server.address):\(server.port)", forType: .string)
            }) {
                Label("Скопировать адрес", systemImage: "doc.on.doc")
            }
            if let onEdit = onEdit {
                Button(action: onEdit) {
                    Label("Редактировать...", systemImage: "pencil")
                }
            }
            if let onDelete = onDelete {
                Divider()
                Button(role: .destructive, action: onDelete) {
                    Label("Удалить сервер", systemImage: "trash")
                }
            }
        }
    }
    
    private func pingColor(for ms: Int) -> Color {
        if ms < 150 { return ModernMacTheme.neonGreen }
        if ms < 300 { return Color.orange }
        return Color.red
    }
}
