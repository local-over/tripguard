import Foundation
import ServiceManagement

public extension Notification.Name {
    static let shieldStateDidChange = Notification.Name("shieldStateDidChange")
    static let networkStatsDidUpdate = Notification.Name("networkStatsDidUpdate")
    static let preferencesDidChange = Notification.Name("preferencesDidChange")
}

public final class PreferencesManager {
    public static let shared = PreferencesManager()
    
    private let defaults = UserDefaults.standard
    
    public enum Keys {
        public static let launchAtLogin = "launchAtLogin"
        public static let activateAtLaunch = "activateAtLaunch"
        public static let activateWithLeftClick = "activateWithLeftClick"
        public static let autoActivateOnNetworkChange = "autoActivateOnNetworkChange"
        public static let autoCutoffAtLimit = "autoCutoffAtLimit"
        public static let showMenuBarSpeed = "showMenuBarSpeed"
        public static let coloredMenuBarIcon = "coloredMenuBarIcon"
        public static let strictProcessBlocker = "strictProcessBlocker"
        public static let allowNotifications = "allowNotifications"
        public static let showSystemDaemons = "showSystemDaemons"
        public static let selectedDataCapMB = "selectedDataCapMB"
        public static let selectedProfile = "selectedProfile"
        public static let profileRulesPrefix = "profileRules_"
        public static let persistedSessionBytes = "persistedSessionBytes"
        public static let hasGrantedFirewallPermission = "hasGrantedFirewallPermission"
        public static let kernelFirewallAuthorized = "kernelFirewallAuthorized"
    }
    
    public static let profiles = ["Default", "Hotspot", "Work", "Travel"]
    
    private init() {
        registerDefaults()
    }
    
    private func registerDefaults() {
        defaults.register(defaults: [
            Keys.launchAtLogin: false,
            Keys.activateAtLaunch: false,
            Keys.activateWithLeftClick: false,
            Keys.autoActivateOnNetworkChange: true,
            Keys.autoCutoffAtLimit: true,
            Keys.showMenuBarSpeed: true,
            Keys.coloredMenuBarIcon: false,
            Keys.strictProcessBlocker: true,
            Keys.allowNotifications: true,
            Keys.showSystemDaemons: false,
            Keys.selectedDataCapMB: 0, // 0 = unlimited (∞)
            Keys.selectedProfile: "Default",
            Keys.persistedSessionBytes: 0,
            Keys.hasGrantedFirewallPermission: false,
            Keys.kernelFirewallAuthorized: false
        ])
    }
    
    public var hasGrantedFirewallPermission: Bool {
        get { defaults.bool(forKey: Keys.hasGrantedFirewallPermission) }
        set {
            defaults.set(newValue, forKey: Keys.hasGrantedFirewallPermission)
            NotificationCenter.default.post(name: .preferencesDidChange, object: nil)
        }
    }
    
    public var kernelFirewallAuthorized: Bool {
        get { defaults.bool(forKey: Keys.kernelFirewallAuthorized) }
        set {
            defaults.set(newValue, forKey: Keys.kernelFirewallAuthorized)
            NotificationCenter.default.post(name: .preferencesDidChange, object: nil)
        }
    }
    
    public var launchAtLogin: Bool {
        get { defaults.bool(forKey: Keys.launchAtLogin) }
        set {
            defaults.set(newValue, forKey: Keys.launchAtLogin)
            if #available(macOS 13.0, *) {
                try? (newValue ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister())
            }
            NotificationCenter.default.post(name: .preferencesDidChange, object: nil)
        }
    }
    
    public var activateAtLaunch: Bool {
        get { defaults.bool(forKey: Keys.activateAtLaunch) }
        set { defaults.set(newValue, forKey: Keys.activateAtLaunch) }
    }
    
    public var activateWithLeftClick: Bool {
        get { defaults.bool(forKey: Keys.activateWithLeftClick) }
        set { defaults.set(newValue, forKey: Keys.activateWithLeftClick) }
    }
    
    public var autoActivateOnNetworkChange: Bool {
        get { defaults.bool(forKey: Keys.autoActivateOnNetworkChange) }
        set { defaults.set(newValue, forKey: Keys.autoActivateOnNetworkChange) }
    }
    
    public var autoCutoffAtLimit: Bool {
        get { defaults.bool(forKey: Keys.autoCutoffAtLimit) }
        set { defaults.set(newValue, forKey: Keys.autoCutoffAtLimit) }
    }
    
    public var showMenuBarSpeed: Bool {
        get { defaults.bool(forKey: Keys.showMenuBarSpeed) }
        set {
            defaults.set(newValue, forKey: Keys.showMenuBarSpeed)
            NotificationCenter.default.post(name: .preferencesDidChange, object: nil)
        }
    }
    
    public var coloredMenuBarIcon: Bool {
        get { defaults.bool(forKey: Keys.coloredMenuBarIcon) }
        set {
            defaults.set(newValue, forKey: Keys.coloredMenuBarIcon)
            NotificationCenter.default.post(name: .preferencesDidChange, object: nil)
        }
    }
    
    public var strictProcessBlocker: Bool {
        get { defaults.bool(forKey: Keys.strictProcessBlocker) }
        set {
            defaults.set(newValue, forKey: Keys.strictProcessBlocker)
            NotificationCenter.default.post(name: .preferencesDidChange, object: nil)
        }
    }
    
    public var allowNotifications: Bool {
        get { defaults.bool(forKey: Keys.allowNotifications) }
        set { defaults.set(newValue, forKey: Keys.allowNotifications) }
    }
    
    public var showSystemDaemons: Bool {
        get { defaults.bool(forKey: Keys.showSystemDaemons) }
        set {
            defaults.set(newValue, forKey: Keys.showSystemDaemons)
            NotificationCenter.default.post(name: .preferencesDidChange, object: nil)
        }
    }
    
    public var selectedDataCapMB: Int {
        get { defaults.integer(forKey: Keys.selectedDataCapMB) }
        set {
            defaults.set(newValue, forKey: Keys.selectedDataCapMB)
            NotificationCenter.default.post(name: .preferencesDidChange, object: nil)
        }
    }
    
    public var selectedProfile: String {
        get { defaults.string(forKey: Keys.selectedProfile) ?? "Default" }
        set {
            defaults.set(newValue, forKey: Keys.selectedProfile)
            NotificationCenter.default.post(name: .preferencesDidChange, object: nil)
        }
    }
    
    // MARK: - Per-Profile App Rules (true = Allowed, false = Blocked)
    
    public func isAppAllowed(identifier: String, defaultAllowed: Bool = true) -> Bool {
        let key = Keys.profileRulesPrefix + selectedProfile
        guard let dict = defaults.dictionary(forKey: key) as? [String: Bool] else {
            return defaultInitialState(for: identifier, fallback: defaultAllowed)
        }
        if let explicit = dict[identifier] {
            return explicit
        }
        return defaultInitialState(for: identifier, fallback: defaultAllowed)
    }
    
    public func setAppAllowed(identifier: String, allowed: Bool) {
        let key = Keys.profileRulesPrefix + selectedProfile
        var dict = (defaults.dictionary(forKey: key) as? [String: Bool]) ?? [:]
        dict[identifier] = allowed
        defaults.set(dict, forKey: key)
        NotificationCenter.default.post(name: .preferencesDidChange, object: nil)
    }
    
    public func setAllAppsAllowed(identifiers: [String], allowed: Bool) {
        let key = Keys.profileRulesPrefix + selectedProfile
        var dict = (defaults.dictionary(forKey: key) as? [String: Bool]) ?? [:]
        for id in identifiers {
            dict[id] = allowed
        }
        defaults.set(dict, forKey: key)
        NotificationCenter.default.post(name: .preferencesDidChange, object: nil)
    }
    
    public func resetCurrentProfileRules() {
        let key = Keys.profileRulesPrefix + selectedProfile
        defaults.removeObject(forKey: key)
        NotificationCenter.default.post(name: .preferencesDidChange, object: nil)
    }
    
    private func defaultInitialState(for identifier: String, fallback: Bool) -> Bool {
        // Smart default: Browsers, terminals, and core communication allowed; heavy cloud syncers/updaters blocked by default in Hotspot/Travel profiles
        let lower = identifier.lowercased()
        let heavySyncers = [
            "dropbox", "onedrive", "icloud", "bird", "cloudd", "nsurlsessiond",
            "photolibraryd", "photos", "steam", "epicgames", "battle.net",
            "creative cloud", "adobe", "softwareupdated", "appstore", "spotlight",
            "backup", "timemachine", "spotify"
        ]
        if heavySyncers.contains(where: { lower.contains($0) }) {
            return false
        }
        if selectedProfile == "Hotspot" || selectedProfile == "Travel" {
            let essential = ["safari", "chrome", "firefox", "arc", "brave", "whatsapp", "slack", "telegram", "messages", "mail", "antigravity", "cursor", "code", "terminal", "iterm", "warp", "mdnsresponder"]
            return essential.contains(where: { lower.contains($0) })
        }
        return fallback
    }
}
