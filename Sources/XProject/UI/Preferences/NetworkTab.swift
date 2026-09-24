import SwiftUI

public struct NetworkTab: View {
    @Bindable var appState: AppState
    
    public init(appState: AppState) {
        self.appState = appState
    }
    
    public var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 16) {
                // MARK: - Section 1: Traffic Interception Mode
                VStack(alignment: .leading, spacing: 10) {
                    Text("СПОСОБ СЕТЕВОГО ПЕРЕХВАТА (СИСТЕМНЫЙ УРОВЕНЬ)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                    
                    HStack(spacing: 12) {
                        trafficModeCard(
                            mode: .tun,
                            title: "TUN интерфейс (VPN)",
                            subtitle: "Сетевой адаптер macOS. Охватывает любые программы: браузеры, Telegram, терминал и фоновые службы.",
                            icon: "shield.checkered",
                            badge: "РЕКОМЕНДУЕТСЯ"
                        )
                        
                        trafficModeCard(
                            mode: .systemProxy,
                            title: "Системный прокси",
                            subtitle: "Настройка параметров сети macOS. Работает только в браузерах и программах с явной поддержкой прокси.",
                            icon: "network",
                            badge: nil
                        )
                    }
                    
                    // Explanatory hint to clarify architecture and eliminate confusion with Routing tab
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(ModernMacTheme.cyanAccent.opacity(0.8))
                        Text("TUN перехватывает весь сетевой стек Mac, а вкладка «Маршрутизация» определяет, какие сайты идут в туннель, а какие — напрямую.")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    .padding(.top, 2)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5))
                )
                
                // MARK: - Section 2: Secure DNS (DoH)
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("БЕЗОПАСНЫЙ DNS (DNS OVER HTTPS)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white.opacity(0.6))
                        
                        Spacer()
                        
                        Text("Шифрование запросов к доменам")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    
                    // DoH URL input field
                    HStack(spacing: 8) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(ModernMacTheme.cyanAccent)
                        
                        TextField("https://1.1.1.1/dns-query", text: $appState.settings.dnsServer)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12, design: .monospaced))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5))
                    )
                    
                    // Quick DNS Presets
                    HStack(spacing: 8) {
                        dnsChip("Cloudflare (1.1.1.1)", url: "https://1.1.1.1/dns-query")
                        dnsChip("Google (8.8.8.8)", url: "https://dns.google/dns-query")
                        dnsChip("AdGuard (Anti-Ads)", url: "https://dns.adguard-dns.com/dns-query")
                        dnsChip("Quad9 (Security)", url: "https://dns.quad9.net/dns-query")
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5))
                )
                
                // MARK: - Section 3: Local Ports
                VStack(alignment: .leading, spacing: 10) {
                    Text("ЛОКАЛЬНЫЕ ВХОДЯЩИЕ ПОРТЫ ЯДРА XRAY")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                    
                    HStack(spacing: 16) {
                        // SOCKS5 Port
                        VStack(alignment: .leading, spacing: 4) {
                            Text("SOCKS5 Порт:")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.8))
                            
                            TextField("10808", value: $appState.settings.socksPort, format: .number.grouping(.never))
                                .textFieldStyle(.plain)
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color.white.opacity(0.06))
                                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5))
                                )
                            
                            Text("Для Telegram, браузеров и терминала")
                                .font(.system(size: 10))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        .frame(maxWidth: .infinity)
                        
                        // HTTP Proxy Port
                        VStack(alignment: .leading, spacing: 4) {
                            Text("HTTP/HTTPS Прокси Порт:")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.8))
                            
                            TextField("10809", value: $appState.settings.httpPort, format: .number.grouping(.never))
                                .textFieldStyle(.plain)
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color.white.opacity(0.06))
                                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5))
                                )
                            
                            Text("Для системных HTTP запросов и cURL")
                                .font(.system(size: 10))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5))
                )
                
                // MARK: - Section 4: Automation & Startup
                VStack(alignment: .leading, spacing: 10) {
                    Text("АВТОМАТИЗАЦИЯ")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Автоматическое подключение при запуске приложения")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white)
                            Text("Сразу запускает туннель к последнему выбранному серверу")
                                .font(.system(size: 10))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        
                        Spacer()
                        
                        GoldenToggle(isOn: $appState.settings.autoConnectOnLaunch)
                    }
                    
                    Divider().opacity(0.2)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Автоматическое обновление подписок при старте")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white)
                            Text("Загружает свежие серверы и квоты трафика в фоновом режиме")
                                .font(.system(size: 10))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        
                        Spacer()
                        
                        GoldenToggle(isOn: $appState.settings.autoUpdateSubscriptions)
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5))
                )
            }
            .padding(18)
        }
        .tint(ModernMacTheme.cyanAccent)
        .onChange(of: appState.settings) { _, _ in
            appState.saveSettings()
        }
    }
    
    // MARK: - Traffic Mode Card Component
    private func trafficModeCard(mode: TrafficMode, title: String, subtitle: String, icon: String, badge: String?) -> some View {
        let isSelected = appState.settings.trafficMode == mode
        return Button(action: {
            withAnimation(ModernMacTheme.smoothSpring) {
                appState.settings.trafficMode = mode
                appState.saveSettings()
            }
        }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(isSelected ? ModernMacTheme.cyanAccent.opacity(0.2) : Color.white.opacity(0.06))
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(isSelected ? ModernMacTheme.cyanAccent : .white.opacity(0.6))
                    }
                    
                    if let b = badge {
                        Text(b)
                            .font(.system(size: 8, weight: .heavy, design: .monospaced))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(ModernMacTheme.neonGreen.opacity(0.25)))
                            .foregroundStyle(ModernMacTheme.neonGreen)
                    }
                    
                    Spacer()
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(ModernMacTheme.cyanAccent)
                    } else {
                        Circle()
                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 1.5)
                            .frame(width: 14, height: 14)
                    }
                }
                
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.85))
                
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.5))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? ModernMacTheme.cyanAccent.opacity(0.12) : Color.white.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(isSelected ? ModernMacTheme.cyanAccent.opacity(0.5) : Color.white.opacity(0.06), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - DNS Preset Chip
    private func dnsChip(_ title: String, url: String) -> some View {
        let isSelected = appState.settings.dnsServer.trimmingCharacters(in: .whitespacesAndNewlines) == url
        return Button(action: {
            withAnimation(ModernMacTheme.smoothSpring) {
                appState.settings.dnsServer = url
                appState.saveSettings()
            }
        }) {
            Text(title)
                .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isSelected ? ModernMacTheme.cyanAccent.opacity(0.25) : Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(isSelected ? ModernMacTheme.cyanAccent.opacity(0.6) : Color.white.opacity(0.1), lineWidth: 0.5)
                        )
                )
                .foregroundStyle(isSelected ? ModernMacTheme.cyanAccent : .white.opacity(0.75))
        }
        .buttonStyle(.plain)
    }
}
