import SwiftUI

public struct NetworkTab: View {
    @Bindable var appState: AppState
    @State private var isModifiersExpanded: Bool = false
    
    public init(appState: AppState) {
        self.appState = appState
    }
    
    public var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 14) {
                // MARK: - Section 1: Traffic Interception Mode
                trafficInterceptionGroup
                
                // MARK: - Section 2: Stealth Engine (Profiles & Contextual Config)
                stealthEngineGroup
                
                // MARK: - Section 3: Fine Anti-DPI Tuning (Presets & Fragmentation & Noise)
                // Shown exclusively for Standard Reality profile (TLS Hello fragmentation and noise padding)
                if appState.settings.stealthProfile == .standardReality {
                    antiDpiGroup
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                
                // MARK: - Section 4: Advanced Anti-DPI Engine (Chains, Mimicry, Temporal Shaping)
                advancedAntiDpiGroup
                
                // MARK: - Section 5: Connection Guard & Failover
                connectionGuardGroup
                
                // MARK: - Section 6: Secure DNS (DoH)
                secureDnsGroup
                
                // MARK: - Section 7: Local Ports & LAN Sharing
                localPortsAndLanGroup
                
                // MARK: - Section 8: System & Access Automation
            }
            .padding(16)
            .animation(ModernMacTheme.smoothSpring, value: appState.settings)
            .animation(ModernMacTheme.smoothSpring, value: isModifiersExpanded)
        }
        .tint(ModernMacTheme.cyanAccent)
        .onChange(of: appState.settings) { _, newSettings in
            if newSettings.streamingMimicryEnabled && appState.settings.noiseEnabled {
                appState.settings.noiseEnabled = false
            }
            appState.saveSettings()
        }
    }
    
    // MARK: - Section 1: Traffic Interception Mode
    private var trafficInterceptionGroup: some View {
        SettingsCardGroup(
            title: "СПОСОБ СЕТЕВОГО ПЕРЕХВАТА (СИСТЕМНЫЙ УРОВЕНЬ)",
            subtitle: "Архитектура захвата сетевого трафика"
        ) {
            // TUN Mode Row
            trafficModeRow(
                mode: .tun,
                title: "TUN интерфейс (Виртуальный адаптер VPN)",
                icon: "shield.checkered",
                badge: "РЕКОМЕНДУЕТСЯ",
                badgeColor: ModernMacTheme.neonGreen,
                info: (
                    title: "TUN интерфейс (VPN)",
                    summary: "Системный сетевой адаптер macOS.",
                    details: "Перехватывает и шифрует весь сетевой стек Mac: браузеры, Telegram, терминал, SSH и фоновые демоны. Маршрутизация определяет, какие сайты идут в туннель, а какие — напрямую.",
                    recommendation: "Рекомендуется для полной прозрачности и работы любых приложений."
                )
            )
            
            Divider().opacity(0.12).padding(.leading, 42)
            
            // System Proxy Mode Row
            trafficModeRow(
                mode: .systemProxy,
                title: "Системный прокси (HTTP / SOCKS5)",
                icon: "network",
                badge: nil,
                badgeColor: .clear,
                info: (
                    title: "Системный прокси",
                    summary: "Настройка параметров сетевого прокси в macOS.",
                    details: "Работает только в браузерах и программах с явной поддержкой прокси. Не перехватывает системный стек, ICMP-пинг и трафик консоли без явных переменных окружения.",
                    recommendation: "Используйте, если нет прав администратора для создания TUN адаптера."
                )
            )
        }
    }
    
    private func trafficModeRow(
        mode: TrafficMode,
        title: String,
        icon: String,
        badge: String?,
        badgeColor: Color,
        info: (title: String, summary: String, details: String?, recommendation: String?)
    ) -> some View {
        let isSelected = appState.settings.trafficMode == mode
        return HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected ? ModernMacTheme.cyanAccent.opacity(0.18) : Color.white.opacity(0.05))
                    .frame(width: 24, height: 24)
                
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isSelected ? ModernMacTheme.cyanAccent : .white.opacity(0.6))
            }
            
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.85))
                
                if let badge = badge {
                    Text(badge)
                        .font(.system(size: 8, weight: .heavy, design: .monospaced))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(Capsule().fill(badgeColor.opacity(0.2)))
                        .foregroundStyle(badgeColor)
                }
            }
            
            Spacer()
            
            // Radio Button matching macOS Reference
            MacRadioButton(
                isSelected: isSelected,
                accentColor: ModernMacTheme.neonYellow
            ) {
                withAnimation(ModernMacTheme.smoothSpring) {
                    appState.settings.trafficMode = mode
                    appState.saveSettings()
                }
            }
            
            // Info popover button
            InfoPopoverButton(
                title: info.title,
                summary: info.summary,
                details: info.details,
                recommendation: info.recommendation
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(minHeight: 38)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(ModernMacTheme.smoothSpring) {
                appState.settings.trafficMode = mode
                appState.saveSettings()
            }
        }
    }
    
    // MARK: - Section 2: Stealth Engine (Profiles & Contextual Config)
    private var stealthEngineGroup: some View {
        SettingsCardGroup(
            title: "ДВИЖОК МАСКИРОВКИ (STEALTH ENGINE)",
            subtitle: "Стратегия защиты трафика от ТСПУ"
        ) {
            // Profile 1: Standard Reality
            stealthProfileRow(
                profile: .standardReality,
                icon: "shield.checkered",
                iconColor: ModernMacTheme.neonYellow,
                badge: "СТАНДАРТ",
                badgeColor: ModernMacTheme.neonYellow,
                info: (
                    title: "Standard Reality (VLESS + REALITY)",
                    summary: "Прямое защищенное соединение с TLS-маскировкой.",
                    details: "Использует протокол VLESS с эмуляцией TLS-рукопожатия под популярные зарубежные сайты. Обеспечивает наивысшую скорость и минимальную задержку сети.",
                    recommendation: "Основной и рекомендуемый режим работы по умолчанию."
                )
            )
            
            Divider().opacity(0.12).padding(.leading, 42)
            
            // Profile 2: CDN Fronting (XHTTP)
            stealthProfileRow(
                profile: .cdnFronting,
                icon: "cloud.fill",
                iconColor: ModernMacTheme.cyanAccent,
                badge: "XHTTP RELAY",
                badgeColor: ModernMacTheme.cyanAccent,
                info: (
                    title: "CDN Fronting (XHTTP)",
                    summary: "Транспорт XHTTP через белые списки российских CDN.",
                    details: "Перенаправляет сетевой трафик через доверенные CDN-сети (VK Cloud, Yandex Cloud), обходя блокировки нестандартных протоколов со стороны ТСПУ.",
                    recommendation: "Используйте при жесткой блокировке прямого TLS/TCP соединения."
                )
            )
            
            // Contextual parameters for CDN Fronting
            if appState.settings.stealthProfile == .cdnFronting {
                VStack(spacing: 8) {
                    // CDN Host
                    HStack(spacing: 8) {
                        Text("CDN Host (SNI):")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(width: 95, alignment: .leading)
                        
                        TextField("cdn.yandex.net", text: $appState.settings.cdnHost)
                            .textFieldStyle(.plain)
                            .font(.system(size: 11, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color.white.opacity(0.06))
                                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5))
                            )
                        
                        HStack(spacing: 4) {
                            presetChip("cdn.yandex.net", text: $appState.settings.cdnHost)
                            presetChip("cdn.vk.com", text: $appState.settings.cdnHost)
                            presetChip("cdn.cloudflare.net", text: $appState.settings.cdnHost)
                        }
                    }
                    
                    // CDN Path
                    HStack(spacing: 8) {
                        Text("XHTTP Path:")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(width: 95, alignment: .leading)
                        
                        TextField("/xhttp-stream", text: $appState.settings.cdnPath)
                            .textFieldStyle(.plain)
                            .font(.system(size: 11, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color.white.opacity(0.06))
                                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5))
                            )
                        
                        HStack(spacing: 4) {
                            presetChip("/", text: $appState.settings.cdnPath)
                            presetChip("/xhttp-stream", text: $appState.settings.cdnPath)
                            presetChip("/cdn-data", text: $appState.settings.cdnPath)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.02))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            Divider().opacity(0.12).padding(.leading, 42)
            
            // Profile 3: WebRTC Camouflage
            stealthProfileRow(
                profile: .webrtcCamouflage,
                icon: "video.fill",
                iconColor: Color(hex: "BF5AF2"),
                badge: "UDP / SRTP",
                badgeColor: Color(hex: "BF5AF2"),
                info: (
                    title: "WebRTC Camouflage",
                    summary: "Мимикрия VPN-трафика под аудио/видеоконференции.",
                    details: "Маскирует пакеты данных под медиа-стриминг WebRTC (UDP/SRTP). Эффективно против DPI, настроенных на фильтрацию чистого VPN трафика.",
                    recommendation: "Используйте для обхода строгой эвристической фильтрации."
                )
            )
            
            // Contextual parameters for WebRTC Camouflage
            if appState.settings.stealthProfile == .webrtcCamouflage {
                VStack(spacing: 6) {
                    HStack(spacing: 8) {
                        Text("WebRTC SNI:")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(width: 95, alignment: .leading)
                        
                        TextField("meet.google.com", text: $appState.settings.webrtcSni)
                            .textFieldStyle(.plain)
                            .font(.system(size: 11, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color.white.opacity(0.06))
                                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5))
                            )
                        
                        HStack(spacing: 4) {
                            presetChip("meet.google.com", text: $appState.settings.webrtcSni)
                            presetChip("webrtc.zoom.us", text: $appState.settings.webrtcSni)
                            presetChip("teams.microsoft.com", text: $appState.settings.webrtcSni)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.02))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            Divider().opacity(0.12).padding(.leading, 42)
            
            // Profile 4: HTTP/3 QUIC Masquerade
            stealthProfileRow(
                profile: .quicMasquerade,
                icon: "bolt.horizontal.circle.fill",
                iconColor: ModernMacTheme.neonGreen,
                badge: "H3 / UDP",
                badgeColor: ModernMacTheme.neonGreen,
                info: (
                    title: "HTTP/3 QUIC Masquerade",
                    summary: "Инкапсуляция трафика в UDP-дейтаграммы стандарта HTTP/3.",
                    details: "Полностью обходит фильтрацию TCP-сессий со стороны ТСПУ за счет использования протокола XHTTP stream-one H3 поверх чистого UDP. Устойчив к блокировкам TLS ClientHello.",
                    recommendation: "Используйте при полной блокировке или сильном троттлинге TCP-соединений."
                )
            )
            
            Divider().opacity(0.12).padding(.leading, 12)
            
            // Collapsible Advanced Modifiers Row
            Button(action: {
                withAnimation(ModernMacTheme.smoothSpring) {
                    isModifiersExpanded.toggle()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(ModernMacTheme.neonYellow)
                        .rotationEffect(.degrees(isModifiersExpanded ? 90 : 0))
                    
                    Text("Продвинутые модификаторы (Micro-Sessions & Port Hopping)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                    
                    Spacer()
                    
                    let activeCount = (appState.settings.enableMicroSessions ? 1 : 0) + (appState.settings.enablePortHopping ? 1 : 0)
                    if activeCount > 0 {
                        Text("\(activeCount) АКТИВНО")
                            .font(.system(size: 8, weight: .heavy, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(ModernMacTheme.neonYellow.opacity(0.2)))
                            .foregroundStyle(ModernMacTheme.neonYellow)
                    } else {
                        Text("СКРЫТО")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Capsule().fill(Color.white.opacity(0.06)))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
            }
            .buttonStyle(.plain)
            
            // Expanded modifiers inside
            if isModifiersExpanded {
                VStack(spacing: 0) {
                    Divider().opacity(0.12).padding(.leading, 42)
                    
                    // Micro-sessions
                    SettingsRowView(
                        icon: "clock.arrow.2.circlepath",
                        iconColor: ModernMacTheme.neonYellow,
                        title: "Микро-сессии (Micro-Sessions)",
                        badge: "ANTI-HEURISTIC",
                        badgeColor: ModernMacTheme.neonYellow,
                        info: (
                            title: "Микро-сессии (Micro-Sessions)",
                            summary: "Частая принудительная ротация короткоживущих сессий связи.",
                            details: "Предотвращает накопление сигнатурной и эвристической статистики DPI-анализаторами при длительных непрерывных скачиваниях.",
                            recommendation: "Рекомендуется включать при разрывах длительных TCP-соединений."
                        )
                    ) {
                        GoldenToggle(isOn: $appState.settings.enableMicroSessions)
                    }
                    
                    Divider().opacity(0.12).padding(.leading, 42)
                    
                    // Port Hopping
                    SettingsRowView(
                        icon: "arrow.triangle.branch",
                        iconColor: ModernMacTheme.cyanAccent,
                        title: "Динамический Port Hopping",
                        badge: "ANTI-BAN",
                        badgeColor: ModernMacTheme.cyanAccent,
                        info: (
                            title: "Динамический Port Hopping",
                            summary: "Периодическая ротация целевых портов подключения.",
                            details: "Защищает соединение от точечных блокировок по комбинациям IP:Port со стороны ТСПУ и DPI провайдера.",
                            recommendation: "Требует поддержки пула портов на стороне сервера."
                        )
                    ) {
                        GoldenToggle(isOn: $appState.settings.enablePortHopping)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
    
    private func stealthProfileRow(
        profile: StealthProfile,
        icon: String,
        iconColor: Color,
        badge: String,
        badgeColor: Color,
        info: (title: String, summary: String, details: String?, recommendation: String?)
    ) -> some View {
        let isSelected = appState.settings.stealthProfile == profile
        return HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected ? iconColor.opacity(0.18) : Color.white.opacity(0.05))
                    .frame(width: 24, height: 24)
                
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isSelected ? iconColor : .white.opacity(0.6))
            }
            
            HStack(spacing: 6) {
                Text(profile.rawValue)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.85))
                
                Text(badge)
                    .font(.system(size: 8, weight: .heavy, design: .monospaced))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .background(Capsule().fill(badgeColor.opacity(0.2)))
                    .foregroundStyle(badgeColor)
            }
            
            Spacer()
            
            MacRadioButton(
                isSelected: isSelected,
                accentColor: ModernMacTheme.neonYellow
            ) {
                withAnimation(ModernMacTheme.smoothSpring) {
                    appState.settings.stealthProfile = profile
                    appState.saveSettings()
                }
            }
            
            InfoPopoverButton(
                title: info.title,
                summary: info.summary,
                details: info.details,
                recommendation: info.recommendation
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(minHeight: 38)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(ModernMacTheme.smoothSpring) {
                appState.settings.stealthProfile = profile
                appState.saveSettings()
            }
        }
    }
    
    // MARK: - Section 3: Fine Anti-DPI Tuning (Presets & Fragmentation & Noise)
    private var antiDpiGroup: some View {
        SettingsCardGroup(
            title: "ТОНКАЯ НАСТРОЙКА ОБХОДА DPI (ТСПУ / ПАКЕТЫ)",
            subtitle: "Маскировка TLS ClientHello и генерация шума"
        ) {
            // Anti-DPI Quick Presets Bar
            HStack(spacing: 6) {
                Text("Пресеты DPI:")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                
                antiDpiPresetChip(title: "Мягкий (Mild)", presetKey: "mild")
                antiDpiPresetChip(title: "Агрессивный (Aggressive)", presetKey: "aggressive")
                antiDpiPresetChip(title: "Кастомный", presetKey: "custom")
                antiDpiPresetChip(title: "Отключено", presetKey: "off")
                
                Spacer()
                
                InfoPopoverButton(
                    title: "Пресеты обхода ТСПУ / DPI",
                    summary: "Быстрая конфигурация фрагментации пакетов и шума.",
                    details: "• Мягкий: фрагментация только ClientHello (100-200 байт), без шума. Высокая скорость.\n• Агрессивный: фрагментация 1-3 пакетов + псевдослучайный шум. Позволяет обходить жесткую цензуру.\n• Кастомный: ручная настройка параметров фрагментов и задержек под вашего провайдера.",
                    recommendation: "Рекомендуется выбрать Мягкий для повседневного серфинга."
                )
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 6)
            
            Divider().opacity(0.12).padding(.leading, 12)
            
            // Fragmentation Row
            SettingsRowView(
                icon: "scissors",
                iconColor: ModernMacTheme.neonYellow,
                title: "Фрагментация TLS ClientHello",
                badge: "DPI BYPASS",
                badgeColor: ModernMacTheme.cyanAccent,
                info: (
                    title: "Фрагментация TLS ClientHello",
                    summary: "Разбивает первое рукопожатие TLS на мелкие фрагменты.",
                    details: "Предотвращает обнаружение имени сервера (SNI) детекторами ТСПУ и DPI провайдеров без снижения скорости интернета.",
                    recommendation: "Рекомендуется включить, если зарубежные сайты перестают открываться."
                )
            ) {
                GoldenToggle(isOn: $appState.settings.fragmentEnabled)
            }
            
            // Nested parameters if enabled
            if appState.settings.fragmentEnabled {
                VStack(spacing: 6) {
                    HStack(spacing: 8) {
                        parameterField(label: "Пакеты:", text: $appState.settings.fragmentPackets, presets: ["tlshello", "1-3", "1-5"])
                        parameterField(label: "Длина (байт):", text: $appState.settings.fragmentLength, presets: ["100-200", "50-100", "10-30"])
                        parameterField(label: "Интервал (мс):", text: $appState.settings.fragmentInterval, presets: ["10-20", "5-10", "1-5"])
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.02))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            Divider().opacity(0.12).padding(.leading, 42)
            
            // Noise Injection Row
            let isNoiseBlockedByStreaming = appState.settings.streamingMimicryEnabled
            SettingsRowView(
                icon: "waveform.path.ecg",
                iconColor: isNoiseBlockedByStreaming ? .white.opacity(0.4) : ModernMacTheme.cyanAccent,
                title: "Инъекция шума (Noises / Padding)",
                badge: isNoiseBlockedByStreaming ? "СТРИМИНГ (ВЫКЛ)" : "ANTI-HEURISTIC",
                badgeColor: isNoiseBlockedByStreaming ? ModernMacTheme.orangeWarning : ModernMacTheme.neonYellow,
                info: (
                    title: "Инъекция шума (Noises)",
                    summary: "Генерирует маскировочные псевдослучайные пакеты перед установкой сессии.",
                    details: "Сбивает статистический и нейросетевой анализ глубоких фильтров пакетов (DPI) провайдера. При активной мимикрии под стриминг шум блокируется, чтобы не разрушать сигнатуру видеопотока.",
                    recommendation: "Эффективно при блокировках по характеру трафика."
                )
            ) {
                GoldenToggle(isOn: $appState.settings.noiseEnabled)
                    .disabled(isNoiseBlockedByStreaming)
            }
            
            if isNoiseBlockedByStreaming {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 10))
                        .foregroundStyle(ModernMacTheme.orangeWarning)
                    Text("Заблокировано: при активной мимикрии под стриминг случайный шум отключается во избежание разрушения сигнатуры видеопотока.")
                        .font(.system(size: 10))
                        .foregroundStyle(ModernMacTheme.orangeWarning.opacity(0.85))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 4)
            } else if appState.settings.noiseEnabled {
                VStack(spacing: 6) {
                    HStack(spacing: 8) {
                        // Type Selector
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Тип шума:")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.white.opacity(0.6))
                            HStack(spacing: 3) {
                                typeSelectButton(title: "rand", label: "Rand", current: $appState.settings.noiseType)
                                typeSelectButton(title: "base64", label: "Base64", current: $appState.settings.noiseType)
                                typeSelectButton(title: "str", label: "Str", current: $appState.settings.noiseType)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        parameterField(label: "Размер пакета:", text: $appState.settings.noisePacket, presets: ["50-100", "10-50", "100-200"])
                        parameterField(label: "Задержка (мс):", text: $appState.settings.noiseDelay, presets: ["10-20", "5-10", "20-40"])
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.02))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
    
    // MARK: - Section 4: Advanced Anti-DPI & Stealth (Proxy Chains, Streaming Mimicry, Temporal Shaping)
    private var advancedAntiDpiGroup: some View {
        SettingsCardGroup(
            title: "ПРОДВИНУТЫЕ МЕХАНИЗМЫ МАСКИРОВКИ (ADVANCED ANTI-DPI)",
            subtitle: "Каскадирование, потоковая мимикрия и рандомизация таймингов"
        ) {
            // Proxy Chains
            let canUseProxyChains = appState.servers.count >= 2
            SettingsRowView(
                icon: "link",
                iconColor: canUseProxyChains ? ModernMacTheme.cyanAccent : .white.opacity(0.4),
                title: "Каскадирование прокси (Proxy Chains)",
                badge: !canUseProxyChains ? "< 2 СЕРВЕРОВ" : (appState.settings.proxyChainEnabled ? "RELAY" : "ВЫКЛ"),
                badgeColor: !canUseProxyChains ? ModernMacTheme.orangeWarning : (appState.settings.proxyChainEnabled ? ModernMacTheme.cyanAccent : .white.opacity(0.4)),
                info: (
                    title: "Каскадирование прокси (Proxy Chains)",
                    summary: "Маршрутизация трафика через промежуточный relay-сервер (двойной хоп).",
                    details: "Трафик сначала отправляется на промежуточный узел (Relay), а оттуда направляется на целевой выходной сервер. Полностью скрывает целевой сервер от местного провайдера.",
                    recommendation: "Используйте для обхода точечной блокировки IP-адреса целевого сервера."
                )
            ) {
                GoldenToggle(isOn: $appState.settings.proxyChainEnabled)
                    .disabled(!canUseProxyChains)
            }
            
            if !canUseProxyChains {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle")
                        .font(.system(size: 10))
                        .foregroundStyle(ModernMacTheme.orangeWarning)
                    Text("Для создания цепочки добавьте минимум 2 сервера")
                        .font(.system(size: 10).italic())
                        .foregroundStyle(ModernMacTheme.orangeWarning.opacity(0.85))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 4)
            } else if appState.settings.proxyChainEnabled {
                HStack(spacing: 8) {
                    Text("Relay-сервер:")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 95, alignment: .leading)
                    
                    let availableRelays = appState.servers.filter { $0.id != appState.selectedServerId }
                    if availableRelays.isEmpty {
                        Text("Нет других серверов для цепочки")
                            .font(.system(size: 11).italic())
                            .foregroundStyle(.white.opacity(0.4))
                    } else {
                        Picker("", selection: $appState.settings.proxyChainRelayId) {
                            Text("Выберите сервер...").tag(nil as UUID?)
                            ForEach(availableRelays) { srv in
                                Text("\(srv.name) (\(srv.address))").tag(srv.id as UUID?)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(ModernMacTheme.cyanAccent)
                        .labelsHidden()
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.02))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            Divider().opacity(0.12).padding(.leading, 42)
            
            // Streaming Mimicry
            SettingsRowView(
                icon: "play.tv.fill",
                iconColor: ModernMacTheme.neonYellow,
                title: "Мимикрия под видеостриминг (Streaming Mimicry)",
                badge: appState.settings.streamingMimicryEnabled ? "HLS / DASH" : "ВЫКЛ",
                badgeColor: appState.settings.streamingMimicryEnabled ? ModernMacTheme.neonYellow : .white.opacity(0.4),
                info: (
                    title: "Мимикрия под видеостриминг",
                    summary: "Подмена заголовков User-Agent и форматов на AppleCoreMedia / HLS.",
                    details: "ТСПУ и сотовые операторы часто дают максимальный приоритет и не режут трафик Apple TV, Netflix и YouTube. Эта функция маскирует сетевые запросы под нативный видеотрафик macOS.",
                    recommendation: "Помогает при жестком троттлинге нестандартных протоколов сотовыми сетями."
                )
            ) {
                GoldenToggle(isOn: $appState.settings.streamingMimicryEnabled)
            }
            
            if appState.settings.streamingMimicryEnabled {
                HStack(spacing: 8) {
                    Text("CDN домен:")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 95, alignment: .leading)
                    
                    TextField("video.cloudflare.com", text: $appState.settings.streamingMimicryCdn)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.white.opacity(0.06))
                                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5))
                        )
                    
                    HStack(spacing: 4) {
                        presetChip("video.cloudflare.com", text: $appState.settings.streamingMimicryCdn)
                        presetChip("media.fastly.net", text: $appState.settings.streamingMimicryCdn)
                        presetChip("hls.itunes.apple.com", text: $appState.settings.streamingMimicryCdn)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.02))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            Divider().opacity(0.12).padding(.leading, 42)
            
            // Temporal Shaping
            SettingsRowView(
                icon: "waveform.badge.magnifyingglass",
                iconColor: Color(hex: "BF5AF2"),
                title: "Временное шейпирование (Temporal Traffic Shaping)",
                badge: appState.settings.temporalShapingEnabled ? "JITTER" : "ВЫКЛ",
                badgeColor: appState.settings.temporalShapingEnabled ? Color(hex: "BF5AF2") : .white.opacity(0.4),
                info: (
                    title: "Временное шейпирование пакетов",
                    summary: "Рандомизация временных интервалов и добавление искусственного джиттера.",
                    details: "Разрушает монотонные тайминг-паттерны передачи данных, которые нейросетевые детекторы DPI используют для идентификации зашифрованных VPN-сессий.",
                    recommendation: "Рекомендуется режим 'Динамический' при частых обрывах соединения через 2-3 минуты."
                )
            ) {
                GoldenToggle(isOn: $appState.settings.temporalShapingEnabled)
            }
            
            if appState.settings.temporalShapingEnabled {
                HStack(spacing: 8) {
                    Text("Интенсивность:")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 95, alignment: .leading)
                    
                    Picker("", selection: $appState.settings.temporalShapingIntensity) {
                        ForEach(TemporalShapingIntensity.allCases) { intensity in
                            Text(intensity.rawValue).tag(intensity)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Color(hex: "BF5AF2"))
                    .labelsHidden()
                    
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.02))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
    
    // MARK: - Section 5: Connection Guard & Failover
    private var connectionGuardGroup: some View {
        SettingsCardGroup(
            title: "НАДЁЖНОСТЬ СОЕДИНЕНИЯ (CONNECTION GUARD)",
            subtitle: "Автоматическое восстановление, failover и защита от утечки IP"
        ) {
            // Auto-Reconnect
            SettingsRowView(
                icon: "arrow.clockwise.circle.fill",
                iconColor: ModernMacTheme.neonGreen,
                title: "Автопереподключение (Auto-Reconnect)",
                badge: appState.settings.autoReconnectEnabled ? "АКТИВНО" : "ВЫКЛ",
                badgeColor: appState.settings.autoReconnectEnabled ? ModernMacTheme.neonGreen : .white.opacity(0.4),
                info: (
                    title: "Автопереподключение",
                    summary: "Автоматический повтор соединения при внезапном разрыве сессии или сбое ядра.",
                    details: "Использует экспоненциальную задержку (exponential backoff) до достижения заданного лимита попыток.",
                    recommendation: "Рекомендуется для стабильной работы в нестабильных сетях и мобильном интернете."
                )
            ) {
                GoldenToggle(isOn: $appState.settings.autoReconnectEnabled)
            }
            
            if appState.settings.autoReconnectEnabled {
                HStack(spacing: 8) {
                    Text("Максимум попыток:")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                    
                    Picker("", selection: $appState.settings.maxReconnectAttempts) {
                        Text("3 попытки").tag(3)
                        Text("5 попыток (стандарт)").tag(5)
                        Text("10 попыток").tag(10)
                    }
                    .pickerStyle(.menu)
                    .tint(ModernMacTheme.neonGreen)
                    .labelsHidden()
                    .frame(width: 170)
                    
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.02))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            Divider().opacity(0.12).padding(.leading, 42)
            
            // Auto-Fallback
            SettingsRowView(
                icon: "arrow.triangle.swap",
                iconColor: ModernMacTheme.cyanAccent,
                title: "Автопереключение на резервный сервер (Auto-Fallback)",
                badge: appState.settings.autoFallbackEnabled ? "SMART PING" : "ВЫКЛ",
                badgeColor: appState.settings.autoFallbackEnabled ? ModernMacTheme.cyanAccent : .white.opacity(0.4),
                info: (
                    title: "Автопереключение на резервный сервер",
                    summary: "Мгновенное переключение на сервер с наилучшим пингом при недоступности текущего узла.",
                    details: "Срабатывает, если исчерпаны попытки переподключения или сервер не отвечает на пинг. Предотвращает полную потерю доступа к интернету.",
                    recommendation: "Рекомендуется держать включенным при наличии 2 и более серверов в подписке."
                )
            ) {
                GoldenToggle(isOn: $appState.settings.autoFallbackEnabled)
            }
            
            if appState.settings.autoFallbackEnabled {
                HStack(spacing: 8) {
                    Text("Порог сбоев для смены:")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                    
                    Picker("", selection: $appState.settings.fallbackFailThreshold) {
                        Text("1 сбой (быстро)").tag(1)
                        Text("2 сбоя (стандарт)").tag(2)
                        Text("3 сбоя").tag(3)
                        Text("5 сбоев").tag(5)
                    }
                    .pickerStyle(.menu)
                    .tint(ModernMacTheme.cyanAccent)
                    .labelsHidden()
                    .frame(width: 170)
                    
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.02))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            Divider().opacity(0.12).padding(.leading, 42)
            
            // Kill Switch
            SettingsRowView(
                icon: "shield.slash.fill",
                iconColor: ModernMacTheme.redDanger,
                title: "Аварийный выключатель трафика (Kill Switch)",
                badge: appState.settings.killSwitchEnabled ? "FAIL-CLOSED" : "ВЫКЛ",
                badgeColor: appState.settings.killSwitchEnabled ? ModernMacTheme.redDanger : .white.opacity(0.4),
                info: (
                    title: "Kill Switch (Аварийный выключатель)",
                    summary: "Блокирует любой незащищенный трафик при падении VPN.",
                    details: "В случае непредвиденного падения ядра или разрыва соединения перенаправляет весь трафик в черную дыру (blackhole 127.0.0.1:1). Ни один байт данных не уйдет в сеть с вашего реального IP. При ручном отключении пользователем блокировка немедленно снимается.",
                    recommendation: "Включайте для гарантированной конфиденциальности и защиты реального IP-адреса."
                )
            ) {
                GoldenToggle(isOn: $appState.settings.killSwitchEnabled, accentColor: ModernMacTheme.redDanger)
            }
        }
    }
    
    // MARK: - Section 6: Secure DNS (DoH)
    private var secureDnsGroup: some View {
        SettingsCardGroup(
            title: "БЕЗОПАСНЫЙ DNS (DNS OVER HTTPS)",
            subtitle: "Шифрование запросов к доменам"
        ) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(ModernMacTheme.cyanAccent.opacity(0.18))
                        .frame(width: 24, height: 24)
                    
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(ModernMacTheme.cyanAccent)
                }
                
                Text("DoH Сервер:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                
                TextField("https://1.1.1.1/dns-query", text: $appState.settings.dnsServer)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5))
                    )
                
                InfoPopoverButton(
                    title: "Безопасный DNS (DoH)",
                    summary: "Шифрование DNS-запросов через протокол HTTPS.",
                    details: "Предотвращает перехват, подмену и отслеживание посещаемых сайтов интернет-провайдером (DNS Hijacking / Poisoning).",
                    recommendation: "Рекомендуется Cloudflare (1.1.1.1) или Quad9 для максимальной безопасности."
                )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(minHeight: 38)
            
            // DNS Preset Chips
            HStack(spacing: 6) {
                Text("Пресеты:")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
                
                dnsChip("Cloudflare", url: "https://1.1.1.1/dns-query")
                dnsChip("Google", url: "https://dns.google/dns-query")
                dnsChip("AdGuard", url: "https://dns.adguard-dns.com/dns-query")
                dnsChip("Quad9", url: "https://dns.quad9.net/dns-query")
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
    }
    
    // MARK: - Section 7: Local Ports
    private var localPortsAndLanGroup: some View {
        SettingsCardGroup(
            title: "ЛОКАЛЬНЫЕ ВХОДЯЩИЕ ПОРТЫ (INBOUNDS)",
            subtitle: "Прямое подключение терминала, cURL и сторонних программ"
        ) {
            // Local Ports Row
            HStack(spacing: 12) {
                // SOCKS5
                HStack(spacing: 6) {
                    Text("SOCKS5:")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                    
                    TextField("10808", value: $appState.settings.socksPort, format: .number.grouping(.never))
                        .textFieldStyle(.plain)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .frame(width: 65)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.white.opacity(0.06))
                                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5))
                        )
                }
                
                // HTTP
                HStack(spacing: 6) {
                    Text("HTTP/HTTPS:")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                    
                    TextField("10809", value: $appState.settings.httpPort, format: .number.grouping(.never))
                        .textFieldStyle(.plain)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .frame(width: 65)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.white.opacity(0.06))
                                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5))
                        )
                }
                
                Spacer()
                
                InfoPopoverButton(
                    title: "Локальные порты Xray",
                    summary: "Порты для ручной настройки прокси в сторонних приложениях.",
                    details: "Указывайте эти порты в Telegram (SOCKS5), терминале (export ALL_PROXY=socks5://127.0.0.1:10808), cURL или специализированных браузерах.",
                    recommendation: "Стандартные порты: 10808 для SOCKS5, 10809 для HTTP."
                )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(minHeight: 38)
        }
    }
    
    // MARK: - Section 8: System & Access Automation
    private var systemAndAccessGroup: some View {
        SettingsCardGroup(
            title: "СИСТЕМА И ДОСТУП",
            subtitle: "Автозапуск, доступ в локальной сети и фоновые службы"
        ) {
            // Launch at login
            SettingsRowView(
                icon: "macwindow.and.cursorarrow",
                iconColor: ModernMacTheme.cyanAccent,
                title: "Запуск при входе в систему (Launch at Login)",
                badge: "macOS Service",
                badgeColor: .white.opacity(0.6),
                info: (
                    title: "Запуск при входе в систему",
                    summary: "Автоматически открывать приложение в строке меню при включении компьютера.",
                    details: "Регистрирует приложение в системных объектах входа macOS (SMAppService) для работы в фоне.",
                    recommendation: "Рекомендуется для постоянной защиты соединения."
                )
            ) {
                GoldenToggle(isOn: $appState.settings.launchAtLogin)
            }
            
            Divider().opacity(0.12).padding(.leading, 42)
            
            // LAN Sharing Row
            SettingsRowView(
                icon: "network",
                iconColor: ModernMacTheme.neonGreen,
                title: "Разрешить подключения из локальной сети (Share LAN)",
                badge: appState.settings.allowLanConnections ? "0.0.0.0 (Все)" : "127.0.0.1",
                badgeColor: appState.settings.allowLanConnections ? ModernMacTheme.neonGreen : .white.opacity(0.5),
                info: (
                    title: "Доступ в локальной сети (Share LAN)",
                    summary: "Слушать входящие порты на адресе 0.0.0.0 вместо 127.0.0.1.",
                    details: "Позволяет смартфонам (iPhone, Android), Smart TV и другим компьютерам в вашей домашней Wi-Fi сети использовать прокси на этом Mac.",
                    recommendation: "Для раздачи настройте на телефоне прокси с IP-адресом вашего Mac в Wi-Fi сети."
                )
            ) {
                GoldenToggle(isOn: $appState.settings.allowLanConnections)
            }
            
            Divider().opacity(0.12).padding(.leading, 42)
            
            // Auto-connect
            SettingsRowView(
                icon: "bolt.fill",
                iconColor: ModernMacTheme.neonYellow,
                title: "Автоматическое подключение к VPN",
                info: (
                    title: "Автоподключение",
                    summary: "Сразу запускает туннель к последнему выбранному серверу при старте приложения.",
                    details: "Исключает необходимость ручного нажатия кнопки «Подключить» после перезагрузки Mac.",
                    recommendation: "Удобно при постоянном использовании одного основного сервера."
                )
            ) {
                GoldenToggle(isOn: $appState.settings.autoConnectOnLaunch)
            }
            
            Divider().opacity(0.12).padding(.leading, 42)
            
            // Auto-update
            SettingsRowView(
                icon: "arrow.triangle.2.circlepath",
                iconColor: ModernMacTheme.cyanAccent,
                title: "Фоновое обновление подписок при старте",
                info: (
                    title: "Фоновое обновление подписок",
                    summary: "Загружает свежие серверы и проверяет квоты трафика при запуске программы.",
                    details: "Гарантирует актуальность рабочих конфигураций без ручного нажатия «Обновить подписку».",
                    recommendation: "Рекомендуется оставить включенным."
                )
            ) {
                GoldenToggle(isOn: $appState.settings.autoUpdateSubscriptions)
            }
        }
    }
    
    // MARK: - Reusable Helpers
    private func parameterField(label: String, text: Binding<String>, presets: [String]) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
            
            TextField("", text: text)
                .textFieldStyle(.plain)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                        .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5))
                )
            
            HStack(spacing: 3) {
                ForEach(presets, id: \.self) { p in
                    presetChip(p, text: text)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func presetChip(_ title: String, text: Binding<String>) -> some View {
        let isSelected = text.wrappedValue == title
        return Button(action: {
            withAnimation(ModernMacTheme.smoothSpring) {
                text.wrappedValue = title
            }
        }) {
            Text(title)
                .font(.system(size: 9, weight: isSelected ? .bold : .medium, design: .monospaced))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(isSelected ? ModernMacTheme.cyanAccent.opacity(0.25) : Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(isSelected ? ModernMacTheme.cyanAccent.opacity(0.6) : Color.white.opacity(0.08), lineWidth: 0.5)
                        )
                )
                .foregroundStyle(isSelected ? ModernMacTheme.cyanAccent : .white.opacity(0.7))
        }
        .buttonStyle(.plain)
    }
    
    private func antiDpiPresetChip(title: String, presetKey: String) -> some View {
        let isSelected = isAntiDpiPresetActive(presetKey)
        return Button(action: {
            applyAntiDpiPreset(presetKey)
        }) {
            Text(title)
                .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(isSelected ? ModernMacTheme.neonYellow.opacity(0.25) : Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .strokeBorder(isSelected ? ModernMacTheme.neonYellow.opacity(0.6) : Color.white.opacity(0.1), lineWidth: 0.5)
                        )
                )
                .foregroundStyle(isSelected ? ModernMacTheme.neonYellow : .white.opacity(0.75))
        }
        .buttonStyle(.plain)
    }
    
    private func isAntiDpiPresetActive(_ key: String) -> Bool {
        switch key {
        case "mild":
            return appState.settings.fragmentEnabled && !appState.settings.noiseEnabled &&
                   appState.settings.fragmentPackets == "tlshello" &&
                   appState.settings.fragmentLength == "100-200"
        case "aggressive":
            return appState.settings.fragmentEnabled && appState.settings.noiseEnabled &&
                   appState.settings.fragmentPackets == "1-3" &&
                   appState.settings.fragmentLength == "50-100"
        case "custom":
            return !isAntiDpiPresetActive("mild") && !isAntiDpiPresetActive("aggressive") && !isAntiDpiPresetActive("off")
        case "off":
            return !appState.settings.fragmentEnabled && !appState.settings.noiseEnabled
        default:
            return false
        }
    }
    
    private func applyAntiDpiPreset(_ key: String) {
        withAnimation(ModernMacTheme.smoothSpring) {
            switch key {
            case "mild":
                appState.settings.fragmentEnabled = true
                appState.settings.fragmentPackets = "tlshello"
                appState.settings.fragmentLength = "100-200"
                appState.settings.fragmentInterval = "10-20"
                appState.settings.noiseEnabled = false
            case "aggressive":
                appState.settings.fragmentEnabled = true
                appState.settings.fragmentPackets = "1-3"
                appState.settings.fragmentLength = "50-100"
                appState.settings.fragmentInterval = "5-10"
                appState.settings.noiseEnabled = true
                appState.settings.noiseType = "rand"
                appState.settings.noisePacket = "50-100"
                appState.settings.noiseDelay = "10-20"
            case "custom":
                if !appState.settings.fragmentEnabled && !appState.settings.noiseEnabled {
                    appState.settings.fragmentEnabled = true
                }
            case "off":
                appState.settings.fragmentEnabled = false
                appState.settings.noiseEnabled = false
            default:
                break
            }
            appState.saveSettings()
        }
    }
    
    private func typeSelectButton(title: String, label: String, current: Binding<String>) -> some View {
        let isSelected = current.wrappedValue == title
        return Button(action: {
            withAnimation(ModernMacTheme.smoothSpring) {
                current.wrappedValue = title
            }
        }) {
            Text(label)
                .font(.system(size: 9, weight: isSelected ? .bold : .medium))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(isSelected ? ModernMacTheme.cyanAccent.opacity(0.25) : Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .strokeBorder(isSelected ? ModernMacTheme.cyanAccent.opacity(0.6) : Color.white.opacity(0.1), lineWidth: 0.5)
                        )
                )
                .foregroundStyle(isSelected ? ModernMacTheme.cyanAccent : .white.opacity(0.75))
        }
        .buttonStyle(.plain)
    }
    
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
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(isSelected ? ModernMacTheme.cyanAccent.opacity(0.25) : Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .strokeBorder(isSelected ? ModernMacTheme.cyanAccent.opacity(0.6) : Color.white.opacity(0.1), lineWidth: 0.5)
                        )
                )
                .foregroundStyle(isSelected ? ModernMacTheme.cyanAccent : .white.opacity(0.75))
        }
        .buttonStyle(.plain)
    }
}
