import Foundation
import AppKit
import CoreImage
import Vision
import ScreenCaptureKit

public enum QRScanError: LocalizedError {
    case captureFailed
    case qrNotFound
    case unsupportedContent(String)
    
    public var errorDescription: String? {
        switch self {
        case .captureFailed:
            return "Не удалось сделать снимок экрана. Проверьте разрешения в Настройки -> Конфиденциальность -> Запись экрана."
        case .qrNotFound:
            return "На экране не обнаружено QR-кодов. Убедитесь, что QR-код виден на одном из ваших мониторов."
        case .unsupportedContent(let str):
            return "QR-код распознан, но не содержит поддерживаемую ссылку: \(str)"
        }
    }
}

public struct ScreenQRScanner {
    /// Checks if screen capture permission is granted by macOS
    public static func hasScreenCapturePermission() -> Bool {
        if #available(macOS 14.0, *) {
            return CGPreflightScreenCaptureAccess()
        }
        return true
    }
    
    /// Requests screen capture permission prompt from macOS
    public static func requestScreenCapturePermission() {
        if #available(macOS 14.0, *) {
            CGRequestScreenCaptureAccess()
        }
    }

    /// Captures active display using ScreenCaptureKit (macOS 14+) with CoreGraphics fallback
    public static func scanScreen() async throws -> String {
        if !hasScreenCapturePermission() {
            requestScreenCapturePermission()
            throw QRScanError.captureFailed
        }
        
        // 1. Try modern ScreenCaptureKit on macOS 14+
        if #available(macOS 14.0, *) {
            if let image = try? await captureViaScreenCaptureKit() {
                if let result = detectQRCode(in: image) {
                    return result
                }
            }
        }
        
        // 2. Fallback to CoreGraphics active display capture
        if let cgImage = captureActiveScreenCG() {
            if let result = detectQRCode(in: cgImage) {
                return result
            }
        }
        
        throw QRScanError.qrNotFound
    }
    
    /// Synchronous variant for legacy callers
    public static func scanScreenSync() throws -> String {
        if !hasScreenCapturePermission() {
            requestScreenCapturePermission()
            throw QRScanError.captureFailed
        }
        
        guard let cgImage = captureActiveScreenCG() else {
            throw QRScanError.captureFailed
        }
        
        if let result = detectQRCode(in: cgImage) {
            return result
        }
        
        throw QRScanError.qrNotFound
    }
    
    @available(macOS 14.0, *)
    private static func captureViaScreenCaptureKit() async throws -> CGImage? {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first else { return nil }
        
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.width = display.width
        config.height = display.height
        config.showsCursor = false
        
        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
    }
    
    /// Captures display using non-deprecated CoreGraphics display APIs
    private static func captureActiveScreenCG() -> CGImage? {
        let mainDisplayID = CGMainDisplayID()
        if let image = CGDisplayCreateImage(mainDisplayID) {
            return image
        }
        
        var displayCount: UInt32 = 0
        var activeDisplays = [CGDirectDisplayID](repeating: 0, count: 8)
        if CGGetActiveDisplayList(8, &activeDisplays, &displayCount) == .success, displayCount > 0 {
            for i in 0..<Int(displayCount) {
                if let img = CGDisplayCreateImage(activeDisplays[i]) {
                    return img
                }
            }
        }
        return nil
    }
    
    /// Detects QR code in any given CGImage (used by screen capture and unit tests)
    public static func detectQRCode(in cgImage: CGImage) -> String? {
        if let visionResult = detectWithVision(cgImage: cgImage) {
            return visionResult
        }
        return detectWithCIDetector(cgImage: cgImage)
    }
    
    private static func detectWithVision(cgImage: CGImage) -> String? {
        var detectedString: String?
        let request = VNDetectBarcodesRequest { req, _ in
            guard let results = req.results as? [VNBarcodeObservation] else { return }
            for obs in results {
                if obs.symbology == .qr, let payload = obs.payloadStringValue {
                    detectedString = payload
                    break
                }
            }
        }
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
        return detectedString
    }
    
    private static func detectWithCIDetector(cgImage: CGImage) -> String? {
        let ciImage = CIImage(cgImage: cgImage)
        let detector = CIDetector(
            ofType: CIDetectorTypeQRCode,
            context: nil,
            options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]
        )
        let features = detector?.features(in: ciImage) as? [CIQRCodeFeature] ?? []
        return features.first?.messageString
    }
}
