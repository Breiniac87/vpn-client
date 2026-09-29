import SwiftUI
import AppKit

public struct ManualServerSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var appState: AppState
    
    public var serverToEdit: ServerProfile?
    
    // Protocol selection
    @State private var selectedProtocol: ServerProtocol = .vless
    
    // General fields
    @State private var name: String = ""
    @State private var address: String = ""
    @State private var portString: String = "443"
    
    // VLESS fields
    @State private var vlessUuid: String = ""
    @State private var vlessFlow: String = "xtls-rprx-vision"
    @State private var vlessSecurity: String = "reality"
    @State private var vlessSni: String = ""
    @State private var vlessPublicKey: String = ""
    @State private var vlessShortId: String = ""
    @State private var vlessSpiderX: String = "/"
    @State private var vlessFingerprint: String = "chrome"
    @State private var vlessTransport: String = "tcp"
    @State private var vlessPath: String = ""
    @State private var vlessHostHeader: String = ""
    
    // Trojan fields
    @State private var trojanPassword: String = ""
    @State private var trojanSni: String = ""
    @State private var trojanSecurity: String = "tls"
    @State private var trojanTransport: String = "tcp"
    @State private var trojanPath: String = ""
    
    // Shadowsocks fields
    @State private var ssMethod: String = "aes-256-gcm"
    @State private var ssPassword: String = ""
    
    // UI state
    @State private var errorMessage: String? = nil
    @State private var showPasswords: Bool = false
    
    private let availableFingerprints = ["chrome", "firefox", "safari", "ios", "edge", "randomized"]
    private let availableSsMethods = [
        "aes-256-gcm",
        "aes-128-gcm",
        "chacha20-ietf-poly1305",
        "2022-blake3-aes-128-gcm",
        "2022-blake3-aes-256-gcm"
    ]
    private let commonSniPresets = ["yahoo.com", "microsoft.com", "apple.com", "cloudflare.com", "gateway.icloud.com"]
    
    public init(appState: AppState, serverToEdit: ServerProfile? = nil) {
        self.appState = appState
        self.serverToEdit = serverToEdit
    }
    
    public var body: some View {
        ZStack {
            // Apple HIG Dark Obsidian Background
            LinearGradient(
                colors: [
                    ModernMacTheme.darkBackgroundTop,
                    ModernMacTheme.darkBackgroundMid,
                    ModernMacTheme.darkBackgroundBottom
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: serverToEdit != nil ? "slider.horizontal.3" : "plus.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(ModernMacTheme.neonYellow)
                        
                        Text(serverToEdit != nil ? "Редактировать сервер" : "Добавить сервер вручную")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    
                    Spacer()
                    
                    Button("Отмена") {
                        dismiss()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.08)))
                    .foregroundStyle(.white.opacity(0.8))
                    .keyboardShortcut(.cancelAction)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(Color.white.opacity(0.02))
                
                Divider()
                    .opacity(0.15)
                
                // Form content
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 16) {
                        // Protocol selector
                        protocolSelectorGroup
                        
                        // General section
                        generalSection
                        
                        // Protocol-specific section
                        switch selectedProtocol {
                        case .vless:
                            vlessSection
                        case .trojan:
                            trojanSection
                        case .shadowsocks:
                            shadowsocksSection
                        case .customJson:
                            EmptyView()
                        }
                        
                        // Error message
                        if let error = errorMessage {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(ModernMacTheme.redDanger)
                                Text(error)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(ModernMacTheme.redDanger)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(ModernMacTheme.redDanger.opacity(0.12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .strokeBorder(ModernMacTheme.redDanger.opacity(0.3), lineWidth: 0.8)
                                    )
                            )
                        }
                        
                        // Action buttons
                        HStack(spacing: 12) {
                            Button("Отмена") {
                                dismiss()
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.white.opacity(0.06))
                                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8))
                            )
                            .foregroundStyle(.white.opacity(0.8))
                            
                            Button(action: saveServer) {
                                HStack(spacing: 6) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 12, weight: .bold))
                                    Text(serverToEdit != nil ? "Сохранить изменения" : "Добавить сервер")
                                        .font(.system(size: 12, weight: .bold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                                .background(
                                    LinearGradient(
                                        colors: [ModernMacTheme.neonYellow, Color(hex: "FFCC00")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .foregroundStyle(.black)
                                .shadow(color: ModernMacTheme.neonYellow.opacity(0.3), radius: 6, y: 2)
                            }
                            .buttonStyle(.plain)
                            .keyboardShortcut(.defaultAction)
                        }
                        .padding(.top, 8)
                    }
                    .padding(20)
                }
            }
        }
        .frame(width: 520, height: 620)
        .onAppear(perform: loadServerData)
    }
    
    // MARK: - Protocol Selector
    private var protocolSelectorGroup: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("ПРОТОКОЛ")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.55))
            
            HStack(spacing: 8) {
                ForEach([ServerProtocol.vless, ServerProtocol.trojan, ServerProtocol.shadowsocks]) { proto in
                    let isSelected = selectedProtocol == proto
                    Button(action: {
                        withAnimation(ModernMacTheme.smoothSpring) {
                            selectedProtocol = proto
                            if proto == .shadowsocks && portString == "443" {
                                portString = "8388"
                            } else if (proto == .vless || proto == .trojan) && portString == "8388" {
                                portString = "443"
                            }
                        }
                    }) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color(hex: proto.badgeColorHex))
                                .frame(width: 8, height: 8)
                            
                            Text(proto.rawValue)
                                .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(isSelected ? Color(hex: proto.badgeColorHex).opacity(0.2) : Color.white.opacity(0.04))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(isSelected ? Color(hex: proto.badgeColorHex).opacity(0.6) : Color.white.opacity(0.08), lineWidth: 1)
                                )
                        )
                        .foregroundStyle(isSelected ? .white : .white.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    // MARK: - General Section
    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ОСНОВНЫЕ ПАРАМЕТРЫ")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.55))
            
            VStack(spacing: 8) {
                inputField(
                    label: "Название сервера",
                    placeholder: "Например: Нидерланды VLESS Reality",
                    text: $name
                )
                
                HStack(spacing: 10) {
                    inputField(
                        label: "Хост или IP-адрес",
                        placeholder: "185.123.45.67 или nl.vpn.com",
                        text: $address
                    )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Порт")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.75))
                        
                        TextField("443", text: $portString)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12, design: .monospaced))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .frame(width: 80)
                            .background(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(Color.white.opacity(0.06))
                                    .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8))
                            )
                            .foregroundStyle(.white)
                    }
                }
                
                // Quick port presets
                HStack(spacing: 6) {
                    Text("Быстрый порт:")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.5))
                    ForEach(["443", "8443", "2053", "80", "8388"], id: \.self) { p in
                        Button(p) {
                            portString = p
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 9, weight: portString == p ? .bold : .regular, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(portString == p ? ModernMacTheme.cyanAccent.opacity(0.25) : Color.white.opacity(0.06)))
                        .foregroundStyle(portString == p ? ModernMacTheme.cyanAccent : .white.opacity(0.6))
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(ModernMacTheme.cardSurface)
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(ModernMacTheme.borderCard, lineWidth: 0.8))
            )
        }
    }
    
    // MARK: - VLESS Section
    private var vlessSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("НАСТРОЙКИ VLESS")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.55))
            
            VStack(spacing: 10) {
                // UUID with Generator button
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("UUID клиента")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.75))
                        Spacer()
                        Button(action: {
                            vlessUuid = UUID().uuidString.lowercased()
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: "wand.and.stars")
                                    .font(.system(size: 9))
                                Text("Сгенерировать")
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundStyle(ModernMacTheme.cyanAccent)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    TextField("xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx", text: $vlessUuid)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11, design: .monospaced))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(Color.white.opacity(0.06))
                                .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8))
                        )
                        .foregroundStyle(.white)
                }
                
                // Security & Flow
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Безопасность (Security)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.75))
                        
                        Picker("", selection: $vlessSecurity) {
                            Text("Reality").tag("reality")
                            Text("TLS").tag("tls")
                            Text("None").tag("none")
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Flow (XTLS)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.75))
                        
                        Picker("", selection: $vlessFlow) {
                            Text("Vision").tag("xtls-rprx-vision")
                            Text("Нет").tag("none")
                        }
                        .pickerStyle(.segmented)
                    }
                }
                
                // Reality specifics
                if vlessSecurity == "reality" || vlessSecurity == "tls" {
                    VStack(alignment: .leading, spacing: 6) {
                        inputField(
                            label: "SNI (ServerName маскировки)",
                            placeholder: "yahoo.com или microsoft.com",
                            text: $vlessSni
                        )
                        
                        // SNI Quick Chips
                        HStack(spacing: 5) {
                            Text("Пресеты:")
                                .font(.system(size: 10))
                                .foregroundStyle(.white.opacity(0.5))
                            ForEach(commonSniPresets, id: \.self) { preset in
                                Button(preset) {
                                    vlessSni = preset
                                }
                                .buttonStyle(.plain)
                                .font(.system(size: 9))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(vlessSni == preset ? ModernMacTheme.cyanAccent.opacity(0.25) : Color.white.opacity(0.06)))
                                .foregroundStyle(vlessSni == preset ? ModernMacTheme.cyanAccent : .white.opacity(0.6))
                            }
                        }
                    }
                }
                
                if vlessSecurity == "reality" {
                    inputField(
                        label: "Публичный ключ Reality (pbk)",
                        placeholder: "e.g. 7_1... (Base64 URL Safe)",
                        text: $vlessPublicKey,
                        isMonospaced: true
                    )
                    
                    HStack(spacing: 10) {
                        inputField(
                            label: "Short ID (sid)",
                            placeholder: "e.g. 6ba851a9",
                            text: $vlessShortId,
                            isMonospaced: true
                        )
                        
                        inputField(
                            label: "SpiderX (spx)",
                            placeholder: "/",
                            text: $vlessSpiderX
                        )
                    }
                }
                
                // Fingerprint & Transport
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Fingerprint (uTLS)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.75))
                        
                        Picker("", selection: $vlessFingerprint) {
                            ForEach(availableFingerprints, id: \.self) { fp in
                                Text(fp.capitalized).tag(fp)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Транспорт")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.75))
                        
                        Picker("", selection: $vlessTransport) {
                            Text("TCP").tag("tcp")
                            Text("gRPC").tag("grpc")
                            Text("WebSocket").tag("ws")
                        }
                        .pickerStyle(.segmented)
                    }
                }
                
                if vlessTransport == "grpc" {
                    inputField(
                        label: "gRPC Service Name",
                        placeholder: "e.g. grpc-service",
                        text: $vlessPath
                    )
                } else if vlessTransport == "ws" {
                    HStack(spacing: 10) {
                        inputField(
                            label: "WebSocket Path",
                            placeholder: "/ws",
                            text: $vlessPath
                        )
                        inputField(
                            label: "Host Header",
                            placeholder: "domain.com",
                            text: $vlessHostHeader
                        )
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(ModernMacTheme.cardSurface)
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(ModernMacTheme.borderCard, lineWidth: 0.8))
            )
        }
    }
    
    // MARK: - Trojan Section
    private var trojanSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("НАСТРОЙКИ TROJAN")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.55))
            
            VStack(spacing: 10) {
                // Password
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Пароль Trojan")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.75))
                        Spacer()
                        Button(action: { showPasswords.toggle() }) {
                            Image(systemName: showPasswords ? "eye.slash" : "eye")
                                .font(.system(size: 10))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                    }
                    
                    if showPasswords {
                        TextField("Пароль", text: $trojanPassword)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12, design: .monospaced))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(RoundedRectangle(cornerRadius: 7).fill(Color.white.opacity(0.06)))
                            .foregroundStyle(.white)
                    } else {
                        SecureField("Пароль", text: $trojanPassword)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12, design: .monospaced))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(RoundedRectangle(cornerRadius: 7).fill(Color.white.opacity(0.06)))
                            .foregroundStyle(.white)
                    }
                }
                
                inputField(
                    label: "SNI (ServerName)",
                    placeholder: "domain.com",
                    text: $trojanSni
                )
                
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Транспорт")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.75))
                        
                        Picker("", selection: $trojanTransport) {
                            Text("TCP").tag("tcp")
                            Text("WebSocket").tag("ws")
                            Text("gRPC").tag("grpc")
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Безопасность")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.75))
                        
                        Picker("", selection: $trojanSecurity) {
                            Text("TLS").tag("tls")
                            Text("None").tag("none")
                        }
                        .pickerStyle(.segmented)
                    }
                }
                
                if trojanTransport == "ws" || trojanTransport == "grpc" {
                    inputField(
                        label: trojanTransport == "ws" ? "WebSocket Path" : "gRPC Service Name",
                        placeholder: trojanTransport == "ws" ? "/trojan-ws" : "grpc-service",
                        text: $trojanPath
                    )
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(ModernMacTheme.cardSurface)
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(ModernMacTheme.borderCard, lineWidth: 0.8))
            )
        }
    }
    
    // MARK: - Shadowsocks Section
    private var shadowsocksSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("НАСТРОЙКИ SHADOWSOCKS")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.55))
            
            VStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Метод шифрования (Cipher)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.75))
                    
                    Picker("", selection: $ssMethod) {
                        ForEach(availableSsMethods, id: \.self) { m in
                            Text(m).tag(m)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Ключ / Пароль")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.75))
                        Spacer()
                        Button(action: { showPasswords.toggle() }) {
                            Image(systemName: showPasswords ? "eye.slash" : "eye")
                                .font(.system(size: 10))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                    }
                    
                    if showPasswords {
                        TextField("Пароль или ключ", text: $ssPassword)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12, design: .monospaced))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(RoundedRectangle(cornerRadius: 7).fill(Color.white.opacity(0.06)))
                            .foregroundStyle(.white)
                    } else {
                        SecureField("Пароль или ключ", text: $ssPassword)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12, design: .monospaced))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(RoundedRectangle(cornerRadius: 7).fill(Color.white.opacity(0.06)))
                            .foregroundStyle(.white)
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(ModernMacTheme.cardSurface)
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(ModernMacTheme.borderCard, lineWidth: 0.8))
            )
        }
    }
    
    // MARK: - Reusable Input Field
    private func inputField(
        label: String,
        placeholder: String,
        text: Binding<String>,
        isMonospaced: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.75))
            
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(.system(size: 12, design: isMonospaced ? .monospaced : .default))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                        .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8))
                )
                .foregroundStyle(.white)
        }
    }
    
    // MARK: - Actions
    private func loadServerData() {
        guard let s = serverToEdit else { return }
        name = s.name
        address = s.address
        portString = String(s.port)
        selectedProtocol = s.protocolType
        
        switch s.protocolType {
        case .vless:
            if let d = s.vlessDetails {
                vlessUuid = d.uuid
                vlessFlow = d.flow ?? "none"
                vlessSecurity = d.security
                vlessSni = d.serverName ?? ""
                vlessPublicKey = d.publicKey ?? ""
                vlessShortId = d.shortId ?? ""
                vlessSpiderX = d.spiderX ?? "/"
                vlessFingerprint = d.fingerprint ?? "chrome"
                vlessTransport = d.transportType
                vlessPath = d.path ?? ""
                vlessHostHeader = d.hostHeader ?? ""
            }
        case .trojan:
            if let d = s.trojanDetails {
                trojanPassword = d.password
                trojanSni = d.serverName ?? ""
                trojanSecurity = d.security
                trojanTransport = d.transportType
                trojanPath = d.path ?? ""
            }
        case .shadowsocks:
            if let d = s.shadowsocksDetails {
                ssMethod = d.method
                ssPassword = d.password
            }
        case .customJson:
            break
        }
    }
    
    private func saveServer() {
        errorMessage = nil
        
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAddress.isEmpty else {
            errorMessage = "Укажите IP-адрес или хост сервера."
            return
        }
        
        guard let port = Int(portString.trimmingCharacters(in: .whitespacesAndNewlines)), port > 0, port <= 65535 else {
            errorMessage = "Укажите корректный порт (от 1 до 65535)."
            return
        }
        
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveName = trimmedName.isEmpty ? "\(selectedProtocol.rawValue) - \(trimmedAddress):\(port)" : trimmedName
        
        var vDetails: VLESSDetails? = nil
        var tDetails: TrojanDetails? = nil
        var sDetails: ShadowsocksDetails? = nil
        
        switch selectedProtocol {
        case .vless:
            let trimmedUuid = vlessUuid.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedUuid.isEmpty else {
                errorMessage = "Укажите UUID клиента для VLESS (нажмите «Сгенерировать»)."
                return
            }
            if vlessSecurity == "reality" && vlessPublicKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                errorMessage = "Для протокола Reality требуется публичный ключ (pbk)."
                return
            }
            
            vDetails = VLESSDetails(
                uuid: trimmedUuid,
                flow: vlessFlow == "none" ? nil : vlessFlow,
                security: vlessSecurity,
                serverName: vlessSni.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : vlessSni.trimmingCharacters(in: .whitespacesAndNewlines),
                publicKey: vlessPublicKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : vlessPublicKey.trimmingCharacters(in: .whitespacesAndNewlines),
                shortId: vlessShortId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : vlessShortId.trimmingCharacters(in: .whitespacesAndNewlines),
                fingerprint: vlessFingerprint,
                spiderX: vlessSpiderX.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : vlessSpiderX.trimmingCharacters(in: .whitespacesAndNewlines),
                transportType: vlessTransport,
                path: vlessPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : vlessPath.trimmingCharacters(in: .whitespacesAndNewlines),
                hostHeader: vlessHostHeader.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : vlessHostHeader.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            
        case .trojan:
            let trimmedPassword = trojanPassword.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedPassword.isEmpty else {
                errorMessage = "Укажите пароль для Trojan сервера."
                return
            }
            tDetails = TrojanDetails(
                password: trimmedPassword,
                serverName: trojanSni.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : trojanSni.trimmingCharacters(in: .whitespacesAndNewlines),
                security: trojanSecurity,
                transportType: trojanTransport,
                path: trojanPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : trojanPath.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            
        case .shadowsocks:
            let trimmedPassword = ssPassword.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedPassword.isEmpty else {
                errorMessage = "Укажите пароль или ключ для Shadowsocks."
                return
            }
            sDetails = ShadowsocksDetails(
                method: ssMethod,
                password: trimmedPassword
            )
            
        case .customJson:
            break
        }
        
        let serverId = serverToEdit?.id ?? UUID()
        let createdServer = ServerProfile(
            id: serverId,
            name: effectiveName,
            address: trimmedAddress,
            port: port,
            protocolType: selectedProtocol,
            vlessDetails: vDetails,
            trojanDetails: tDetails,
            shadowsocksDetails: sDetails,
            subscriptionId: serverToEdit?.subscriptionId,
            pingMs: serverToEdit?.pingMs,
            lastTestedAt: serverToEdit?.lastTestedAt,
            isFavorite: serverToEdit?.isFavorite ?? false,
            createdAt: serverToEdit?.createdAt ?? Date()
        )
        
        if serverToEdit != nil {
            appState.updateServer(createdServer)
        } else {
            appState.addServer(createdServer)
        }
        
        dismiss()
    }
}
