import SwiftUI
import AppKit

public final class PopoverState: ObservableObject {
    public static let shared = PopoverState()
    
    @Published public var isShieldActive: Bool = false
    @Published public var isLockdownActive: Bool = false
    @Published public var apps: [AppTrafficEntry] = []
    @Published public var totalSessionBytes: UInt64 = 0
    @Published public var totalDownloadSpeedBps: Double = 0
    @Published public var totalUploadSpeedBps: Double = 0
    @Published public var totalBlockedAttempts: Int = 0
    @Published public var activeInterfaceName: String = "Wi-Fi (en0)"
    
    @Published public var selectedMainTab: MainNavTab = .overview
    @Published public var selectedAppID: String? = nil
    
    private init() {
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(refresh), name: .shieldStateDidChange, object: nil)
        center.addObserver(self, selector: #selector(refresh), name: .networkStatsDidUpdate, object: nil)
        center.addObserver(self, selector: #selector(refresh), name: .preferencesDidChange, object: nil)
        refresh()
    }
    
    @objc public func refresh() {
        DispatchQueue.main.async {
            self.isShieldActive = FirewallController.shared.isShieldActive
            self.isLockdownActive = FirewallController.shared.isLockdownActive
            let engine = NetworkMonitorEngine.shared
            self.apps = engine.apps
            self.totalSessionBytes = engine.totalSessionBytes
            self.totalDownloadSpeedBps = engine.totalDownloadSpeedBps
            self.totalUploadSpeedBps = engine.totalUploadSpeedBps
            self.totalBlockedAttempts = engine.totalBlockedAttempts
            self.activeInterfaceName = engine.activeInterfaceName
        }
    }
}

struct PopoverContentView: View {
    @ObservedObject var state = PopoverState.shared
    @AppStorage(PreferencesManager.Keys.selectedDataCapMB) private var selectedDataCapMB = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 1. Minimal Header: Title, Status, and Master Shield Toggle
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("TripGuard")
                        .font(.system(size: 14, weight: .bold))
                    
                    HStack(spacing: 5) {
                        Circle()
                            .fill(statusDotColor)
                            .frame(width: 6, height: 6)
                        Text(statusSubtitleText)
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundColor(state.isShieldActive ? statusDotColor : .secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                Toggle("", isOn: Binding(
                    get: { state.isShieldActive },
                    set: { newVal in
                        if newVal {
                            FirewallController.shared.activateShield()
                        } else {
                            FirewallController.shared.deactivateShield()
                        }
                    }
                ))
                .toggleStyle(.switch)
                .scaleEffect(0.85)
                .labelsHidden()
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 10)
            
            Divider()
                .padding(.horizontal, 10)
            
            // 2. Simple Session Usage Summary Card
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("SESSION USAGE")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundColor(.secondary)
                        Text(NetworkMonitorEngine.formatBytes(state.totalSessionBytes))
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("↓ " + NetworkMonitorEngine.formatSpeed(state.totalDownloadSpeedBps))
                            .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                            .foregroundColor(state.totalDownloadSpeedBps > 300 ? Color(red: 0.00, green: 0.62, blue: 0.95) : .secondary)
                        Text("↑ " + NetworkMonitorEngine.formatSpeed(state.totalUploadSpeedBps))
                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
                
                if selectedDataCapMB > 0 {
                    let capBytes = Double(selectedDataCapMB) * 1_000_000.0
                    let ratio = min(1.0, Double(state.totalSessionBytes) / max(1.0, capBytes))
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2.5)
                                .fill(Color.primary.opacity(0.08))
                                .frame(height: 5)
                            RoundedRectangle(cornerRadius: 2.5)
                                .fill(ratio >= 0.9 ? Color.red : Color(red: 0.00, green: 0.65, blue: 0.95))
                                .frame(width: max(4, geo.size.width * CGFloat(ratio)), height: 5)
                        }
                    }
                    .frame(height: 5)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            
            Divider()
                .padding(.horizontal, 10)
            
            // 3. Clean Session App List
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(state.apps.prefix(7))) { app in
                        simpleAppRow(app: app)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            }
            .frame(height: 185)
            
            Divider()
                .padding(.horizontal, 10)
            
            // 4. Open Full App Button + Footer Actions
            VStack(spacing: 6) {
                Button {
                    StatusBarController.shared?.closePopover()
                    FloatingWindowManager.shared.showMainAppWindow(initialTab: .overview)
                } label: {
                    HStack {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.system(size: 11.5, weight: .semibold))
                        Text("Open TripGuard & History...")
                            .font(.system(size: 12, weight: .semibold))
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(Color(red: 0.00, green: 0.52, blue: 0.95))
                    )
                    .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                
                HStack {
                    Button("Reset Session") {
                        NetworkMonitorEngine.shared.resetSessionCounters()
                    }
                    .font(.system(size: 11))
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button("Settings") {
                        StatusBarController.shared?.closePopover()
                        FloatingWindowManager.shared.showMainAppWindow(initialTab: .settings)
                    }
                    .font(.system(size: 11))
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    
                    Button("Quit") {
                        UsageHistoryStore.shared.saveToDiskIfNeeded()
                        FirewallController.shared.deactivateShield()
                        NSApp.terminate(nil)
                    }
                    .font(.system(size: 11))
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal, 2)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
        }
        .frame(width: 268)
    }
    
    private var statusDotColor: Color {
        if state.isLockdownActive { return .red }
        if state.isShieldActive { return Color(red: 0.00, green: 0.78, blue: 0.55) }
        return .secondary
    }
    
    private var statusSubtitleText: String {
        if state.isLockdownActive { return "Lockdown • Cap Reached" }
        if state.isShieldActive { return "Shield Active • \(state.activeInterfaceName)" }
        return "Monitoring • \(state.activeInterfaceName)"
    }
    
    @ViewBuilder
    private func simpleAppRow(app: AppTrafficEntry) -> some View {
        let isAllowed = PreferencesManager.shared.isAppAllowed(identifier: app.id, defaultAllowed: !app.isSystemDaemon)
        let effectivelyBlocked = state.isShieldActive && (!isAllowed || state.isLockdownActive)
        
        HStack(spacing: 8) {
            Button {
                StatusBarController.shared?.closePopover()
                FloatingWindowManager.shared.showMainAppWindow(initialTab: .applications, selectedAppID: app.id)
            } label: {
                HStack(spacing: 8) {
                    Image(nsImage: app.icon)
                        .resizable()
                        .frame(width: 20, height: 20)
                        .opacity(effectivelyBlocked ? 0.5 : 1.0)
                    
                    Text(app.name)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(effectivelyBlocked ? .secondary : .primary)
                        .lineLimit(1)
                    
                    Spacer(minLength: 4)
                    
                    Text(NetworkMonitorEngine.formatBytes(app.totalSessionBytes))
                        .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                        .foregroundColor(effectivelyBlocked ? .red.opacity(0.8) : .secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            Toggle("", isOn: Binding(
                get: { isAllowed },
                set: { newVal in
                    PreferencesManager.shared.setAppAllowed(identifier: app.id, allowed: newVal)
                    if newVal {
                        FirewallController.shared.resumePIDs(app.pids)
                    } else if state.isShieldActive {
                        _ = FirewallController.shared.enforceBlockOnPIDs(app.pids, appName: app.name, isSystemDaemon: app.isSystemDaemon)
                    }
                    state.refresh()
                }
            ))
            .toggleStyle(.switch)
            .scaleEffect(0.66)
            .labelsHidden()
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
    }
}

struct SettingItemRow: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool
    var onChange: ((Bool) -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.00, green: 0.50, blue: 0.95).opacity(0.12))
                    .frame(width: 22, height: 22)
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color(red: 0.00, green: 0.55, blue: 0.95))
            }
            Text(title)
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(.primary)
            Spacer()
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .scaleEffect(0.80)
                .labelsHidden()
                .onChange(of: isOn) { val in
                    onChange?(val)
                }
        }
        .frame(height: 24)
    }
}

// MARK: - Window Manager for Full Main App Window, Donate & About

public final class FloatingWindowManager: NSObject, NSWindowDelegate {
    public static let shared = FloatingWindowManager()
    private var mainAppWindow: NSWindow?
    private var donateWindow: NSWindow?
    private var aboutWindow: NSWindow?
    
    public func showMainAppWindow(initialTab: MainNavTab = .overview, selectedAppID: String? = nil) {
        PopoverState.shared.selectedMainTab = initialTab
        if let appID = selectedAppID {
            PopoverState.shared.selectedAppID = appID
        }
        
        if let win = mainAppWindow {
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 960, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        win.title = "TripGuard — Network Usage & Firewall"
        win.minSize = NSSize(width: 880, height: 580)
        win.center()
        win.isReleasedWhenClosed = false
        win.delegate = self
        win.contentView = NSHostingView(rootView: MainAppWindowView())
        self.mainAppWindow = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    public func showDonateWindow() {
        if let win = donateWindow {
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 255),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        win.title = "Support TripGuard"
        win.center()
        win.isReleasedWhenClosed = false
        win.level = .floating
        win.delegate = self
        win.contentView = NSHostingView(rootView: DonateModalView { [weak win] in
            win?.close()
        })
        self.donateWindow = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    public func showAboutWindow() {
        if let win = aboutWindow {
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 290),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        win.title = "About TripGuard"
        win.center()
        win.isReleasedWhenClosed = false
        win.level = .floating
        win.delegate = self
        win.contentView = NSHostingView(rootView: AboutModalView { [weak win] in
            win?.close()
        })
        self.aboutWindow = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    public func windowWillClose(_ notification: Notification) {
        if let closedWin = notification.object as? NSWindow {
            if closedWin == mainAppWindow {
                mainAppWindow = nil
            } else if closedWin == donateWindow {
                donateWindow = nil
            } else if closedWin == aboutWindow {
                aboutWindow = nil
            }
        }
    }
}

struct DonateModalView: View {
    var onClose: () -> Void
    @State private var copied = false
    private let cryptoAddr = "UQBEJwLa4EGPRmUKw4O1i9d_JjJGmjkJ2myqR5lborzgceT-"
    
    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("Support TripGuard")
                    .font(.system(size: 16, weight: .bold))
                Text("Created by Hassan Elkady (local-over)")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 4)
            
            VStack(spacing: 10) {
                Button {
                    if let url = URL(string: "https://paypal.me/HassanElkady2") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    HStack {
                        Image(systemName: "creditcard.fill")
                        Text("Donate via PayPal")
                            .fontWeight(.medium)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 11))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(red: 0.00, green: 0.48, blue: 1.0))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("USDT (TON / TRC20)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        Spacer()
                        Button(copied ? "Copied!" : "Copy") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(cryptoAddr, forType: .string)
                            copied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                copied = false
                            }
                        }
                        .font(.system(size: 11, weight: .bold))
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    
                    Text(cryptoAddr)
                        .font(.system(size: 10, design: .monospaced))
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.primary.opacity(0.06))
                        .cornerRadius(6)
                        .lineLimit(2)
                }
            }
            .padding(.horizontal, 16)
            
            HStack {
                Spacer()
                Button("Close") {
                    onClose()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .frame(width: 360, height: 255)
    }
}

struct AboutModalView: View {
    var onClose: () -> Void
    
    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.00, green: 0.68, blue: 0.95).opacity(0.12))
                    .frame(width: 56, height: 56)
                Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                    .font(.system(size: 26))
                    .foregroundColor(Color(red: 0.00, green: 0.68, blue: 0.95))
            }
            .padding(.top, 8)
            
            VStack(spacing: 4) {
                Text("TripGuard")
                    .font(.system(size: 17, weight: .bold))
                Text("Version 1.0.0")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Text("Created by Hassan Elkady (local-over)")
                    .font(.system(size: 12, weight: .medium))
                    .padding(.top, 2)
                Text("100% Free & Open-Source under MIT License.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 12) {
                Button("Website") {
                    if let url = URL(string: "https://local-over.github.io/tripguard") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.bordered)
                
                Button("GitHub") {
                    if let url = URL(string: "https://github.com/local-over/tripguard") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.bordered)
            }
            
            Button("Close") {
                onClose()
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .padding(.top, 4)
            .padding(.bottom, 8)
        }
        .frame(width: 360, height: 290)
    }
}
