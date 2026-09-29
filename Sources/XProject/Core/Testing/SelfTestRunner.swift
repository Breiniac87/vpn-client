import Foundation
import CoreImage

public struct SelfTestRunner {
    public static func runAllTests() {
        print("\n=======================================================")
        print("🚀 Запуск встроенного набора тестов X-project (Self-Test)")
        print("=======================================================")
        
        var passed = 0
        var failed = 0
        
        func test(_ name: String, block: () throws -> Void) {
            do {
                try block()
                print("  ✔ \(name)")
                passed += 1
            } catch {
                print("  ❌ \(name): \(error.localizedDescription)")
                failed += 1
            }
        }
        
        // MARK: - 1. Parsers
        print("\n[1/5] Тестирование сетевых парсеров:")
        test("VLESS + XTLS-Reality + Vision") {
            let url = "vless://a28b0561-269e-4e4b-97e3-059c1c4f5f5e@nl-ams.fastnode.org:443?security=reality&sni=speedtest.net&pbk=oI7CDmF6T6g15MMInNEtC3TyoLc2PZ8EUc2R9lYOlEE&sid=6ba7b810&fp=chrome&type=tcp&flow=xtls-rprx-vision#Netherlands%20Reality"
            let profile = try URLSchemeParser.parseSingleLink(url)
            assert(profile.protocolType == .vless)
            assert(profile.vlessDetails?.security == "reality")
            assert(profile.vlessDetails?.flow == "xtls-rprx-vision")
            assert(profile.vlessDetails?.publicKey == "oI7CDmF6T6g15MMInNEtC3TyoLc2PZ8EUc2R9lYOlEE")
        }
        
        test("Trojan TLS") {
            let url = "trojan://password123@de-fra.trojan.net:8443?security=tls&sni=my-cdn.com#Germany%20Trojan"
            let profile = try URLSchemeParser.parseSingleLink(url)
            assert(profile.protocolType == .trojan)
            assert(profile.trojanDetails?.password == "password123")
            assert(profile.trojanDetails?.serverName == "my-cdn.com")
        }
        
        test("Shadowsocks SIP002") {
            let url = "ss://YWVzLTI1Ni1nY206bXktc2VjdXJlLXBhc3N3b3Jk@jp-tyo.ss.org:8388#Japan%20SS"
            let profile = try URLSchemeParser.parseSingleLink(url)
            assert(profile.protocolType == .shadowsocks)
            assert(profile.shadowsocksDetails?.method == "aes-256-gcm")
            assert(profile.shadowsocksDetails?.password == "my-secure-password")
        }
        
        test("QA: Парсинг IPv6 хостов (Shadowsocks & VLESS)") {
            let ipv6Link = "ss://YWVzLTEyOC1nY206cGFzc3dvcmQ=@[2001:db8::1]:8388#IPv6%20Node"
            let profile = try ShadowsocksParser.parse(urlString: ipv6Link)
            assert(profile.address == "2001:db8::1")
            assert(profile.port == 8388)
        }
        
        test("QA: Устойчивость Base64 подписок к переносам строк MIME (\\r\\n)") {
            let raw = "vless://u@n.com:443#N1\r\nvless://u@n.com:443#N2"
            let b64 = raw.data(using: .utf8)!.base64EncodedString()
            let wrapped = "  " + b64.prefix(10) + "\r\n  " + b64.dropFirst(10) + "\n\t  "
            let decoded = ShadowsocksParser.decodeBase64Safe(wrapped)
            assert(decoded == raw)
        }
        
        test("QA: Отсев некорректных и мусорных ссылок без крашей") {
            let invalid = ["", "   ", "not-a-vpn", "vless://", "trojan://", "ss://!!!"]
            for str in invalid {
                var didThrow = false
                do {
                    _ = try URLSchemeParser.parseSingleLink(str)
                } catch {
                    didThrow = true
                }
                assert(didThrow, "Строка '\(str)' должна вызывать ошибку парсинга")
            }
        }
        
        test("QA: Авто-детекция Base64 экспорта и JSON конфигураций") {
            // Test Base64 list
            let link1 = "vless://a28b0561-269e-4e4b-97e3-059c1c4f5f5e@s1.com:443#Server1"
            let link2 = "trojan://pass@s2.com:443#Server2"
            let combined = "\(link1)\n\(link2)"
            let b64 = combined.data(using: .utf8)!.base64EncodedString()
            let decoded = ShadowsocksParser.decodeBase64Safe(b64)
            assert(decoded != nil)
            let servers = URLSchemeParser.parseMultipleLinks(decoded!)
            assert(servers.count == 2)
            assert(servers[0].name == "Server1")
            assert(servers[1].name == "Server2")
            
            // Test raw JSON
            let json = """
            { "outbounds": [ { "protocol": "vless", "settings": { "vnext": [ { "address": "test.com", "port": 443 } ] } } ] }
            """
            let jsonServer = try URLSchemeParser.parseRawJson(json)
            assert(jsonServer.protocolType == .vless)
        }
        
        test("QA: Многострочный VLESS с URL-кодированными фрагментами (#%F0%...)") {
            let line1 = "vless://u1@171.22.129.43:8444?security=reality&sni=avito.ru&pbk=key1&fp=qq#%F0%9F%87%B3%F0%9F%87%B1%E2%9B%93%EF%B8%8F3X-NL-34%20%7C%20%E2%8C%9B25-09-2026"
            let line2 = "vless://u2@212.192.14.48:8445?security=reality&sni=avito.ru&pbk=key2&fp=qq#%F0%9F%87%B3%F0%9F%87%B1%E2%9B%93%EF%B8%8F3X-NL-35%20%7C%20%E2%8C%9B25-09-2026"
            let line3 = "vless://u3@46.8.96.102:8443?security=reality&sni=avito.ru&pbk=key3&fp=qq#%F0%9F%87%AB%F0%9F%87%AE%F0%9F%8E%AF1X-FI-15%20%7C%20%E2%8C%9B25-09-2026"
            let multiline = "\(line1)\n\(line2)\n\(line3)"
            let servers = URLSchemeParser.parseContent(multiline)
            assert(servers.count == 3, "Ожидалось 3 сервера, получено \(servers.count)")
            assert(servers[0].flagEmoji == "🇳🇱", "Сервер 1 должен иметь флаг 🇳🇱")
            assert(servers[0].name.contains("3X-NL-34"), "Имя сервера 1 должно содержать 3X-NL-34")
            assert(!servers[0].name.contains("%F0"), "Имя сервера 1 не должно содержать сырой %F0")
            assert(servers[1].flagEmoji == "🇳🇱", "Сервер 2 должен иметь флаг 🇳🇱")
            assert(servers[2].flagEmoji == "🇫🇮", "Сервер 3 должен иметь флаг 🇫🇮")
            assert(servers[2].name.contains("1X-FI-15"), "Имя сервера 3 должно содержать 1X-FI-15")
        }
        
        test("UltimaVPN / Happ JSON-массив подписки (парсинг серверов, флагов и субтитров)") {
            let json = """
            [
              {
                "remarks": "🇱🇻  Латвия",
                "outbounds": [
                  {
                    "tag": "proxy",
                    "protocol": "vless",
                    "settings": {
                      "vnext": [{ "address": "api.flowwow.app", "port": 23357, "users": [{ "id": "91ea447c-2bbb-475e-9cb5-872248b52396" }] }]
                    },
                    "streamSettings": {
                      "network": "grpc",
                      "grpcSettings": { "serviceName": "api" },
                      "security": "reality",
                      "realitySettings": { "serverName": "deepl.com", "publicKey": "WAhW2-p24oIRD6v7XQDVC-LH3t2_oQSnWM8r7QdPKkE", "shortId": "4149657667076e2b", "fingerprint": "firefox" }
                    },
                    "fragment": { "packets": "1-3", "length": "50-100", "interval": "10-20" }
                  }
                ]
              },
              {
                "remarks": "🇸🇪 Швеция",
                "outbounds": [
                  {
                    "tag": "proxy",
                    "protocol": "vless",
                    "settings": {
                      "vnext": [{ "address": "cloud.figmafound.org", "port": 443, "users": [{ "id": "91ea447c-2bbb-475e-9cb5-872248b52396", "flow": "xtls-rprx-vision" }] }]
                    },
                    "streamSettings": {
                      "network": "tcp",
                      "security": "reality",
                      "realitySettings": { "serverName": "cloud.figmafound.org", "publicKey": "H5CXI4RvEWW0TFPvFrnF1iX-05Y57ZYMMngjmkMfv24", "shortId": "711ad7f475c35e5e" }
                    }
                  }
                ]
              },
              {
                "remarks": "🇪🇺 Hysteria",
                "outbounds": [
                  {
                    "tag": "proxy",
                    "protocol": "vless",
                    "settings": {
                      "vnext": [{ "address": "api.allureops.org", "port": 23356, "users": [{ "id": "91ea447c-2bbb-475e-9cb5-872248b52396" }] }]
                    },
                    "streamSettings": {
                      "network": "grpc",
                      "grpcSettings": { "serviceName": "deepl" },
                      "security": "reality",
                      "realitySettings": { "serverName": "deepl.com" }
                    }
                  }
                ]
              }
            ]
            """
            let servers = URLSchemeParser.parseContent(json)
            assert(servers.count == 3, "Должно быть распарсено 3 сервера")
            
            let lv = servers[0]
            assert(lv.flagEmoji == "🇱🇻")
            assert(lv.cleanDisplayName == "Латвия")
            assert(lv.address == "api.flowwow.app")
            assert(lv.port == 23357)
            assert(lv.protocolType == .vless)
            assert(lv.vlessDetails?.transportType == "grpc")
            assert(lv.vlessDetails?.path == "api")
            assert(lv.protocolDetailsSubtitle.contains("GRPC"))
            assert(lv.protocolDetailsSubtitle.contains("Reality"))
            assert(lv.protocolDetailsSubtitle.contains("JSON"))
            assert(lv.rawUri?.hasPrefix("vless://") == true)
            
            let se = servers[1]
            assert(se.flagEmoji == "🇸🇪")
            assert(se.cleanDisplayName == "Швеция")
            assert(se.vlessDetails?.flow == "xtls-rprx-vision")
            
            let eu = servers[2]
            assert(eu.flagEmoji == "🇪🇺")
            assert(eu.cleanDisplayName == "Hysteria")
        }
        
        test("Интеграционный тест: Загрузка живой подписки UltimaVPN через сеть") {
            let sema = DispatchSemaphore(value: 0)
            var fetchError: Error?
            var fetchResult: SubscriptionFetchResult?
            Task {
                do {
                    let res = try await SubscriptionManager.shared.fetchSubscriptionWithUserInfo(
                        from: "https://g.ultm.in/s/3r0SJBJ0K6qH4z7L",
                        subscriptionId: UUID()
                    )
                    fetchResult = res
                } catch {
                    fetchError = error
                }
                sema.signal()
            }
            _ = sema.wait(timeout: .now() + 35.0)
            if let err = fetchError {
                throw err
            }
            guard let res = fetchResult else {
                throw ParserError.malformedUrl("Таймаут получения подписки")
            }
            assert(res.servers.count == 10, "Ожидалось 10 серверов, получено \(res.servers.count)")
            assert(res.profileTitle == "UltimaVPN", "Ожидался заголовок UltimaVPN, получено \(res.profileTitle ?? "nil")")
            assert(res.servers[0].flagEmoji == "🇱🇻", "Ожидался флаг 🇱🇻")
            assert(res.servers[0].cleanDisplayName == "Латвия")
            assert(res.servers[0].protocolDetailsSubtitle.contains("JSON"))
            assert(res.downloadBytes != nil && res.downloadBytes! > 0, "Должна быть квота скачанного трафика")
        }
        
        // MARK: - 2. Screen QR Scanner Round-trip
        print("\n[2/5] Тестирование оптического распознавания QR-кодов:")
        test("Генерация QR в памяти -> Vision/CoreImage детектор -> Парсинг ссылки") {
            let testUrl = "vless://b73b2241-1111-2222-3333-444455556666@de.vpnnode.net:443?security=reality&sni=cloudflare.com&pbk=oI7CDmF6T6g15MMInNEtC3TyoLc2PZ8EUc2R9lYOlEE&sid=abcdef01&fp=safari&type=tcp#German%20Screen%20QR"
            guard let filter = CIFilter(name: "CIQRCodeGenerator") else {
                throw ParserError.missingField("CIQRCodeGenerator unavailable")
            }
            filter.setValue(testUrl.data(using: .utf8), forKey: "inputMessage")
            filter.setValue("M", forKey: "inputCorrectionLevel")
            guard let ciImage = filter.outputImage else {
                throw ParserError.missingField("Failed to generate CIImage")
            }
            let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
            guard let cgImage = CIContext().createCGImage(scaled, from: scaled.extent) else {
                throw ParserError.missingField("Failed to render CGImage")
            }
            guard let detected = ScreenQRScanner.detectQRCode(in: cgImage) else {
                throw ParserError.missingField("QR Code not detected")
            }
            assert(detected == testUrl)
            let profile = try URLSchemeParser.parseSingleLink(detected)
            assert(profile.protocolType == .vless)
            assert(profile.name == "German Screen QR")
        }
        
        // MARK: - 3. Xray-core Binary & Configuration Validation
        print("\n[3/5] Валидация сгенерированного JSON официальным бинарником Xray-core:")
        test("Запуск xray -test -c config.json") {
            guard let binary = XrayBinaryManager.locateBinary() else {
                throw ParserError.missingField("Бинарный файл xray не найден")
            }
            let version = XrayBinaryManager.checkVersion() ?? "unknown"
            print("     (Ядро: \(binary), версия: \(version))")
            
            let sampleServer = ServerProfile(
                name: "Test Node",
                address: "1.2.3.4",
                port: 443,
                protocolType: .vless,
                vlessDetails: VLESSDetails(
                    uuid: "a28b0561-269e-4e4b-97e3-059c1c4f5f5e",
                    flow: "xtls-rprx-vision",
                    security: "reality",
                    serverName: "speedtest.net",
                    publicKey: "oI7CDmF6T6g15MMInNEtC3TyoLc2PZ8EUc2R9lYOlEE",
                    shortId: "6ba7b810"
                )
            )
            
            let result = try XrayProcessManager.shared.testConfiguration(
                server: sampleServer,
                routing: .defaultConfiguration,
                settings: .standard
            )
            assert(result.isValid, "Xray validation failed: \(result.output)")
        }
        
        test("Валидация Xray-core конфигурации с активным FakeDNS (198.18.0.0/15)") {
            var fakeDnsRouting = RoutingConfig.defaultConfiguration
            fakeDnsRouting.fakeDnsEnabled = true
            fakeDnsRouting.domainStrategy = "IPIfNonMatch"
            
            let sampleServer = ServerProfile(
                name: "FakeDNS Test Node",
                address: "1.2.3.4",
                port: 443,
                protocolType: .vless,
                vlessDetails: VLESSDetails(
                    uuid: "a28b0561-269e-4e4b-97e3-059c1c4f5f5e",
                    flow: "xtls-rprx-vision",
                    security: "reality",
                    serverName: "speedtest.net",
                    publicKey: "oI7CDmF6T6g15MMInNEtC3TyoLc2PZ8EUc2R9lYOlEE",
                    shortId: "6ba7b810"
                )
            )
            
            let result = try XrayProcessManager.shared.testConfiguration(
                server: sampleServer,
                routing: fakeDnsRouting,
                settings: .standard
            )
            assert(result.isValid, "FakeDNS validation failed: \(result.output)")
        }
        
        test("Валидация Xray-core на сервере UltimaVPN с настройкой fragment") {
            let json = """
            {
              "remarks": "🇱🇻  Латвия",
              "outbounds": [
                {
                  "tag": "proxy",
                  "protocol": "vless",
                  "settings": {
                    "vnext": [{ "address": "api.flowwow.app", "port": 23357, "users": [{ "id": "91ea447c-2bbb-475e-9cb5-872248b52396" }] }]
                  },
                  "streamSettings": {
                    "network": "grpc",
                    "grpcSettings": { "serviceName": "api" },
                    "security": "reality",
                    "realitySettings": { "serverName": "deepl.com", "publicKey": "WAhW2-p24oIRD6v7XQDVC-LH3t2_oQSnWM8r7QdPKkE", "shortId": "4149657667076e2b", "fingerprint": "firefox" }
                  },
                  "fragment": { "packets": "1-3", "length": "50-100", "interval": "10-20" }
                }
              ]
            }
            """
            let server = try URLSchemeParser.parseRawJson(json)
            let result = try XrayProcessManager.shared.testConfiguration(
                server: server,
                routing: .defaultConfiguration,
                settings: .standard
            )
            assert(result.isValid, "UltimaVPN server Xray validation failed: \(result.output)")
        }
        
        test("Валидация Xray-core с Chained dialerProxy, fragment и noises через xray -test -c") {
            var antiDpiSettings = AppSettings.standard
            antiDpiSettings.fragmentEnabled = true
            antiDpiSettings.fragmentPackets = "1-3"
            antiDpiSettings.fragmentLength = "50-100"
            antiDpiSettings.fragmentInterval = "10-20"
            antiDpiSettings.noiseEnabled = true
            antiDpiSettings.noiseType = "rand"
            antiDpiSettings.noisePacket = "50-100"
            antiDpiSettings.noiseDelay = "10-20"
            
            let sampleServer = ServerProfile(
                name: "Anti-DPI Reality Node",
                address: "1.2.3.4",
                port: 443,
                protocolType: .vless,
                vlessDetails: VLESSDetails(
                    uuid: "a28b0561-269e-4e4b-97e3-059c1c4f5f5e",
                    flow: "xtls-rprx-vision",
                    security: "reality",
                    serverName: "speedtest.net",
                    publicKey: "oI7CDmF6T6g15MMInNEtC3TyoLc2PZ8EUc2R9lYOlEE",
                    shortId: "6ba7b810"
                )
            )
            
            // 1. Проверяем структуру сгенерированного конфигурационного JSON
            let configJson = try XrayConfigGenerator.generateConfig(
                server: sampleServer,
                routing: .defaultConfiguration,
                settings: antiDpiSettings
            )
            guard let jsonData = configJson.data(using: .utf8),
                  let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let outbounds = json["outbounds"] as? [[String: Any]] else {
                throw ParserError.missingField("Не удалось распарсить сгенерированный configJson")
            }
            
            // Проверка привязки sockopt.dialerProxy в основном proxy outbound
            guard let proxyOutbound = outbounds.first(where: { ($0["tag"] as? String) == "proxy" }),
                  let streamSettings = proxyOutbound["streamSettings"] as? [String: Any],
                  let sockopt = streamSettings["sockopt"] as? [String: Any],
                  let dialerProxy = sockopt["dialerProxy"] as? String else {
                throw ParserError.missingField("В outbound proxy отсутствует streamSettings.sockopt.dialerProxy")
            }
            assert(dialerProxy == "anti-dpi-dialer", "dialerProxy должен указывать на 'anti-dpi-dialer'")
            assert(proxyOutbound["fragment"] == nil, "Прямой fragment должен быть удален из proxy для избежания конфликтов")
            
            // Проверка цепочки dialerProxy: наличие вспомогательного outbound freedom
            guard let dialerOutbound = outbounds.first(where: { ($0["tag"] as? String) == "anti-dpi-dialer" }) else {
                throw ParserError.missingField("В outbounds отсутствует исходящий узел 'anti-dpi-dialer'")
            }
            assert((dialerOutbound["protocol"] as? String) == "freedom")
            guard let dialerSettings = dialerOutbound["settings"] as? [String: Any] else {
                throw ParserError.missingField("В anti-dpi-dialer отсутствуют settings")
            }
            
            // Проверка секции fragment внутри dialerProxy
            guard let fragment = dialerSettings["fragment"] as? [String: Any] else {
                throw ParserError.missingField("В anti-dpi-dialer отсутствует секция fragment")
            }
            assert((fragment["packets"] as? String) == "1-3")
            assert((fragment["length"] as? String) == "50-100")
            assert((fragment["interval"] as? String) == "10-20")
            
            // Проверка секции noises внутри dialerProxy
            guard let noises = dialerSettings["noises"] as? [[String: Any]], !noises.isEmpty else {
                throw ParserError.missingField("В anti-dpi-dialer отсутствует секция noises")
            }
            assert((noises[0]["type"] as? String) == "rand")
            assert((noises[0]["packet"] as? String) == "50-100")
            assert((noises[0]["delay"] as? String) == "10-20")
            
            // 2. Валидация официальным бинарным файлом xray через команду xray -test -c
            let result = try XrayProcessManager.shared.testConfiguration(
                server: sampleServer,
                routing: .defaultConfiguration,
                settings: antiDpiSettings
            )
            assert(result.isValid, "Валидация бинарником xray с Chained dialerProxy провалилась: \(result.output)")
        }
        
        test("Валидация inbounds при переключении allowLanConnections (127.0.0.1 vs 0.0.0.0)") {
            var localSettings = AppSettings.standard
            localSettings.allowLanConnections = false
            
            let sampleServer = ServerProfile(
                name: "Test Node",
                address: "1.2.3.4",
                port: 443,
                protocolType: .vless,
                vlessDetails: VLESSDetails(
                    uuid: "a28b0561-269e-4e4b-97e3-059c1c4f5f5e",
                    flow: "xtls-rprx-vision",
                    security: "reality",
                    serverName: "speedtest.net",
                    publicKey: "oI7CDmF6T6g15MMInNEtC3TyoLc2PZ8EUc2R9lYOlEE",
                    shortId: "6ba7b810"
                )
            )
            
            let localJson = try XrayConfigGenerator.generateConfig(server: sampleServer, routing: .defaultConfiguration, settings: localSettings)
            guard let localData = localJson.data(using: .utf8),
                  let localDict = try JSONSerialization.jsonObject(with: localData) as? [String: Any],
                  let localInbounds = localDict["inbounds"] as? [[String: Any]] else {
                throw ParserError.missingField("Не удалось распарсить inbounds для localSettings")
            }
            for inb in localInbounds {
                assert((inb["listen"] as? String) == "127.0.0.1", "Ожидался listen 127.0.0.1 при отключенном LAN")
            }
            
            var lanSettings = AppSettings.standard
            lanSettings.allowLanConnections = true
            let lanJson = try XrayConfigGenerator.generateConfig(server: sampleServer, routing: .defaultConfiguration, settings: lanSettings)
            guard let lanData = lanJson.data(using: .utf8),
                  let lanDict = try JSONSerialization.jsonObject(with: lanData) as? [String: Any],
                  let lanInbounds = lanDict["inbounds"] as? [[String: Any]] else {
                throw ParserError.missingField("Не удалось распарсить inbounds для lanSettings")
            }
            for inb in lanInbounds {
                assert((inb["listen"] as? String) == "0.0.0.0", "Ожидался listen 0.0.0.0 при включенном LAN")
            }
            
            let lanResult = try XrayProcessManager.shared.testConfiguration(server: sampleServer, routing: .defaultConfiguration, settings: lanSettings)
            assert(lanResult.isValid, "Валидация LAN-конфигурации бинарником xray провалилась: \(lanResult.output)")
        }
        
        test("Валидация Stealth Profile: CDN Fronting (xhttp over TLS) через xray -test -c") {
            var cdnSettings = AppSettings.standard
            cdnSettings.stealthProfile = .cdnFronting
            cdnSettings.cdnHost = "cdn.cloudflare.com"
            cdnSettings.cdnPath = "/api/v1/xhttp"
            cdnSettings.enableMicroSessions = true
            
            let sampleServer = ServerProfile(
                name: "CDN Fronting Test Node",
                address: "cdn.cloudflare.com",
                port: 443,
                protocolType: .vless,
                vlessDetails: VLESSDetails(
                    uuid: "a28b0561-269e-4e4b-97e3-059c1c4f5f5e",
                    serverName: "cdn.cloudflare.com",
                    path: "/api/v1/xhttp"
                )
            )
            
            let configJson = try XrayConfigGenerator.generateConfig(
                server: sampleServer,
                routing: .defaultConfiguration,
                settings: cdnSettings
            )
            
            guard let jsonData = configJson.data(using: .utf8),
                  let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let outbounds = json["outbounds"] as? [[String: Any]],
                  let proxy = outbounds.first(where: { ($0["tag"] as? String) == "proxy" }),
                  let stream = proxy["streamSettings"] as? [String: Any] else {
                throw ParserError.missingField("Не удалось распарсить streamSettings для CDN Fronting")
            }
            
            assert((stream["network"] as? String) == "xhttp", "Сеть должна быть xhttp")
            assert((stream["security"] as? String) == "tls", "Безопасность должна быть tls")
            assert(stream["realitySettings"] == nil, "Reality должен отсутствовать в CDN Fronting")
            
            let xhttp = stream["xhttpSettings"] as? [String: Any]
            assert((xhttp?["host"] as? String) == "cdn.cloudflare.com")
            assert((xhttp?["path"] as? String) == "/api/v1/xhttp")
            
            let sockopt = stream["sockopt"] as? [String: Any]
            assert((sockopt?["tcpKeepAliveInterval"] as? Int) == 15, "Micro-sessions keepalive должно быть 15")
            assert((sockopt?["tcpNoDelay"] as? Bool) == true, "Micro-sessions tcpNoDelay должно быть true")
            
            let result = try XrayProcessManager.shared.testConfiguration(
                server: sampleServer,
                routing: .defaultConfiguration,
                settings: cdnSettings
            )
            assert(result.isValid, "Валидация CDN Fronting бинарником xray провалилась: \(result.output)")
        }
        
        test("Валидация Stealth Profile: WebRTC Camouflage (kcp/UDP) через xray -test -c") {
            var webrtcSettings = AppSettings.standard
            webrtcSettings.stealthProfile = .webrtcCamouflage
            webrtcSettings.webrtcSni = "webrtc.zoom.us"
            webrtcSettings.enableMicroSessions = true
            
            let sampleServer = ServerProfile(
                name: "WebRTC Camouflage Node",
                address: "1.2.3.4",
                port: 443,
                protocolType: .vless,
                vlessDetails: VLESSDetails(uuid: "a28b0561-269e-4e4b-97e3-059c1c4f5f5e")
            )
            
            let configJson = try XrayConfigGenerator.generateConfig(
                server: sampleServer,
                routing: .defaultConfiguration,
                settings: webrtcSettings
            )
            
            guard let jsonData = configJson.data(using: .utf8),
                  let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let outbounds = json["outbounds"] as? [[String: Any]],
                  let proxy = outbounds.first(where: { ($0["tag"] as? String) == "proxy" }),
                  let stream = proxy["streamSettings"] as? [String: Any] else {
                throw ParserError.missingField("Не удалось распарсить streamSettings для WebRTC Camouflage")
            }
            
            assert((stream["network"] as? String) == "kcp", "Сеть должна быть kcp")
            assert((stream["security"] as? String) == "tls", "Безопасность должна быть tls при указанном SNI")
            
            let tls = stream["tlsSettings"] as? [String: Any]
            assert((tls?["serverName"] as? String) == "webrtc.zoom.us")
            
            let kcp = stream["kcpSettings"] as? [String: Any]
            assert((kcp?["mtu"] as? Int) == 1350)
            
            let sockopt = stream["sockopt"] as? [String: Any]
            assert((sockopt?["tcpKeepAliveInterval"] as? Int) == 10)
            
            let result = try XrayProcessManager.shared.testConfiguration(
                server: sampleServer,
                routing: .defaultConfiguration,
                settings: webrtcSettings
            )
            assert(result.isValid, "Валидация WebRTC Camouflage бинарником xray провалилась: \(result.output)")
        }
        
        // MARK: - 4. Storage & Persistence
        print("\n[4/5] Тестирование сериализации и хранилища:")
        test("JSON Roundtrip для ServerProfile и RoutingConfig") {
            let config = RoutingConfig.defaultConfiguration
            let data = try JSONEncoder().encode(config)
            let decoded = try JSONDecoder().decode(RoutingConfig.self, from: data)
            assert(decoded.mode == config.mode)
            assert(decoded.proxyRules.count == config.proxyRules.count)
            assert(decoded.directRules.count == config.directRules.count)
        }
        
        test("Схемы маршрутизации Happ & V2RayTUN: кодирование, декодирование и round-trip") {
            let original = RoutingConfig.defaultConfiguration
            let happUrl = try HappRoutingCodec.exportHappUrl(from: original, name: "Unit Test Scheme")
            assert(happUrl.hasPrefix("happ://routing/add/"))
            
            let decodedScheme = try HappRoutingCodec.decode(from: happUrl)
            assert(decodedScheme.name == "Unit Test Scheme")
            assert(decodedScheme.proxySites.contains("geosite:openai"))
            assert(decodedScheme.directIp.contains("geoip:ru"))
            
            var appliedConfig = RoutingConfig()
            HappRoutingCodec.apply(scheme: decodedScheme, to: &appliedConfig, merge: false)
            assert(appliedConfig.proxyRules.contains(where: { $0.value == "geosite:openai" }))
            assert(appliedConfig.directRules.contains(where: { $0.value == "geoip:ru" }))
            
            // Test V2RayTUN format decoding
            let v2rayTunJson = """
            {
              "domainStrategy": "IPIfNonMatch",
              "name": "DigneZzZ Test Routing",
              "rules": [
                { "type": "field", "__name__": "Block Ads", "domain": ["geosite:category-ads-all"], "outboundTag": "block" },
                { "type": "field", "__name__": "Proxy AI", "domain": ["domain:chatgpt.com", "domain:claude.ai"], "outboundTag": "proxy" },
                { "type": "field", "__name__": "Direct RU", "ip": ["geoip:ru"], "outboundTag": "direct" }
              ]
            }
            """
            let decodedV2RayTun = try HappRoutingCodec.decode(from: v2rayTunJson)
            assert(decodedV2RayTun.name == "DigneZzZ Test Routing")
            assert(decodedV2RayTun.blockSites.contains("geosite:category-ads-all"))
            assert(decodedV2RayTun.proxySites.contains("domain:chatgpt.com"))
            assert(decodedV2RayTun.directIp.contains("geoip:ru"))
        }
        
        test("Парсинг HTTP заголовка routing: \"<base64>\" и применение схемы") {
            let testScheme = HappRoutingScheme(
                name: "Server Routing",
                directSites: ["yandex.ru", "vk.com"],
                proxySites: ["youtube.com", "instagram.com"],
                domainStrategy: "IPIfNonMatch",
                fakeDNS: true
            )
            let rawJson = try JSONEncoder().encode(testScheme)
            let b64 = rawJson.base64EncodedString()
            let headerValWithQuotes = "\"\(b64)\""
            
            var raw = headerValWithQuotes.trimmingCharacters(in: .whitespacesAndNewlines)
            if raw.hasPrefix("\"") && raw.hasSuffix("\"") && raw.count >= 2 {
                raw = String(raw.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            let decoded = try HappRoutingCodec.decode(from: raw)
            assert(decoded.name == "Server Routing")
            assert(decoded.fakeDNS == true)
            assert(decoded.proxySites.contains("youtube.com"))
            
            var config = RoutingConfig()
            HappRoutingCodec.apply(scheme: decoded, to: &config, merge: true)
            assert(config.proxyRules.contains(where: { $0.value == "youtube.com" }))
            assert(config.directRules.contains(where: { $0.value == "yandex.ru" }))
            assert(config.fakeDnsEnabled == true)
        }
        
        test("Сериализация GeoAssetMetadata и определение путей гео-баз") {
            let metadata = GeoAssetMetadata(
                lastUpdated: Date(),
                geositeBytes: 15_234_567,
                geoipBytes: 4_890_123,
                source: "DigneZzZ/routing (jsDelivr)"
            )
            let data = try JSONEncoder().encode(metadata)
            let decoded = try JSONDecoder().decode(GeoAssetMetadata.self, from: data)
            assert(decoded.geositeBytes == 15_234_567)
            assert(decoded.geoipBytes == 4_890_123)
            assert(decoded.source.contains("DigneZzZ"))
            
            let assetsDir = GeoAssetManager.assetsDirectoryURL
            assert(assetsDir.path.contains("XProject/assets"))
        }
        
        test("Запоминание выбранного сервера и автозапуск туннеля (autoConnectOnLaunch)") {
            // Backup user's actual settings and UserDefaults keys to prevent test pollution
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.appendingPathComponent("XProject")
            let settingsUrl = appSupport?.appendingPathComponent("settings.json")
            let serversUrl = appSupport?.appendingPathComponent("servers.json")
            let origSettingsData = settingsUrl.flatMap { try? Data(contentsOf: $0) }
            let origServersData = serversUrl.flatMap { try? Data(contentsOf: $0) }
            let origUDId = UserDefaults.standard.string(forKey: "lastSelectedServerId")
            let origUDKey = UserDefaults.standard.string(forKey: "lastSelectedServerKey")
            let origUDName = UserDefaults.standard.string(forKey: "lastSelectedServerName")
            let origUDAutoConnect = UserDefaults.standard.object(forKey: "autoConnectOnLaunch")
            
            defer {
                if let data = origSettingsData, let url = settingsUrl { try? data.write(to: url, options: .atomic) }
                if let data = origServersData, let url = serversUrl { try? data.write(to: url, options: .atomic) }
                UserDefaults.standard.set(origUDId, forKey: "lastSelectedServerId")
                UserDefaults.standard.set(origUDKey, forKey: "lastSelectedServerKey")
                UserDefaults.standard.set(origUDName, forKey: "lastSelectedServerName")
                if let auto = origUDAutoConnect {
                    UserDefaults.standard.set(auto, forKey: "autoConnectOnLaunch")
                } else {
                    UserDefaults.standard.removeObject(forKey: "autoConnectOnLaunch")
                }
                UserDefaults.standard.synchronize()
            }
            
            let state = AppState()
            let server1 = ServerProfile(name: "Persist Node 1", address: "1.1.1.1", port: 443, protocolType: .vless)
            let server2 = ServerProfile(name: "Persist Node 2", address: "2.2.2.2", port: 443, protocolType: .vless)
            state.servers = [server1, server2]
            
            // User selects server 2
            state.selectServer(id: server2.id)
            assert(state.selectedServerId == server2.id)
            
            // Check persistence in UserDefaults
            let savedId = UserDefaults.standard.string(forKey: "lastSelectedServerId")
            assert(savedId == server2.id.uuidString)
            
            // Simulate reload with restoreSelectedServer
            state.selectedServerId = nil
            state.restoreSelectedServer()
            assert(state.selectedServerId == server2.id, "Сервер 2 должен быть восстановлен")
            
            // Test autoConnectOnLaunch toggle
            state.settings.autoConnectOnLaunch = true
            assert(state.settings.autoConnectOnLaunch == true)
        }
        
        test("Обратная совместимость AppSettings при миграции старого settings.json (v1.0 -> v2.0)") {
            // Старый формат settings.json (v1.0) без полей fragment, noise, launchAtLogin и allowLanConnections
            let legacyJson = """
            {
              "trafficMode": "tun",
              "routingMode": "rule_based",
              "socksPort": 10808,
              "httpPort": 10809,
              "dnsServer": "https://1.1.1.1/dns-query",
              "autoConnectOnLaunch": true,
              "autoUpdateSubscriptions": false,
              "lastSelectedServerId": "A28B0561-269E-4E4B-97E3-059C1C4F5F5E",
              "lastSelectedServerName": "Legacy Netherlands Node",
              "lastSelectedServerKey": "legacy-cache-key"
            }
            """
            
            guard let data = legacyJson.data(using: .utf8) else {
                throw ParserError.missingField("Не удалось преобразовать legacyJson в Data")
            }
            
            let decoder = JSONDecoder()
            let decoded = try decoder.decode(AppSettings.self, from: data)
            
            // 1. Проверяем сохранение всех оригинальных значений v1.0
            assert(decoded.trafficMode == .tun)
            assert(decoded.routingMode == .ruleBased)
            assert(decoded.socksPort == 10808)
            assert(decoded.httpPort == 10809)
            assert(decoded.dnsServer == "https://1.1.1.1/dns-query")
            assert(decoded.autoConnectOnLaunch == true)
            assert(decoded.autoUpdateSubscriptions == false)
            assert(decoded.lastSelectedServerId == UUID(uuidString: "A28B0561-269E-4E4B-97E3-059C1C4F5F5E"))
            assert(decoded.lastSelectedServerName == "Legacy Netherlands Node")
            assert(decoded.lastSelectedServerKey == "legacy-cache-key")
            
            // 2. Проверяем корректные безопасные дефолты для новых полей v2.0
            assert(decoded.launchAtLogin == false, "launchAtLogin должен быть false по умолчанию")
            assert(decoded.allowLanConnections == false, "allowLanConnections должен быть false по умолчанию")
            assert(decoded.fragmentEnabled == false, "fragmentEnabled должен быть false по умолчанию")
            assert(decoded.fragmentPackets == "tlshello", "fragmentPackets по умолчанию 'tlshello'")
            assert(decoded.fragmentLength == "100-200", "fragmentLength по умолчанию '100-200'")
            assert(decoded.fragmentInterval == "10-20", "fragmentInterval по умолчанию '10-20'")
            assert(decoded.noiseEnabled == false, "noiseEnabled должен быть false по умолчанию")
            assert(decoded.noiseType == "rand", "noiseType по умолчанию 'rand'")
            assert(decoded.noisePacket == "50-100", "noisePacket по умолчанию '50-100'")
            assert(decoded.noiseDelay == "10-20", "noiseDelay по умолчанию '10-20'")
            
            // 3. Проверяем миграцию, сохранение и roundtrip в новой структуре
            var migrated = decoded
            migrated.fragmentEnabled = true
            migrated.fragmentPackets = "1-3"
            migrated.noiseEnabled = true
            migrated.allowLanConnections = true
            
            let encoder = JSONEncoder()
            let migratedData = try encoder.encode(migrated)
            let roundtrip = try decoder.decode(AppSettings.self, from: migratedData)
            
            assert(roundtrip == migrated, "Мигрированные настройки должны совпадать после roundtrip сериализации")
            assert(roundtrip.fragmentEnabled == true)
            assert(roundtrip.fragmentPackets == "1-3")
            assert(roundtrip.noiseEnabled == true)
            assert(roundtrip.allowLanConnections == true)
        }
        
        // MARK: - 5. Network Stack
        print("\n[5/5] Тестирование сетевых адаптеров macOS:")
        test("Определение сетевых служб (networksetup)") {
            let services = SystemProxyManager.shared.getActiveNetworkServices()
            assert(!services.isEmpty, "Должна быть обнаружена хотя бы одна сетевая служба")
            print("     (Обнаружены службы: \(services.joined(separator: ", ")))")
        }
        
        test("Переключение TUN-интерфейса") {
            let tun = TUNManager.shared
            tun.startTun(socksPort: 10808) { _, _ in }
            assert(tun.isActive)
            tun.stopTun()
            assert(!tun.isActive)
        }
        
        print("\n=======================================================")
        print("🏁 ИТОГ ТЕСТИРОВАНИЯ: Успешно: \(passed), Ошибок: \(failed)")
        print("=======================================================\n")
        
        if failed > 0 {
            exit(1)
        }
    }
}
