import Foundation

public final class SystemProxyManager: @unchecked Sendable {
    public static let shared = SystemProxyManager()
    
    private var modifiedServices: Set<String> = []
    private let lock = NSLock()
    
    private init() {}
    
    /// Returns a list of active network services (e.g. ["Wi-Fi", "Ethernet"])
    public func getActiveNetworkServices() -> [String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
        process.arguments = ["-listallnetworkservices"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return [] }
            
            let ignoredKeywords = ["happ", "v2raytun", "wireguard", "tailscale", "openvpn", "cisco", "forticlient", "globalprotect"]
            return output.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { line in
                    guard !line.isEmpty,
                          !line.contains("An asterisk (*) denotes"),
                          !line.hasPrefix("*") else { return false }
                    let lower = line.lowercased()
                    return !ignoredKeywords.contains(where: { lower.contains($0) })
                }
        } catch {
            return []
        }
    }
    
    /// Enables SOCKS5 and HTTP/HTTPS proxies on all active network services
    public func enableProxy(httpPort: Int, socksPort: Int) {
        lock.lock()
        defer { lock.unlock() }
        
        let services = getActiveNetworkServices()
        for service in services {
            // Set SOCKS proxy
            runNetworkSetup(arguments: ["-setsocksfirewallproxy", service, "127.0.0.1", String(socksPort)])
            runNetworkSetup(arguments: ["-setsocksfirewallproxystate", service, "on"])
            
            // Set HTTP Web Proxy
            runNetworkSetup(arguments: ["-setwebproxy", service, "127.0.0.1", String(httpPort)])
            runNetworkSetup(arguments: ["-setwebproxystate", service, "on"])
            
            // Set HTTPS Secure Web Proxy
            runNetworkSetup(arguments: ["-setsecurewebproxy", service, "127.0.0.1", String(httpPort)])
            runNetworkSetup(arguments: ["-setsecurewebproxystate", service, "on"])
            
            modifiedServices.insert(service)
        }
    }
    
    /// Disables all proxies previously set by this manager
    public func disableProxy() {
        lock.lock()
        defer { lock.unlock() }
        
        let servicesToDisable = modifiedServices.isEmpty ? getActiveNetworkServices() : Array(modifiedServices)
        for service in servicesToDisable {
            runNetworkSetup(arguments: ["-setsocksfirewallproxystate", service, "off"])
            runNetworkSetup(arguments: ["-setwebproxystate", service, "off"])
            runNetworkSetup(arguments: ["-setsecurewebproxystate", service, "off"])
        }
        modifiedServices.removeAll()
    }
    
    /// Cleans up any dangling proxies pointing to 127.0.0.1 from a previous crashed session
    public func cleanupDanglingProxies() {
        let services = getActiveNetworkServices()
        for service in services {
            if isProxyEnabledForLocalhost(service: service, type: "-getsocksfirewallproxy") {
                runNetworkSetup(arguments: ["-setsocksfirewallproxystate", service, "off"])
            }
            if isProxyEnabledForLocalhost(service: service, type: "-getwebproxy") {
                runNetworkSetup(arguments: ["-setwebproxystate", service, "off"])
            }
            if isProxyEnabledForLocalhost(service: service, type: "-getsecurewebproxy") {
                runNetworkSetup(arguments: ["-setsecurewebproxystate", service, "off"])
            }
        }
    }
    
    private func isProxyEnabledForLocalhost(service: String, type: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
        process.arguments = [type, service]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return false }
            
            let isEnabled = output.contains("Enabled: Yes")
            let isLocalhost = output.contains("127.0.0.1") || output.contains("localhost")
            return isEnabled && isLocalhost
        } catch {
            return false
        }
    }
    
    @discardableResult
    private func runNetworkSetup(arguments: [String]) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
        process.arguments = arguments
        
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}
