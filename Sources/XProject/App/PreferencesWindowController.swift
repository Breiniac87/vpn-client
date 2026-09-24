import SwiftUI
import AppKit

public final class PreferencesWindowController: NSWindowController {
    public static let shared = PreferencesWindowController()
    
    private var appState: AppState?
    
    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "X-project"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.backgroundColor = NSColor(red: 8/255.0, green: 11/255.0, blue: 28/255.0, alpha: 1.0)
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.setFrameAutosaveName("XProjectMainWindow")
        
        super.init(window: window)
        window.delegate = self
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func show(
        appState: AppState,
        onScanScreenQR: (() -> Void)? = nil,
        onImportClipboard: (() -> Void)? = nil,
        onImportJsonFile: (() -> Void)? = nil
    ) {
        self.appState = appState
        
        let contentView = MainWindowView(
            appState: appState,
            onScanScreenQR: onScanScreenQR ?? { ImportCoordinator.shared.scanScreenQR(into: appState) },
            onImportClipboard: onImportClipboard ?? { ImportCoordinator.shared.importFromClipboard(into: appState) },
            onImportJsonFile: onImportJsonFile ?? { ImportCoordinator.shared.importJsonFile(into: appState) }
        )
        
        window?.contentView = NSHostingView(rootView: contentView)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

extension PreferencesWindowController: NSWindowDelegate {
    public func windowWillClose(_ notification: Notification) {
        // Полная выгрузка содержимого окна при нажатии на крестик
        window?.contentView = nil
    }
}
