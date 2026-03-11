import Foundation
import SwiftUI

// MARK: - Activity Type Enum
enum ActivityType: String, CaseIterable, Codable, Identifiable {
    case aerobic = "Aerobic"
    case anaerobic = "Anaerobic"
    case cognitive = "Cognitive"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .aerobic: return "figure.run"
        case .anaerobic: return "dumbbell.fill"
        case .cognitive: return "brain.head.profile"
        }
    }
    
    var color: Color {
        switch self {
        case .aerobic: return .green
        case .anaerobic: return .orange
        case .cognitive: return .purple
        }
    }
    
    var description: String {
        switch self {
        case .aerobic: return "Running, cycling, swimming, etc."
        case .anaerobic: return "Weight lifting, HIIT, sprints, etc."
        case .cognitive: return "Work, studying, problem-solving, etc."
        }
    }
}

// MARK: - Activity Entry Model
struct ActivityEntry: Identifiable, Codable {
    let id: UUID
    var activityType: ActivityType
    var activityName: String
    var stressLevel: Int // 1-10 scale
    var startTime: Date
    var endTime: Date
    
    // Computed property for backwards compatibility and display
    var timestamp: Date { startTime }
    
    init(id: UUID = UUID(), activityType: ActivityType, activityName: String, stressLevel: Int, startTime: Date = Date(), endTime: Date = Date()) {
        self.id = id
        self.activityType = activityType
        self.activityName = activityName
        self.stressLevel = stressLevel
        self.startTime = startTime
        self.endTime = endTime
    }
    
    // Duration in minutes
    var durationMinutes: Int {
        Int(endTime.timeIntervalSince(startTime) / 60)
    }
    
    // Formatted duration string
    var durationString: String {
        let minutes = durationMinutes
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes == 0 {
                return "\(hours) hr"
            }
            return "\(hours) hr \(remainingMinutes) min"
        }
    }
    
    var stressDescription: String {
        switch stressLevel {
        case 1...3: return "Low"
        case 4...6: return "Moderate"
        case 7...10: return "High"
        default: return "Unknown"
        }
    }
    
    var stressColor: Color {
        switch stressLevel {
        case 1...3: return .green
        case 4...6: return .yellow
        case 7...10: return .red
        default: return .gray
        }
    }
}

// MARK: - Auto-Detected Activity Entry
/// Represents an activity detected by the ML classifier
struct DetectedActivityEntry: Identifiable, Codable {
    let id: UUID
    let activityType: String  // "PHYSICAL" or "COGNITIVE"
    let confidence: Double
    let startTime: Date
    var endTime: Date
    let stressScore: Int?  // Only for cognitive activities
    
    init(id: UUID = UUID(), activityType: String, confidence: Double, startTime: Date, endTime: Date = Date(), stressScore: Int? = nil) {
        self.id = id
        self.activityType = activityType
        self.confidence = confidence
        self.startTime = startTime
        self.endTime = endTime
        self.stressScore = stressScore
    }
    
    var durationMinutes: Int {
        Int(endTime.timeIntervalSince(startTime) / 60)
    }
    
    var formattedTimeRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "\(formatter.string(from: startTime)) - \(formatter.string(from: endTime))"
    }
    
    var icon: String {
        activityType == "PHYSICAL" ? "figure.run" : "brain.head.profile"
    }
    
    var color: Color {
        activityType == "PHYSICAL" ? .green : .purple
    }
}

// MARK: - Activity Manager
/// Manages the storage and retrieval of self-reported activity data.
/// 
/// ## Data Storage
/// Activities are stored locally on the device using **UserDefaults** with the key `"savedActivities"`.
/// The data is encoded as JSON and persists across app launches.
///
/// ## Where Data is Stored
/// - **Location**: App's sandboxed UserDefaults container
/// - **Path**: `~/Library/Preferences/<bundle-id>.plist` (on device, this is in the app's container)
/// - **Format**: JSON-encoded array of ActivityEntry objects
///
/// ## How Users Can Access Data
/// 1. **In-App**: Through the Activity History section in the dashboard
/// 2. **Export**: Use the `exportActivitiesAsJSON()` or `exportActivitiesAsCSV()` methods
/// 3. **Programmatic**: Call `ActivityManager.shared.activities` to get all entries
///
/// ## How Developers Can Access Data
/// - Access the singleton: `ActivityManager.shared`
/// - Get all activities: `ActivityManager.shared.activities`
/// - Filter by date: `ActivityManager.shared.activitiesForDate(_:)`
/// - Filter by type: `ActivityManager.shared.activitiesForType(_:)`
/// - Export data: `ActivityManager.shared.exportActivitiesAsJSON()`
///
class ActivityManager: ObservableObject {
    static let shared = ActivityManager()
    
    private let storageKey = "savedActivities"
    private let detectedActivitiesKey = "detectedActivities"
    
    @Published var activities: [ActivityEntry] = []
    @Published var detectedActivities: [DetectedActivityEntry] = []
    
    // Track the last detected activity to enable merging consecutive activities
    private var lastDetectedActivityType: String?
    private var lastDetectedActivityTime: Date?
    private let mergeThresholdMinutes: Double = 10  // Merge activities within 10 minutes
    
    private init() {
        loadActivities()
        loadDetectedActivities()
    }
    
    // MARK: - CRUD Operations
    
    /// Adds a new activity entry and saves to storage
    func addActivity(_ activity: ActivityEntry) {
        activities.insert(activity, at: 0) // Most recent first
        saveActivities()
        
        // Notify Body Battery Manager about the stress impact.
        // BodyBatteryManager is @MainActor, so schedule on main to avoid
        // racing with concurrent battery mutations from the pipeline timer.
        DispatchQueue.main.async {
            BodyBatteryManager.shared.applyStress(
                stressLevel: activity.stressLevel,
                durationMinutes: activity.durationMinutes
            )
        }
    }
    
    // MARK: - Auto-Detected Activity Logging
    
    /// Logs an activity detected by the ML classifier.
    /// Automatically merges consecutive activities of the same type.
    func logDetectedActivity(activityType: String, confidence: Double, stressScore: Int? = nil) {
        let now = Date()
        
        // Check if we should merge with the previous activity
        if let lastType = lastDetectedActivityType,
           let lastTime = lastDetectedActivityTime,
           lastType == activityType,
           now.timeIntervalSince(lastTime) < mergeThresholdMinutes * 60 {
            // Extend the last activity's end time
            if let lastIndex = detectedActivities.firstIndex(where: { $0.activityType == lastType && Calendar.current.isDate($0.endTime, equalTo: lastTime, toGranularity: .minute) }) {
                detectedActivities[lastIndex].endTime = now
                lastDetectedActivityTime = now
                saveDetectedActivities()
                return
            }
        }
        
        // Create a new activity entry
        let entry = DetectedActivityEntry(
            activityType: activityType,
            confidence: confidence,
            startTime: now.addingTimeInterval(-5 * 60),  // Started 5 minutes ago (window size)
            endTime: now,
            stressScore: stressScore
        )
        
        detectedActivities.insert(entry, at: 0)
        lastDetectedActivityType = activityType
        lastDetectedActivityTime = now
        
        // Keep only last 100 detected activities to manage storage
        if detectedActivities.count > 100 {
            detectedActivities = Array(detectedActivities.prefix(100))
        }
        
        saveDetectedActivities()
    }
    
    /// Returns detected activities for today, grouped by type with time ranges
    var todaysDetectedActivities: [DetectedActivityEntry] {
        detectedActivities.filter { Calendar.current.isDateInToday($0.startTime) }
    }
    
    /// Returns a summary of detected activities for today
    var todayActivitySummary: (physicalMinutes: Int, cognitiveMinutes: Int) {
        let today = todaysDetectedActivities
        let physical = today.filter { $0.activityType == "PHYSICAL" }.reduce(0) { $0 + $1.durationMinutes }
        let cognitive = today.filter { $0.activityType == "COGNITIVE" }.reduce(0) { $0 + $1.durationMinutes }
        return (physical, cognitive)
    }
    
    /// Removes an activity by its ID
    func removeActivity(id: UUID) {
        activities.removeAll { $0.id == id }
        saveActivities()
    }
    
    /// Removes activities at the specified offsets (for SwiftUI List deletion)
    func removeActivities(at offsets: IndexSet) {
        activities.remove(atOffsets: offsets)
        saveActivities()
    }
    
    /// Updates an existing activity
    func updateActivity(_ updatedActivity: ActivityEntry) {
        if let index = activities.firstIndex(where: { $0.id == updatedActivity.id }) {
            activities[index] = updatedActivity
            saveActivities()
        }
    }
    
    /// Clears all saved activities
    func clearAllActivities() {
        activities.removeAll()
        saveActivities()
    }
    
    // MARK: - Query Methods
    
    /// Returns activities for a specific date
    func activitiesForDate(_ date: Date) -> [ActivityEntry] {
        let calendar = Calendar.current
        return activities.filter { calendar.isDate($0.timestamp, inSameDayAs: date) }
    }
    
    /// Returns activities for today
    var todaysActivities: [ActivityEntry] {
        activitiesForDate(Date())
    }
    
    /// Returns activities for a specific activity type
    func activitiesForType(_ type: ActivityType) -> [ActivityEntry] {
        activities.filter { $0.activityType == type }
    }
    
    /// Returns activities within a date range
    func activitiesInRange(from startDate: Date, to endDate: Date) -> [ActivityEntry] {
        activities.filter { $0.timestamp >= startDate && $0.timestamp <= endDate }
    }
    
    /// Average stress level for today
    var todayAverageStress: Double? {
        let todayEntries = todaysActivities
        guard !todayEntries.isEmpty else { return nil }
        let total = todayEntries.reduce(0) { $0 + $1.stressLevel }
        return Double(total) / Double(todayEntries.count)
    }
    
    /// Average stress level by activity type
    func averageStress(for type: ActivityType) -> Double? {
        let typeEntries = activitiesForType(type)
        guard !typeEntries.isEmpty else { return nil }
        let total = typeEntries.reduce(0) { $0 + $1.stressLevel }
        return Double(total) / Double(typeEntries.count)
    }
    
    // MARK: - Persistence
    
    private func saveActivities() {
        PersistenceManager.save(activities, filename: PersistenceManager.File.activities)
    }
    
    private func loadActivities() {
        if let loaded = PersistenceManager.load([ActivityEntry].self, filename: PersistenceManager.File.activities) {
            activities = loaded
        }
    }
    
    private func saveDetectedActivities() {
        PersistenceManager.save(detectedActivities, filename: PersistenceManager.File.detectedActivities)
    }
    
    private func loadDetectedActivities() {
        if let loaded = PersistenceManager.load([DetectedActivityEntry].self, filename: PersistenceManager.File.detectedActivities) {
            detectedActivities = loaded
        }
    }
    
    /// Clears detected activities older than specified days
    func cleanupOldDetectedActivities(olderThanDays: Int = 7) {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -olderThanDays, to: Date()) ?? Date()
        detectedActivities.removeAll { $0.endTime < cutoffDate }
        saveDetectedActivities()
    }
    
    // MARK: - Export Methods
    
    /// Exports all activities as a JSON string
    func exportActivitiesAsJSON() -> String? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        do {
            let data = try encoder.encode(activities)
            return String(data: data, encoding: .utf8)
        } catch {
            debugLog("Failed to export as JSON: \(error)")
            return nil
        }
    }
    
    /// Exports all activities as a CSV string
    func exportActivitiesAsCSV() -> String {
        var csv = "ID,Activity Type,Activity Name,Stress Level,Timestamp\n"
        
        let dateFormatter = ISO8601DateFormatter()
        
        for activity in activities {
            let row = "\(activity.id.uuidString),\(activity.activityType.rawValue),\"\(activity.activityName)\",\(activity.stressLevel),\(dateFormatter.string(from: activity.timestamp))\n"
            csv += row
        }
        
        return csv
    }
}
