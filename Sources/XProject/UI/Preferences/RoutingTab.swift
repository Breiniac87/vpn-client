import SwiftUI

public struct RoutingTab: View {
    @Bindable var appState: AppState
    @State private var activeListSelection: RoutingTarget = .proxy
    @State private var newRuleText: String = ""
    @State private var newRuleComment: String = ""
    @State private var searchRuleQuery: String = ""
    @State private var presetAppliedMessage: String?
    @State private var showingHappSchemeSheet = false
    
    public init(appState: AppState) {
        self.appState = appState
    }
    
    public var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 12) {
                // MARK: - Section 1: Geo Databases Card (geosite.dat & geoip.dat)
                geoDatabaseCard
                
                // MARK: - Section 2: Routing Mode Selector Card
                SettingsCardGroup(
                    title: "ПРАВИЛА РАЗДЕЛЕНИЯ ТРАФИКА (SPLIT TUNNELING)"
                ) {
                // Header action: Happ schemes
                HStack {
                    Text("Режим маршрутизации")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.55))
                    
                    Spacer()
                    
                    Button(action: { showingHappSchemeSheet = true }) {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 10, weight: .semibold))
                            Text("Схемы Happ (Импорт / Экспорт)")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(ModernMacTheme.cyanAccent.opacity(0.12))
                                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(ModernMacTheme.cyanAccent.opacity(0.3), lineWidth: 0.5))
                        )
                        .foregroundStyle(ModernMacTheme.cyanAccent)
                    }
                    .buttonStyle(.plain)
                    .help("Экспорт или импорт схем маршрутизации в формате Happ")
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 2)
                
                // Rule-based mode row
                routingModeRow(
                    mode: .ruleBased,
                    title: "По правилам (Split Tunneling)",
                    icon: "arrow.triangle.branch",
                    badge: "УМНЫЙ",
                    badgeColor: ModernMacTheme.neonGreen,
                    info: (
                        title: "Режим по правилам (Split)",
                        summary: "Умное разделение сетевого трафика.",
                        details: "VPN используется только для заблокированных сайтов из списка правил. Российские банки, Госуслуги, маркетплейсы и локальные сервисы работают напрямую на максимальной скорости.",
                        recommendation: "Рекомендуется для повседневного использования."
                    )
                )
                
                Divider().opacity(0.12).padding(.leading, 42)
                
                // Global mode row
                routingModeRow(
                    mode: .global,
                    title: "Глобальный (All Traffic)",
                    icon: "globe.americas.fill",
                    badge: nil,
                    badgeColor: .clear,
                    info: (
                        title: "Глобальный режим туннелирования",
                        summary: "Весь интернет-трафик безусловно направляется через VPN.",
                        details: "Все исходящие соединения всех программ проксируются через выбранный сервер без исключений по IP или доменам.",
                        recommendation: "Используйте для полной изоляции трафика в публичных Wi-Fi сетях."
                    )
                )
            }
            
            // MARK: - FakeDNS & Domain Strategy Settings
            SettingsCardGroup {
                // FakeDNS row
                SettingsRowView(
                    icon: "network.badge.shield.half.filled",
                    iconColor: ModernMacTheme.neonGreen,
                    title: "FakeDNS пул (198.18.0.0/15)",
                    badge: appState.routingConfig.fakeDnsEnabled ? "АКТИВЕН" : nil,
                    badgeColor: ModernMacTheme.neonGreen,
                    info: (
                        title: "FakeDNS пул (198.18.0.0/15)",
                        summary: "Локальный пул виртуальных адресов для ускорения разрешения имен.",
                        details: "Устраняет задержку двойного DNS-запроса при Split Tunneling, отдавая мгновенный локальный IP для доменов из правил.",
                        recommendation: "Рекомендуется для мгновенного отклика при открытии сайтов."
                    )
                ) {
                    GoldenToggle(isOn: $appState.routingConfig.fakeDnsEnabled) { _ in
                        appState.saveRouting()
                    }
                }
                
                Divider().opacity(0.12).padding(.leading, 42)
                
                // Domain Strategy row
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(ModernMacTheme.cyanAccent.opacity(0.15))
                            .frame(width: 24, height: 24)
                        
                        Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(ModernMacTheme.cyanAccent)
                    }
                    
                    Text("Стратегия доменов:")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                    
                    Spacer()
                    
                    Picker("", selection: $appState.routingConfig.domainStrategy) {
                        Text("IPIfNonMatch (Авто)").tag("IPIfNonMatch")
                        Text("AsIs (Прямая)").tag("AsIs")
                        Text("IPOnDemand (По запросу)").tag("IPOnDemand")
                    }
                    .pickerStyle(.menu)
                    .frame(width: 170)
                    .onChange(of: appState.routingConfig.domainStrategy) { _, _ in
                        appState.saveRouting()
                    }
                    
                    InfoPopoverButton(
                        title: "Стратегия разрешения доменов",
                        summary: "Алгоритм сопоставления правил маршрутизации в ядре Xray.",
                        details: "• IPIfNonMatch: проверяет совпадение по домену, а если совпадений нет — резолвит IP для проверки по гео-базе.\n• AsIs: сопоставляет только имя домена как есть без DNS-запроса.\n• IPOnDemand: резолвит IP при первой необходимости.",
                        recommendation: "IPIfNonMatch является наиболее надежной стратегией."
                    )
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(minHeight: 38)
            }
            
            if appState.routingConfig.mode == .global {
                // MARK: - Global Mode Compact Info Card
                SettingsCardGroup {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(ModernMacTheme.cyanAccent.opacity(0.15))
                                .frame(width: 36, height: 36)
                            
                            Image(systemName: "globe.americas.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(ModernMacTheme.cyanAccent)
                        }
                        
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Глобальный режим туннелирования (All Traffic)")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white)
                            
                            Text("Все сетевые соединения macOS безусловно проксируются через выбранный сервер без разделения по доменам или IP-адресам.")
                                .font(.system(size: 10))
                                .foregroundStyle(.white.opacity(0.55))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        
                        Spacer()
                    }
                    .padding(12)
                }
            } else {
                // MARK: - Split Tunneling Rules Management
                VStack(spacing: 12) {
                    // 1. List Switcher (Proxy vs Direct)
                    HStack(spacing: 8) {
                        listTabButton(
                            target: .proxy,
                            title: "Пускать через прокси",
                            count: appState.routingConfig.proxyRules.count,
                            icon: "paperplane.fill",
                            accentColor: ModernMacTheme.cyanAccent
                        )
                        
                        listTabButton(
                            target: .direct,
                            title: "Пускать напрямую / Bypass",
                            count: appState.routingConfig.directRules.count,
                            icon: "bolt.fill",
                            accentColor: ModernMacTheme.neonGreen
                        )
                    }
                    
                    // 2. Add New Rule Bar
                    HStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 13))
                                .foregroundStyle(ModernMacTheme.cyanAccent)
                            
                            TextField(
                                activeListSelection == .proxy ? "Домен или правило (напр. gemini.google.com, geosite:openai)" : "Домен или IP (напр. gosuslugi.ru, geoip:ru)",
                                text: $newRuleText
                            )
                            .textFieldStyle(.plain)
                            .font(.system(size: 12, design: .monospaced))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.white.opacity(0.06))
                                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5))
                        )
                        
                        TextField("Примечание (опционально)", text: $newRuleComment)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .frame(width: 170)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.white.opacity(0.06))
                                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5))
                            )
                        
                        Button(action: addNewRule) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                    .font(.system(size: 11, weight: .bold))
                                Text("Добавить")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(newRuleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.white.opacity(0.08) : ModernMacTheme.cyanAccent.opacity(0.25))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .strokeBorder(newRuleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.clear : ModernMacTheme.cyanAccent.opacity(0.5), lineWidth: 1)
                                    )
                            )
                            .foregroundStyle(newRuleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.white.opacity(0.4) : ModernMacTheme.cyanAccent)
                        }
                        .buttonStyle(.plain)
                        .disabled(newRuleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    
                    // 3. Search & Rules Filter Bar
                    HStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.4))
                            
                            TextField("Поиск по списку правил...", text: $searchRuleQuery)
                                .textFieldStyle(.plain)
                                .font(.system(size: 11))
                            
                            if !searchRuleQuery.isEmpty {
                                Button(action: { searchRuleQuery = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.white.opacity(0.4))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.white.opacity(0.04))
                        )
                        
                        Spacer()
                        
                        if let msg = presetAppliedMessage {
                            Text(msg)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(ModernMacTheme.neonGreen)
                                .transition(.opacity)
                        }
                    }
                    
                    // 4. Interactive Rules Table
                    rulesListSection
                    
                    // 5. Quick Presets Bar
                    quickPresetsBar
                }
            }
        }
        .padding(16)
        }
        .tint(ModernMacTheme.cyanAccent)
        .sheet(isPresented: $showingHappSchemeSheet) {
            HappSchemeSheetView(appState: appState)
        }
    }
    
    // MARK: - Geo Database (geosite.dat / geoip.dat) Card
    private var geoDatabaseCard: some View {
        SettingsCardGroup {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(ModernMacTheme.cyanAccent.opacity(0.15))
                        .frame(width: 24, height: 24)
                    
                    Image(systemName: "cylinder.split.1x2.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(ModernMacTheme.cyanAccent)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Базы гео-маршрутизации")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.9))
                        
                        Text("DigneZzZ / jsDelivr")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(ModernMacTheme.cyanAccent.opacity(0.15)))
                            .foregroundStyle(ModernMacTheme.cyanAccent)
                    }
                    
                    Text(geoAssetStatusText)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.45))
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Manual Update Button
                Button(action: {
                    appState.updateGeoAssetsManually()
                }) {
                    HStack(spacing: 5) {
                        if appState.isUpdatingGeoAssets {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        
                        Text(appState.isUpdatingGeoAssets ? "Обновление..." : "Обновить базы")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(appState.isUpdatingGeoAssets ? Color.white.opacity(0.04) : ModernMacTheme.cyanAccent.opacity(0.15))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(appState.isUpdatingGeoAssets ? Color.white.opacity(0.1) : ModernMacTheme.cyanAccent.opacity(0.4), lineWidth: 0.5)
                            )
                    )
                    .foregroundStyle(appState.isUpdatingGeoAssets ? .white.opacity(0.5) : ModernMacTheme.cyanAccent)
                }
                .buttonStyle(.plain)
                .disabled(appState.isUpdatingGeoAssets)
                
                InfoPopoverButton(
                    title: "Базы гео-маршрутизации",
                    summary: "Файлы geosite.dat и geoip.dat для классификации доменов и IP-адресов.",
                    details: "Используются для правил geosite:category-gov-ru, geoip:ru и других категорий для точного разделения трафика.",
                    recommendation: "Обновляются автоматически ежедневно при запуске приложения."
                )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(minHeight: 38)
            
            if appState.isUpdatingGeoAssets {
                VStack(spacing: 4) {
                    ProgressView(value: appState.geoAssetUpdateProgress, total: 1.0)
                        .progressViewStyle(.linear)
                        .tint(ModernMacTheme.cyanAccent)
                    
                    HStack {
                        Text(appState.geoAssetStatusMessage)
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.6))
                        Spacer()
                        Text("\(Int(appState.geoAssetUpdateProgress * 100))%")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(ModernMacTheme.cyanAccent)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
        }
    }
    
    // MARK: - Routing Mode Row Component
    private func routingModeRow(
        mode: ProxyRoutingMode,
        title: String,
        icon: String,
        badge: String?,
        badgeColor: Color,
        info: (title: String, summary: String, details: String?, recommendation: String?)
    ) -> some View {
        let isSelected = appState.routingConfig.mode == mode
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
                    appState.routingConfig.mode = mode
                    appState.saveRouting()
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
                appState.routingConfig.mode = mode
                appState.saveRouting()
            }
        }
    }
    
    private var geoAssetStatusText: String {
        let meta = appState.geoAssetMetadata
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        
        let dateStr: String
        if let d = meta.lastUpdated {
            dateStr = formatter.string(from: d)
        } else {
            dateStr = "Не обновлялись"
        }
        
        if meta.geositeBytes > 0 && meta.geoipBytes > 0 {
            let bFormatter = ByteCountFormatter()
            bFormatter.countStyle = .binary
            let siteStr = bFormatter.string(fromByteCount: Int64(meta.geositeBytes))
            let ipStr = bFormatter.string(fromByteCount: Int64(meta.geoipBytes))
            return "Обновлено: \(dateStr) • geosite: \(siteStr), geoip: \(ipStr) • Авто-проверка: ежедневно"
        } else {
            return "Обновлено: \(dateStr) • Авто-проверка: ежедневно при запуске (тихий режим)"
        }
    }
    
    // MARK: - Mode Button Component
    private func modeButton(title: String, subtitle: String, icon: String, mode: ProxyRoutingMode, badge: String? = nil) -> some View {
        let isSelected = appState.routingConfig.mode == mode
        return Button(action: {
            withAnimation(ModernMacTheme.smoothSpring) {
                appState.routingConfig.mode = mode
                appState.saveRouting()
            }
        }) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(isSelected ? ModernMacTheme.cyanAccent.opacity(0.2) : Color.white.opacity(0.06))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isSelected ? ModernMacTheme.cyanAccent : .white.opacity(0.6))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(isSelected ? .white : .white.opacity(0.85))
                        
                        if let b = badge {
                            Text(b)
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(ModernMacTheme.neonGreen)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(ModernMacTheme.neonGreen.opacity(0.15)))
                        }
                    }
                    
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(ModernMacTheme.cyanAccent)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? ModernMacTheme.cyanAccent.opacity(0.12) : Color.white.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(isSelected ? ModernMacTheme.cyanAccent.opacity(0.4) : Color.white.opacity(0.06), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - List Tab Switcher Button
    private func listTabButton(target: RoutingTarget, title: String, count: Int, icon: String, accentColor: Color) -> some View {
        let isSelected = activeListSelection == target
        return Button(action: {
            withAnimation(ModernMacTheme.smoothSpring) {
                activeListSelection = target
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(isSelected ? accentColor : .white.opacity(0.6))
                
                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.7))
                
                Text("\(count)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(
                        Capsule()
                            .fill(isSelected ? accentColor.opacity(0.25) : Color.white.opacity(0.08))
                    )
                    .foregroundStyle(isSelected ? accentColor : .white.opacity(0.6))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.1) : Color.white.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(isSelected ? accentColor.opacity(0.5) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Filtered Rules List
    private var filteredRules: [RoutingRule] {
        let baseRules = (activeListSelection == .proxy)
            ? appState.routingConfig.proxyRules
            : appState.routingConfig.directRules
        
        let q = searchRuleQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return baseRules }
        
        return baseRules.filter {
            $0.value.lowercased().contains(q) ||
            ($0.comment?.lowercased().contains(q) ?? false)
        }
    }
    
    // MARK: - Rules List Section
    private var rulesListSection: some View {
        ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(spacing: 4) {
                if filteredRules.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "tray")
                            .font(.system(size: 28))
                            .foregroundStyle(.white.opacity(0.3))
                        Text(searchRuleQuery.isEmpty ? "Список правил пуст. Добавьте свои домены или примените быстрый пресет." : "Ничего не найдено по запросу '\(searchRuleQuery)'")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.5))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                } else {
                    ForEach(filteredRules) { rule in
                        ruleRow(rule)
                    }
                }
            }
            .padding(.horizontal, 2)
        }
        .frame(minHeight: 180, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.02))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5))
        )
    }
    
    // MARK: - Individual Rule Row
    private func ruleRow(_ rule: RoutingRule) -> some View {
        HStack(spacing: 8) {
            // Protocol / Type Badge
            ruleTypeBadge(for: rule.value)
            
            // Rule Value
            Text(rule.value)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.white)
            
            // Optional Comment
            if let comment = rule.comment, !comment.isEmpty {
                Text("— \(comment)")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Delete button
            Button(action: {
                withAnimation(ModernMacTheme.smoothSpring) {
                    deleteRule(rule)
                }
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(4)
            }
            .buttonStyle(.plain)
            .help("Удалить правило")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.white.opacity(0.03))
        )
    }
    
    // MARK: - Rule Type Badge
    private func ruleTypeBadge(for val: String) -> some View {
        let tag: (String, Color)
        if val.hasPrefix("geosite:") {
            tag = ("GEOSITE", ModernMacTheme.cyanAccent)
        } else if val.hasPrefix("geoip:") {
            tag = ("GEOIP", Color.orange)
        } else if val.hasPrefix("domain:") {
            tag = ("DOMAIN", ModernMacTheme.neonGreen)
        } else if val.hasPrefix("full:") {
            tag = ("EXACT", Color.purple)
        } else {
            tag = ("HOST", Color.white.opacity(0.7))
        }
        
        return Text(tag.0)
            .font(.system(size: 8, weight: .heavy, design: .monospaced))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 4).fill(tag.1.opacity(0.2)))
            .foregroundStyle(tag.1)
    }
    
    // MARK: - Quick Presets Bar
    private var quickPresetsBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("БЫСТРЫЕ ПРЕСЕТЫ ПРАВИЛ:")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.55))
                
                Spacer()
                
                Text("Добавление в 1 клик")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.4))
            }
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 195, maximum: 300), spacing: 8)], spacing: 8) {
                presetChip(
                    title: "🤖 AI (OpenAI, Claude, Gemini)",
                    help: "Добавить правила для ChatGPT, Claude AI, Google Gemini и Perplexity"
                ) {
                    applyAIPreset()
                }
                
                presetChip(
                    title: "🇷🇺 Антизапрет РФ (Instagram, X, FB)",
                    help: "Добавить правила проксирования для заблокированных соцсетей и медиа"
                ) {
                    applyRFAntiCensorPreset()
                }
                
                presetChip(
                    title: "📺 YouTube & Мультимедиа",
                    help: "Добавить YouTube, Google Video, Spotify и Netflix в прокси"
                ) {
                    applyMediaPreset()
                }
                
                presetChip(
                    title: "💼 Работа (Notion, GitHub, Figma)",
                    help: "Добавить Notion, GitHub и Figma в прокси"
                ) {
                    applyWorkPreset()
                }
                
                presetChip(
                    title: "⚡️ Гос. сайты РФ в Bypass",
                    help: "Пускать Госуслуги, Сбербанк, Яндекс и VK напрямую без VPN"
                ) {
                    applyRFBypassPreset()
                }
                
                presetChip(
                    title: "🔄 Сброс на базовые",
                    help: "Сбросить конфигурацию правил к исходным рекомендуемым значениям"
                ) {
                    resetToDefaults()
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
                )
        )
    }
    
    private func presetChip(title: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            withAnimation(ModernMacTheme.smoothSpring) {
                action()
            }
        }) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.6)
                    )
            )
        }
        .buttonStyle(.plain)
        .help(help)
    }
    
    // MARK: - Actions
    private func addNewRule() {
        let trimmed = newRuleText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let comment = newRuleComment.trimmingCharacters(in: .whitespacesAndNewlines)
        let rule = RoutingRule(
            value: trimmed,
            target: activeListSelection,
            comment: comment.isEmpty ? nil : comment
        )
        
        if activeListSelection == .proxy {
            if !appState.routingConfig.proxyRules.contains(where: { $0.value == rule.value }) {
                appState.routingConfig.proxyRules.append(rule)
            }
        } else {
            if !appState.routingConfig.directRules.contains(where: { $0.value == rule.value }) {
                appState.routingConfig.directRules.append(rule)
            }
        }
        
        newRuleText = ""
        newRuleComment = ""
        appState.saveRouting()
        showFeedback("Правило добавлено")
    }
    
    private func deleteRule(_ rule: RoutingRule) {
        if rule.target == .proxy {
            appState.routingConfig.proxyRules.removeAll(where: { $0.id == rule.id })
        } else {
            appState.routingConfig.directRules.removeAll(where: { $0.id == rule.id })
        }
        appState.saveRouting()
    }
    
    private func applyAIPreset() {
        let aiRules = [
            RoutingRule(value: "geosite:openai", target: .proxy, comment: "ChatGPT / OpenAI"),
            RoutingRule(value: "domain:chatgpt.com", target: .proxy, comment: "ChatGPT Web"),
            RoutingRule(value: "domain:oaistatic.com", target: .proxy, comment: "OpenAI Static"),
            RoutingRule(value: "geosite:anthropic", target: .proxy, comment: "Claude / Anthropic"),
            RoutingRule(value: "domain:claude.ai", target: .proxy, comment: "Claude Web"),
            RoutingRule(value: "geosite:google-gemini", target: .proxy, comment: "Google Gemini AI"),
            RoutingRule(value: "domain:gemini.google.com", target: .proxy, comment: "Gemini Web"),
            RoutingRule(value: "domain:generativelanguage.googleapis.com", target: .proxy, comment: "Gemini API"),
            RoutingRule(value: "domain:aistudio.google.com", target: .proxy, comment: "Google AI Studio"),
            RoutingRule(value: "domain:perplexity.ai", target: .proxy, comment: "Perplexity AI"),
            RoutingRule(value: "domain:midjourney.com", target: .proxy, comment: "Midjourney")
        ]
        
        var added = 0
        for r in aiRules {
            if !appState.routingConfig.proxyRules.contains(where: { $0.value == r.value }) {
                appState.routingConfig.proxyRules.append(r)
                added += 1
            }
        }
        appState.saveRouting()
        showFeedback("Добавлено правил AI: \(added)")
    }
    
    private func applyRFAntiCensorPreset() {
        let rules = [
            RoutingRule(value: "geosite:instagram", target: .proxy, comment: "Instagram"),
            RoutingRule(value: "geosite:twitter", target: .proxy, comment: "X / Twitter"),
            RoutingRule(value: "domain:x.com", target: .proxy, comment: "X.com"),
            RoutingRule(value: "geosite:facebook", target: .proxy, comment: "Facebook & Meta"),
            RoutingRule(value: "domain:rutracker.org", target: .proxy, comment: "RuTracker"),
            RoutingRule(value: "domain:nnmclub.to", target: .proxy, comment: "NNM Club")
        ]
        
        var added = 0
        for r in rules {
            if !appState.routingConfig.proxyRules.contains(where: { $0.value == r.value }) {
                appState.routingConfig.proxyRules.append(r)
                added += 1
            }
        }
        appState.saveRouting()
        showFeedback("Добавлено правил Антизапрет: \(added)")
    }
    
    private func applyMediaPreset() {
        let rules = [
            RoutingRule(value: "geosite:youtube", target: .proxy, comment: "YouTube"),
            RoutingRule(value: "domain:googlevideo.com", target: .proxy, comment: "Google Video CDN"),
            RoutingRule(value: "geosite:spotify", target: .proxy, comment: "Spotify"),
            RoutingRule(value: "geosite:netflix", target: .proxy, comment: "Netflix")
        ]
        var added = 0
        for r in rules {
            if !appState.routingConfig.proxyRules.contains(where: { $0.value == r.value }) {
                appState.routingConfig.proxyRules.append(r)
                added += 1
            }
        }
        appState.saveRouting()
        showFeedback("Добавлено правил Мультимедиа: \(added)")
    }
    
    private func applyWorkPreset() {
        let rules = [
            RoutingRule(value: "domain:notion.so", target: .proxy, comment: "Notion"),
            RoutingRule(value: "geosite:github", target: .proxy, comment: "GitHub"),
            RoutingRule(value: "domain:figma.com", target: .proxy, comment: "Figma"),
            RoutingRule(value: "domain:docker.com", target: .proxy, comment: "Docker")
        ]
        var added = 0
        for r in rules {
            if !appState.routingConfig.proxyRules.contains(where: { $0.value == r.value }) {
                appState.routingConfig.proxyRules.append(r)
                added += 1
            }
        }
        appState.saveRouting()
        showFeedback("Добавлено правил для работы: \(added)")
    }
    
    private func applyRFBypassPreset() {
        let rules = [
            RoutingRule(value: "geoip:ru", target: .direct, comment: "Российские IP-адреса"),
            RoutingRule(value: "geosite:category-gov-ru", target: .direct, comment: "Госуслуги и гос. сайты"),
            RoutingRule(value: "geosite:yandex", target: .direct, comment: "Сервисы Яндекса"),
            RoutingRule(value: "geosite:vk", target: .direct, comment: "ВКонтакте и Mail.ru"),
            RoutingRule(value: "domain:sberbank.ru", target: .direct, comment: "Сбербанк Онлайн"),
            RoutingRule(value: "domain:tbank.ru", target: .direct, comment: "Т-Банк (Тинькофф)")
        ]
        var added = 0
        for r in rules {
            if !appState.routingConfig.directRules.contains(where: { $0.value == r.value }) {
                appState.routingConfig.directRules.append(r)
                added += 1
            }
        }
        appState.saveRouting()
        showFeedback("Добавлено правил прямого доступа: \(added)")
    }
    
    private func resetToDefaults() {
        appState.routingConfig = RoutingConfig.defaultConfiguration
        appState.saveRouting()
        showFeedback("Правила сброшены к базовым")
    }
    
    private func showFeedback(_ text: String) {
        presetAppliedMessage = "✓ \(text)"
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation {
                presetAppliedMessage = nil
            }
        }
    }
}
