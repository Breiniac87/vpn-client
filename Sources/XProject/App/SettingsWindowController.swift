import SwiftUI
import AppKit

public final class SettingsWindowController: NSWindowController {
    public static let shared = SettingsWindowController()
    
    private var appState: AppState?
    
    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 780, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Настройки — X-project"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.backgroundColor = NSColor(red: 11/255.0, green: 14/255.0, blue: 36/255.0, alpha: 1.0)
        window.minSize = NSSize(width: 740, height: 560)
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.setFrameAutosaveName("XProjectSettingsWindow")
        
        super.init(window: window)
        window.delegate = self
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func show(appState: AppState, initialTab: SettingsTab = .routing) {
        self.appState = appState
        
        let contentView = SettingsContainerView(
            appState: appState,
            initialTab: initialTab,
            onClose: { [weak self] in
                self?.window?.close()
            }
        )
        
        window?.contentView = NSHostingView(rootView: contentView)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

extension SettingsWindowController: NSWindowDelegate {
    public func windowWillClose(_ notification: Notification) {
        window?.contentView = nil
    }
}
