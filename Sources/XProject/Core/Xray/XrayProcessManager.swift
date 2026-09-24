import Foundation

public final class XrayProcessManager: @unchecked Sendable {
    public static let shared = XrayProcessManager()
    
    private var process: Process?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?
    private let lock = NSLock()
    
    private var isIntentionalStop: Bool = false
    
    private init() {}
    
    public var isRunning: Bool {
        lock.lock()
        defer { lock.unlock() }
        return process?.isRunning ?? false
    }
    
    /// Starts the Xray core process with the generated configuration
    public func start(
        server: ServerProfile,
        routing: RoutingConfig,
        settings: AppSettings,
        onLog: @escaping @Sendable (LogLevel, String) -> Void,
        onUnexpectedTermination: (@Sendable (Int32) -> Void)? = nil
    ) throws {
        lock.lock()
        defer { lock.unlock() }
        
        isIntentionalStop = false
        
        // 1. Terminate any previous instance
        if let existing = process, existing.isRunning {
            existing.terminate()
            existing.waitUntilExit()
            self.process = nil
        }
        
        // 2. Locate binary
        guard let binaryPath = XrayBinaryManager.locateBinary() else {
            throw ParserError.missingField("Исполняемый файл xray не найден. Запустите scripts/download_xray.sh или пересоберите приложение.")
        }
        
        // 3. Generate and write config.json
        let configJson = try XrayConfigGenerator.generateConfig(server: server, routing: routing, settings: settings)
        let configURL = getRunDirectory().appendingPathComponent("config.json")
        try configJson.data(using: .utf8)?.write(to: configURL)
        
        // 4. Configure Process
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: binaryPath)
        proc.arguments = ["run", "-c", configURL.path]
        
        // Assets environment (geoip.dat and geosite.dat)
        var env = ProcessInfo.processInfo.environment
        if let assetDir = XrayBinaryManager.locateAssetDirectory() {
            env["XRAY_LOCATION_ASSET"] = assetDir
        }
        proc.environment = env
        
        let outPipe = Pipe()
        let errPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError = errPipe
        
        // Pipe readers
        setupPipeReader(pipe: outPipe, defaultLevel: .info, onLog: onLog)
        setupPipeReader(pipe: errPipe, defaultLevel: .warning, onLog: onLog)
        
        proc.terminationHandler = { [weak self] p in
            onLog(.info, "Процесс Xray-core завершил работу с кодом: \(p.terminationStatus)")
            let wasIntentional = self?.isIntentionalStop ?? false
            if !wasIntentional && p.terminationStatus != 0 {
                onUnexpectedTermination?(p.terminationStatus)
            }
        }
        
        try proc.run()
        self.process = proc
        self.stdoutPipe = outPipe
        self.stderrPipe = errPipe
        
        onLog(.info, "Xray-core успешно запущен (PID: \(proc.processIdentifier))")
    }
    
    /// Stops the running Xray process
    public func stop() {
        lock.lock()
        defer { lock.unlock() }
        
        isIntentionalStop = true
        guard let proc = process, proc.isRunning else { return }
        proc.terminate()
        proc.waitUntilExit()
        self.process = nil
        self.stdoutPipe = nil
        self.stderrPipe = nil
    }
    
    /// Validates the configuration using the real Xray core test argument (`xray -test -c config.json`)
    public func testConfiguration(
        server: ServerProfile,
        routing: RoutingConfig,
        settings: AppSettings
    ) throws -> (isValid: Bool, output: String) {
        guard let binaryPath = XrayBinaryManager.locateBinary() else {
            return (false, "Бинарный файл xray не найден")
        }
        
        let configJson = try XrayConfigGenerator.generateConfig(server: server, routing: routing, settings: settings)
        let testConfigURL = getRunDirectory().appendingPathComponent("test_config.json")
        try configJson.data(using: .utf8)?.write(to: testConfigURL)
        
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: binaryPath)
        proc.arguments = ["-test", "-c", testConfigURL.path]
        
        if let assetDir = XrayBinaryManager.locateAssetDirectory() {
            var env = ProcessInfo.processInfo.environment
            env["XRAY_LOCATION_ASSET"] = assetDir
            proc.environment = env
        }
        
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe
        
        try proc.run()
        proc.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        let isSuccess = (proc.terminationStatus == 0)
        
        return (isSuccess, output.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    
    private func setupPipeReader(
        pipe: Pipe,
        defaultLevel: LogLevel,
        onLog: @escaping @Sendable (LogLevel, String) -> Void
    ) {
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            
            let lines = text.components(separatedBy: .newlines)
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                
                var level = defaultLevel
                if trimmed.localizedCaseInsensitiveContains("error") {
                    level = .error
                } else if trimmed.localizedCaseInsensitiveContains("warning") || trimmed.localizedCaseInsensitiveContains("warn") {
                    level = .warning
                }
                
                onLog(level, trimmed)
            }
        }
    }
    
    private func getRunDirectory() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let runDir = appSupport.appendingPathComponent("XProject/run", isDirectory: true)
        try? FileManager.default.createDirectory(at: runDir, withIntermediateDirectories: true)
        return runDir
    }
}
