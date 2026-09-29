import Foundation
import ServiceManagement
import os.log

/// Safe wrapper around macOS `SMAppService.mainApp` for managing Launch at Login functionality.
/// Includes graceful fallback and error suppression when running in CLI, unit test, or unpackaged environments.
public enum LaunchAtLoginManager {
    private static let logger = Logger(subsystem: "com.xproject.app", category: "LaunchAtLogin")
    
    /// Detects whether the current process is running inside an application bundle (.app)
    public static var isRunningInAppBundle: Bool {
        guard let bundleId = Bundle.main.bundleIdentifier, !bundleId.isEmpty else {
            return false
        }
        return Bundle.main.bundlePath.hasSuffix(".app")
    }
    
    /// Current registration status with macOS ServiceManagement
    public static var isEnabled: Bool {
        guard isRunningInAppBundle else {
            return false
        }
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }
    
    /// Registers or unregisters the app from macOS Login Items.
    /// In CLI / test environments, this operation safely returns without raising errors.
    public static func setEnabled(_ enabled: Bool) throws {
        guard isRunningInAppBundle else {
            logger.info("SMAppService skipped: running in CLI/test mode outside .app bundle.")
            return
        }
        
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    if SMAppService.mainApp.status != .enabled {
                        try SMAppService.mainApp.register()
                    }
                } else {
                    if SMAppService.mainApp.status == .enabled {
                        try SMAppService.mainApp.unregister()
                    }
                }
            } catch {
                logger.error("Failed to update SMAppService launchAtLogin status: \(error.localizedDescription)")
                throw error
            }
        }
    }
    
    /// Safe non-throwing variant that logs failures without disrupting callers
    @discardableResult
    public static func safeSetEnabled(_ enabled: Bool) -> Bool {
        do {
            try setEnabled(enabled)
            return true
        } catch {
            return false
        }
    }
}
