import Foundation

public struct ExitIpInfo: Codable, Equatable, Sendable {
    public let ip: String
    public let countryCode: String
    public let countryName: String
    public let flagEmoji: String
    public let timestamp: Date
    
    public init(ip: String, countryCode: String, timestamp: Date = Date()) {
        self.ip = ip
        let cleanCode = countryCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        self.countryCode = cleanCode
        self.timestamp = timestamp
        
        // Генерация эмодзи флага из 2-символьного кода страны (ISO 3166-1 alpha-2)
        let base: UInt32 = 127397
        var flag = ""
        for scalar in cleanCode.unicodeScalars {
            if let scalarValue = UnicodeScalar(base + scalar.value) {
                flag.unicodeScalars.append(scalarValue)
            }
        }
        self.flagEmoji = flag.isEmpty ? "🌐" : flag
        
        // Локализация названия страны через системную локаль macOS
        let localized = Locale.current.localizedString(forRegionCode: cleanCode)
        self.countryName = localized ?? cleanCode
    }
    
    public init(ip: String, countryCode: String, countryName: String, flagEmoji: String, timestamp: Date = Date()) {
        self.ip = ip
        self.countryCode = countryCode
        self.countryName = countryName
        self.flagEmoji = flagEmoji
        self.timestamp = timestamp
    }
}
