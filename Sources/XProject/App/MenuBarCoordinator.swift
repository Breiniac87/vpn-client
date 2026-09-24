import SwiftUI
import AppKit

@MainActor
public final class MenuBarCoordinator: NSObject {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private let appState: AppState
    
    // Animation timer for active/connecting states
    private var animationTimer: Timer?
    private var animationFrame: Int = 0
    private var currentAnimationInterval: TimeInterval = 0
    
    // Callbacks passed to preferences/actions
    var onScanScreenQR: (() -> Void)?
    var onImportClipboard: (() -> Void)?
    var onImportJsonFile: (() -> Void)?
    
    public init(appState: AppState) {
        self.appState = appState
        super.init()
        setupStatusItem()
        setupPopover()
        
        appState.onStatusChange = { [weak self] _ in
            self?.updateIcon()
        }
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem?.button else { return }
        
        button.target = self
        button.action = #selector(handleStatusItemClick)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        
        updateIcon()
    }
    
    private func setupPopover() {
        let pop = NSPopover()
        pop.behavior = .transient
        pop.animates = true
        
        let contentView = MenuBarPopoverView(
            appState: appState,
            onOpenPreferences: { [weak self] in
                self?.openPreferences()
            },
            onQuit: {
                NSApp.terminate(nil)
            }
        )
        
        pop.contentViewController = NSHostingController(rootView: contentView)
        self.popover = pop
    }
    
    @objc private func handleStatusItemClick() {
        guard let button = statusItem?.button, let popover = popover else { return }
        
        if popover.isShown {
            popover.performClose(nil)
        } else {
            let contentView = MenuBarPopoverView(
                appState: appState,
                onOpenPreferences: { [weak self] in
                    self?.openPreferences()
                },
                onQuit: {
                    NSApp.terminate(nil)
                }
            )
            popover.contentViewController = NSHostingController(rootView: contentView)
            
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
    
    // MARK: - Status Item Rendering & Micro-Animations
    public func updateIcon() {
        guard let button = statusItem?.button else { return }
        
        switch appState.connectionStatus {
        case .connected:
            // Connected state: steady glowing green dot centered inside white outline shield (no blinking, 0% CPU)
            stopAnimation()
            button.image = makeConnectedIcon()
            button.image?.isTemplate = false
            button.contentTintColor = nil
            
        case .connecting, .disconnecting:
            // Connecting state: fast breathing/pulsing cyan dot in center (0.15s interval)
            startAnimation(interval: 0.15)
            button.image = makeConnectingIcon(frame: animationFrame)
            button.image?.isTemplate = false
            button.contentTintColor = nil
            
        case .disconnected, .error:
            // Disconnected state: resting white outline shield (0% CPU)
            stopAnimation()
            button.image = makeDisconnectedIcon()
            button.image?.isTemplate = false
            button.contentTintColor = nil
        }
    }
    
    private func startAnimation(interval: TimeInterval) {
        if animationTimer != nil && currentAnimationInterval == interval {
            return
        }
        stopAnimation()
        currentAnimationInterval = interval
        animationTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, let button = self.statusItem?.button else { return }
                self.animationFrame = (self.animationFrame + 1) % 8
                
                switch self.appState.connectionStatus {
                case .connected:
                    self.stopAnimation()
                    button.image = self.makeConnectedIcon()
                    button.image?.isTemplate = false
                case .connecting, .disconnecting:
                    button.image = self.makeConnectingIcon(frame: self.animationFrame)
                    button.image?.isTemplate = false
                case .disconnected, .error:
                    self.stopAnimation()
                    button.image = self.makeDisconnectedIcon()
                    button.image?.isTemplate = false
                }
            }
        }
    }
    
    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        currentAnimationInterval = 0
        animationFrame = 0
    }
    
    // MARK: - Icon Generators (Always Pure Brilliant White Outline Shield)
    
    /// Connected: White outline shield with a steady vibrant neon-green beacon centered inside
    private func makeConnectedIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let weightConfig = NSImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        let colorConfig = NSImage.SymbolConfiguration(paletteColors: [NSColor.white])
        let symbolConfig = weightConfig.applying(colorConfig)
        
        let img = NSImage(size: size, flipped: false) { rect in
            if let baseShield = NSImage(systemSymbolName: "shield", accessibilityDescription: "Подключено")?.withSymbolConfiguration(symbolConfig) {
                baseShield.draw(in: NSRect(x: 1.5, y: 1.0, width: 15.0, height: 16.0))
            } else {
                // Vector fallback: white outline shield
                let path = NSBezierPath()
                path.move(to: NSPoint(x: 9.0, y: 16.5))
                path.line(to: NSPoint(x: 15.5, y: 15.0))
                path.curve(to: NSPoint(x: 15.0, y: 7.5), controlPoint1: NSPoint(x: 15.5, y: 12.0), controlPoint2: NSPoint(x: 15.5, y: 9.5))
                path.curve(to: NSPoint(x: 9.0, y: 1.5), controlPoint1: NSPoint(x: 14.5, y: 4.5), controlPoint2: NSPoint(x: 11.5, y: 2.5))
                path.curve(to: NSPoint(x: 3.0, y: 7.5), controlPoint1: NSPoint(x: 6.5, y: 2.5), controlPoint2: NSPoint(x: 3.5, y: 4.5))
                path.curve(to: NSPoint(x: 2.5, y: 15.0), controlPoint1: NSPoint(x: 2.5, y: 9.5), controlPoint2: NSPoint(x: 2.5, y: 12.0))
                path.close()
                NSColor.white.setStroke()
                path.lineWidth = 1.6
                path.lineJoinStyle = .round
                path.stroke()
            }
            
            // Centered glowing neon-green beacon dot (steady, not blinking)
            let center = NSPoint(x: 9.0, y: 9.2)
            let radius: CGFloat = 2.2
            let dot = NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
            NSColor(red: 0.0, green: 0.95, blue: 0.45, alpha: 1.0).setFill()
            dot.fill()
            
            return true
        }
        img.isTemplate = false
        return img
    }
    
    /// Connecting: White outline shield with pulsing cyan beacon in the center
    private func makeConnectingIcon(frame: Int) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let weightConfig = NSImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        let colorConfig = NSImage.SymbolConfiguration(paletteColors: [NSColor.white])
        let symbolConfig = weightConfig.applying(colorConfig)
        
        let img = NSImage(size: size, flipped: false) { rect in
            if let baseShield = NSImage(systemSymbolName: "shield", accessibilityDescription: "Подключение...")?.withSymbolConfiguration(symbolConfig) {
                baseShield.draw(in: NSRect(x: 1.5, y: 1.0, width: 15.0, height: 16.0))
            } else {
                // Vector fallback: white outline shield
                let path = NSBezierPath()
                path.move(to: NSPoint(x: 9.0, y: 16.5))
                path.line(to: NSPoint(x: 15.5, y: 15.0))
                path.curve(to: NSPoint(x: 15.0, y: 7.5), controlPoint1: NSPoint(x: 15.5, y: 12.0), controlPoint2: NSPoint(x: 15.5, y: 9.5))
                path.curve(to: NSPoint(x: 9.0, y: 1.5), controlPoint1: NSPoint(x: 14.5, y: 4.5), controlPoint2: NSPoint(x: 11.5, y: 2.5))
                path.curve(to: NSPoint(x: 3.0, y: 7.5), controlPoint1: NSPoint(x: 6.5, y: 2.5), controlPoint2: NSPoint(x: 3.5, y: 4.5))
                path.curve(to: NSPoint(x: 2.5, y: 15.0), controlPoint1: NSPoint(x: 2.5, y: 9.5), controlPoint2: NSPoint(x: 2.5, y: 12.0))
                path.close()
                NSColor.white.setStroke()
                path.lineWidth = 1.6
                path.lineJoinStyle = .round
                path.stroke()
            }
            
            // Pulsing cyan beacon in the center
            let pulseRadii: [CGFloat] = [1.2, 1.5, 1.9, 2.3, 2.6, 2.3, 1.9, 1.5]
            let r = pulseRadii[frame % pulseRadii.count]
            let center = NSPoint(x: 9.0, y: 9.2)
            
            let dot = NSBezierPath(ovalIn: NSRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
            NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 0.95).setFill()
            dot.fill()
            
            return true
        }
        img.isTemplate = false
        return img
    }
    
    /// Disconnected: Crisp bold white outline shield (resting, clean, brilliant white)
    private func makeDisconnectedIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let weightConfig = NSImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        let colorConfig = NSImage.SymbolConfiguration(paletteColors: [NSColor.white])
        let symbolConfig = weightConfig.applying(colorConfig)
        
        let img = NSImage(size: size, flipped: false) { rect in
            if let baseShield = NSImage(systemSymbolName: "shield", accessibilityDescription: "Отключено")?.withSymbolConfiguration(symbolConfig) {
                baseShield.draw(in: NSRect(x: 1.5, y: 1.0, width: 15.0, height: 16.0))
            } else {
                // Vector fallback: pure white shield path
                let path = NSBezierPath()
                path.move(to: NSPoint(x: 9.0, y: 16.5))
                path.line(to: NSPoint(x: 15.5, y: 15.0))
                path.curve(to: NSPoint(x: 15.0, y: 7.5), controlPoint1: NSPoint(x: 15.5, y: 12.0), controlPoint2: NSPoint(x: 15.5, y: 9.5))
                path.curve(to: NSPoint(x: 9.0, y: 1.5), controlPoint1: NSPoint(x: 14.5, y: 4.5), controlPoint2: NSPoint(x: 11.5, y: 2.5))
                path.curve(to: NSPoint(x: 3.0, y: 7.5), controlPoint1: NSPoint(x: 6.5, y: 2.5), controlPoint2: NSPoint(x: 3.5, y: 4.5))
                path.curve(to: NSPoint(x: 2.5, y: 15.0), controlPoint1: NSPoint(x: 2.5, y: 9.5), controlPoint2: NSPoint(x: 2.5, y: 12.0))
                path.close()
                
                NSColor.white.setStroke()
                path.lineWidth = 1.6
                path.lineJoinStyle = .round
                path.stroke()
            }
            return true
        }
        img.isTemplate = false
        return img
    }
    
    public func openPreferences() {
        popover?.performClose(nil)
        PreferencesWindowController.shared.show(
            appState: appState,
            onScanScreenQR: onScanScreenQR,
            onImportClipboard: onImportClipboard,
            onImportJsonFile: onImportJsonFile
        )
    }
}
