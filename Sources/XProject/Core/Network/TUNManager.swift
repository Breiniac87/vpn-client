import Foundation
import NetworkExtension

public final class TUNManager: @unchecked Sendable {
    public static let shared = TUNManager()
    
    private var isTunActive: Bool = false
    private let lock = NSLock()
    
    private init() {}
    
    public var isActive: Bool {
        lock.lock()
        defer { lock.unlock() }
        return isTunActive
    }
    
    /// Activates the virtual network routing via System Proxy
    public func startTun(
        httpPort: Int = 10809,
        socksPort: Int = 10808,
        onLog: @escaping @Sendable (LogLevel, String) -> Void
    ) {
        lock.lock()
        defer { lock.unlock() }
        
        onLog(.info, "Активация сетевого перехвата трафика macOS (SOCKS5:\(socksPort), HTTP:\(httpPort))...")
        SystemProxyManager.shared.enableProxy(httpPort: httpPort, socksPort: socksPort)
        self.isTunActive = true
        onLog(.info, "Сетевой трафик macOS успешно перенаправлен в туннель через системный стек.")
    }
    
    /// Stops the TUN interface and resets proxies
    public func stopTun() {
        lock.lock()
        defer { lock.unlock() }
        
        guard isTunActive else { return }
        SystemProxyManager.shared.disableProxy()
        self.isTunActive = false
    }
}
