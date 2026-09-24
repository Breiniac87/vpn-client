import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    var appState = AppState()
    var menuBarCoordinator: MenuBarCoordinator?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure regular activation policy so the app icon is visible in Dock (not hidden)
        NSApp.setActivationPolicy(.regular)
        
        // Set dynamic Dock icon matching the user-provided brand shield image
        if let iconPath = Bundle.main.path(forResource: "AppIcon", ofType: "png") ?? Bundle.main.path(forResource: "AppIcon", ofType: "icns") ?? (FileManager.default.fileExists(atPath: "Resources/AppIcon.png") ? "Resources/AppIcon.png" : nil),
           let iconImage = NSImage(contentsOfFile: iconPath) {
            NSApp.applicationIconImage = iconImage
        }
        
        // Disable automatic window restoration to avoid restoring stale or duplicate windows
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")
        UserDefaults.standard.removeObject(forKey: "NSWindow Frame com_apple_SwiftUI_Settings_window")
        UserDefaults.standard.removeObject(forKey: "NSWindow Frame XProjectPreferencesWindow")
        
        // Reset any leftover dangling proxy configuration from previous crashes
        SystemProxyManager.shared.cleanupDanglingProxies()
        
        menuBarCoordinator = MenuBarCoordinator(appState: appState)
        
        menuBarCoordinator?.onScanScreenQR = { [weak self] in
            guard let self = self else { return }
            ImportCoordinator.shared.scanScreenQR(into: self.appState)
        }
        menuBarCoordinator?.onImportClipboard = { [weak self] in
            guard let self = self else { return }
            ImportCoordinator.shared.importFromClipboard(into: self.appState)
        }
        menuBarCoordinator?.onImportJsonFile = { [weak self] in
            guard let self = self else { return }
            ImportCoordinator.shared.importJsonFile(into: self.appState)
        }
        
        PreferencesWindowController.shared.show(appState: appState)
        menuBarCoordinator?.updateIcon()
        
        // Ensure only the main window is visible on launch (close any stray SwiftUI-generated Settings windows)
        DispatchQueue.main.async {
            for window in NSApp.windows {
                if window !== PreferencesWindowController.shared.window && window !== SettingsWindowController.shared.window {
                    if window.title.contains("Settings") || window.title.contains("Preferences") || window.frameAutosaveName.contains("Settings") || window.frameAutosaveName.contains("Preferences") {
                        window.orderOut(nil)
                        window.close()
                    }
                }
            }
        }
        
        // Auto-connect tunnel to last selected server on launch if enabled
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.appState.performAutoConnectIfEnabled()
        }
        
        // Auto-update subscriptions if configured, or if any subscription has 0 servers
        if (!appState.subscriptions.isEmpty && appState.settings.autoUpdateSubscriptions) ||
            appState.subscriptions.contains(where: { $0.serverCount == 0 }) {
            Task { [weak self] in
                guard let self = self else { return }
                await SubscriptionManager.shared.updateAllSubscriptions(in: self.appState)
                
                // If autoConnect was waiting for servers, trigger now
                await MainActor.run {
                    if self.appState.settings.autoConnectOnLaunch && self.appState.connectionStatus == .disconnected {
                        self.appState.performAutoConnectIfEnabled()
                    }
                }
            }
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Clicking the Dock icon opens the Preferences window centered
        if !flag {
            PreferencesWindowController.shared.show(appState: appState)
        }
        return true
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return false
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Clean disconnect on quit
        if appState.connectionStatus == .connected {
            appState.disconnect()
        }
    }
}

@main
struct XProjectApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        if CommandLine.arguments.contains("--test") {
            SelfTestRunner.runAllTests()
            exit(0)
        }
        
        if CommandLine.arguments.contains("--test-launch") {
            let state = AppState()
            print("AutoConnect enabled: \(state.settings.autoConnectOnLaunch)")
            print("Selected server ID: \(String(describing: state.selectedServerId))")
            print("Selected server name: \(String(describing: state.selectedServer?.name))")
            print("Connection status before: \(state.connectionStatus)")
            state.performAutoConnectIfEnabled()
            print("Connection status after: \(state.connectionStatus)")
            if state.connectionStatus == .connected {
                state.disconnect()
            }
            exit(0)
        }
        
        if CommandLine.arguments.contains("--update-subscriptions") {
            let state = AppState()
            var done = false
            Task { @MainActor in
                print("Updating all subscriptions...")
                await SubscriptionManager.shared.updateAllSubscriptions(in: state)
                print("Done! Total servers: \(state.servers.count)")
                done = true
            }
            while !done {
                RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.1))
            }
            exit(0)
        }
    }
    
    var body: some Scene {
        // Empty Settings scene as we use custom centered SettingsWindowController
        Settings {
            EmptyView()
                .frame(width: 0, height: 0)
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Настройки...") {
                    SettingsWindowController.shared.show(appState: appDelegate.appState)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            
            CommandMenu("Сервер") {
                Button("Подключить / Отключить") {
                    appDelegate.appState.toggleConnection()
                }
                .keyboardShortcut("k", modifiers: [.command, .shift])
                
                Divider()
                
                ForEach(appDelegate.appState.servers) { server in
                    Button(server.name) {
                        appDelegate.appState.selectServer(id: server.id)
                    }
                }
            }
        }
    }
}
