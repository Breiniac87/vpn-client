import XCTest
import CoreImage
@testable import XProject

final class QRScannerTests: XCTestCase {
    
    func testQRCodeGenerationAndDetectionRoundtrip() throws {
        let testVlessUrl = "vless://b73b2241-1111-2222-3333-444455556666@de.vpnnode.net:443?security=reality&sni=cloudflare.com&pbk=AbCdEfGhIjKlMnOpQrStUvWxYz0123456789=&sid=abcdef01&fp=safari&type=tcp#German%20Screen%20QR"
        
        // 1. Generate QR Code image in memory
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else {
            XCTFail("CIQRCodeGenerator unavailable")
            return
        }
        
        let data = testVlessUrl.data(using: .utf8)
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        
        guard let ciImage = filter.outputImage else {
            XCTFail("Failed to generate CIImage QR code")
            return
        }
        
        // Scale up QR code so detectors easily recognize it
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledCIImage = ciImage.transformed(by: transform)
        
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaledCIImage, from: scaledCIImage.extent) else {
            XCTFail("Failed to render CGImage from CIImage")
            return
        }
        
        // 2. Detect with ScreenQRScanner detection engine
        let detected = ScreenQRScanner.detectQRCode(in: cgImage)
        XCTAssertNotNil(detected, "QR Code detection should succeed on valid QR image")
        XCTAssertEqual(detected, testVlessUrl)
        
        // 3. Parse decoded payload
        let profile = try URLSchemeParser.parseSingleLink(detected!)
        XCTAssertEqual(profile.protocolType, .vless)
        XCTAssertEqual(profile.name, "German Screen QR")
        XCTAssertEqual(profile.address, "de.vpnnode.net")
        XCTAssertEqual(profile.vlessDetails?.security, "reality")
        XCTAssertEqual(profile.vlessDetails?.serverName, "cloudflare.com")
    }
}
