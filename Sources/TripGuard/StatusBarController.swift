import AppKit
import Foundation
import SwiftUI

public final class StatusBarController: NSObject {
    public static weak var shared: StatusBarController?
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    
    private var animationTimer: Timer?
    private var currentAnimationFrame: Int = 0
    private var globalHotkeyMonitor: Any?
    private var localHotkeyMonitor: Any?
    
    public override init() {
        super.init()
        StatusBarController.shared = self
        setupStatusItem()
        setupPopover()
        setupGlobalHotkey()
        
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(handleStateUpdate), name: .shieldStateDidChange, object: nil)
        center.addObserver(self, selector: #selector(handleStatsUpdate), name: .networkStatsDidUpdate, object: nil)
        center.addObserver(self, selector: #selector(handlePreferencesUpdate), name: .preferencesDidChange, object: nil)
        
        if PreferencesManager.shared.activateAtLaunch {
            FirewallController.shared.activateShield()
        }
        
        updateUI()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        animationTimer?.invalidate()
        if let monitor = globalHotkeyMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let local = localHotkeyMonitor {
            NSEvent.removeMonitor(local)
        }
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusBarButtonClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.imagePosition = .imageLeading
            updateIconAndTitle()
        }
    }
    
    private func setupPopover() {
        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(rootView: PopoverContentView())
    }
    
    private func setupGlobalHotkey() {
        // Option + T (keyCode 17) global hotkey
        globalHotkeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains(.option) && event.keyCode == 17 {
                DispatchQueue.main.async {
                    FirewallController.shared.toggleShield()
                }
            }
        }
        localHotkeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains(.option) && event.keyCode == 17 {
                DispatchQueue.main.async {
                    FirewallController.shared.toggleShield()
                }
                return nil
            }
            return event
        }
    }
    
    @objc private func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        guard let currentEvent = NSApp.currentEvent else { return }
        
        let isRightClick = currentEvent.type == .rightMouseUp ||
            (currentEvent.modifierFlags.contains(.control) && currentEvent.type == .leftMouseUp)
        
        if PreferencesManager.shared.activateWithLeftClick {
            if isRightClick {
                togglePopover()
            } else {
                FirewallController.shared.toggleShield()
            }
        } else {
            togglePopover()
        }
    }
    
    public func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
    
    public func closePopover() {
        if popover.isShown {
            popover.performClose(nil)
        }
    }
    
    @objc private func handleStateUpdate() {
        updateUI()
    }
    
    @objc private func handleStatsUpdate() {
        updateTitleAndTooltip()
    }
    
    @objc private func handlePreferencesUpdate() {
        updateUI()
    }
    
    private func updateUI() {
        updateIconAndTitle()
        updateTitleAndTooltip()
    }
    
    private func updateIconAndTitle() {
        let active = FirewallController.shared.isShieldActive
        let colored = PreferencesManager.shared.coloredMenuBarIcon
        
        if active {
            startAnimation(colored: colored)
        } else {
            stopAnimation()
            statusItem.button?.image = MenuBarIconGenerator.shared.inactiveIcon()
        }
        updateTitleAndTooltip()
    }
    
    private func updateTitleAndTooltip() {
        guard let button = statusItem.button else { return }
        let engine = NetworkMonitorEngine.shared
        let active = FirewallController.shared.isShieldActive
        
        if PreferencesManager.shared.showMenuBarSpeed {
            let speed = engine.totalDownloadSpeedBps + engine.totalUploadSpeedBps
            let labelStr: String
            if speed >= 1_000 {
                labelStr = " " + NetworkMonitorEngine.formatSpeed(speed)
            } else {
                labelStr = " " + NetworkMonitorEngine.formatBytes(engine.totalSessionBytes)
            }
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)
            ]
            button.attributedTitle = NSAttributedString(string: labelStr, attributes: attrs)
        } else {
            button.title = ""
        }
        
        let usedStr = NetworkMonitorEngine.formatBytes(engine.totalSessionBytes)
        if active {
            button.toolTip = "TripGuard: Shield Active • \(usedStr) used (\(engine.totalBlockedAttempts) blocked)"
        } else {
            button.toolTip = "TripGuard: Monitoring Only • \(usedStr) used"
        }
    }
    
    private func startAnimation(colored: Bool) {
        if animationTimer == nil {
            currentAnimationFrame = 0
            animationTimer = Timer.scheduledTimer(withTimeInterval: 0.22, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                let engine = NetworkMonitorEngine.shared
                if engine.totalDownloadSpeedBps + engine.totalUploadSpeedBps > 200 {
                    self.currentAnimationFrame = (self.currentAnimationFrame + 1) % 4
                }
                self.statusItem.button?.image = MenuBarIconGenerator.shared.activeIcon(
                    frame: self.currentAnimationFrame,
                    colored: PreferencesManager.shared.coloredMenuBarIcon
                )
            }
        }
        statusItem.button?.image = MenuBarIconGenerator.shared.activeIcon(frame: 0, colored: colored)
    }
    
    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
    }
}
