import Foundation
import Network

public struct LatencyTester {
    
    /// Measures TCP handshake latency to the specified host and port in milliseconds
    public static func measureLatency(host: String, port: Int, timeoutSeconds: Double = 3.0) async -> Int? {
        guard let nwPort = NWEndpoint.Port(rawValue: UInt16(port)) else { return nil }
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: nwPort)
        
        let parameters = NWParameters.tcp
        parameters.prohibitedInterfaceTypes = []
        
        let connection = NWConnection(to: endpoint, using: parameters)
        
        final class ResumeBox: @unchecked Sendable {
            private var hasResumed = false
            private let lock = NSLock()
            func executeOnce(_ action: () -> Void) {
                lock.lock()
                defer { lock.unlock() }
                if !hasResumed {
                    hasResumed = true
                    action()
                }
            }
        }
        
        let box = ResumeBox()
        let startTime = DispatchTime.now()
        
        return await withCheckedContinuation { continuation in
            // Timeout work item
            let timeoutWorkItem = DispatchWorkItem {
                box.executeOnce {
                    connection.cancel()
                    continuation.resume(returning: nil)
                }
            }
            
            DispatchQueue.global().asyncAfter(
                deadline: .now() + timeoutSeconds,
                execute: timeoutWorkItem
            )
            
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    box.executeOnce {
                        timeoutWorkItem.cancel()
                        let elapsed = DispatchTime.now().uptimeNanoseconds - startTime.uptimeNanoseconds
                        let ms = Int(elapsed / 1_000_000)
                        connection.cancel()
                        continuation.resume(returning: ms)
                    }
                case .failed, .cancelled:
                    box.executeOnce {
                        timeoutWorkItem.cancel()
                        connection.cancel()
                        continuation.resume(returning: nil)
                    }
                default:
                    break
                }
            }
            
            connection.start(queue: .global())
        }
    }
    
    /// Measures ping for an array of servers concurrently
    public static func measureBatch(servers: [ServerProfile]) async -> [UUID: Int] {
        await withTaskGroup(of: (UUID, Int?).self) { group in
            for server in servers {
                group.addTask {
                    let ping = await measureLatency(host: server.address, port: server.port)
                    return (server.id, ping)
                }
            }
            
            var results: [UUID: Int] = [:]
            for await (id, ping) in group {
                if let ms = ping {
                    results[id] = ms
                }
            }
            return results
        }
    }
}
