import Foundation
import AppKit
import Darwin
import Network

public struct AppTrafficEntry: Identifiable {
    public let id: String               // Bundle path or process name
    public let name: String             // Clean display name (e.g., "Google Chrome")
    public let bundlePath: String?      // Path to outermost .app bundle if available
    public let icon: NSImage            // Native macOS application icon
    public let isSystemDaemon: Bool
    public var pids: Set<Int32>
    public var sessionBytesIn: UInt64
    public var sessionBytesOut: UInt64
    public var downloadSpeedBps: Double
    public var uploadSpeedBps: Double
    public var blockedAttempts: Int
    public var isPausedByFirewall: Bool
    
    public var totalSessionBytes: UInt64 {
        sessionBytesIn + sessionBytesOut
    }
    
    public var totalSpeedBps: Double {
        downloadSpeedBps + uploadSpeedBps
    }
}

public final class NetworkMonitorEngine {
    public static let shared = NetworkMonitorEngine()
    
    public private(set) var apps: [AppTrafficEntry] = []
    public private(set) var totalSessionBytes: UInt64 = 0
    public private(set) var totalSessionBytesIn: UInt64 = 0
    public private(set) var totalSessionBytesOut: UInt64 = 0
    public private(set) var totalDownloadSpeedBps: Double = 0
    public private(set) var totalUploadSpeedBps: Double = 0
    public private(set) var totalBlockedAttempts: Int = 0
    public private(set) var activeInterfaceName: String = "Wi-Fi (en0)"
    public private(set) var isHotspotLikely: Bool = false
    
    private struct PIDBaseline {
        var lastBytesIn: UInt64
        var lastBytesOut: UInt64
    }
    
    private struct AppAccumulator {
        let id: String
        let name: String
        let bundlePath: String?
        let isSystemDaemon: Bool
        var pids: Set<Int32>
        var sessionBytesIn: UInt64
        var sessionBytesOut: UInt64
        var currentDeltaIn: UInt64
        var currentDeltaOut: UInt64
        var blockedAttempts: Int
    }
    
    private var pidBaselines: [Int32: PIDBaseline] = [:]
    private var appAccumulators: [String: AppAccumulator] = [:]
    private var pidResolutionCache: [Int32: (id: String, name: String, bundlePath: String?, isDaemon: Bool)] = [:]
    private var iconCache: [String: NSImage] = [:]
    
    private let monitorQueue = DispatchQueue(label: "com.localover.tripguard.nettop", qos: .utility)
    private var pollTimer: DispatchSourceTimer?
    private var lastPollTime: Date = Date()
    private var isFirstSample: Bool = true
    private var pathMonitor: NWPathMonitor?
    private var lastInterfaceSignature: String = ""
    
    private init() {
        setupNetworkPathMonitor()
        startMonitoring()
    }
    
    public func startMonitoring() {
        guard pollTimer == nil else { return }
        let timer = DispatchSource.makeTimerSource(queue: monitorQueue)
        timer.schedule(deadline: .now(), repeating: .milliseconds(1600))
        timer.setEventHandler { [weak self] in
            self?.sampleNetworkTraffic()
        }
        pollTimer = timer
        timer.resume()
    }
    
    public func resetSessionCounters() {
        monitorQueue.async { [weak self] in
            guard let self = self else { return }
            for key in self.appAccumulators.keys {
                self.appAccumulators[key]?.sessionBytesIn = 0
                self.appAccumulators[key]?.sessionBytesOut = 0
                self.appAccumulators[key]?.blockedAttempts = 0
            }
            if FirewallController.shared.isLockdownActive {
                FirewallController.shared.setLockdown(false)
            }
            self.publishState(elapsed: 1.6)
        }
    }
    
    public func resetAppCounter(appId: String) {
        monitorQueue.async { [weak self] in
            guard let self = self else { return }
            self.appAccumulators[appId]?.sessionBytesIn = 0
            self.appAccumulators[appId]?.sessionBytesOut = 0
            self.appAccumulators[appId]?.blockedAttempts = 0
            self.publishState(elapsed: 1.6)
        }
    }
    
    public func triggerImmediateEnforcement() {
        monitorQueue.async { [weak self] in
            self?.sampleNetworkTraffic()
        }
    }
    
    /// Returns entries for any TimeRangeFilter (Session, Today, 7 Days, 30 Days, 12 Months)
    public func entries(for range: TimeRangeFilter) -> [AppTrafficEntry] {
        if range == .session {
            return apps
        }
        
        let showDaemons = PreferencesManager.shared.showSystemDaemons
        let historicalMap = UsageHistoryStore.shared.aggregatedAppRecords(for: range)
        let liveByID = Dictionary(uniqueKeysWithValues: apps.map { ($0.id, $0) })
        
        let allIDs = Set(historicalMap.keys).union(liveByID.keys)
        var result: [AppTrafficEntry] = []
        
        for id in allIDs {
            let hist = historicalMap[id]
            let live = liveByID[id]
            
            let name = live?.name ?? hist?.name ?? id
            let bundlePath = live?.bundlePath ?? hist?.bundlePath
            let isDaemon = live?.isSystemDaemon ?? hist?.isSystemDaemon ?? false
            
            if isDaemon && !showDaemons { continue }
            
            let bIn = hist?.bytesIn ?? live?.sessionBytesIn ?? 0
            let bOut = hist?.bytesOut ?? live?.sessionBytesOut ?? 0
            let blocked = hist?.blockedAttemptsCount ?? live?.blockedAttempts ?? 0
            
            if bundlePath == nil && bIn == 0 && bOut == 0 && blocked == 0 {
                continue
            }
            
            let icon = live?.icon ?? resolveIcon(for: id, bundlePath: bundlePath)
            let pids = live?.pids ?? []
            let downSpeed = live?.downloadSpeedBps ?? 0
            let upSpeed = live?.uploadSpeedBps ?? 0
            let isPaused = live?.isPausedByFirewall ?? false
            
            result.append(AppTrafficEntry(
                id: id,
                name: name,
                bundlePath: bundlePath,
                icon: icon,
                isSystemDaemon: isDaemon,
                pids: pids,
                sessionBytesIn: bIn,
                sessionBytesOut: bOut,
                downloadSpeedBps: downSpeed,
                uploadSpeedBps: upSpeed,
                blockedAttempts: blocked,
                isPausedByFirewall: isPaused
            ))
        }
        
        result.sort { a, b in
            if a.totalSessionBytes != b.totalSessionBytes {
                return a.totalSessionBytes > b.totalSessionBytes
            }
            if abs(a.totalSpeedBps - b.totalSpeedBps) > 256 {
                return a.totalSpeedBps > b.totalSpeedBps
            }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
        return result
    }
    
    private func setupNetworkPathMonitor() {
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            var ifaceDesc = "Offline"
            var hotspot = false
            
            if path.status == .satisfied {
                if path.usesInterfaceType(.wifi) {
                    let name = path.availableInterfaces.first(where: { $0.type == .wifi })?.name ?? "en0"
                    if path.isExpensive {
                        ifaceDesc = "Personal Hotspot (\(name))"
                        hotspot = true
                    } else {
                        ifaceDesc = "Wi-Fi (\(name))"
                    }
                } else if path.usesInterfaceType(.cellular) {
                    ifaceDesc = "Cellular Tether"
                    hotspot = true
                } else if path.usesInterfaceType(.wiredEthernet) {
                    let name = path.availableInterfaces.first(where: { $0.type == .wiredEthernet })?.name ?? "en1"
                    ifaceDesc = "Ethernet (\(name))"
                } else {
                    ifaceDesc = "Connected Network"
                }
            }
            
            let sig = "\(path.status)-\(ifaceDesc)-\(path.isExpensive)"
            let changed = !self.lastInterfaceSignature.isEmpty && self.lastInterfaceSignature != sig
            self.lastInterfaceSignature = sig
            
            DispatchQueue.main.async {
                self.activeInterfaceName = ifaceDesc
                self.isHotspotLikely = hotspot
                if changed && path.status == .satisfied && PreferencesManager.shared.autoActivateOnNetworkChange {
                    if !FirewallController.shared.isShieldActive {
                        FirewallController.shared.activateShield()
                    }
                }
                NotificationCenter.default.post(name: .networkStatsDidUpdate, object: nil)
            }
        }
        pathMonitor = monitor
        monitor.start(queue: DispatchQueue(label: "com.localover.tripguard.path"))
    }
    
    private func sampleNetworkTraffic() {
        let now = Date()
        let elapsed = max(0.5, now.timeIntervalSince(lastPollTime))
        lastPollTime = now
        
        for key in appAccumulators.keys {
            appAccumulators[key]?.currentDeltaIn = 0
            appAccumulators[key]?.currentDeltaOut = 0
            appAccumulators[key]?.pids.removeAll()
        }
        
        let runningApps = NSWorkspace.shared.runningApplications
        let myBundleID = Bundle.main.bundleIdentifier ?? "com.localover.tripguard"
        
        for rApp in runningApps where rApp.activationPolicy == .regular {
            if rApp.bundleIdentifier == myBundleID || rApp.localizedName == "TripGuard" { continue }
            guard let bundleURL = rApp.bundleURL else { continue }
            let bundlePath = bundleURL.path
            let appName = rApp.localizedName ?? bundleURL.deletingPathExtension().lastPathComponent
            let pid = rApp.processIdentifier
            
            pidResolutionCache[pid] = (id: bundlePath, name: appName, bundlePath: bundlePath, isDaemon: false)
            
            if appAccumulators[bundlePath] == nil {
                appAccumulators[bundlePath] = AppAccumulator(
                    id: bundlePath,
                    name: appName,
                    bundlePath: bundlePath,
                    isSystemDaemon: false,
                    pids: [pid],
                    sessionBytesIn: 0,
                    sessionBytesOut: 0,
                    currentDeltaIn: 0,
                    currentDeltaOut: 0,
                    blockedAttempts: 0
                )
            } else {
                appAccumulators[bundlePath]?.pids.insert(pid)
            }
        }
        
        let rawSamples = runNettopSnapshot()
        let existingToday = UsageHistoryStore.shared.aggregatedAppRecords(for: .today, now: now)
        
        for sample in rawSamples {
            let resolved = resolveProcess(pid: sample.pid, fallbackName: sample.rawName)
            if resolved.name == "TripGuard" || resolved.name == "nettop" { continue }
            
            var deltaIn: UInt64 = 0
            var deltaOut: UInt64 = 0
            var speedDeltaIn: UInt64 = 0
            var speedDeltaOut: UInt64 = 0
            
            if let prev = pidBaselines[sample.pid] {
                if sample.bytesIn >= prev.lastBytesIn {
                    deltaIn = sample.bytesIn - prev.lastBytesIn
                    speedDeltaIn = deltaIn
                }
                if sample.bytesOut >= prev.lastBytesOut {
                    deltaOut = sample.bytesOut - prev.lastBytesOut
                    speedDeltaOut = deltaOut
                }
            } else if isFirstSample {
                // Seed initial session counters from active OS process counters so the app immediately shows real active session usage
                deltaIn = sample.bytesIn
                deltaOut = sample.bytesOut
                speedDeltaIn = 0
                speedDeltaOut = 0
            } else {
                deltaIn = min(sample.bytesIn, 512_000)
                deltaOut = min(sample.bytesOut, 512_000)
                speedDeltaIn = deltaIn
                speedDeltaOut = deltaOut
            }
            
            pidBaselines[sample.pid] = PIDBaseline(lastBytesIn: sample.bytesIn, lastBytesOut: sample.bytesOut)
            
            let permitted = FirewallController.shared.isAppPermitted(identifier: resolved.id, isSystemDaemon: resolved.isDaemon)
            var newlyBlocked = 0
            
            if var acc = appAccumulators[resolved.id] {
                acc.pids.insert(sample.pid)
                if permitted || isFirstSample {
                    acc.sessionBytesIn += deltaIn
                    acc.sessionBytesOut += deltaOut
                    acc.currentDeltaIn += speedDeltaIn
                    acc.currentDeltaOut += speedDeltaOut
                } else if deltaIn > 0 || deltaOut > 0 {
                    newlyBlocked = FirewallController.shared.enforceBlockOnPIDs(acc.pids, appName: acc.name, isSystemDaemon: acc.isSystemDaemon)
                    acc.blockedAttempts += newlyBlocked
                }
                appAccumulators[resolved.id] = acc
            } else {
                if !permitted && !isFirstSample && (deltaIn > 0 || deltaOut > 0) {
                    newlyBlocked = FirewallController.shared.enforceBlockOnPIDs([sample.pid], appName: resolved.name, isSystemDaemon: resolved.isDaemon)
                }
                appAccumulators[resolved.id] = AppAccumulator(
                    id: resolved.id,
                    name: resolved.name,
                    bundlePath: resolved.bundlePath,
                    isSystemDaemon: resolved.isDaemon,
                    pids: [sample.pid],
                    sessionBytesIn: (permitted || isFirstSample) ? deltaIn : 0,
                    sessionBytesOut: (permitted || isFirstSample) ? deltaOut : 0,
                    currentDeltaIn: permitted ? speedDeltaIn : 0,
                    currentDeltaOut: permitted ? speedDeltaOut : 0,
                    blockedAttempts: newlyBlocked
                )
            }
            
            // Persist into UsageHistoryStore
            if !isFirstSample {
                if permitted && (deltaIn > 0 || deltaOut > 0) {
                    UsageHistoryStore.shared.recordTraffic(
                        appId: resolved.id,
                        name: resolved.name,
                        bundlePath: resolved.bundlePath,
                        isSystemDaemon: resolved.isDaemon,
                        deltaIn: deltaIn,
                        deltaOut: deltaOut,
                        blockedDelta: 0,
                        at: now
                    )
                } else if newlyBlocked > 0 {
                    UsageHistoryStore.shared.recordTraffic(
                        appId: resolved.id,
                        name: resolved.name,
                        bundlePath: resolved.bundlePath,
                        isSystemDaemon: resolved.isDaemon,
                        deltaIn: 0,
                        deltaOut: 0,
                        blockedDelta: newlyBlocked,
                        at: now
                    )
                }
            } else if existingToday[resolved.id] == nil && (deltaIn > 0 || deltaOut > 0) {
                // Seed today's historical bucket if this app wasn't recorded yet today
                UsageHistoryStore.shared.recordTraffic(
                    appId: resolved.id,
                    name: resolved.name,
                    bundlePath: resolved.bundlePath,
                    isSystemDaemon: resolved.isDaemon,
                    deltaIn: deltaIn,
                    deltaOut: deltaOut,
                    blockedDelta: 0,
                    at: now
                )
            }
        }
        
        if FirewallController.shared.isShieldActive {
            for (key, acc) in appAccumulators {
                let permitted = FirewallController.shared.isAppPermitted(identifier: key, isSystemDaemon: acc.isSystemDaemon)
                if permitted {
                    FirewallController.shared.resumePIDs(acc.pids)
                } else if PreferencesManager.shared.strictProcessBlocker && !acc.isSystemDaemon {
                    _ = FirewallController.shared.enforceBlockOnPIDs(acc.pids, appName: acc.name, isSystemDaemon: acc.isSystemDaemon)
                }
            }
        }
        
        if isFirstSample {
            UsageHistoryStore.shared.saveToDiskIfNeeded()
        }
        isFirstSample = false
        publishState(elapsed: elapsed)
    }
    
    private func publishState(elapsed: Double) {
        let showDaemons = PreferencesManager.shared.showSystemDaemons
        var builtEntries: [AppTrafficEntry] = []
        var sumBytesIn: UInt64 = 0
        var sumBytesOut: UInt64 = 0
        var sumDownBps: Double = 0
        var sumUpBps: Double = 0
        var sumBlocked: Int = 0
        
        for acc in appAccumulators.values {
            let downBps = Double(acc.currentDeltaIn) / elapsed
            let upBps = Double(acc.currentDeltaOut) / elapsed
            sumBytesIn += acc.sessionBytesIn
            sumBytesOut += acc.sessionBytesOut
            sumDownBps += downBps
            sumUpBps += upBps
            sumBlocked += acc.blockedAttempts
            
            if acc.isSystemDaemon && !showDaemons {
                continue
            }
            if acc.bundlePath == nil && acc.sessionBytesIn == 0 && acc.sessionBytesOut == 0 && acc.blockedAttempts == 0 {
                continue
            }
            
            let icon = resolveIcon(for: acc.id, bundlePath: acc.bundlePath)
            let isPaused = FirewallController.shared.hasAnyPausedPID(acc.pids)
            
            builtEntries.append(AppTrafficEntry(
                id: acc.id,
                name: acc.name,
                bundlePath: acc.bundlePath,
                icon: icon,
                isSystemDaemon: acc.isSystemDaemon,
                pids: acc.pids,
                sessionBytesIn: acc.sessionBytesIn,
                sessionBytesOut: acc.sessionBytesOut,
                downloadSpeedBps: downBps,
                uploadSpeedBps: upBps,
                blockedAttempts: acc.blockedAttempts,
                isPausedByFirewall: isPaused
            ))
        }
        
        builtEntries.sort { a, b in
            if abs(a.totalSpeedBps - b.totalSpeedBps) > 512 {
                return a.totalSpeedBps > b.totalSpeedBps
            }
            if a.totalSessionBytes != b.totalSessionBytes {
                return a.totalSessionBytes > b.totalSessionBytes
            }
            if a.blockedAttempts != b.blockedAttempts {
                return a.blockedAttempts > b.blockedAttempts
            }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
        
        let sumTotal = sumBytesIn + sumBytesOut
        let capMB = PreferencesManager.shared.selectedDataCapMB
        if capMB > 0 && PreferencesManager.shared.autoCutoffAtLimit && FirewallController.shared.isShieldActive {
            let capBytes = UInt64(capMB) * 1_000_000
            if sumTotal >= capBytes && !FirewallController.shared.isLockdownActive {
                let usedMB = Double(sumTotal) / 1_000_000.0
                DispatchQueue.main.async {
                    FirewallController.shared.setLockdown(true)
                    FirewallController.shared.sendCutoffNotification(usedMB: usedMB, capMB: capMB)
                }
            }
        }
        
        DispatchQueue.main.async {
            self.apps = builtEntries
            self.totalSessionBytesIn = sumBytesIn
            self.totalSessionBytesOut = sumBytesOut
            self.totalSessionBytes = sumTotal
            self.totalDownloadSpeedBps = sumDownBps
            self.totalUploadSpeedBps = sumUpBps
            self.totalBlockedAttempts = sumBlocked
            NotificationCenter.default.post(name: .networkStatsDidUpdate, object: nil)
        }
    }
    
    private func runNettopSnapshot() -> [(rawName: String, pid: Int32, bytesIn: UInt64, bytesOut: UInt64)] {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/nettop")
        task.arguments = ["-P", "-L", "1", "-J", "bytes_in,bytes_out", "-x"]
        
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
        
        var results: [(String, Int32, UInt64, UInt64)] = []
        let lines = output.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed.contains("bytes_in") { continue }
            
            let cols = trimmed.components(separatedBy: ",")
            guard cols.count >= 3 else { continue }
            
            let procField = cols[0]
            guard let dotIdx = procField.lastIndex(of: ".") else { continue }
            let rawName = String(procField[..<dotIdx])
            let pidStr = String(procField[procField.index(after: dotIdx)...])
            
            guard let pid = Int32(pidStr) else { continue }
            let bIn = UInt64(cols[1]) ?? 0
            let bOut = UInt64(cols[2]) ?? 0
            
            results.append((rawName, pid, bIn, bOut))
        }
        
        return results
    }
    
    private func resolveProcess(pid: Int32, fallbackName: String) -> (id: String, name: String, bundlePath: String?, isDaemon: Bool) {
        if let cached = pidResolutionCache[pid] {
            return cached
        }
        
        var pathBuffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        let len = proc_pidpath(pid, &pathBuffer, UInt32(MAXPATHLEN))
        if len > 0 {
            let fullPath = String(cString: pathBuffer)
            let components = fullPath.components(separatedBy: "/")
            if let firstAppIdx = components.firstIndex(where: { $0.hasSuffix(".app") }) {
                let bundleComponents = Array(components[0...firstAppIdx])
                let bundlePath = bundleComponents.joined(separator: "/")
                let bundleFilename = components[firstAppIdx]
                let cleanAppName = String(bundleFilename.dropLast(4))
                let isSystem = bundlePath.hasPrefix("/System/Library/CoreServices")
                let result = (id: bundlePath, name: cleanAppName, bundlePath: bundlePath as String?, isDaemon: isSystem)
                pidResolutionCache[pid] = result
                return result
            }
            
            let execName = (fullPath as NSString).lastPathComponent
            let isDaemon = fullPath.hasPrefix("/usr/libexec") || fullPath.hasPrefix("/System/") || fullPath.hasPrefix("/usr/sbin") || pid < 400
            let result = (id: execName, name: execName, bundlePath: nil as String?, isDaemon: isDaemon)
            pidResolutionCache[pid] = result
            return result
        }
        
        let result = (id: fallbackName, name: fallbackName, bundlePath: nil as String?, isDaemon: true)
        pidResolutionCache[pid] = result
        return result
    }
    
    public func resolveIcon(for id: String, bundlePath: String?) -> NSImage {
        if let cached = iconCache[id] {
            return cached
        }
        let img: NSImage
        if let path = bundlePath, FileManager.default.fileExists(atPath: path) {
            img = NSWorkspace.shared.icon(forFile: path)
        } else {
            img = NSWorkspace.shared.icon(forFile: "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/ExecutableBinaryIcon.icns")
        }
        img.size = NSSize(width: 28, height: 28)
        iconCache[id] = img
        return img
    }
    
    // MARK: - Formatting Helpers
    
    public static func formatBytes(_ bytes: UInt64) -> String {
        let kb = Double(bytes) / 1_000.0
        let mb = Double(bytes) / 1_000_000.0
        let gb = Double(bytes) / 1_000_000_000.0
        
        if gb >= 1.0 {
            return String(format: "%.2f GB", gb)
        } else if mb >= 10.0 {
            return String(format: "%.1f MB", mb)
        } else if mb >= 1.0 {
            return String(format: "%.2f MB", mb)
        } else if kb >= 1.0 {
            return String(format: "%.0f KB", kb)
        } else {
            return "\(bytes) B"
        }
    }
    
    public static func formatSpeed(_ bps: Double) -> String {
        if bps < 100 {
            return "0 KB/s"
        }
        let kbps = bps / 1_000.0
        let mbps = bps / 1_000_000.0
        if mbps >= 1.0 {
            return String(format: "%.1f MB/s", mbps)
        } else {
            return String(format: "%.0f KB/s", max(1, kbps))
        }
    }
}

private extension AppUsageRecord {
    var blockedAttemptsCount: Int { blockedCount }
}
