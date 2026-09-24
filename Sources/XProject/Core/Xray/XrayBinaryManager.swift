import Foundation

public struct XrayBinaryManager {
    /// Returns the path to the executable xray binary
    public static func locateBinary() -> String? {
        // 1. Inside App Bundle Resources (Contents/Resources/xray/xray)
        if let bundleUrl = Bundle.main.resourceURL?.appendingPathComponent("xray/xray"),
           FileManager.default.isExecutableFile(atPath: bundleUrl.path) {
            return bundleUrl.path
        }
        
        let bundleDirect = Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/xray/xray").path
        if FileManager.default.isExecutableFile(atPath: bundleDirect) {
            return bundleDirect
        }
        
        // 2. Local workspace directory for development (bin/xray/xray)
        let cwdPath = FileManager.default.currentDirectoryPath + "/bin/xray/xray"
        if FileManager.default.isExecutableFile(atPath: cwdPath) {
            return cwdPath
        }
        
        // 3. Application Support directory (~/Library/Application Support/XProject/bin/xray)
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let appSupportBin = appSupport.appendingPathComponent("XProject/bin/xray").path
        if FileManager.default.isExecutableFile(atPath: appSupportBin) {
            return appSupportBin
        }
        
        // 4. System Homebrew installations
        let brewPaths = ["/opt/homebrew/bin/xray", "/usr/local/bin/xray", "/usr/bin/xray"]
        for p in brewPaths {
            if FileManager.default.isExecutableFile(atPath: p) {
                return p
            }
        }
        
        return nil
    }
    
    /// Returns the path to the directory containing geoip.dat and geosite.dat
    public static func locateAssetDirectory() -> String? {
        // 1. Dynamic downloaded user assets (~/Library/Application Support/XProject/assets)
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let userAssetsDir = appSupport.appendingPathComponent("XProject/assets").path
        if FileManager.default.fileExists(atPath: userAssetsDir + "/geoip.dat") &&
           FileManager.default.fileExists(atPath: userAssetsDir + "/geosite.dat") {
            return userAssetsDir
        }
        
        // 2. Bundled app resources (Contents/Resources/xray)
        if let binPath = locateBinary() {
            let dir = URL(fileURLWithPath: binPath).deletingLastPathComponent().path
            let geoip = dir + "/geoip.dat"
            if FileManager.default.fileExists(atPath: geoip) {
                return dir
            }
        }
        
        // 3. Workspace development directory
        let cwdDir = FileManager.default.currentDirectoryPath + "/bin/xray"
        if FileManager.default.fileExists(atPath: cwdDir + "/geoip.dat") {
            return cwdDir
        }
        
        return nil
    }
    
    /// Tests if the located binary is working and returns its version string
    public static func checkVersion() -> String? {
        guard let binaryPath = locateBinary() else { return nil }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = ["version"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                return output.components(separatedBy: .newlines).first
            }
        } catch {
            return nil
        }
        
        return nil
    }
}
