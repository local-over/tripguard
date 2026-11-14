import Foundation
import AppKit
import Darwin
import UserNotifications
import ApplicationServices

public struct SocketConnectionInfo: Identifiable, Equatable {
    public let id = UUID()
    public let proto: String
    public let localAddress: String
    public let remoteAddress: String
    public let state: String
    public let pid: Int32
}

public final class PermissionsManager: ObservableObject {
    public static let shared = PermissionsManager()
    
    @Published public var firewallPermissionGranted: Bool = PreferencesManager.shared.hasGrantedFirewallPermission
    @Published public var kernelFirewallAuthorized: Bool = PreferencesManager.shared.kernelFirewallAuthorized
    @Published public var notificationsAuthorized: Bool = false
    @Published public var accessibilityTrusted: Bool = AXIsProcessTrusted()
    
    private var isBundledApp: Bool {
        Bundle.main.bundlePath.hasSuffix(".app")
    }
    
    private init() {
        refreshPermissionsStatus()
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshPermissionsStatus()
        }
    }
    
    public func refreshPermissionsStatus() {
        DispatchQueue.main.async {
            self.firewallPermissionGranted = PreferencesManager.shared.hasGrantedFirewallPermission
            self.kernelFirewallAuthorized = PreferencesManager.shared.kernelFirewallAuthorized
            self.accessibilityTrusted = AXIsProcessTrusted()
        }
        
        guard isBundledApp else { return }
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.notificationsAuthorized = (settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional)
            }
        }
    }
    
    /// Requests initial permissions on app launch when running inside TripGuard.app
    public func requestInitialPermissionsOnLaunchIfNeeded() {
        refreshPermissionsStatus()
        if isBundledApp {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                DispatchQueue.main.async {
                    self.notificationsAuthorized = granted
                }
            }
        }
    }
    
    /// Prompts the user to grant TripGuard Network Firewall permission
    @discardableResult
    public func promptFirewallPermissionModal() -> Bool {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.icon = NSApp.applicationIconImage
        alert.messageText = "Allow TripGuard to Control Per-App Network Traffic?"
        alert.informativeText = "TripGuard monitors live network sockets (nettop & lsof) and pauses or blocks unauthorized applications when the Firewall Shield is active.\n\nChoose \"Allow Network Control\" for instant per-app blocking, or \"Authorize Kernel Firewall (Admin)...\" to also grant macOS pfctl packet filter privileges."
        alert.addButton(withTitle: "Allow Network Control")
        alert.addButton(withTitle: "Authorize Kernel Firewall (Admin)...")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            PreferencesManager.shared.hasGrantedFirewallPermission = true
            refreshPermissionsStatus()
            return true
        } else if response == .alertSecondButtonReturn {
            PreferencesManager.shared.hasGrantedFirewallPermission = true
            refreshPermissionsStatus()
            authorizeKernelFirewallWithAdminPrompt()
            return true
        }
        return false
    }
    
    /// Invokes the native macOS Touch ID / Administrator password dialog for pfctl packet filter access
    public func authorizeKernelFirewallWithAdminPrompt() {
        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            task.arguments = [
                "-e",
                "do shell script \"/sbin/pfctl -s info >/dev/null 2>&1\" with administrator privileges"
            ]
            do {
                try task.run()
                task.waitUntilExit()
                if task.terminationStatus == 0 {
                    DispatchQueue.main.async {
                        PreferencesManager.shared.hasGrantedFirewallPermission = true
                        PreferencesManager.shared.kernelFirewallAuthorized = true
                        self.refreshPermissionsStatus()
                    }
                }
            } catch {
                // User canceled or osascript unavailable
            }
        }
    }
    
    /// Requests macOS Notification permission or opens System Settings -> Notifications
    public func requestNotificationPermission() {
        guard isBundledApp else {
            if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
                NSWorkspace.shared.open(url)
            }
            return
        }
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            if settings.authorizationStatus == .notDetermined {
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    DispatchQueue.main.async {
                        self.notificationsAuthorized = granted
                    }
                }
            } else {
                DispatchQueue.main.async {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
    }
    
    /// Triggers the native macOS Accessibility permission prompt for the global ⌥T shortcut
    public func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        DispatchQueue.main.async {
            self.accessibilityTrusted = trusted
        }
    }
    
    public func openSystemPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") {
            NSWorkspace.shared.open(url)
        }
    }
}

public final class FirewallController {
    public static let shared = FirewallController()
    
    public private(set) var isShieldActive: Bool = false
    public private(set) var isLockdownActive: Bool = false
    private var pausedPIDs: Set<Int32> = []
    private let lock = NSLock()
    
    // Protected PIDs and processes that must never be SIGSTOPped (system stability & self)
    private let protectedProcessNames: Set<String> = [
        "TripGuard", "Finder", "WindowServer", "loginwindow", "Dock", "SystemUIServer",
        "ControlCenter", "mDNSResponder", "configd", "networkserviceproxy", "trustd",
        "securityd", "UserEventAgent", "launchd", "kernel_task", " airportd", "wifip2pd",
        "Bluetoothd", "coreaudiod", "hidd", "PowerUIAgent", "NotificationCenter"
    ]
    
    private init() {}
    
    public func activateShield() {
        guard !isShieldActive else { return }
        if !PreferencesManager.shared.hasGrantedFirewallPermission {
            let granted = PermissionsManager.shared.promptFirewallPermissionModal()
            if !granted {
                NotificationCenter.default.post(name: .shieldStateDidChange, object: nil)
                return
            }
        }
        isShieldActive = true
        NotificationCenter.default.post(name: .shieldStateDidChange, object: nil)
        NetworkMonitorEngine.shared.triggerImmediateEnforcement()
    }
    
    public func deactivateShield() {
        isShieldActive = false
        isLockdownActive = false
        resumeAllPausedProcesses()
        NotificationCenter.default.post(name: .shieldStateDidChange, object: nil)
    }
    
    public func toggleShield() {
        if isShieldActive {
            deactivateShield()
        } else {
            activateShield()
        }
    }
    
    public func setLockdown(_ enabled: Bool) {
        isLockdownActive = enabled
        if enabled && !isShieldActive {
            isShieldActive = true
        }
        if !enabled {
            resumeAllowedProcesses()
        }
        NotificationCenter.default.post(name: .shieldStateDidChange, object: nil)
        NetworkMonitorEngine.shared.triggerImmediateEnforcement()
    }
    
    public func isAppPermitted(identifier: String, isSystemDaemon: Bool) -> Bool {
        if !isShieldActive {
            return true
        }
        if isLockdownActive {
            return false
        }
        return PreferencesManager.shared.isAppAllowed(
            identifier: identifier,
            defaultAllowed: !isSystemDaemon
        )
    }
    
    /// Called when a blocked app attempts network traffic while Shield is ON
    public func enforceBlockOnPIDs(_ pids: Set<Int32>, appName: String, isSystemDaemon: Bool) -> Int {
        guard isShieldActive else { return 0 }
        guard PreferencesManager.shared.strictProcessBlocker else { return 1 }
        
        let myPID = ProcessInfo.processInfo.processIdentifier
        let myUID = getuid()
        var newlyHandled = 0
        
        lock.lock()
        defer { lock.unlock() }
        
        for pid in pids {
            if pid <= 100 || pid == myPID { continue }
            if protectedProcessNames.contains(appName) { continue }
            if isSystemDaemon { continue }
            
            if let frontApp = NSWorkspace.shared.frontmostApplication,
               frontApp.processIdentifier == pid {
                newlyHandled += 1
                continue
            }
            
            var info = proc_bsdinfo()
            let size = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, Int32(MemoryLayout<proc_bsdinfo>.stride))
            if size == Int32(MemoryLayout<proc_bsdinfo>.stride) && info.pbi_uid == myUID {
                if !pausedPIDs.contains(pid) {
                    if kill(pid, SIGSTOP) == 0 {
                        pausedPIDs.insert(pid)
                        newlyHandled += 1
                    }
                } else {
                    newlyHandled += 1
                }
            }
        }
        return max(1, newlyHandled)
    }
    
    public func resumePIDs(_ pids: Set<Int32>) {
        lock.lock()
        defer { lock.unlock() }
        
        for pid in pids {
            if pausedPIDs.contains(pid) {
                kill(pid, SIGCONT)
                pausedPIDs.remove(pid)
            }
        }
    }
    
    public func resumeAllowedProcesses() {
        let entries = NetworkMonitorEngine.shared.apps
        for entry in entries {
            if isAppPermitted(identifier: entry.id, isSystemDaemon: entry.isSystemDaemon) {
                resumePIDs(entry.pids)
            }
        }
    }
    
    public func resumeAllPausedProcesses() {
        lock.lock()
        let allPaused = pausedPIDs
        pausedPIDs.removeAll()
        lock.unlock()
        
        for pid in allPaused {
            kill(pid, SIGCONT)
        }
    }
    
    public func isPIDPaused(_ pid: Int32) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return pausedPIDs.contains(pid)
    }
    
    public func hasAnyPausedPID(_ pids: Set<Int32>) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return !pausedPIDs.isDisjoint(with: pids)
    }
    
    /// Inspects live TCP/UDP sockets for a set of PIDs using lsof
    public func inspectSockets(for pids: Set<Int32>) -> [SocketConnectionInfo] {
        guard !pids.isEmpty else { return [] }
        let pidList = pids.map(String.init).joined(separator: ",")
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        task.arguments = ["-i", "-n", "-P", "-a", "-p", pidList]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return []
        }
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return [] }
        
        var connections: [SocketConnectionInfo] = []
        let lines = output.components(separatedBy: .newlines)
        
        for line in lines.dropFirst() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            
            let parts = trimmed.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            guard parts.count >= 9 else { continue }
            
            let pidVal = Int32(parts[1]) ?? 0
            let proto = parts[7]
            let nameField = parts[8]
            let stateField = parts.count >= 10 ? parts[9].replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: "") : "ACTIVE"
            
            let endpoints = nameField.components(separatedBy: "->")
            let localAddr = endpoints.first ?? nameField
            let remoteAddr = endpoints.count > 1 ? endpoints[1] : "Listening"
            
            let info = SocketConnectionInfo(
                proto: proto,
                localAddress: localAddr,
                remoteAddress: remoteAddr,
                state: stateField,
                pid: pidVal
            )
            if !connections.contains(where: { $0.remoteAddress == info.remoteAddress && $0.proto == info.proto }) {
                connections.append(info)
            }
        }
        
        return Array(connections.prefix(8))
    }
    
    public func sendCutoffNotification(usedMB: Double, capMB: Int) {
        guard PreferencesManager.shared.allowNotifications else { return }
        NSSound.beep()
        guard Bundle.main.bundlePath.hasSuffix(".app") else { return }
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "TripGuard Data Cap Reached"
        content.body = String(format: "Session usage reached %.1f MB (Limit: %d MB). Lockdown enabled to prevent overage.", usedMB, capMB)
        content.sound = .default
        let req = UNNotificationRequest(identifier: "tripguard.datacap.\(Int(Date().timeIntervalSince1970))", content: content, trigger: nil)
        center.add(req)
    }
}
