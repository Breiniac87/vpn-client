import SwiftUI
import AppKit

public struct LogsTab: View {
    @Bindable var appState: AppState
    @State private var filterLevel: LogLevel? = nil
    @State private var searchQuery: String = ""
    @State private var autoScroll: Bool = true
    
    public init(appState: AppState) {
        self.appState = appState
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            // MARK: - Filter Toolbar
            HStack(spacing: 10) {
                // Search box
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Поиск по логам...", text: $searchQuery)
                        .textFieldStyle(.plain)
                    if !searchQuery.isEmpty {
                        Button(action: { searchQuery = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(NSColor.controlBackgroundColor))
                )
                
                // Severity filter
                Picker("Уровень", selection: $filterLevel) {
                    Text("Все").tag(LogLevel?.none)
                    ForEach(LogLevel.allCases, id: \.self) { lvl in
                        Text(lvl.rawValue).tag(LogLevel?.some(lvl))
                    }
                }
                .frame(width: 110)
                
                Spacer()
                
                HStack(spacing: 6) {
                    Text("Автоскролл")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                    
                    GoldenToggle(isOn: $autoScroll)
                }
                
                Button(action: copyAllLogs) {
                    Label("Копировать", systemImage: "doc.on.doc")
                }
                .controlSize(.small)
                
                Button(action: { appState.clearLogs() }) {
                    Label("Очистить", systemImage: "trash")
                }
                .controlSize(.small)
            }
            .padding(.horizontal, 4)
            
            // MARK: - Console Terminal Area
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(filteredLogs) { entry in
                            HStack(alignment: .top, spacing: 8) {
                                Text(entry.formattedTime)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                
                                Text("[\(entry.level.rawValue)]")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(entry.level.color)
                                    .frame(width: 48, alignment: .leading)
                                
                                Text(entry.message)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.primary)
                                    .textSelection(.enabled)
                            }
                            .id(entry.id)
                        }
                    }
                    .padding(10)
                }
                .background(Color(NSColor.textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                )
                .onChange(of: appState.logs.count) { _, _ in
                    if autoScroll, let last = filteredLogs.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .padding(20)
    }
    
    private var filteredLogs: [LogEntry] {
        appState.logs.filter { entry in
            if let level = filterLevel, entry.level != level {
                return false
            }
            if !searchQuery.isEmpty && !entry.message.localizedCaseInsensitiveContains(searchQuery) {
                return false
            }
            return true
        }
    }
    
    private func copyAllLogs() {
        let text = filteredLogs.map { "[\($0.formattedTime)] [\($0.level.rawValue)] \($0.message)" }.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
