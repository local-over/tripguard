import AppKit
import Foundation
import Darwin

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        signal(SIGINT) { _ in
            UsageHistoryStore.shared.saveToDiskIfNeeded()
            FirewallController.shared.resumeAllPausedProcesses()
            exit(0)
        }
        signal(SIGTERM) { _ in
            UsageHistoryStore.shared.saveToDiskIfNeeded()
            FirewallController.shared.resumeAllPausedProcesses()
            exit(0)
        }
        
        statusBarController = StatusBarController()
        PermissionsManager.shared.requestInitialPermissionsOnLaunchIfNeeded()
        // Open the full TripGuard application window on launch so the user can explore Overview & History right away
        FloatingWindowManager.shared.showMainAppWindow(initialTab: .overview)
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            FloatingWindowManager.shared.showMainAppWindow(initialTab: .overview)
        }
        return true
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        UsageHistoryStore.shared.saveToDiskIfNeeded()
        FirewallController.shared.deactivateShield()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
