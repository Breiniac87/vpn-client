import SwiftUI
import AppKit

public struct HappSchemeSheetView: View {
    @Bindable var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTab: Int = 0 // 0: Экспорт, 1: Импорт
    @State private var schemeName: String = "X-project Scheme"
    @State private var copiedFeedback: String? = nil
    
    // Import state
    @State private var importInputText: String = ""
    @State private var parsedScheme: HappRoutingScheme? = nil
    @State private var parseError: String? = nil
    @State private var mergeRules: Bool = true
    @State private var importSuccessMessage: String? = nil
    
    public init(appState: AppState) {
        self.appState = appState
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
                        Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(ModernMacTheme.cyanAccent)
                        
                        Text("Схемы маршрутизации Happ")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    
                    Spacer()
                    
                    // Segmented Control
                    Picker("", selection: $selectedTab) {
                        Text("Экспорт").tag(0)
                        Text("Импорт").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                    
                    Spacer()
                    
                    Button("Закрыть") {
                        dismiss()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.08)))
                    .foregroundStyle(.white.opacity(0.8))
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(Color.white.opacity(0.02))
                
                Divider()
                    .opacity(0.15)
                
                // Tab Content
                ScrollView {
                    VStack(spacing: 16) {
                        if selectedTab == 0 {
                            exportSection
                        } else {
                            importSection
                        }
                    }
                    .padding(20)
                }
            }
        }
        .frame(width: 580, height: 480)
        .tint(ModernMacTheme.cyanAccent)
    }
    
    // MARK: - Export Section
    private var exportSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Summary Card
            VStack(alignment: .leading, spacing: 8) {
                Text("ТЕКУЩАЯ КОНФИГУРАЦИЯ:")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.5))
                
                HStack(spacing: 12) {
                    summaryBadge(title: "Прокси", count: appState.routingConfig.proxyRules.count, color: ModernMacTheme.cyanAccent)
                    summaryBadge(title: "Прямой (Bypass)", count: appState.routingConfig.directRules.count, color: ModernMacTheme.neonGreen)
                    summaryBadge(title: "Блок", count: appState.routingConfig.blockRules.count, color: ModernMacTheme.redDanger)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(appState.routingConfig.fakeDnsEnabled ? ModernMacTheme.neonGreen : Color.white.opacity(0.3))
                            .frame(width: 6, height: 6)
                        Text(appState.routingConfig.fakeDnsEnabled ? "FakeDNS Вкл" : "FakeDNS Выкл")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(ModernMacTheme.cardSurface)
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(ModernMacTheme.borderCard, lineWidth: 0.8))
            )
            
            // Scheme Name Input
            VStack(alignment: .leading, spacing: 6) {
                Text("Название экспортируемой схемы:")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                
                TextField("Например: My Home Routing", text: $schemeName)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(0.05))
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8))
                    )
                    .foregroundStyle(.white)
            }
            
            // Happ URL Link Preview Box
            VStack(alignment: .leading, spacing: 6) {
                Text("Формат Happ (deep-link для мобильного клиента Happ iOS):")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                
                Text(happUrlPreview)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(ModernMacTheme.cyanAccent)
                    .lineLimit(2)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(0.04))
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(ModernMacTheme.cyanAccent.opacity(0.2), lineWidth: 0.8))
                    )
            }
            
            // Action Buttons
            VStack(spacing: 8) {
                Button(action: copyHappUrl) {
                    HStack {
                        Image(systemName: "doc.on.doc.fill")
                        Text("Скопировать ссылку Happ (happ://)")
                        Spacer()
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(RoundedRectangle(cornerRadius: 8).fill(ModernMacTheme.cyanAccent))
                }
                .buttonStyle(.plain)
                
                HStack(spacing: 10) {
                    Button(action: copyBase64) {
                        HStack {
                            Image(systemName: "number")
                            Text("Скопировать Base64")
                        }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.08)))
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8))
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: copyJson) {
                        HStack {
                            Image(systemName: "curlybraces")
                            Text("Скопировать JSON")
                        }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.08)))
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8))
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: saveJsonFile) {
                        HStack {
                            Image(systemName: "arrow.down.doc")
                            Text("Сохранить .json...")
                        }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.08)))
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 4)
            
            if let feedback = copiedFeedback {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(ModernMacTheme.neonGreen)
                    Text(feedback)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(ModernMacTheme.neonGreen)
                }
                .transition(.opacity)
            }
        }
    }
    
    // MARK: - Import Section
    private var importSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Вставьте ссылку happ://, Base64 строку или выберите .json файл:")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
            
            // Text Input Field
            VStack(alignment: .trailing, spacing: 6) {
                TextEditor(text: $importInputText)
                    .font(.system(size: 11, design: .monospaced))
                    .frame(height: 100)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(0.05))
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8))
                    )
                    .onChange(of: importInputText) { _, newValue in
                        validateImport(newValue)
                    }
                
                HStack {
                    Button("Вставить из буфера") {
                        if let clip = NSPasteboard.general.string(forType: .string) {
                            importInputText = clip
                            validateImport(clip)
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10))
                    .foregroundStyle(ModernMacTheme.cyanAccent)
                    
                    Spacer()
                    
                    Button("Выбрать .json файл...") {
                        openJsonFile()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
                }
            }
            
            // Live Scheme Preview
            if let scheme = parsedScheme {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(ModernMacTheme.neonGreen)
                        Text("Схема распознана: \(scheme.name)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                        
                        Spacer()
                        
                        if let date = scheme.lastUpdated {
                            Text(date)
                                .font(.system(size: 10))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                    
                    HStack(spacing: 12) {
                        summaryBadge(title: "Прокси", count: scheme.proxySites.count + scheme.proxyIp.count, color: ModernMacTheme.cyanAccent)
                        summaryBadge(title: "Прямой (Bypass)", count: scheme.directSites.count + scheme.directIp.count, color: ModernMacTheme.neonGreen)
                        summaryBadge(title: "Блок", count: scheme.blockSites.count + scheme.blockIp.count, color: ModernMacTheme.redDanger)
                        
                        Spacer()
                        
                        Text("FakeDNS: \(scheme.fakeDNS ? "Вкл" : "Выкл")")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(ModernMacTheme.cardSurface)
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(ModernMacTheme.neonGreen.opacity(0.3), lineWidth: 0.8))
                )
            } else if let error = parseError, !importInputText.isEmpty {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(ModernMacTheme.redDanger)
                    .padding(.horizontal, 4)
            }
            
            // Apply Mode Selection
            HStack(spacing: 8) {
                Text("Объединить с текущими правилами (Merge)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                
                Spacer()
                
                GoldenToggle(isOn: $mergeRules)
            }
            .padding(.top, 4)
            
            // Apply Button
            Button(action: applyImportedScheme) {
                HStack {
                    Image(systemName: "arrow.down.circle.fill")
                    Text("Применить схему маршрутизации")
                    Spacer()
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.black)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(parsedScheme == nil ? Color.white.opacity(0.2) : ModernMacTheme.neonGreen)
                )
            }
            .buttonStyle(.plain)
            .disabled(parsedScheme == nil)
            
            if let success = importSuccessMessage {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(ModernMacTheme.neonGreen)
                    Text(success)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(ModernMacTheme.neonGreen)
                }
            }
        }
    }
    
    // MARK: - Helpers
    private var happUrlPreview: String {
        (try? HappRoutingCodec.exportHappUrl(from: appState.routingConfig, name: schemeName)) ?? "happ://routing/add/..."
    }
    
    private func summaryBadge(title: String, count: Int, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.7))
            Text("\(count)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(color.opacity(0.12)))
    }
    
    private func copyHappUrl() {
        if let url = try? HappRoutingCodec.exportHappUrl(from: appState.routingConfig, name: schemeName) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(url, forType: .string)
            showCopiedFeedback("Ссылка Happ скопирована в буфер")
        }
    }
    
    private func copyBase64() {
        if let b64 = try? HappRoutingCodec.exportBase64(from: appState.routingConfig, name: schemeName) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(b64, forType: .string)
            showCopiedFeedback("Base64 схема скопирована")
        }
    }
    
    private func copyJson() {
        if let json = try? HappRoutingCodec.exportJson(from: appState.routingConfig, name: schemeName) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(json, forType: .string)
            showCopiedFeedback("JSON схема скопирована")
        }
    }
    
    private func saveJsonFile() {
        guard let json = try? HappRoutingCodec.exportJson(from: appState.routingConfig, name: schemeName) else { return }
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.json]
        savePanel.canCreateDirectories = true
        savePanel.nameFieldStringValue = "\(schemeName.replacingOccurrences(of: " ", with: "_")).json"
        
        if savePanel.runModal() == .OK, let url = savePanel.url {
            try? json.write(to: url, atomically: true, encoding: .utf8)
            showCopiedFeedback("Схема сохранена в \(url.lastPathComponent)")
        }
    }
    
    private func openJsonFile() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.json]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        
        if openPanel.runModal() == .OK, let url = openPanel.url, let content = try? String(contentsOf: url) {
            importInputText = content
            validateImport(content)
        }
    }
    
    private func validateImport(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            parsedScheme = nil
            parseError = nil
            return
        }
        
        do {
            let scheme = try HappRoutingCodec.decode(from: trimmed)
            parsedScheme = scheme
            parseError = nil
        } catch {
            parsedScheme = nil
            parseError = "Не удалось распознать формат схемы Happ"
        }
    }
    
    private func applyImportedScheme() {
        guard let scheme = parsedScheme else { return }
        
        withAnimation(ModernMacTheme.smoothSpring) {
            HappRoutingCodec.apply(scheme: scheme, to: &appState.routingConfig, merge: mergeRules)
            appState.saveRouting()
            importSuccessMessage = "Схема «\(scheme.name)» успешно применена!"
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            dismiss()
        }
    }
    
    private func showCopiedFeedback(_ msg: String) {
        withAnimation(ModernMacTheme.smoothSpring) {
            copiedFeedback = msg
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                copiedFeedback = nil
            }
        }
    }
}
