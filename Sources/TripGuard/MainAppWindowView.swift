import SwiftUI
import AppKit
import ServiceManagement
import UniformTypeIdentifiers

public enum MainNavTab: String, CaseIterable, Identifiable {
    case overview = "Overview & History"
    case applications = "Applications"
    case limits = "Limits & Profiles"
    case settings = "Settings"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .overview: return "chart.bar.xaxis"
        case .applications: return "app.badge.checkmark"
        case .limits: return "gauge.with.dots.needle.67percent"
        case .settings: return "gearshape"
        }
    }
}

public enum AppListFilter: String, CaseIterable {
    case all = "All Apps"
    case allowed = "Allowed"
    case blocked = "Blocked"
    case activeNow = "Active Now"
}

public enum AppSortField: String, CaseIterable {
    case totalBytes = "Total Data"
    case downloadBytes = "Downloaded"
    case uploadBytes = "Uploaded"
    case liveSpeed = "Live Speed"
    case name = "Name"
}

public struct MainAppWindowView: View {
    @ObservedObject var state = PopoverState.shared
    @ObservedObject var permissions = PermissionsManager.shared
    
    @State private var selectedTimeRange: TimeRangeFilter = .today
    @State private var appFilter: AppListFilter = .all
    @State private var sortField: AppSortField = .totalBytes
    @State private var sortAscending: Bool = false
    @State private var searchText: String = ""
    @State private var inspectedSockets: [SocketConnectionInfo] = []
    @State private var hoveredBarPoint: ChartBarPoint? = nil
    @State private var customDataCapText: String = ""
    @State private var showClearHistoryConfirm: Bool = false
    @State private var permissionBannerDismissed: Bool = false
    
    @AppStorage(PreferencesManager.Keys.launchAtLogin) private var launchAtLogin = false
    @AppStorage(PreferencesManager.Keys.activateAtLaunch) private var activateAtLaunch = false
    @AppStorage(PreferencesManager.Keys.activateWithLeftClick) private var activateWithLeftClick = false
    @AppStorage(PreferencesManager.Keys.autoActivateOnNetworkChange) private var autoActivateOnNetworkChange = true
    @AppStorage(PreferencesManager.Keys.autoCutoffAtLimit) private var autoCutoffAtLimit = true
    @AppStorage(PreferencesManager.Keys.showMenuBarSpeed) private var showMenuBarSpeed = true
    @AppStorage(PreferencesManager.Keys.coloredMenuBarIcon) private var coloredMenuBarIcon = false
    @AppStorage(PreferencesManager.Keys.strictProcessBlocker) private var strictProcessBlocker = true
    @AppStorage(PreferencesManager.Keys.showSystemDaemons) private var showSystemDaemons = false
    @AppStorage(PreferencesManager.Keys.allowNotifications) private var allowNotifications = true
    @AppStorage(PreferencesManager.Keys.selectedDataCapMB) private var selectedDataCapMB = 0
    @AppStorage(PreferencesManager.Keys.selectedProfile) private var selectedProfile = "Default"
    
    public init(initialTab: MainNavTab = .overview) {
        PopoverState.shared.selectedMainTab = initialTab
    }
    
    private var entriesForSelectedRange: [AppTrafficEntry] {
        NetworkMonitorEngine.shared.entries(for: selectedTimeRange)
    }
    
    private func countForFilter(_ mode: AppListFilter) -> Int {
        entriesForSelectedRange.filter { app in
            let allowed = PreferencesManager.shared.isAppAllowed(identifier: app.id, defaultAllowed: !app.isSystemDaemon)
            switch mode {
            case .all: return true
            case .allowed: return allowed
            case .blocked: return !allowed
            case .activeNow: return app.totalSpeedBps >= 100
            }
        }.count
    }
    
    private var filteredAndSortedApps: [AppTrafficEntry] {
        let base = entriesForSelectedRange.filter { app in
            if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if !app.name.localizedCaseInsensitiveContains(searchText) &&
                   !app.id.localizedCaseInsensitiveContains(searchText) {
                    return false
                }
            }
            let allowed = PreferencesManager.shared.isAppAllowed(identifier: app.id, defaultAllowed: !app.isSystemDaemon)
            switch appFilter {
            case .all: return true
            case .allowed: return allowed
            case .blocked: return !allowed
            case .activeNow: return app.totalSpeedBps >= 100
            }
        }
        
        return base.sorted { a, b in
            let asc = sortAscending
            switch sortField {
            case .totalBytes:
                if a.totalSessionBytes != b.totalSessionBytes {
                    return asc ? (a.totalSessionBytes < b.totalSessionBytes) : (a.totalSessionBytes > b.totalSessionBytes)
                }
            case .downloadBytes:
                if a.sessionBytesIn != b.sessionBytesIn {
                    return asc ? (a.sessionBytesIn < b.sessionBytesIn) : (a.sessionBytesIn > b.sessionBytesIn)
                }
            case .uploadBytes:
                if a.sessionBytesOut != b.sessionBytesOut {
                    return asc ? (a.sessionBytesOut < b.sessionBytesOut) : (a.sessionBytesOut > b.sessionBytesOut)
                }
            case .liveSpeed:
                if abs(a.totalSpeedBps - b.totalSpeedBps) > 10 {
                    return asc ? (a.totalSpeedBps < b.totalSpeedBps) : (a.totalSpeedBps > b.totalSpeedBps)
                }
            case .name:
                let cmp = a.name.localizedCaseInsensitiveCompare(b.name)
                return asc ? (cmp == .orderedDescending) : (cmp == .orderedAscending)
            }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }
    
    private var rangeTotals: (bytesIn: UInt64, bytesOut: UInt64, blocked: Int) {
        var bIn: UInt64 = 0
        var bOut: UInt64 = 0
        var blk: Int = 0
        for e in entriesForSelectedRange {
            bIn += e.sessionBytesIn
            bOut += e.sessionBytesOut
            blk += e.blockedAttempts
        }
        return (bIn, bOut, blk)
    }
    
    public var body: some View {
        HStack(spacing: 0) {
            // Left Sidebar
            sidebarView
                .frame(width: 218)
                .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Main Content Area
            VStack(spacing: 0) {
                topToolbarView
                Divider()
                
                if !permissions.firewallPermissionGranted && !permissionBannerDismissed {
                    permissionPromptBanner
                    Divider()
                }
                
                Group {
                    switch state.selectedMainTab {
                    case .overview:
                        overviewTabView
                    case .applications:
                        applicationsTabView
                    case .limits:
                        limitsAndProfilesTabView
                    case .settings:
                        settingsTabView
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Color(NSColor.controlBackgroundColor).opacity(0.45))
        }
        .frame(minWidth: 880, minHeight: 580)
        .onChange(of: state.selectedAppID) { newID in
            if let id = newID, let entry = entriesForSelectedRange.first(where: { $0.id == id }) {
                inspectedSockets = FirewallController.shared.inspectSockets(for: entry.pids)
            }
        }
        .alert("Clear All Historical Data?", isPresented: $showClearHistoryConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Clear History", role: .destructive) {
                UsageHistoryStore.shared.clearAllHistory()
                NetworkMonitorEngine.shared.resetSessionCounters()
            }
        } message: {
            Text("This will reset all recorded hourly, daily, and monthly network usage history and start fresh from zero.")
        }
    }
    
    // MARK: - Top Permission Banner
    
    private var permissionPromptBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 16))
                .foregroundColor(Color(red: 0.00, green: 0.55, blue: 0.95))
            
            VStack(alignment: .leading, spacing: 1) {
                Text("Permissions Required for Full Network Firewall Control")
                    .font(.system(size: 12, weight: .bold))
                Text("Grant TripGuard permission to block unauthorized background apps and send data cap notifications.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Grant Permission...") {
                if PermissionsManager.shared.promptFirewallPermissionModal() {
                    PermissionsManager.shared.requestNotificationPermission()
                }
            }
            .font(.system(size: 11.5, weight: .semibold))
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            
            Button {
                permissionBannerDismissed = true
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 9)
        .background(Color(red: 0.00, green: 0.55, blue: 0.95).opacity(0.08))
    }
    
    // MARK: - Sidebar
    
    private var sidebarView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // App Identity Card
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.00, green: 0.82, blue: 0.56),
                                    Color(red: 0.00, green: 0.55, blue: 0.96)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 34, height: 34)
                    Image(systemName: "shield.checkered")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("TripGuard")
                        .font(.system(size: 14, weight: .bold))
                    Text(state.activeInterfaceName)
                        .font(.system(size: 10.5))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 14)
            
            // Shield Status Card inside Sidebar
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Circle()
                        .fill(state.isShieldActive ? Color(red: 0.00, green: 0.78, blue: 0.55) : Color.secondary)
                        .frame(width: 8, height: 8)
                    Text(state.isShieldActive ? "Shield Active" : "Monitoring Only")
                        .font(.system(size: 11.5, weight: .semibold))
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { state.isShieldActive },
                        set: { val in
                            if val { FirewallController.shared.activateShield() }
                            else { FirewallController.shared.deactivateShield() }
                        }
                    ))
                    .toggleStyle(.switch)
                    .scaleEffect(0.75)
                    .labelsHidden()
                }
                
                HStack {
                    Text("↓ " + NetworkMonitorEngine.formatSpeed(state.totalDownloadSpeedBps))
                        .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color(red: 0.00, green: 0.62, blue: 0.95))
                    Spacer()
                    Text("↑ " + NetworkMonitorEngine.formatSpeed(state.totalUploadSpeedBps))
                        .font(.system(size: 10.5, weight: .regular, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            .padding(11)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.primary.opacity(0.045))
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 16)
            
            Text("NAVIGATION")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 18)
                .padding(.bottom, 6)
            
            VStack(spacing: 4) {
                ForEach(MainNavTab.allCases) { tab in
                    let isSel = (state.selectedMainTab == tab)
                    Button {
                        state.selectedMainTab = tab
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 13, weight: isSel ? .semibold : .regular))
                                .frame(width: 18)
                                .foregroundColor(isSel ? .white : Color(red: 0.00, green: 0.55, blue: 0.95))
                            Text(tab.rawValue)
                                .font(.system(size: 12.5, weight: isSel ? .semibold : .medium))
                                .foregroundColor(isSel ? .white : .primary)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isSel ? Color(red: 0.00, green: 0.52, blue: 0.95) : Color.clear)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            
            Spacer()
            
            Divider()
                .padding(.horizontal, 12)
            
            // Bottom Sidebar Quick Controls
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Active Profile")
                        .font(.system(size: 10.5))
                        .foregroundColor(.secondary)
                    Spacer()
                    Menu {
                        ForEach(PreferencesManager.profiles, id: \.self) { prof in
                            Button {
                                selectedProfile = prof
                                FirewallController.shared.resumeAllowedProcesses()
                                NetworkMonitorEngine.shared.triggerImmediateEnforcement()
                                state.refresh()
                            } label: {
                                HStack {
                                    Text(prof)
                                    if selectedProfile == prof {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Text(selectedProfile)
                            .font(.system(size: 10.5, weight: .semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(red: 0.00, green: 0.55, blue: 0.95).opacity(0.14))
                            .foregroundColor(Color(red: 0.00, green: 0.55, blue: 0.95))
                            .cornerRadius(4)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
                
                HStack(spacing: 10) {
                    Button {
                        FloatingWindowManager.shared.showAboutWindow()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 10.5))
                            Text("About")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    
                    Text("•")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    
                    Button {
                        FloatingWindowManager.shared.showDonateWindow()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 10))
                                .foregroundColor(Color(red: 0.00, green: 0.68, blue: 0.95))
                            Text("Support")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 2)
            }
            .padding(14)
        }
    }
    
    // MARK: - Top Toolbar (Time Range Selector & Export)
    
    private var topToolbarView: some View {
        HStack(spacing: 12) {
            Text(state.selectedMainTab.rawValue)
                .font(.system(size: 16, weight: .bold))
            
            Spacer()
            
            if state.selectedMainTab == .overview || state.selectedMainTab == .applications {
                // Time Range Filter Pills: Session | Today | 7 Days | 30 Days | Monthly
                HStack(spacing: 3) {
                    ForEach(TimeRangeFilter.allCases) { range in
                        let isSel = (selectedTimeRange == range)
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedTimeRange = range
                                hoveredBarPoint = nil
                            }
                        } label: {
                            Text(range.shortLabel)
                                .font(.system(size: 11, weight: isSel ? .semibold : .medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(isSel ? Color(red: 0.00, green: 0.52, blue: 0.95) : Color.clear)
                                )
                                .foregroundColor(isSel ? .white : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.primary.opacity(0.06))
                )
                
                Button {
                    exportCurrentRangeCSV()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 11))
                        Text("Export CSV")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.primary.opacity(0.06))
                    )
                }
                .buttonStyle(.plain)
                .help("Export usage table to CSV")
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - Tab 1: Overview & History
    
    private var overviewTabView: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 18) {
                let totals = rangeTotals
                let grandTotal = totals.bytesIn + totals.bytesOut
                
                // 1. 4 Metric Summary Cards
                HStack(spacing: 14) {
                    metricCard(
                        title: "\(selectedTimeRange.rawValue) Total",
                        value: NetworkMonitorEngine.formatBytes(grandTotal),
                        subtitle: selectedDataCapMB > 0 ? "Cap: \(selectedDataCapMB) MB" : "No Data Cap Set",
                        icon: "chart.pie.fill",
                        tint: Color(red: 0.00, green: 0.55, blue: 0.95)
                    )
                    
                    metricCard(
                        title: "Downloaded",
                        value: NetworkMonitorEngine.formatBytes(totals.bytesIn),
                        subtitle: "Live: ↓ " + NetworkMonitorEngine.formatSpeed(state.totalDownloadSpeedBps),
                        icon: "arrow.down.circle.fill",
                        tint: Color(red: 0.00, green: 0.72, blue: 0.55)
                    )
                    
                    metricCard(
                        title: "Uploaded",
                        value: NetworkMonitorEngine.formatBytes(totals.bytesOut),
                        subtitle: "Live: ↑ " + NetworkMonitorEngine.formatSpeed(state.totalUploadSpeedBps),
                        icon: "arrow.up.circle.fill",
                        tint: Color.purple
                    )
                    
                    metricCard(
                        title: "Blocked Attempts",
                        value: "\(totals.blocked)",
                        subtitle: state.isShieldActive ? "Shield Enforcing (\(selectedProfile))" : "Shield Inactive",
                        icon: "hand.raised.shield.fill",
                        tint: Color.red
                    )
                }
                
                // 2. Visual Timeline Usage Chart Card (Hours / Days / Months)
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Data Usage Timeline (\(selectedTimeRange.rawValue))")
                                .font(.system(size: 13.5, weight: .bold))
                            if let hov = hoveredBarPoint {
                                Text("\(hov.fullDateLabel) — Total: \(NetworkMonitorEngine.formatBytes(hov.totalBytes)) (↓ \(NetworkMonitorEngine.formatBytes(hov.bytesIn)) / ↑ \(NetworkMonitorEngine.formatBytes(hov.bytesOut)))")
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                    .foregroundColor(Color(red: 0.00, green: 0.55, blue: 0.95))
                            } else {
                                Text("Hover or click any bar to inspect \(timelineGranularityLabel)")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        
                        HStack(spacing: 12) {
                            HStack(spacing: 5) {
                                Circle().fill(Color(red: 0.00, green: 0.58, blue: 0.96)).frame(width: 8, height: 8)
                                Text("Download").font(.system(size: 11)).foregroundColor(.secondary)
                            }
                            HStack(spacing: 5) {
                                Circle().fill(Color(red: 0.00, green: 0.80, blue: 0.56)).frame(width: 8, height: 8)
                                Text("Upload").font(.system(size: 11)).foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    let points = UsageHistoryStore.shared.chartPoints(for: selectedTimeRange)
                    usageBarChartView(points: points, height: 170)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(NSColor.windowBackgroundColor))
                        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
                )
                
                // 3. Top Applications Usage Breakdown Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Top Data Consumers (\(selectedTimeRange.shortLabel))")
                            .font(.system(size: 13.5, weight: .bold))
                        Spacer()
                        Button("View All Applications →") {
                            state.selectedMainTab = .applications
                        }
                        .font(.system(size: 11.5, weight: .semibold))
                        .buttonStyle(.plain)
                        .foregroundColor(Color(red: 0.00, green: 0.55, blue: 0.95))
                    }
                    
                    let topApps = Array(entriesForSelectedRange.prefix(6))
                    let maxAppBytes = max(1, topApps.first?.totalSessionBytes ?? 1)
                    
                    if topApps.isEmpty {
                        Text("No application network usage recorded for this period yet.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .padding(.vertical, 16)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(topApps) { app in
                                let isAllowed = PreferencesManager.shared.isAppAllowed(identifier: app.id, defaultAllowed: !app.isSystemDaemon)
                                let ratio = Double(app.totalSessionBytes) / Double(maxAppBytes)
                                
                                HStack(spacing: 10) {
                                    Button {
                                        state.selectedAppID = app.id
                                        state.selectedMainTab = .applications
                                    } label: {
                                        HStack(spacing: 10) {
                                            Image(nsImage: app.icon)
                                                .resizable()
                                                .frame(width: 24, height: 24)
                                            
                                            VStack(alignment: .leading, spacing: 3) {
                                                HStack {
                                                    Text(app.name)
                                                        .font(.system(size: 12, weight: .semibold))
                                                        .foregroundColor(.primary)
                                                    Spacer()
                                                    Text("↓ \(NetworkMonitorEngine.formatBytes(app.sessionBytesIn))   ↑ \(NetworkMonitorEngine.formatBytes(app.sessionBytesOut))")
                                                        .font(.system(size: 10.5, design: .monospaced))
                                                        .foregroundColor(.secondary)
                                                    Text(NetworkMonitorEngine.formatBytes(app.totalSessionBytes))
                                                        .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                                                        .foregroundColor(.primary)
                                                        .frame(width: 75, alignment: .trailing)
                                                }
                                                
                                                GeometryReader { geo in
                                                    ZStack(alignment: .leading) {
                                                        RoundedRectangle(cornerRadius: 3)
                                                            .fill(Color.primary.opacity(0.06))
                                                            .frame(height: 6)
                                                        RoundedRectangle(cornerRadius: 3)
                                                            .fill(isAllowed ? Color(red: 0.00, green: 0.58, blue: 0.96) : Color.red.opacity(0.75))
                                                            .frame(width: max(4, geo.size.width * CGFloat(ratio)), height: 6)
                                                    }
                                                }
                                                .frame(height: 6)
                                            }
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
                                    .scaleEffect(0.72)
                                    .labelsHidden()
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(NSColor.windowBackgroundColor))
                        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
                )
            }
            .padding(20)
        }
    }
    
    // MARK: - Tab 2: Applications (Full Filterable Table + Per-App History Drawer)
    
    private var applicationsTabView: some View {
        VStack(spacing: 0) {
            // Filter & Search Bar
            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    TextField("Filter applications by name...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(width: 210)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color.primary.opacity(0.06))
                )
                
                // Status Filter Pills with Live Counts
                HStack(spacing: 4) {
                    ForEach(AppListFilter.allCases, id: \.self) { mode in
                        let isSel = (appFilter == mode)
                        let cnt = countForFilter(mode)
                        Button {
                            appFilter = mode
                        } label: {
                            Text("\(mode.rawValue) (\(cnt))")
                                .font(.system(size: 11, weight: isSel ? .semibold : .medium))
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(isSel ? Color(red: 0.00, green: 0.55, blue: 0.95) : Color.primary.opacity(0.05))
                                )
                                .foregroundColor(isSel ? .white : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Spacer()
                
                // Sort Picker
                Menu {
                    ForEach(AppSortField.allCases, id: \.self) { field in
                        Button {
                            if sortField == field {
                                sortAscending.toggle()
                            } else {
                                sortField = field
                                sortAscending = false
                            }
                        } label: {
                            HStack {
                                Text("Sort by \(field.rawValue)")
                                if sortField == field {
                                    Image(systemName: sortAscending ? "arrow.up" : "arrow.down")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 10))
                        Text("Sort: \(sortField.rawValue)")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.primary.opacity(0.06))
                    )
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                
                Button("Allow All") {
                    let ids = entriesForSelectedRange.map(\.id)
                    PreferencesManager.shared.setAllAppsAllowed(identifiers: ids, allowed: true)
                    FirewallController.shared.setLockdown(false)
                    FirewallController.shared.resumeAllPausedProcesses()
                    state.refresh()
                }
                .font(.system(size: 11, weight: .semibold))
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button("Block All") {
                    let ids = entriesForSelectedRange.map(\.id)
                    PreferencesManager.shared.setAllAppsAllowed(identifiers: ids, allowed: false)
                    if !state.isShieldActive {
                        FirewallController.shared.activateShield()
                    } else {
                        NetworkMonitorEngine.shared.triggerImmediateEnforcement()
                    }
                    state.refresh()
                }
                .font(.system(size: 11, weight: .semibold))
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Master-Detail Split: Left Table + Right App Inspector
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    // Clickable Sortable Table Column Headers
                    HStack(spacing: 8) {
                        sortableColumnHeader("APPLICATION", field: .name, alignment: .leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        sortableColumnHeader("LIVE SPEED", field: .liveSpeed, alignment: .trailing)
                            .frame(width: 90, alignment: .trailing)
                        sortableColumnHeader("DOWNLOADED", field: .downloadBytes, alignment: .trailing)
                            .frame(width: 90, alignment: .trailing)
                        sortableColumnHeader("UPLOADED", field: .uploadBytes, alignment: .trailing)
                            .frame(width: 85, alignment: .trailing)
                        sortableColumnHeader("TOTAL (\(selectedTimeRange.shortLabel.uppercased()))", field: .totalBytes, alignment: .trailing)
                            .frame(width: 100, alignment: .trailing)
                        Text("ACCESS")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                            .frame(width: 64, alignment: .center)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(Color.primary.opacity(0.03))
                    
                    Divider()
                    
                    ScrollView(.vertical, showsIndicators: true) {
                        LazyVStack(spacing: 2) {
                            let appsList = filteredAndSortedApps
                            if appsList.isEmpty {
                                Text("No matching applications found.")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                    .padding(.vertical, 40)
                            } else {
                                ForEach(appsList) { app in
                                    fullAppTableRow(app: app)
                                }
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Selected App Detail & History Drawer
                if let selID = state.selectedAppID,
                   let selectedApp = entriesForSelectedRange.first(where: { $0.id == selID }) {
                    Divider()
                    selectedAppDetailDrawer(app: selectedApp)
                        .frame(width: 285)
                        .background(Color(NSColor.windowBackgroundColor))
                }
            }
        }
    }
    
    @ViewBuilder
    private func sortableColumnHeader(_ title: String, field: AppSortField, alignment: Alignment) -> some View {
        Button {
            if sortField == field {
                sortAscending.toggle()
            } else {
                sortField = field
                sortAscending = false
            }
        } label: {
            HStack(spacing: 3) {
                if alignment == .trailing { Spacer(minLength: 0) }
                Text(title)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(sortField == field ? Color(red: 0.00, green: 0.55, blue: 0.95) : .secondary)
                if sortField == field {
                    Image(systemName: sortAscending ? "arrow.up" : "arrow.down")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundColor(Color(red: 0.00, green: 0.55, blue: 0.95))
                }
                if alignment == .leading { Spacer(minLength: 0) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private func fullAppTableRow(app: AppTrafficEntry) -> some View {
        let isAllowed = PreferencesManager.shared.isAppAllowed(identifier: app.id, defaultAllowed: !app.isSystemDaemon)
        let effectivelyBlocked = state.isShieldActive && (!isAllowed || state.isLockdownActive)
        let isSelected = (state.selectedAppID == app.id)
        
        HStack(spacing: 8) {
            // App Icon + Name + Subtitle
            HStack(spacing: 10) {
                Image(nsImage: app.icon)
                    .resizable()
                    .frame(width: 26, height: 26)
                    .opacity(effectivelyBlocked ? 0.55 : 1.0)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(app.name)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundColor(effectivelyBlocked ? .secondary : .primary)
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        Text(effectivelyBlocked ? "Blocked by Shield" : (app.isSystemDaemon ? "macOS Daemon" : "Allowed"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(effectivelyBlocked ? .red : .secondary)
                        
                        if app.blockedAttempts > 0 {
                            Text("• \(app.blockedAttempts) stopped")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Live Speed
            Text(app.totalSpeedBps >= 200 ? "↓ " + NetworkMonitorEngine.formatSpeed(app.totalSpeedBps) : "—")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(app.totalSpeedBps >= 200 ? Color(red: 0.00, green: 0.62, blue: 0.95) : .secondary)
                .frame(width: 90, alignment: .trailing)
            
            // Downloaded
            Text(NetworkMonitorEngine.formatBytes(app.sessionBytesIn))
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 90, alignment: .trailing)
            
            // Uploaded
            Text(NetworkMonitorEngine.formatBytes(app.sessionBytesOut))
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 85, alignment: .trailing)
            
            // Total
            Text(NetworkMonitorEngine.formatBytes(app.totalSessionBytes))
                .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                .foregroundColor(.primary)
                .frame(width: 100, alignment: .trailing)
            
            // Allow / Block Switch
            HStack {
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
                .scaleEffect(0.75)
                .labelsHidden()
            }
            .frame(width: 64, alignment: .center)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color(red: 0.00, green: 0.52, blue: 0.95).opacity(0.12) : Color(NSColor.windowBackgroundColor))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if state.selectedAppID == app.id {
                state.selectedAppID = nil
            } else {
                state.selectedAppID = app.id
                inspectedSockets = FirewallController.shared.inspectSockets(for: app.pids)
            }
        }
    }
    
    @ViewBuilder
    private func selectedAppDetailDrawer(app: AppTrafficEntry) -> some View {
        let isAllowed = PreferencesManager.shared.isAppAllowed(identifier: app.id, defaultAllowed: !app.isSystemDaemon)
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(nsImage: app.icon)
                        .resizable()
                        .frame(width: 36, height: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(app.name)
                            .font(.system(size: 14, weight: .bold))
                            .lineLimit(1)
                        Text(app.isSystemDaemon ? "macOS System Process" : "Application")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button {
                        state.selectedAppID = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                
                if let bp = app.bundlePath {
                    Button {
                        NSWorkspace.shared.selectFile(bp, inFileViewerRootedAtPath: "")
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "folder")
                                .font(.system(size: 10))
                            Text(bp)
                                .font(.system(size: 10, design: .monospaced))
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .foregroundColor(Color(red: 0.00, green: 0.55, blue: 0.95))
                    }
                    .buttonStyle(.plain)
                    .help("Reveal in Finder")
                }
                
                Divider()
                
                // Access Rule Toggle
                HStack {
                    Text("Internet Access")
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Toggle(isAllowed ? "Allowed" : "Blocked", isOn: Binding(
                        get: { isAllowed },
                        set: { val in
                            PreferencesManager.shared.setAppAllowed(identifier: app.id, allowed: val)
                            if val { FirewallController.shared.resumePIDs(app.pids) }
                            else if state.isShieldActive {
                                _ = FirewallController.shared.enforceBlockOnPIDs(app.pids, appName: app.name, isSystemDaemon: app.isSystemDaemon)
                            }
                            state.refresh()
                        }
                    ))
                    .toggleStyle(.switch)
                    .font(.system(size: 11, weight: .medium))
                }
                
                // App Usage Stats for Selected Time Range
                VStack(spacing: 8) {
                    HStack {
                        Text("Period")
                            .font(.system(size: 11)).foregroundColor(.secondary)
                        Spacer()
                        Text(selectedTimeRange.rawValue)
                            .font(.system(size: 11, weight: .semibold))
                    }
                    HStack {
                        Text("Downloaded")
                            .font(.system(size: 11)).foregroundColor(.secondary)
                        Spacer()
                        Text(NetworkMonitorEngine.formatBytes(app.sessionBytesIn))
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    }
                    HStack {
                        Text("Uploaded")
                            .font(.system(size: 11)).foregroundColor(.secondary)
                        Spacer()
                        Text(NetworkMonitorEngine.formatBytes(app.sessionBytesOut))
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    }
                    HStack {
                        Text("Total Usage")
                            .font(.system(size: 11)).foregroundColor(.secondary)
                        Spacer()
                        Text(NetworkMonitorEngine.formatBytes(app.totalSessionBytes))
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(red: 0.00, green: 0.55, blue: 0.95))
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.primary.opacity(0.04))
                )
                
                Button {
                    NetworkMonitorEngine.shared.resetAppCounter(appId: app.id)
                } label: {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Reset App Session Counter")
                    }
                    .font(.system(size: 11, weight: .medium))
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                // Per-App Historical Mini Chart
                VStack(alignment: .leading, spacing: 6) {
                    Text("App History (\(selectedTimeRange.shortLabel))")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                    let appPoints = UsageHistoryStore.shared.chartPoints(for: selectedTimeRange, appId: app.id)
                    usageBarChartView(points: appPoints, height: 95)
                }
                
                Divider()
                
                // Live Active Sockets
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Active Connections")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                        Spacer()
                        Button {
                            inspectedSockets = FirewallController.shared.inspectSockets(for: app.pids)
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "arrow.clockwise")
                                Text("Refresh")
                            }
                            .font(.system(size: 10))
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(Color(red: 0.00, green: 0.55, blue: 0.95))
                    }
                    
                    if inspectedSockets.isEmpty {
                        Text("No open external sockets right now.")
                            .font(.system(size: 10.5))
                            .foregroundColor(.secondary)
                            .padding(.vertical, 6)
                    } else {
                        ForEach(inspectedSockets) { sock in
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(sock.proto)
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(Color(red: 0.00, green: 0.55, blue: 0.95).opacity(0.15))
                                        .cornerRadius(3)
                                    Spacer()
                                    Text(sock.state)
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }
                                Text(sock.remoteAddress)
                                    .font(.system(size: 10, design: .monospaced))
                                    .lineLimit(1)
                            }
                            .padding(6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.primary.opacity(0.04))
                            )
                        }
                    }
                }
            }
            .padding(16)
        }
    }
    
    // MARK: - Tab 3: Limits & Profiles
    
    private var limitsAndProfilesTabView: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 18) {
                // Data Cap Card
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Session Data Limit & Overage Cutoff")
                                .font(.system(size: 14, weight: .bold))
                            Text("Automatically block network traffic when your session usage hits your mobile hotspot cap.")
                                .font(.system(size: 11.5))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("Auto-Cutoff at Limit", isOn: $autoCutoffAtLimit)
                            .toggleStyle(.switch)
                            .font(.system(size: 12, weight: .medium))
                    }
                    
                    let presets: [(Int, String)] = [
                        (0, "Unlimited (∞)"),
                        (100, "100 MB"),
                        (250, "250 MB"),
                        (500, "500 MB"),
                        (1000, "1 GB"),
                        (2000, "2 GB"),
                        (5000, "5 GB"),
                        (10000, "10 GB")
                    ]
                    
                    HStack(spacing: 8) {
                        ForEach(presets, id: \.0) { item in
                            let isSel = (selectedDataCapMB == item.0)
                            Button {
                                selectedDataCapMB = item.0
                                if item.0 == 0 && state.isLockdownActive {
                                    FirewallController.shared.setLockdown(false)
                                }
                            } label: {
                                Text(item.1)
                                    .font(.system(size: 11.5, weight: isSel ? .bold : .medium))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(
                                        RoundedRectangle(cornerRadius: 7)
                                            .fill(isSel ? Color(red: 0.00, green: 0.55, blue: 0.95) : Color.primary.opacity(0.06))
                                    )
                                    .foregroundColor(isSel ? .white : .primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    // Custom MB Input Row
                    HStack(spacing: 10) {
                        Text("Custom Limit (MB):")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        TextField("e.g. 750", text: $customDataCapText)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 110)
                            .font(.system(size: 11.5, design: .monospaced))
                        
                        Button("Set Custom Limit") {
                            let cleaned = customDataCapText.trimmingCharacters(in: .whitespacesAndNewlines)
                            if let mb = Int(cleaned), mb >= 0 {
                                selectedDataCapMB = mb
                                customDataCapText = ""
                                if mb == 0 && state.isLockdownActive {
                                    FirewallController.shared.setLockdown(false)
                                }
                            }
                        }
                        .font(.system(size: 11.5, weight: .semibold))
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        if state.isLockdownActive {
                            Spacer()
                            Button("Unlock Lockdown Now") {
                                FirewallController.shared.setLockdown(false)
                            }
                            .font(.system(size: 11.5, weight: .bold))
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                            .controlSize(.small)
                        }
                    }
                    
                    if selectedDataCapMB > 0 {
                        let capBytes = Double(selectedDataCapMB) * 1_000_000.0
                        let ratio = min(1.0, Double(state.totalSessionBytes) / max(1.0, capBytes))
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Current Session: \(NetworkMonitorEngine.formatBytes(state.totalSessionBytes)) of \(selectedDataCapMB) MB (\(Int(ratio * 100))%)")
                                    .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                                Spacer()
                                Button("Reset Session Counter") {
                                    NetworkMonitorEngine.shared.resetSessionCounters()
                                }
                                .font(.system(size: 11))
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.primary.opacity(0.08))
                                        .frame(height: 8)
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(ratio >= 0.9 ? Color.red : Color(red: 0.00, green: 0.65, blue: 0.95))
                                        .frame(width: max(6, geo.size.width * CGFloat(ratio)), height: 8)
                                }
                            }
                            .frame(height: 8)
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(NSColor.windowBackgroundColor))
                )
                
                // Firewall Profiles Card
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Firewall Rule Profiles")
                                .font(.system(size: 14, weight: .bold))
                            Text("Each profile remembers its own set of Allowed and Blocked applications.")
                                .font(.system(size: 11.5))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button("Reset \"\(selectedProfile)\" Rules to Default") {
                            PreferencesManager.shared.resetCurrentProfileRules()
                            FirewallController.shared.resumeAllowedProcesses()
                            NetworkMonitorEngine.shared.triggerImmediateEnforcement()
                            state.refresh()
                        }
                        .font(.system(size: 11))
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    
                    HStack(spacing: 12) {
                        profileCard(name: "Default", desc: "Standard balanced protection blocking heavy cloud syncers.", icon: "shield.fill")
                        profileCard(name: "Hotspot", desc: "Strict tethering mode allowing only browsers & chat apps.", icon: "personalhotspot")
                        profileCard(name: "Work", desc: "Optimized for Slack, Zoom, IDEs, and productivity tools.", icon: "briefcase.fill")
                        profileCard(name: "Travel", desc: "Ultra-low bandwidth profile for roaming & flights.", icon: "airplane")
                    }
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(NSColor.windowBackgroundColor))
                )
            }
            .padding(20)
        }
    }
    
    // MARK: - Tab 4: Settings & System Permissions
    
    private var settingsTabView: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 16) {
                // 1. System Permissions & Access Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("System Permissions & Access")
                            .font(.system(size: 13.5, weight: .bold))
                        Spacer()
                        Button("Refresh Status") {
                            permissions.refreshPermissionsStatus()
                        }
                        .font(.system(size: 11))
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    
                    permissionStatusRow(
                        icon: "network.badge.shield.half.filled",
                        title: "Per-App Network Monitor & Process Blocker",
                        subtitle: "Required to inspect sockets (nettop/lsof) and pause unauthorized background apps.",
                        granted: permissions.firewallPermissionGranted,
                        buttonTitle: "Grant Firewall Permission..."
                    ) {
                        PermissionsManager.shared.promptFirewallPermissionModal()
                    }
                    
                    Divider()
                    
                    permissionStatusRow(
                        icon: "lock.shield.fill",
                        title: "Deep Kernel Packet Filter (pfctl Administrator Access)",
                        subtitle: "Optional macOS administrator privilege for kernel-level packet inspection.",
                        granted: permissions.kernelFirewallAuthorized,
                        buttonTitle: "Authorize with Admin..."
                    ) {
                        PermissionsManager.shared.authorizeKernelFirewallWithAdminPrompt()
                    }
                    
                    Divider()
                    
                    permissionStatusRow(
                        icon: "bell.badge.fill",
                        title: "macOS Data Cap Alert Notifications",
                        subtitle: "Required to alert you when your hotspot session data limit is reached.",
                        granted: permissions.notificationsAuthorized,
                        buttonTitle: "Request Notification Access"
                    ) {
                        PermissionsManager.shared.requestNotificationPermission()
                    }
                    
                    Divider()
                    
                    permissionStatusRow(
                        icon: "keyboard.badge.eye",
                        title: "Global Shortcut (⌥T) Accessibility Access",
                        subtitle: "Allows toggling TripGuard Shield from any application using Option + T.",
                        granted: permissions.accessibilityTrusted,
                        buttonTitle: "Grant Shortcut Permission"
                    ) {
                        PermissionsManager.shared.requestAccessibilityPermission()
                    }
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(NSColor.windowBackgroundColor)))
                
                // 2. General & Menu Bar Card
                VStack(alignment: .leading, spacing: 12) {
                    Text("General & Menu Bar")
                        .font(.system(size: 13.5, weight: .bold))
                    
                    SettingItemRow(icon: "power", title: "Launch TripGuard at Login", isOn: $launchAtLogin) { val in
                        PreferencesManager.shared.launchAtLogin = val
                    }
                    Divider()
                    SettingItemRow(icon: "shield.fill", title: "Activate Shield Automatically at Launch", isOn: $activateAtLaunch)
                    Divider()
                    SettingItemRow(icon: "cursorarrow.rays", title: "Toggle Shield with Left Click on Menu Bar Icon", isOn: $activateWithLeftClick)
                    Divider()
                    SettingItemRow(icon: "speedometer", title: "Show Live Speed / Usage Counter in Menu Bar", isOn: $showMenuBarSpeed) { _ in
                        NotificationCenter.default.post(name: .preferencesDidChange, object: nil)
                    }
                    Divider()
                    SettingItemRow(icon: "paintpalette", title: "Use Colored Emerald/Cyan Menu Bar Icon", isOn: $coloredMenuBarIcon) { _ in
                        NotificationCenter.default.post(name: .preferencesDidChange, object: nil)
                    }
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(NSColor.windowBackgroundColor)))
                
                // 3. Firewall & Network Automation Card
                VStack(alignment: .leading, spacing: 12) {
                    Text("Firewall & Network Automation")
                        .font(.system(size: 13.5, weight: .bold))
                    
                    SettingItemRow(icon: "personalhotspot", title: "Auto-Activate Shield on Network or Hotspot Change", isOn: $autoActivateOnNetworkChange)
                    Divider()
                    SettingItemRow(icon: "hand.raised.fill", title: "Strict Background Process Blocker (Pause Blocked Apps on Traffic)", isOn: $strictProcessBlocker) { val in
                        if !val { FirewallController.shared.resumeAllPausedProcesses() }
                        else { NetworkMonitorEngine.shared.triggerImmediateEnforcement() }
                    }
                    Divider()
                    SettingItemRow(icon: "cpu", title: "Include macOS System Daemons in Application List", isOn: $showSystemDaemons) { _ in
                        NetworkMonitorEngine.shared.triggerImmediateEnforcement()
                    }
                    Divider()
                    SettingItemRow(icon: "bell.fill", title: "Allow macOS Data Cap Alert Notifications", isOn: $allowNotifications) { val in
                        if val { PermissionsManager.shared.requestNotificationPermission() }
                    }
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(NSColor.windowBackgroundColor)))
                
                // 4. Historical Usage Data Card
                VStack(alignment: .leading, spacing: 12) {
                    Text("Historical Usage Data")
                        .font(.system(size: 13.5, weight: .bold))
                    
                    HStack(spacing: 12) {
                        Button("Reset Current Session Counter") {
                            NetworkMonitorEngine.shared.resetSessionCounters()
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Export CSV Report...") {
                            exportCurrentRangeCSV()
                        }
                        .buttonStyle(.bordered)
                        
                        Spacer()
                        
                        Button("Clear All Historical Data...") {
                            showClearHistoryConfirm = true
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(NSColor.windowBackgroundColor)))
            }
            .padding(20)
        }
    }
    
    @ViewBuilder
    private func permissionStatusRow(
        icon: String,
        title: String,
        subtitle: String,
        granted: Bool,
        buttonTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill((granted ? Color(red: 0.00, green: 0.75, blue: 0.52) : Color(red: 0.00, green: 0.50, blue: 0.95)).opacity(0.14))
                    .frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(granted ? Color(red: 0.00, green: 0.75, blue: 0.52) : Color(red: 0.00, green: 0.55, blue: 0.95))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 10.5))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if granted {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11))
                    Text("Authorized")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(Color(red: 0.00, green: 0.72, blue: 0.50))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(red: 0.00, green: 0.75, blue: 0.52).opacity(0.12))
                .cornerRadius(6)
            } else {
                Button(buttonTitle) {
                    action()
                }
                .font(.system(size: 11, weight: .semibold))
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
    }
    
    // MARK: - Reusable Chart & Cards
    
    private var timelineGranularityLabel: String {
        switch selectedTimeRange {
        case .session, .today: return "the last 24 hours"
        case .sevenDays: return "the last 7 days"
        case .thirtyDays: return "the last 30 days"
        case .twelveMonths: return "the last 12 months"
        }
    }
    
    @ViewBuilder
    private func metricCard(title: String, value: String, subtitle: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundColor(tint)
            }
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundColor(.primary)
                .lineLimit(1)
            Text(subtitle)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.windowBackgroundColor))
                .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        )
    }
    
    @ViewBuilder
    private func profileCard(name: String, desc: String, icon: String) -> some View {
        let isSel = (selectedProfile == name)
        Button {
            selectedProfile = name
            FirewallController.shared.resumeAllowedProcesses()
            NetworkMonitorEngine.shared.triggerImmediateEnforcement()
            state.refresh()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(isSel ? .white : Color(red: 0.00, green: 0.55, blue: 0.95))
                    Spacer()
                    if isSel {
                        Text("ACTIVE")
                            .font(.system(size: 8.5, weight: .bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.24))
                            .cornerRadius(4)
                    }
                }
                Text(name)
                    .font(.system(size: 13, weight: .bold))
                Text(desc)
                    .font(.system(size: 10.5))
                    .opacity(0.85)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 105, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSel ? Color(red: 0.00, green: 0.52, blue: 0.95) : Color.primary.opacity(0.05))
            )
            .foregroundColor(isSel ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private func usageBarChartView(points: [ChartBarPoint], height: CGFloat) -> some View {
        let maxVal = max(1024, points.map(\.totalBytes).max() ?? 1024)
        VStack(spacing: 6) {
            HStack(alignment: .bottom, spacing: points.count > 16 ? 4 : 10) {
                ForEach(points) { pt in
                    let inRatio = CGFloat(Double(pt.bytesIn) / Double(maxVal))
                    let outRatio = CGFloat(Double(pt.bytesOut) / Double(maxVal))
                    let isHovered = (hoveredBarPoint?.id == pt.id)
                    
                    VStack(spacing: 4) {
                        GeometryReader { geo in
                            let availH = geo.size.height
                            VStack(spacing: 1) {
                                Spacer(minLength: 0)
                                if pt.bytesOut > 0 {
                                    RoundedRectangle(cornerRadius: 2.5)
                                        .fill(Color(red: 0.00, green: 0.80, blue: 0.56))
                                        .frame(height: max(3, availH * outRatio))
                                }
                                RoundedRectangle(cornerRadius: 2.5)
                                    .fill(pt.totalBytes > 0 ? Color(red: 0.00, green: 0.58, blue: 0.96) : Color.primary.opacity(0.07))
                                    .frame(height: pt.totalBytes > 0 ? max(4, availH * inRatio) : 4)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        }
                        
                        Text(pt.label)
                            .font(.system(size: 9, weight: isHovered ? .bold : .medium, design: .monospaced))
                            .foregroundColor(isHovered ? Color(red: 0.00, green: 0.55, blue: 0.95) : .secondary)
                            .lineLimit(1)
                            .frame(height: 12)
                    }
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isHovered ? Color.primary.opacity(0.06) : Color.clear)
                    )
                    .help("\(pt.fullDateLabel): \(NetworkMonitorEngine.formatBytes(pt.totalBytes)) (↓ \(NetworkMonitorEngine.formatBytes(pt.bytesIn)) / ↑ \(NetworkMonitorEngine.formatBytes(pt.bytesOut)))")
                    .onHover { hovering in
                        if hovering {
                            hoveredBarPoint = pt
                        } else if hoveredBarPoint?.id == pt.id {
                            hoveredBarPoint = nil
                        }
                    }
                    .onTapGesture {
                        hoveredBarPoint = pt
                    }
                }
            }
            .frame(height: height)
        }
    }
    
    private func exportCurrentRangeCSV() {
        let csv = UsageHistoryStore.shared.exportCSV(for: selectedTimeRange)
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "TripGuard-Usage-\(selectedTimeRange.shortLabel.replacingOccurrences(of: " ", with: "")).csv"
        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK, let url = panel.url {
            try? csv.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
