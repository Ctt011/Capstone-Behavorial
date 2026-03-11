import Foundation

// MARK: - File-Based Persistence
/// Moves large Codable arrays from UserDefaults to the Application Support directory.
/// This prevents hitting the ~512 KB UserDefaults limit on iOS.
/// Small scalar values (battery level, baselines) remain in UserDefaults.
enum PersistenceManager {
    
    private static let fileManager = FileManager.default
    
    private static var appSupportURL: URL {
        let url = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = url.appendingPathComponent("PhysioTwin", isDirectory: true)
        if !fileManager.fileExists(atPath: appDir.path) {
            try? fileManager.createDirectory(at: appDir, withIntermediateDirectories: true)
        }
        return appDir
    }
    
    // MARK: - Generic Save / Load
    
    static func save<T: Encodable>(_ value: T, filename: String) {
        let url = appSupportURL.appendingPathComponent("\(filename).json")
        do {
            let data = try JSONEncoder().encode(value)
            try data.write(to: url, options: .atomic)
        } catch {
            debugLog("⚠️ PersistenceManager: Failed to save \(filename): \(error.localizedDescription)")
        }
    }
    
    static func load<T: Decodable>(_ type: T.Type, filename: String) -> T? {
        let url = appSupportURL.appendingPathComponent("\(filename).json")
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(type, from: data)
        } catch {
            debugLog("⚠️ PersistenceManager: Failed to load \(filename): \(error.localizedDescription)")
            return nil
        }
    }
    
    static func delete(filename: String) {
        let url = appSupportURL.appendingPathComponent("\(filename).json")
        try? fileManager.removeItem(at: url)
    }
    
    // MARK: - File names for each data type
    
    enum File {
        static let batteryHistory = "battery_history"
        static let stressPredictions = "stress_predictions"
        static let recoveryActivities = "recovery_activities"
        static let sessionMetrics = "session_metrics"
        static let sleepScore = "sleep_score"
        static let activities = "activities"
        static let detectedActivities = "detected_activities"
    }
    
    // MARK: - Migration from UserDefaults
    
    /// One-time migration of large arrays from UserDefaults to file storage.
    /// Call on app launch. Safe to call multiple times — skips if already migrated.
    static func migrateFromUserDefaultsIfNeeded() {
        let migrationKey = "hasCompletedFileMigration_v1"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }
        
        // Migrate battery history
        migrateArray(key: "batteryHistory_v2", filename: File.batteryHistory)
        
        // Migrate stress predictions
        migrateArray(key: "todayStressPredictions", filename: File.stressPredictions)
        
        // Migrate recovery activities
        migrateArray(key: "recoveryActivities", filename: File.recoveryActivities)
        
        // Migrate session metrics
        migrateArray(key: "savedSessionMetrics", filename: File.sessionMetrics)
        
        // Migrate sleep score
        migrateData(key: "lastSleepRecoveryScore", filename: File.sleepScore)
        
        // Migrate activity entries
        migrateArray(key: "savedActivities", filename: File.activities)
        
        // Migrate detected activities
        migrateArray(key: "detectedActivities", filename: File.detectedActivities)
        
        UserDefaults.standard.set(true, forKey: migrationKey)
        debugLog("✅ PersistenceManager: Migration from UserDefaults completed")
    }
    
    private static func migrateArray(key: String, filename: String) {
        guard let data = UserDefaults.standard.data(forKey: key) else { return }
        let url = appSupportURL.appendingPathComponent("\(filename).json")
        do {
            try data.write(to: url, options: .atomic)
            UserDefaults.standard.removeObject(forKey: key)
        } catch {
            debugLog("⚠️ PersistenceManager: Migration failed for \(key): \(error.localizedDescription)")
        }
    }
    
    private static func migrateData(key: String, filename: String) {
        guard let data = UserDefaults.standard.data(forKey: key) else { return }
        let url = appSupportURL.appendingPathComponent("\(filename).json")
        do {
            try data.write(to: url, options: .atomic)
            UserDefaults.standard.removeObject(forKey: key)
        } catch {
            debugLog("⚠️ PersistenceManager: Migration failed for \(key): \(error.localizedDescription)")
        }
    }
}
