import Foundation
import AppKit

public enum TimeRangeFilter: String, CaseIterable, Identifiable {
    case session = "Current Session"
    case today = "Today (24h)"
    case sevenDays = "Last 7 Days"
    case thirtyDays = "Last 30 Days"
    case twelveMonths = "12 Months"
    
    public var id: String { rawValue }
    
    public var shortLabel: String {
        switch self {
        case .session: return "Session"
        case .today: return "Today"
        case .sevenDays: return "7 Days"
        case .thirtyDays: return "30 Days"
        case .twelveMonths: return "Monthly"
        }
    }
}

public struct AppUsageRecord: Codable {
    public var appId: String
    public var name: String
    public var bundlePath: String?
    public var isSystemDaemon: Bool
    public var bytesIn: UInt64
    public var bytesOut: UInt64
    public var blockedCount: Int
    public var lastSeen: Date
    
    public var totalBytes: UInt64 {
        bytesIn + bytesOut
    }
}

public struct TimeBucket: Codable {
    public var key: String // "yyyy-MM-dd-HH", "yyyy-MM-dd", or "yyyy-MM"
    public var bytesIn: UInt64
    public var bytesOut: UInt64
    public var blockedCount: Int
    public var perApp: [String: AppUsageRecord]
    
    public var totalBytes: UInt64 {
        bytesIn + bytesOut
    }
}

public struct ChartBarPoint: Identifiable {
    public let id: String
    public let label: String
    public let fullDateLabel: String
    public let bytesIn: UInt64
    public let bytesOut: UInt64
    public var totalBytes: UInt64 { bytesIn + bytesOut }
}

private struct PersistedHistoryDatabase: Codable {
    var hourlyBuckets: [String: TimeBucket] = [:]
    var dailyBuckets: [String: TimeBucket] = [:]
    var monthlyBuckets: [String: TimeBucket] = [:]
}

public final class UsageHistoryStore {
    public static let shared = UsageHistoryStore()
    
    private var db = PersistedHistoryDatabase()
    private let lock = NSLock()
    private let fileURL: URL
    private var dirty = false
    private var saveTimer: Timer?
    
    private let hourFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd-HH"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
    
    private let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
    
    private let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
    
    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let folder = appSupport.appendingPathComponent("TripGuard", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        self.fileURL = folder.appendingPathComponent("usage_history.json")
        loadFromDisk()
        
        DispatchQueue.main.async {
            self.saveTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
                self?.saveToDiskIfNeeded()
            }
        }
    }
    
    public func recordTraffic(
        appId: String,
        name: String,
        bundlePath: String?,
        isSystemDaemon: Bool,
        deltaIn: UInt64,
        deltaOut: UInt64,
        blockedDelta: Int,
        at date: Date = Date()
    ) {
        guard deltaIn > 0 || deltaOut > 0 || blockedDelta > 0 else { return }
        
        let hKey = hourFormatter.string(from: date)
        let dKey = dayFormatter.string(from: date)
        let mKey = monthFormatter.string(from: date)
        
        lock.lock()
        updateBucket(&db.hourlyBuckets, key: hKey, appId: appId, name: name, bundlePath: bundlePath, isSystemDaemon: isSystemDaemon, deltaIn: deltaIn, deltaOut: deltaOut, blockedDelta: blockedDelta, date: date)
        updateBucket(&db.dailyBuckets, key: dKey, appId: appId, name: name, bundlePath: bundlePath, isSystemDaemon: isSystemDaemon, deltaIn: deltaIn, deltaOut: deltaOut, blockedDelta: blockedDelta, date: date)
        updateBucket(&db.monthlyBuckets, key: mKey, appId: appId, name: name, bundlePath: bundlePath, isSystemDaemon: isSystemDaemon, deltaIn: deltaIn, deltaOut: deltaOut, blockedDelta: blockedDelta, date: date)
        dirty = true
        lock.unlock()
    }
    
    private func updateBucket(
        _ map: inout [String: TimeBucket],
        key: String,
        appId: String,
        name: String,
        bundlePath: String?,
        isSystemDaemon: Bool,
        deltaIn: UInt64,
        deltaOut: UInt64,
        blockedDelta: Int,
        date: Date
    ) {
        var bucket = map[key] ?? TimeBucket(key: key, bytesIn: 0, bytesOut: 0, blockedCount: 0, perApp: [:])
        bucket.bytesIn += deltaIn
        bucket.bytesOut += deltaOut
        bucket.blockedCount += blockedDelta
        
        var appRec = bucket.perApp[appId] ?? AppUsageRecord(
            appId: appId,
            name: name,
            bundlePath: bundlePath,
            isSystemDaemon: isSystemDaemon,
            bytesIn: 0,
            bytesOut: 0,
            blockedCount: 0,
            lastSeen: date
        )
        appRec.name = name
        if let bp = bundlePath { appRec.bundlePath = bp }
        appRec.bytesIn += deltaIn
        appRec.bytesOut += deltaOut
        appRec.blockedCount += blockedDelta
        appRec.lastSeen = date
        
        bucket.perApp[appId] = appRec
        map[key] = bucket
    }
    
    // MARK: - Querying Aggregated App Usage for a Time Range
    
    public func aggregatedAppRecords(for range: TimeRangeFilter, now: Date = Date()) -> [String: AppUsageRecord] {
        lock.lock()
        defer { lock.unlock() }
        
        let cal = Calendar.current
        var merged: [String: AppUsageRecord] = [:]
        
        switch range {
        case .session:
            // Handled live by NetworkMonitorEngine, but return empty here so caller uses session state
            return [:]
            
        case .today:
            let todayKey = dayFormatter.string(from: now)
            if let bucket = db.dailyBuckets[todayKey] {
                return bucket.perApp
            }
            return [:]
            
        case .sevenDays:
            for offset in 0..<7 {
                if let d = cal.date(byAdding: .day, value: -offset, to: now) {
                    let k = dayFormatter.string(from: d)
                    if let b = db.dailyBuckets[k] {
                        mergeAppMap(&merged, with: b.perApp)
                    }
                }
            }
            return merged
            
        case .thirtyDays:
            for offset in 0..<30 {
                if let d = cal.date(byAdding: .day, value: -offset, to: now) {
                    let k = dayFormatter.string(from: d)
                    if let b = db.dailyBuckets[k] {
                        mergeAppMap(&merged, with: b.perApp)
                    }
                }
            }
            return merged
            
        case .twelveMonths:
            for offset in 0..<12 {
                if let d = cal.date(byAdding: .month, value: -offset, to: now) {
                    let k = monthFormatter.string(from: d)
                    if let b = db.monthlyBuckets[k] {
                        mergeAppMap(&merged, with: b.perApp)
                    }
                }
            }
            return merged
        }
    }
    
    private func mergeAppMap(_ target: inout [String: AppUsageRecord], with source: [String: AppUsageRecord]) {
        for (appId, rec) in source {
            if var existing = target[appId] {
                existing.bytesIn += rec.bytesIn
                existing.bytesOut += rec.bytesOut
                existing.blockedCount += rec.blockedCount
                if rec.lastSeen > existing.lastSeen {
                    existing.lastSeen = rec.lastSeen
                }
                if existing.bundlePath == nil, let bp = rec.bundlePath {
                    existing.bundlePath = bp
                }
                target[appId] = existing
            } else {
                target[appId] = rec
            }
        }
    }
    
    // MARK: - Querying Timeline Bar Chart Points (Global or Per-App)
    
    public func chartPoints(for range: TimeRangeFilter, appId: String? = nil, now: Date = Date()) -> [ChartBarPoint] {
        lock.lock()
        defer { lock.unlock() }
        
        let cal = Calendar.current
        var points: [ChartBarPoint] = []
        
        switch range {
        case .session, .today:
            // Show last 24 hours in 2-hour or 1-hour bars (12 bars of 2h or 24 bars of 1h; let's do 24 hourly bars for Today)
            let displayHourFmt = DateFormatter()
            displayHourFmt.dateFormat = "ha"
            let fullHourFmt = DateFormatter()
            fullHourFmt.dateFormat = "MMM d, h:00 a"
            
            for offset in stride(from: 23, through: 0, by: -1) {
                if let d = cal.date(byAdding: .hour, value: -offset, to: now) {
                    let k = hourFormatter.string(from: d)
                    let bucket = db.hourlyBuckets[k]
                    let bIn: UInt64
                    let bOut: UInt64
                    if let specificApp = appId {
                        bIn = bucket?.perApp[specificApp]?.bytesIn ?? 0
                        bOut = bucket?.perApp[specificApp]?.bytesOut ?? 0
                    } else {
                        bIn = bucket?.bytesIn ?? 0
                        bOut = bucket?.bytesOut ?? 0
                    }
                    let lbl = offset % 3 == 0 ? displayHourFmt.string(from: d).lowercased() : ""
                    points.append(ChartBarPoint(
                        id: k,
                        label: lbl,
                        fullDateLabel: fullHourFmt.string(from: d),
                        bytesIn: bIn,
                        bytesOut: bOut
                    ))
                }
            }
            
        case .sevenDays:
            let shortDayFmt = DateFormatter()
            shortDayFmt.dateFormat = "EEE"
            let fullDayFmt = DateFormatter()
            fullDayFmt.dateFormat = "EEEE, MMM d"
            
            for offset in stride(from: 6, through: 0, by: -1) {
                if let d = cal.date(byAdding: .day, value: -offset, to: now) {
                    let k = dayFormatter.string(from: d)
                    let bucket = db.dailyBuckets[k]
                    let bIn: UInt64
                    let bOut: UInt64
                    if let specificApp = appId {
                        bIn = bucket?.perApp[specificApp]?.bytesIn ?? 0
                        bOut = bucket?.perApp[specificApp]?.bytesOut ?? 0
                    } else {
                        bIn = bucket?.bytesIn ?? 0
                        bOut = bucket?.bytesOut ?? 0
                    }
                    points.append(ChartBarPoint(
                        id: k,
                        label: offset == 0 ? "Today" : shortDayFmt.string(from: d),
                        fullDateLabel: fullDayFmt.string(from: d),
                        bytesIn: bIn,
                        bytesOut: bOut
                    ))
                }
            }
            
        case .thirtyDays:
            let shortDateFmt = DateFormatter()
            shortDateFmt.dateFormat = "MMM d"
            
            for offset in stride(from: 29, through: 0, by: -1) {
                if let d = cal.date(byAdding: .day, value: -offset, to: now) {
                    let k = dayFormatter.string(from: d)
                    let bucket = db.dailyBuckets[k]
                    let bIn: UInt64
                    let bOut: UInt64
                    if let specificApp = appId {
                        bIn = bucket?.perApp[specificApp]?.bytesIn ?? 0
                        bOut = bucket?.perApp[specificApp]?.bytesOut ?? 0
                    } else {
                        bIn = bucket?.bytesIn ?? 0
                        bOut = bucket?.bytesOut ?? 0
                    }
                    let lbl = (offset % 5 == 0 || offset == 0) ? shortDateFmt.string(from: d) : ""
                    points.append(ChartBarPoint(
                        id: k,
                        label: lbl,
                        fullDateLabel: shortDateFmt.string(from: d),
                        bytesIn: bIn,
                        bytesOut: bOut
                    ))
                }
            }
            
        case .twelveMonths:
            let shortMonthFmt = DateFormatter()
            shortMonthFmt.dateFormat = "MMM"
            let fullMonthFmt = DateFormatter()
            fullMonthFmt.dateFormat = "MMMM yyyy"
            
            for offset in stride(from: 11, through: 0, by: -1) {
                if let d = cal.date(byAdding: .month, value: -offset, to: now) {
                    let k = monthFormatter.string(from: d)
                    let bucket = db.monthlyBuckets[k]
                    let bIn: UInt64
                    let bOut: UInt64
                    if let specificApp = appId {
                        bIn = bucket?.perApp[specificApp]?.bytesIn ?? 0
                        bOut = bucket?.perApp[specificApp]?.bytesOut ?? 0
                    } else {
                        bIn = bucket?.bytesIn ?? 0
                        bOut = bucket?.bytesOut ?? 0
                    }
                    points.append(ChartBarPoint(
                        id: k,
                        label: shortMonthFmt.string(from: d),
                        fullDateLabel: fullMonthFmt.string(from: d),
                        bytesIn: bIn,
                        bytesOut: bOut
                    ))
                }
            }
        }
        
        return points
    }
    
    // MARK: - Persistence & Export
    
    public func saveToDiskIfNeeded() {
        lock.lock()
        guard dirty else {
            lock.unlock()
            return
        }
        let snapshot = db
        dirty = false
        lock.unlock()
        
        if let data = try? JSONEncoder().encode(snapshot) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
    
    private func loadFromDisk() {
        lock.lock()
        defer { lock.unlock() }
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(PersistedHistoryDatabase.self, from: data) {
            self.db = decoded
        }
    }
    
    public func clearAllHistory() {
        lock.lock()
        db = PersistedHistoryDatabase()
        dirty = true
        lock.unlock()
        saveToDiskIfNeeded()
        NetworkMonitorEngine.shared.resetSessionCounters()
    }
    
    public func exportCSV(for range: TimeRangeFilter) -> String {
        var lines = ["Application,Bundle Path,Download Bytes,Upload Bytes,Total Bytes,Formatted Total,Blocked Attempts"]
        let entries = NetworkMonitorEngine.shared.entries(for: range)
        for e in entries {
            let safeName = e.name.replacingOccurrences(of: ",", with: " ")
            let safePath = (e.bundlePath ?? "System").replacingOccurrences(of: ",", with: " ")
            let formatted = NetworkMonitorEngine.formatBytes(e.totalSessionBytes)
            lines.append("\(safeName),\(safePath),\(e.sessionBytesIn),\(e.sessionBytesOut),\(e.totalSessionBytes),\(formatted),\(e.blockedAttempts)")
        }
        return lines.joined(separator: "\n")
    }
}
