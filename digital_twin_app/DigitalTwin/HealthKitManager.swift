import Foundation
import HealthKit
import Combine
import UserNotifications

// MARK: - Data Models
struct DailySteps: Identifiable {
    let id = UUID()
    let date: Date
    let steps: Double
    
    var dayAbbreviation: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return String(formatter.string(from: date).prefix(1))
    }
    
    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
}

// MARK: - Health Metric with Timestamp
struct HealthMetric<T> {
    var value: T?
    var lastUpdated: Date?
    
    var formattedTimestamp: String {
        guard let date = lastUpdated else { return "Never" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    var detailedTimestamp: String {
        guard let date = lastUpdated else { return "No data" }
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(date) {
            formatter.dateFormat = "h:mm a"
            return "Today at \(formatter.string(from: date))"
        } else if Calendar.current.isDateInYesterday(date) {
            formatter.dateFormat = "h:mm a"
            return "Yesterday at \(formatter.string(from: date))"
        } else {
            formatter.dateFormat = "MMM d, h:mm a"
            return formatter.string(from: date)
        }
    }
}

// MARK: - Sleep Stage Data
struct SleepStageData: Identifiable {
    let id = UUID()
    let stage: SleepStage
    let duration: TimeInterval
    let startDate: Date
    let endDate: Date
}

enum SleepStage: String {
    case awake = "Awake"
    case rem = "REM"
    case core = "Core"
    case deep = "Deep"
    case asleep = "Asleep" // Legacy fallback
    
    var color: String {
        switch self {
        case .awake: return "orange"
        case .rem: return "purple"
        case .core: return "blue"
        case .deep: return "indigo"
        case .asleep: return "blue"
        }
    }
    
    var icon: String {
        switch self {
        case .awake: return "sun.max.fill"
        case .rem: return "brain.head.profile"
        case .core: return "moon.fill"
        case .deep: return "moon.zzz.fill"
        case .asleep: return "moon.fill"
        }
    }
}

// MARK: - Workout Summary
struct WorkoutSummary: Identifiable {
    let id = UUID()
    let workoutType: HKWorkoutActivityType
    let duration: TimeInterval
    let calories: Double?
    let distance: Double?
    let startDate: Date
    let endDate: Date
    
    var workoutName: String {
        switch workoutType {
        case .running: return "Running"
        case .walking: return "Walking"
        case .cycling: return "Cycling"
        case .swimming: return "Swimming"
        case .yoga: return "Yoga"
        case .functionalStrengthTraining: return "Strength Training"
        case .highIntensityIntervalTraining: return "HIIT"
        case .mindAndBody: return "Mind & Body"
        default: return "Workout"
        }
    }
    
    var icon: String {
        switch workoutType {
        case .running: return "figure.run"
        case .walking: return "figure.walk"
        case .cycling: return "bicycle"
        case .swimming: return "figure.pool.swim"
        case .yoga: return "figure.yoga"
        case .functionalStrengthTraining: return "dumbbell.fill"
        case .highIntensityIntervalTraining: return "flame.fill"
        case .mindAndBody: return "brain.head.profile"
        default: return "figure.mixed.cardio"
        }
    }
    
    var formattedDuration: String {
        let minutes = Int(duration / 60)
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            return "\(hours)h \(mins)m"
        }
        return "\(minutes) min"
    }
}

// MARK: - Mindful Session
struct MindfulSession: Identifiable {
    let id = UUID()
    let duration: TimeInterval
    let startDate: Date
    let endDate: Date
    
    var formattedDuration: String {
        let minutes = Int(duration / 60)
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            return "\(hours)h \(mins)m"
        }
        return "\(minutes) min"
    }
}

// MARK: - Activity Session Metrics
/// Metrics recorded during a recharge activity session (breathing, walking, meditation, stretching)
struct ActivitySessionMetrics: Identifiable {
    let id = UUID()
    let activityName: String
    let startTime: Date
    let endTime: Date
    let durationSeconds: Int
    
    // Heart Rate Metrics
    let heartRateSamples: [HeartRateSample]
    let minHeartRate: Double?
    let maxHeartRate: Double?
    let avgHeartRate: Double?
    
    // Heart Rate Variability Metrics
    let hrvSamples: [HRVSample]
    let rmssd: Double? // Root Mean Square of Successive Differences
    let avgHRV: Double?
    
    // Additional Metrics
    let caloriesBurned: Double?
    let respiratoryRate: Double?
    
    var heartRateRange: String {
        guard let min = minHeartRate, let max = maxHeartRate else { return "N/A" }
        return "\(Int(min)) - \(Int(max)) BPM"
    }
    
    var formattedDuration: String {
        let minutes = durationSeconds / 60
        let seconds = durationSeconds % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }
    
    var heartRateVariability: String {
        guard let rmssd = rmssd else { return "N/A" }
        return String(format: "%.1f ms", rmssd)
    }
    
    /// Interprets the HRV reading
    var hrvInterpretation: String {
        guard let rmssd = rmssd else { return "Not enough data" }
        switch rmssd {
        case 0..<20:
            return "Low variability - indicates higher stress"
        case 20..<40:
            return "Moderate variability - normal stress levels"
        case 40..<60:
            return "Good variability - relaxed state"
        default:
            return "Excellent variability - very relaxed"
        }
    }
    
    /// Overall relaxation score based on metrics
    var relaxationScore: Int {
        var score = 50 // Base score
        
        // Add points for good HRV
        if let rmssd = rmssd {
            if rmssd > 50 { score += 25 }
            else if rmssd > 30 { score += 15 }
            else if rmssd > 20 { score += 5 }
        }
        
        // Add points for heart rate reduction during activity
        if let samples = heartRateSamples.count > 2 ? heartRateSamples : nil {
            let firstHalf = Array(samples.prefix(samples.count / 2))
            let secondHalf = Array(samples.suffix(samples.count / 2))
            
            let firstAvg = firstHalf.map { $0.bpm }.reduce(0, +) / Double(firstHalf.count)
            let secondAvg = secondHalf.map { $0.bpm }.reduce(0, +) / Double(secondHalf.count)
            
            if secondAvg < firstAvg {
                score += Int((firstAvg - secondAvg) * 2)
            }
        }
        
        return min(100, max(0, score))
    }
    
    var relaxationLevel: String {
        switch relaxationScore {
        case 80...100: return "Excellent"
        case 60..<80: return "Good"
        case 40..<60: return "Moderate"
        default: return "Developing"
        }
    }
    
    /// Whether this session has any meaningful heart rate data
    var hasHeartRateData: Bool {
        return !heartRateSamples.isEmpty
    }
    
    /// Whether this session has any data at all
    var hasAnyData: Bool {
        return hasHeartRateData || !hrvSamples.isEmpty || (caloriesBurned ?? 0) > 0
    }
}

struct HeartRateSample: Identifiable {
    let id = UUID()
    let timestamp: Date
    let bpm: Double
}

struct HRVSample: Identifiable {
    let id = UUID()
    let timestamp: Date
    let sdnn: Double // Standard deviation of NN intervals (ms)
}

// MARK: - HealthKit Manager
@MainActor
class HealthKitManager: ObservableObject {
    private let healthStore = HKHealthStore()
    
    // Anchor storage keys for UserDefaults
    private let anchorKeyPrefix = "HealthKitAnchor_"
    
    // Activity classification pipeline
    private var stressPipeline: StressDetectionPipeline?
    private var lastActivityClassificationTime: Date?
    private let activityClassificationInterval: TimeInterval = 5 * 60  // 5 minutes
    
    @Published var isAuthorized = false
    @Published var authorizationStatus = "Not connected"
    @Published var isBackgroundDeliveryEnabled = false
    @Published var lastBackgroundSync: Date?
    @Published var latestActivityType: String?  // "PHYSICAL" or "COGNITIVE"
    @Published var latestActivityConfidence: Double = 0
    
    // Apple Watch connectivity
    @Published var isAppleWatchConnected: Bool = false
    @Published var appleWatchLastSeen: Date?
    private let watchActiveDataWindow: TimeInterval = 15 * 60 // 15 minutes
    private let watchStatusLookbackWindow: TimeInterval = 2 * 60 * 60 // 2 hours
    
    // Metrics with timestamps
    @Published var sleepMetric = HealthMetric<Double>()
    @Published var sleepStages: [SleepStageData] = []
    @Published var restingHeartRateMetric = HealthMetric<Double>()
    @Published var heartRateMetric = HealthMetric<Double>()
    @Published var hrvMetric = HealthMetric<Double>()
    @Published var respiratoryRateMetric = HealthMetric<Double>()
    @Published var activeEnergyMetric = HealthMetric<Double>()
    @Published var stepsMetric = HealthMetric<Double>()
    @Published var distanceMetric = HealthMetric<Double>()
    @Published var workouts: [WorkoutSummary] = []
    @Published var mindfulSessions: [MindfulSession] = []
    @Published var overnightHRVMetric = HealthMetric<Double>()
    @Published var overnightRestingHeartRateMetric = HealthMetric<Double>()
    
    // Legacy properties for compatibility
    @Published var latestHeartRate: Double?
    @Published var restingHeartRate: Double?
    @Published var latestHRV: Double?
    @Published var todaySteps: Double?
    @Published var activeCalories: Double?
    @Published var todayDistance: Double?
    @Published var lastNightSleep: Double?
    @Published var weeklySteps: [DailySteps] = []
    
    // Observer queries for background delivery
    private var observerQueries: [HKObserverQuery] = []
    
    private let typesToRead: Set<HKObjectType> = {
        var types = Set<HKObjectType>()
        let quantityTypes: [HKQuantityTypeIdentifier] = [
            .stepCount, .activeEnergyBurned, .distanceWalkingRunning,
            .heartRate, .restingHeartRate, .heartRateVariabilitySDNN,
            .bodyMass, .height, .appleExerciseTime, .respiratoryRate
        ]
        for id in quantityTypes {
            if let type = HKObjectType.quantityType(forIdentifier: id) {
                types.insert(type)
            }
        }
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleep)
        }
        if let mindful = HKObjectType.categoryType(forIdentifier: .mindfulSession) {
            types.insert(mindful)
        }
        types.insert(HKObjectType.workoutType())
        return types
    }()
    
    private let typesToWrite: Set<HKSampleType> = {
        var types = Set<HKSampleType>()
        types.insert(HKObjectType.workoutType())
        if let activeEnergy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(activeEnergy)
        }
        if let mindful = HKObjectType.categoryType(forIdentifier: .mindfulSession) {
            types.insert(mindful)
        }
        return types
    }()
    
    // Types that support background delivery
    private var backgroundDeliveryTypes: [HKSampleType] {
        var types: [HKSampleType] = []
        let quantityTypeIds: [HKQuantityTypeIdentifier] = [
            .stepCount, .activeEnergyBurned, .distanceWalkingRunning,
            .heartRate, .restingHeartRate, .heartRateVariabilitySDNN,
            .respiratoryRate
        ]
        for id in quantityTypeIds {
            if let type = HKQuantityType.quantityType(forIdentifier: id) {
                types.append(type)
            }
        }
        if let sleep = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) {
            types.append(sleep)
        }
        if let mindful = HKCategoryType.categoryType(forIdentifier: .mindfulSession) {
            types.append(mindful)
        }
        types.append(HKObjectType.workoutType())
        return types
    }
    
    // Workout session for high-frequency HR monitoring
    private var workoutBuilder: HKWorkoutBuilder?
    
    init() {
        checkAuthorizationStatus()
        requestNotificationPermission()
        // Initialize the stress detection pipeline with self reference
        // Note: Pipeline is created lazily since self isn't fully initialized yet
        Task { @MainActor in
            self.stressPipeline = StressDetectionPipeline(healthKitManager: self)
        }
    }
    
    var isHealthKitAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }
    
    // MARK: - Apple Watch Detection
    
    /// Checks if an Apple Watch is actively providing health data.
    ///
    /// Detection strategy:
    /// - Scan recent heart-rate samples and identify Apple Watch-origin samples
    ///   using sourceRevision.productType, source name, and device metadata.
    /// - Consider watch "connected/worn" when the most recent watch-origin HR sample
    ///   is fresh (within activeWatchWindow).
    func checkAppleWatchStatus() async {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            isAppleWatchConnected = false
            return
        }
        
        let now = Date()
        let lookbackStart = now.addingTimeInterval(-watchStatusLookbackWindow)
        let activeDataWindow = watchActiveDataWindow
        let predicate = HKQuery.predicateForSamples(withStart: lookbackStart, end: now, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        let result: (connected: Bool, lastSeen: Date?) = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: heartRateType, predicate: predicate, limit: 200, sortDescriptors: [sortDescriptor]) { _, samples, _ in
                guard let hrSamples = samples as? [HKQuantitySample], !hrSamples.isEmpty else {
                    continuation.resume(returning: (false, nil))
                    return
                }
                
                func isAppleWatchSample(_ sample: HKQuantitySample) -> Bool {
                    let sourceName = sample.sourceRevision.source.name.lowercased()
                    let productType = sample.sourceRevision.productType?.lowercased() ?? ""
                    let sourceBundle = sample.sourceRevision.source.bundleIdentifier.lowercased()
                    let deviceModel = sample.device?.model?.lowercased() ?? ""
                    let deviceName = sample.device?.name?.lowercased() ?? ""
                    let deviceManufacturer = sample.device?.manufacturer?.lowercased() ?? ""
                    
                    // Strongest signal: watch hardware identifier, e.g. "Watch7,1"
                    if productType.contains("watch") { return true }
                    
                    // Device metadata fallback
                    if (deviceManufacturer.contains("apple") && deviceModel.contains("watch")) ||
                        deviceName.contains("apple watch") {
                        return true
                    }
                    
                    // Source-name fallback (localized device names often include watch)
                    if sourceName.contains("watch") { return true }
                    
                    // Additional fallback for Apple-provided watch measurements in some pipelines
                    if sourceBundle.contains("apple") && (sourceName.contains("heart") || sourceName.contains("watch")) {
                        return true
                    }
                    
                    return false
                }
                
                // Find the most recent Apple Watch-origin sample
                let latestWatchSample = hrSamples.first(where: { isAppleWatchSample($0) })
                let lastSeen = latestWatchSample?.startDate
                let isConnected: Bool
                if let lastSeen = lastSeen {
                    isConnected = now.timeIntervalSince(lastSeen) <= activeDataWindow
                } else {
                    isConnected = false
                }
                
                continuation.resume(returning: (isConnected, lastSeen))
            }
            self.healthStore.execute(query)
        }
        
        isAppleWatchConnected = result.connected
        appleWatchLastSeen = result.lastSeen
        
        if result.connected {
            print("⌚ Apple Watch detected (last data: \(result.lastSeen?.description ?? "unknown"))")
        } else {
            print("⌚ Apple Watch NOT detected — stress prediction disabled")
        }
    }

    /// Returns true only when Apple Watch has provided data recently enough
    /// to be considered valid for real-time stress and battery updates.
    func hasFreshAppleWatchData(maxAge: TimeInterval? = nil) -> Bool {
        guard isAppleWatchConnected, let lastSeen = appleWatchLastSeen else {
            return false
        }
        let allowedAge = maxAge ?? watchActiveDataWindow
        return Date().timeIntervalSince(lastSeen) <= allowedAge
    }
    
    // MARK: - Activity Classification
    
    /// Runs the activity classification pipeline if enough time has passed
    func runActivityClassificationIfNeeded() async {
        // Skip classification if Apple Watch is not connected
        guard hasFreshAppleWatchData() else {
            print("⌚ Skipping activity classification — Apple Watch not detected")
            return
        }
        
        let now = Date()
        
        // Only run if enough time has passed since last classification
        if let lastTime = lastActivityClassificationTime,
           now.timeIntervalSince(lastTime) < activityClassificationInterval {
            return
        }
        
        // Initialize pipeline if needed
        if stressPipeline == nil {
            stressPipeline = StressDetectionPipeline(healthKitManager: self)
        }
        
        guard let pipeline = stressPipeline else { return }
        
        // Run the pipeline
        let result = await pipeline.runFullPipeline()
        
        lastActivityClassificationTime = now
        latestActivityType = result.activityType.rawValue
        latestActivityConfidence = result.activityConfidence
        
        // Log to ActivityManager
        ActivityManager.shared.logDetectedActivity(
            activityType: result.activityType.rawValue,
            confidence: result.activityConfidence,
            stressScore: result.activityType == .cognitive ? result.stressScore : nil
        )
        
        // Update BodyBatteryManager with latest pipeline stress results
        // This ensures background pipeline runs reflect in the Body Battery view
        if result.activityType == .cognitive {
            BodyBatteryManager.shared.updateFromPipelineResult(
                stressScore: result.stressScore,
                activityType: result.activityType.rawValue,
                dc: result.dc,
                ac: result.ac,
                sdnn: result.sdnn,
                adjustedThreshold: result.adjustedThreshold,
                isStressed: result.isStressed,
                timestamp: result.timestamp
            )
        }
        
        // Send notification for significant activity detections (confidence > 70%)
        if result.activityConfidence > 0.7 {
            sendActivityNotification(
                activityType: result.activityType.rawValue,
                confidence: result.activityConfidence
            )
        }
        
        print("🏃 Activity classified: \\(result.activityType.rawValue) (confidence: \\(String(format: \"%.1f%%\", result.activityConfidence * 100)))")
    }
    
    // MARK: - Notification Permission
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("✅ Notification permission granted")
            } else if let error = error {
                print("⚠️ Notification permission error: \\(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Send Background Sync Notification
    // Disabled - was too noisy for users
    private func sendBackgroundSyncNotification(dataType: String) {
        // Notification disabled - we now use activity classification notifications instead
        // Keep for debugging if needed:
        // let content = UNMutableNotificationContent()
        // content.title = "Health Data Synced"
        // content.body = "New \(dataType) data received. Keep the app running for accurate insights."
        // content.sound = .default
        // let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        // UNUserNotificationCenter.current().add(request) { error in
        //     if let error = error {
        //         print("⚠️ Failed to send notification: \(error.localizedDescription)")
        //     }
        // }
    }
    
    // MARK: - Activity Classification Notification
    func sendActivityNotification(activityType: String, confidence: Double) {
        let content = UNMutableNotificationContent()
        content.title = "Activity Detected"
        content.body = "You appear to be doing \(activityType.lowercased()) activity."
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: "activity-\(UUID().uuidString)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("⚠️ Failed to send activity notification: \(error.localizedDescription)")
            }
        }
    }
    
    func checkAuthorizationStatus() {
        guard isHealthKitAvailable else {
            authorizationStatus = "HealthKit not available"
            isAuthorized = false
            return
        }
        guard let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) else { return }
        let status = healthStore.authorizationStatus(for: stepType)
        switch status {
        case .sharingAuthorized:
            authorizationStatus = "Connected"
            isAuthorized = true
        case .sharingDenied:
            authorizationStatus = "Access denied"
            isAuthorized = false
        case .notDetermined:
            authorizationStatus = "Not connected"
            isAuthorized = false
        @unknown default:
            authorizationStatus = "Unknown"
            isAuthorized = false
        }
    }
    
    func requestAuthorization() {
        guard isHealthKitAvailable else {
            authorizationStatus = "HealthKit not available"
            return
        }
        healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead) { [weak self] success, error in
            Task { @MainActor in
                if success {
                    self?.isAuthorized = true
                    self?.authorizationStatus = "Connected"
                    await self?.refreshAllData()
                    self?.setupBackgroundDelivery()
                } else {
                    self?.isAuthorized = false
                    self?.authorizationStatus = error?.localizedDescription ?? "Authorization failed"
                }
            }
        }
    }
    
    // MARK: - Background Delivery Setup
    
    /// Sets up background delivery for all supported health data types
    func setupBackgroundDelivery() {
        guard isHealthKitAvailable else { return }
        
        // Stop any existing observer queries
        for query in observerQueries {
            healthStore.stop(query)
        }
        observerQueries.removeAll()
        
        for sampleType in backgroundDeliveryTypes {
            enableBackgroundDelivery(for: sampleType)
        }
        
        Task { @MainActor in
            isBackgroundDeliveryEnabled = true
        }
        print("✅ Background delivery setup complete for \(backgroundDeliveryTypes.count) types")
    }
    
    /// Enables background delivery for a specific sample type with observer and anchored queries
    private func enableBackgroundDelivery(for sampleType: HKSampleType) {
        // Create observer query
        let observerQuery = HKObserverQuery(sampleType: sampleType, predicate: nil) { [weak self] query, completionHandler, error in
            guard let self = self else {
                completionHandler()
                return
            }
            
            if let error = error {
                print("⚠️ Observer query error for \(sampleType.identifier): \(error.localizedDescription)")
                completionHandler() // ALWAYS call completion handler even on error
                return
            }
            
            // Run anchored object query to fetch only new samples
            Task {
                await self.fetchNewSamplesWithAnchor(for: sampleType)
                completionHandler() // ALWAYS call completion handler
            }
        }
        
        observerQueries.append(observerQuery)
        healthStore.execute(observerQuery)
        
        // Enable background delivery with immediate frequency
        healthStore.enableBackgroundDelivery(for: sampleType, frequency: .immediate) { success, error in
            if success {
                print("✅ Background delivery enabled for \(sampleType.identifier)")
            } else if let error = error {
                print("⚠️ Failed to enable background delivery for \(sampleType.identifier): \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Anchor Management
    
    /// Gets the stored anchor for a sample type
    private func getStoredAnchor(for sampleType: HKSampleType) -> HKQueryAnchor? {
        let key = anchorKeyPrefix + sampleType.identifier
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
    }
    
    /// Stores the anchor for a sample type
    private func storeAnchor(_ anchor: HKQueryAnchor?, for sampleType: HKSampleType) {
        let key = anchorKeyPrefix + sampleType.identifier
        if let anchor = anchor,
           let data = try? NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    
    /// Fetches new samples since last anchor using HKAnchoredObjectQuery
    private func fetchNewSamplesWithAnchor(for sampleType: HKSampleType) async {
        let anchor = getStoredAnchor(for: sampleType)
        
        return await withCheckedContinuation { continuation in
            let query = HKAnchoredObjectQuery(
                type: sampleType,
                predicate: nil,
                anchor: anchor,
                limit: HKObjectQueryNoLimit
            ) { [weak self] query, newSamples, deletedSamples, newAnchor, error in
                guard let self = self else {
                    continuation.resume()
                    return
                }
                
                if let error = error {
                    print("⚠️ Anchored query error for \(sampleType.identifier): \(error.localizedDescription)")
                    continuation.resume()
                    return
                }
                
                // Store new anchor
                self.storeAnchor(newAnchor, for: sampleType)
                
                // Process new samples
                if let samples = newSamples, !samples.isEmpty {
                    Task { @MainActor in
                        self.processFetchedSamples(samples, for: sampleType)
                        self.lastBackgroundSync = Date()
                        
                        // Send notification for significant updates
                        if samples.count > 0 {
                            let typeName = self.friendlyName(for: sampleType)
                            self.sendBackgroundSyncNotification(dataType: typeName)
                        }
                    }
                }
                
                continuation.resume()
            }
            
            healthStore.execute(query)
        }
    }
    
    /// Returns a friendly name for a sample type
    private func friendlyName(for sampleType: HKSampleType) -> String {
        switch sampleType.identifier {
        case HKQuantityTypeIdentifier.stepCount.rawValue: return "Steps"
        case HKQuantityTypeIdentifier.heartRate.rawValue: return "Heart Rate"
        case HKQuantityTypeIdentifier.heartRateVariabilitySDNN.rawValue: return "HRV"
        case HKQuantityTypeIdentifier.restingHeartRate.rawValue: return "Resting Heart Rate"
        case HKQuantityTypeIdentifier.respiratoryRate.rawValue: return "Respiratory Rate"
        case HKQuantityTypeIdentifier.activeEnergyBurned.rawValue: return "Active Energy"
        case HKQuantityTypeIdentifier.distanceWalkingRunning.rawValue: return "Distance"
        case HKCategoryTypeIdentifier.sleepAnalysis.rawValue: return "Sleep"
        case HKCategoryTypeIdentifier.mindfulSession.rawValue: return "Mindful Session"
        case "HKWorkoutTypeIdentifier": return "Workout"
        default: return "Health Data"
        }
    }
    
    /// Processes fetched samples and updates corresponding metrics
    @MainActor
    private func processFetchedSamples(_ samples: [HKSample], for sampleType: HKSampleType) {
        guard let latestSample = samples.sorted(by: { $0.startDate > $1.startDate }).first else { return }
        
        switch sampleType.identifier {
        case HKQuantityTypeIdentifier.stepCount.rawValue:
            // Aggregate today's steps
            Task { await refreshStepsData() }
            
        case HKQuantityTypeIdentifier.heartRate.rawValue:
            if let quantitySample = latestSample as? HKQuantitySample {
                let value = quantitySample.quantity.doubleValue(for: HKUnit(from: "count/min"))
                heartRateMetric = HealthMetric(value: value, lastUpdated: latestSample.startDate)
                latestHeartRate = value
            }
            // Re-check Apple Watch status and trigger classification when new heart rate data arrives
            Task {
                await checkAppleWatchStatus()
                await runActivityClassificationIfNeeded()
            }
            
        case HKQuantityTypeIdentifier.heartRateVariabilitySDNN.rawValue:
            if let quantitySample = latestSample as? HKQuantitySample {
                let value = quantitySample.quantity.doubleValue(for: .secondUnit(with: .milli))
                hrvMetric = HealthMetric(value: value, lastUpdated: latestSample.startDate)
                latestHRV = value
            }
            
        case HKQuantityTypeIdentifier.restingHeartRate.rawValue:
            if let quantitySample = latestSample as? HKQuantitySample {
                let value = quantitySample.quantity.doubleValue(for: HKUnit(from: "count/min"))
                restingHeartRateMetric = HealthMetric(value: value, lastUpdated: latestSample.startDate)
                restingHeartRate = value
            }
            
        case HKQuantityTypeIdentifier.respiratoryRate.rawValue:
            if let quantitySample = latestSample as? HKQuantitySample {
                let value = quantitySample.quantity.doubleValue(for: HKUnit(from: "count/min"))
                respiratoryRateMetric = HealthMetric(value: value, lastUpdated: latestSample.startDate)
            }
            
        case HKQuantityTypeIdentifier.activeEnergyBurned.rawValue:
            Task { await refreshActiveEnergyData() }
            
        case HKQuantityTypeIdentifier.distanceWalkingRunning.rawValue:
            Task { await refreshDistanceData() }
            
        case HKCategoryTypeIdentifier.sleepAnalysis.rawValue:
            Task { await refreshSleepData() }
            
        case HKCategoryTypeIdentifier.mindfulSession.rawValue:
            Task { await refreshMindfulSessionsData() }
            
        default:
            if sampleType is HKWorkoutType {
                Task { await refreshWorkoutsData() }
            }
        }
    }
    
    // MARK: - Data Refresh Methods
    
    private func refreshStepsData() async {
        if let (steps, date) = await fetchTodayStepsWithTimestamp() {
            stepsMetric = HealthMetric(value: steps, lastUpdated: date)
            todaySteps = steps
        }
    }
    
    private func refreshActiveEnergyData() async {
        if let (energy, date) = await fetchActiveCaloriesWithTimestamp() {
            activeEnergyMetric = HealthMetric(value: energy, lastUpdated: date)
            activeCalories = energy
        }
    }
    
    private func refreshDistanceData() async {
        if let (distance, date) = await fetchTodayDistanceWithTimestamp() {
            distanceMetric = HealthMetric(value: distance, lastUpdated: date)
            todayDistance = distance
        }
    }
    
    func refreshSleepData() async {
        let (hours, stages, date) = await fetchSleepWithStages()
        sleepMetric = HealthMetric(value: hours, lastUpdated: date)
        sleepStages = stages
        lastNightSleep = hours

        if let h = hours {
            print("😴 refreshSleepData: \(String(format: "%.1f", h))h, \(stages.count) stages, lastUpdated=\(date?.description ?? "nil")")
        } else {
            print("😴 refreshSleepData: no sleep data found")
        }

        await refreshOvernightRecoverySnapshot(stages: stages, sleepEndDate: date)
    }

    private func refreshOvernightRecoverySnapshot(stages: [SleepStageData], sleepEndDate: Date?) async {
        guard let window = resolveOvernightWindow(stages: stages, fallbackEndDate: sleepEndDate) else {
            overnightHRVMetric = HealthMetric(value: nil, lastUpdated: nil)
            overnightRestingHeartRateMetric = HealthMetric(value: nil, lastUpdated: nil)
            return
        }

        async let overnightHRV = fetchLatestHRVWithTimestamp(start: window.start, end: window.end)
        async let overnightRHR = fetchLatestRestingHeartRateWithTimestamp(start: window.start, end: window.end)

        if let (value, date) = await overnightHRV {
            overnightHRVMetric = HealthMetric(value: value, lastUpdated: date)
        } else {
            overnightHRVMetric = HealthMetric(value: nil, lastUpdated: nil)
        }

        if let (value, date) = await overnightRHR {
            overnightRestingHeartRateMetric = HealthMetric(value: value, lastUpdated: date)
        } else {
            overnightRestingHeartRateMetric = HealthMetric(value: nil, lastUpdated: nil)
        }
    }

    private func resolveOvernightWindow(stages: [SleepStageData], fallbackEndDate: Date?) -> (start: Date, end: Date)? {
        let sleepStagesOnly = stages.filter { $0.stage != .awake }
        if let minStart = sleepStagesOnly.map({ $0.startDate }).min(),
           let maxEnd = sleepStagesOnly.map({ $0.endDate }).max(),
           minStart < maxEnd {
            return (minStart, maxEnd)
        }

        let calendar = Calendar.current
        let now = Date()
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: now) else { return nil }
        guard let fallbackStart = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: yesterday) else { return nil }

        let fallbackEnd = fallbackEndDate ?? calendar.date(bySettingHour: 12, minute: 0, second: 0, of: now) ?? now
        guard fallbackStart < fallbackEnd else { return nil }

        return (fallbackStart, fallbackEnd)
    }
    
    private func refreshWorkoutsData() async {
        let (workoutList, date) = await fetchTodayWorkouts()
        workouts = workoutList
        if !workoutList.isEmpty {
            // Update the last workout timestamp
        }
    }
    
    private func refreshMindfulSessionsData() async {
        let (sessions, date) = await fetchTodayMindfulSessions()
        mindfulSessions = sessions
    }
    
    func refreshAllData() async {
        // Check Apple Watch status first
        await checkAppleWatchStatus()
        
        async let steps = fetchTodayStepsWithTimestamp()
        async let calories = fetchActiveCaloriesWithTimestamp()
        async let distance = fetchTodayDistanceWithTimestamp()
        async let heartRate = fetchLatestHeartRateWithTimestamp()
        async let restingHR = fetchRestingHeartRateWithTimestamp()
        async let hrv = fetchLatestHRVWithTimestamp()
        async let sleep = fetchSleepWithStages()
        async let weekly = fetchWeeklySteps()
        async let respRate = fetchLatestRespiratoryRateWithTimestamp()
        async let workoutData = fetchTodayWorkouts()
        async let mindfulData = fetchTodayMindfulSessions()
        
        // Steps
        if let (stepValue, stepDate) = await steps {
            stepsMetric = HealthMetric(value: stepValue, lastUpdated: stepDate)
            todaySteps = stepValue
        }
        
        // Calories
        if let (calValue, calDate) = await calories {
            activeEnergyMetric = HealthMetric(value: calValue, lastUpdated: calDate)
            activeCalories = calValue
        }
        
        // Distance
        if let (distValue, distDate) = await distance {
            distanceMetric = HealthMetric(value: distValue, lastUpdated: distDate)
            todayDistance = distValue
        }
        
        // Heart Rate
        if let (hrValue, hrDate) = await heartRate {
            heartRateMetric = HealthMetric(value: hrValue, lastUpdated: hrDate)
            latestHeartRate = hrValue
        }
        
        // Resting HR
        if let (rhrValue, rhrDate) = await restingHR {
            restingHeartRateMetric = HealthMetric(value: rhrValue, lastUpdated: rhrDate)
            restingHeartRate = rhrValue
        }
        
        // HRV
        if let (hrvValue, hrvDate) = await hrv {
            hrvMetric = HealthMetric(value: hrvValue, lastUpdated: hrvDate)
            latestHRV = hrvValue
        }
        
        // Respiratory Rate
        if let (respValue, respDate) = await respRate {
            respiratoryRateMetric = HealthMetric(value: respValue, lastUpdated: respDate)
        }
        
        // Sleep with stages
        let (sleepHours, stages, sleepDate) = await sleep
        sleepMetric = HealthMetric(value: sleepHours, lastUpdated: sleepDate)
        sleepStages = stages
        lastNightSleep = sleepHours
        await refreshOvernightRecoverySnapshot(stages: stages, sleepEndDate: sleepDate)
        
        // Weekly steps
        weeklySteps = await weekly
        
        // Workouts
        let (workoutList, _) = await workoutData
        workouts = workoutList
        
        // Mindful sessions
        let (sessionsList, _) = await mindfulData
        mindfulSessions = sessionsList
    }
    
    // MARK: - Fetch Methods with Timestamps
    
    private func fetchTodayStepsWithTimestamp() async -> (Double, Date)? {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return nil }
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                if let sum = result?.sumQuantity()?.doubleValue(for: .count()),
                   let endDate = result?.endDate {
                    continuation.resume(returning: (sum, endDate))
                } else {
                    continuation.resume(returning: nil)
                }
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchActiveCaloriesWithTimestamp() async -> (Double, Date)? {
        guard let calorieType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return nil }
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: calorieType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                if let sum = result?.sumQuantity()?.doubleValue(for: .kilocalorie()),
                   let endDate = result?.endDate {
                    continuation.resume(returning: (sum, endDate))
                } else {
                    continuation.resume(returning: nil)
                }
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchTodayDistanceWithTimestamp() async -> (Double, Date)? {
        guard let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) else { return nil }
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: distanceType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                if let sum = result?.sumQuantity()?.doubleValue(for: .meter()),
                   let endDate = result?.endDate {
                    continuation.resume(returning: (sum, endDate))
                } else {
                    continuation.resume(returning: nil)
                }
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchLatestHeartRateWithTimestamp() async -> (Double, Date)? {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return nil }
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: heartRateType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
                if let sample = samples?.first as? HKQuantitySample {
                    let value = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
                    continuation.resume(returning: (value, sample.startDate))
                } else {
                    continuation.resume(returning: nil)
                }
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchRestingHeartRateWithTimestamp() async -> (Double, Date)? {
        await fetchLatestRestingHeartRateWithTimestamp(start: nil, end: nil)
    }
    
    private func fetchLatestHRVWithTimestamp() async -> (Double, Date)? {
        // Look for HRV data from the last 7 days to ensure we get recent data
        let now = Date()
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: now)!

        if let result = await fetchLatestHRVWithTimestamp(start: sevenDaysAgo, end: now) {
            return result
        }

        print("⚠️ No HRV samples found in last 7 days. Fetching all-time latest...")
        return await fetchLatestHRVWithTimestamp(start: nil, end: nil)
    }

    private func fetchLatestHRVWithTimestamp(start: Date?, end: Date?) async -> (Double, Date)? {
        guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return nil }
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let predicate = start != nil || end != nil
            ? HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            : nil

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: hrvType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error = error {
                    print("⚠️ HRV fetch error: \(error.localizedDescription)")
                }

                if let sample = samples?.first as? HKQuantitySample {
                    let value = sample.quantity.doubleValue(for: .secondUnit(with: .milli))
                    let source = sample.sourceRevision.source.name
                    print("✅ HRV sample found: \(value) ms from \(source) at \(sample.startDate)")
                    continuation.resume(returning: (value, sample.startDate))
                } else {
                    continuation.resume(returning: nil)
                }
            }
            healthStore.execute(query)
        }
    }

    private func fetchLatestRestingHeartRateWithTimestamp(start: Date?, end: Date?) async -> (Double, Date)? {
        guard let restingHRType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else { return nil }
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let predicate = start != nil || end != nil
            ? HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            : nil

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: restingHRType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
                if let sample = samples?.first as? HKQuantitySample {
                    let value = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
                    continuation.resume(returning: (value, sample.startDate))
                } else {
                    continuation.resume(returning: nil)
                }
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchLatestRespiratoryRateWithTimestamp() async -> (Double, Date)? {
        guard let respType = HKQuantityType.quantityType(forIdentifier: .respiratoryRate) else { return nil }
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: respType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
                if let sample = samples?.first as? HKQuantitySample {
                    let value = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
                    continuation.resume(returning: (value, sample.startDate))
                } else {
                    continuation.resume(returning: nil)
                }
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchSleepWithStages() async -> (Double?, [SleepStageData], Date?) {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return (nil, [], nil) }
        let calendar = Calendar.current
        let now = Date()

        // Determine the "sleep day" we're interested in.
        // If it's before noon we want LAST night's sleep (the one ending today).
        // If it's noon or later we still want last night's sleep.
        // The query window must be wide enough for WHOOP / third-party devices
        // that write long .inBed samples or unusual timestamps.
        //
        // Window: 2 days ago at 6 PM → today at 2 PM
        // This catches:
        //   - Normal 10 PM → 6 AM sleep
        //   - Late 2 AM → 10 AM sleep (attributed to today)
        //   - Early risers / multi-phase sleepers
        //   - WHOOP long .inBed spans
        guard let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: now) else { return (nil, [], nil) }
        let windowStart = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: twoDaysAgo)!
        // End at 2 PM today or now, whichever is earlier
        let todayAfternoon = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: now)!
        let windowEnd = min(todayAfternoon, now)

        // Use no strict options — return ANY sample that overlaps the window.
        // This is the most inclusive and catches WHOOP, Apple Watch, and all
        // third-party devices regardless of how they write sample boundaries.
        let predicate = HKQuery.predicateForSamples(withStart: windowStart, end: windowEnd, options: [])

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]) { _, samples, _ in
                guard let samples = samples as? [HKCategorySample], !samples.isEmpty else {
                    print("😴 No sleep samples found in window \(windowStart) → \(windowEnd)")
                    continuation.resume(returning: (nil, [], nil))
                    return
                }

                // Debug: log all raw samples so we can diagnose issues
                print("😴 Found \(samples.count) raw sleep samples in window:")
                for (i, sample) in samples.prefix(20).enumerated() {
                    let val = HKCategoryValueSleepAnalysis(rawValue: sample.value)
                    let valName: String
                    switch val {
                    case .awake: valName = "awake"
                    case .asleepREM: valName = "REM"
                    case .asleepCore: valName = "core"
                    case .asleepDeep: valName = "deep"
                    case .asleep: valName = "asleep"
                    default: valName = "inBed/other(\(sample.value))"
                    }
                    let src = sample.sourceRevision.source.name
                    let dur = sample.endDate.timeIntervalSince(sample.startDate) / 60.0
                    print("   [\(i)] \(valName): \(sample.startDate) → \(sample.endDate) (\(String(format: "%.0f", dur))min) src=\(src)")
                }

                // ----------------------------------------------------------------
                // Group samples into "sleep sessions" so we pick the most recent
                // qualifying night. A session is a cluster of samples where gaps
                // between consecutive samples are ≤ 60 min.
                // ----------------------------------------------------------------
                let sorted = samples.sorted { $0.startDate < $1.startDate }
                var sessions: [[HKCategorySample]] = []
                var currentSession: [HKCategorySample] = []

                for sample in sorted {
                    if let last = currentSession.last {
                        let gap = sample.startDate.timeIntervalSince(last.endDate)
                        if gap > 60 * 60 { // > 60 min gap → new session
                            if !currentSession.isEmpty { sessions.append(currentSession) }
                            currentSession = [sample]
                        } else {
                            currentSession.append(sample)
                        }
                    } else {
                        currentSession.append(sample)
                    }
                }
                if !currentSession.isEmpty { sessions.append(currentSession) }

                // Pick the session whose END is most recent AND that has actual
                // asleep data (at least 30 min total sleep).
                // Fall back to the most recent session if none qualifies.
                func parseSession(_ sessionSamples: [HKCategorySample]) -> (Double, [SleepStageData], Date?) {
                    var stages: [SleepStageData] = []
                    var totalAsleepSeconds: TimeInterval = 0
                    var latestDate: Date? = nil
                    var hasStageData = false

                    for sample in sessionSamples {
                        let duration = sample.endDate.timeIntervalSince(sample.startDate)
                        let value = HKCategoryValueSleepAnalysis(rawValue: sample.value)

                        if latestDate == nil || sample.endDate > (latestDate ?? .distantPast) {
                            latestDate = sample.endDate
                        }

                        var stage: SleepStage? = nil
                        var countAsAsleep = false

                        switch value {
                        case .awake:
                            stage = .awake
                        case .asleepREM:
                            stage = .rem
                            countAsAsleep = true
                            hasStageData = true
                        case .asleepCore:
                            stage = .core
                            countAsAsleep = true
                            hasStageData = true
                        case .asleepDeep:
                            stage = .deep
                            countAsAsleep = true
                            hasStageData = true
                        case .asleep:
                            stage = .asleep
                            countAsAsleep = true
                        default:
                            // .inBed / other: count as asleep ONLY if we have no
                            // stage-specific data for this session. This handles
                            // WHOOP and third-party devices that only write .inBed.
                            stage = .asleep
                            // We'll decide countAsAsleep below after full scan
                            break
                        }

                        if let stage = stage {
                            stages.append(SleepStageData(
                                stage: stage,
                                duration: duration,
                                startDate: sample.startDate,
                                endDate: sample.endDate
                            ))
                        }

                        if countAsAsleep {
                            totalAsleepSeconds += duration
                        }
                    }

                    // Second pass: if no stage-specific data was found, count
                    // .inBed / default samples as asleep time (WHOOP fallback).
                    if !hasStageData {
                        totalAsleepSeconds = 0
                        for sample in sessionSamples {
                            let value = HKCategoryValueSleepAnalysis(rawValue: sample.value)
                            if value != .awake {
                                totalAsleepSeconds += sample.endDate.timeIntervalSince(sample.startDate)
                            }
                        }
                    }

                    let hours = totalAsleepSeconds / 3600.0
                    return (hours, stages, latestDate)
                }

                // Try sessions from most-recent-ending to oldest.
                let rankedSessions = sessions.sorted { s1, s2 in
                    let end1 = s1.map({ $0.endDate }).max() ?? .distantPast
                    let end2 = s2.map({ $0.endDate }).max() ?? .distantPast
                    return end1 > end2
                }

                for session in rankedSessions {
                    let (hours, stages, latestDate) = parseSession(session)
                    // Accept sessions with ≥ 0.5 hours of sleep
                    if hours >= 0.5 {
                        let src = session.first?.sourceRevision.source.name ?? "unknown"
                        print("😴 Sleep data: \(String(format: "%.1f", hours))h, \(stages.count) stage samples, source=\(src)")
                        continuation.resume(returning: (hours, stages, latestDate))
                        return
                    }
                }

                // No qualifying session — return empty
                print("😴 Sleep samples found (\(samples.count)) but none qualified (< 30 min total sleep)")
                continuation.resume(returning: (nil, [], nil))
            }
            healthStore.execute(query)
        }
    }
    
    /// Checks whether the user is currently in an active workout session
    /// recorded on the Apple Watch (walking, running, etc.).
    /// Returns the workout if one is currently in progress (started but not yet ended).
    func fetchActiveWorkout() async -> HKWorkout? {
        let workoutType = HKObjectType.workoutType()
        let now = Date()
        // Look back up to 4 hours for an ongoing workout
        let lookback = now.addingTimeInterval(-4 * 3600)
        let predicate = HKQuery.predicateForSamples(withStart: lookback, end: now, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: workoutType,
                                      predicate: predicate,
                                      limit: 5,
                                      sortDescriptors: [sortDescriptor]) { _, samples, _ in
                guard let workouts = samples as? [HKWorkout] else {
                    continuation.resume(returning: nil)
                    return
                }
                // A workout is "active" if its endDate is very recent (within 60s)
                // or effectively equal to now (some apps set endDate = startDate while active)
                for w in workouts {
                    if w.endDate.timeIntervalSince(w.startDate) < 5 || now.timeIntervalSince(w.endDate) < 60 {
                        continuation.resume(returning: w)
                        return
                    }
                }
                continuation.resume(returning: nil)
            }
            healthStore.execute(query)
        }
    }

    /// Fetches total step count for the last N minutes as a single number.
    /// More reliable than per-minute buckets because HealthKit may batch-deliver steps.
    func fetchTotalSteps(minutes: Int) async -> Double {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return 0 }
        let now = Date()
        let startTime = now.addingTimeInterval(-Double(minutes * 60))
        let predicate = HKQuery.predicateForSamples(withStart: startTime, end: now, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: stepType,
                                          quantitySamplePredicate: predicate,
                                          options: .cumulativeSum) { _, result, _ in
                let steps = result?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                continuation.resume(returning: steps)
            }
            healthStore.execute(query)
        }
    }

    private func fetchTodayWorkouts() async -> ([WorkoutSummary], Date?) {
        let workoutType = HKObjectType.workoutType()
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: workoutType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, _ in
                guard let workouts = samples as? [HKWorkout], !workouts.isEmpty else {
                    continuation.resume(returning: ([], nil))
                    return
                }
                
                let summaries = workouts.map { workout in
                    WorkoutSummary(
                        workoutType: workout.workoutActivityType,
                        duration: workout.duration,
                        calories: workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()),
                        distance: workout.totalDistance?.doubleValue(for: .meter()),
                        startDate: workout.startDate,
                        endDate: workout.endDate
                    )
                }
                
                continuation.resume(returning: (summaries, workouts.first?.endDate))
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchTodayMindfulSessions() async -> ([MindfulSession], Date?) {
        guard let mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession) else { return ([], nil) }
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: mindfulType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, _ in
                guard let sessions = samples as? [HKCategorySample], !sessions.isEmpty else {
                    continuation.resume(returning: ([], nil))
                    return
                }
                
                let mindfulSessions = sessions.map { session in
                    MindfulSession(
                        duration: session.endDate.timeIntervalSince(session.startDate),
                        startDate: session.startDate,
                        endDate: session.endDate
                    )
                }
                
                continuation.resume(returning: (mindfulSessions, sessions.first?.endDate))
            }
            healthStore.execute(query)
        }
    }
    
    // MARK: - Legacy Fetch Methods (for compatibility)
    
    private func fetchTodaySteps() async -> Double? {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return nil }
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                let steps = result?.sumQuantity()?.doubleValue(for: .count())
                continuation.resume(returning: steps)
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchActiveCalories() async -> Double? {
        guard let calorieType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return nil }
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: calorieType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                let calories = result?.sumQuantity()?.doubleValue(for: .kilocalorie())
                continuation.resume(returning: calories)
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchTodayDistance() async -> Double? {
        guard let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) else { return nil }
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: distanceType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                let distance = result?.sumQuantity()?.doubleValue(for: .meter())
                continuation.resume(returning: distance)
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchLatestHeartRate() async -> Double? {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return nil }
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: heartRateType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
                let heartRate = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: HKUnit(from: "count/min"))
                continuation.resume(returning: heartRate)
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchRestingHeartRate() async -> Double? {
        guard let restingHRType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else { return nil }
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: restingHRType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
                let heartRate = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: HKUnit(from: "count/min"))
                continuation.resume(returning: heartRate)
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchLatestHRV() async -> Double? {
        guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return nil }
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: hrvType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
                let hrv = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: .secondUnit(with: .milli))
                continuation.resume(returning: hrv)
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchLastNightSleep() async -> Double? {
        // Delegate to the shared fetchSleepWithStages to ensure consistent
        // window, WHOOP compatibility, and session grouping logic.
        let (hours, _, _) = await fetchSleepWithStages()
        return hours
    }
    
    /// Fetches average sleep hours over the last 30 days for personal baseline
    /// Returns nil if insufficient data (falls back to 7.0 default)
    func fetchAverageSleepLast30Days() async -> Double? {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }
        let calendar = Calendar.current
        let now = Date()
        guard let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now) else { return nil }
        
        let predicate = HKQuery.predicateForSamples(withStart: thirtyDaysAgo, end: now, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                guard let samples = samples as? [HKCategorySample], !samples.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }
                
                // Group sleep samples by night (6 PM to 12 PM next day)
                var nightlySleepHours: [Date: Double] = [:]
                
                for sample in samples {
                    let value = HKCategoryValueSleepAnalysis(rawValue: sample.value)
                    // Accept asleep stages AND .inBed (used by WHOOP and third-party devices)
                    let isAsleep = value == .asleepCore || value == .asleepDeep || value == .asleepREM || value == .asleep
                    let isInBed = (value != .awake && !isAsleep) // .inBed or other non-awake
                    guard isAsleep || isInBed else { continue }
                    
                    // Determine which \"night\" this sample belongs to.\n                    // Sleep before 6 PM → belongs to previous night's wake-day.\n                    // Sleep at/after 6 PM → belongs to the NEXT day's wake-day.\n                    // This means 2 AM sleep on March 3 is keyed to March 3 (wake-day),\n                    // and 11 PM sleep on March 2 is also keyed to March 3 (wake-day).
                    let hour = calendar.component(.hour, from: sample.startDate)
                    var nightDate: Date
                    if hour < 18 {
                        // Before 6 PM - wake-day is today (the day the sample starts on)
                        nightDate = sample.startDate
                    } else {
                        // At/after 6 PM - wake-day is tomorrow
                        nightDate = calendar.date(byAdding: .day, value: 1, to: sample.startDate)!
                    }
                    nightDate = calendar.startOfDay(for: nightDate)
                    
                    let durationHours = sample.endDate.timeIntervalSince(sample.startDate) / 3600.0
                    nightlySleepHours[nightDate, default: 0] += durationHours
                }
                
                // Only count nights with at least 2 hours of sleep (filter out noise)
                let validNights = nightlySleepHours.filter { $0.value >= 2.0 }
                guard validNights.count >= 7 else {
                    // Need at least 7 nights of data for a reliable average
                    continuation.resume(returning: nil)
                    return
                }
                
                let averageHours = validNights.values.reduce(0, +) / Double(validNights.count)
                continuation.resume(returning: averageHours)
            }
            healthStore.execute(query)
        }
    }
    
    /// Fetches step count for the last N minutes (for activity classification)
    func fetchStepsForLastMinutes(_ minutes: Int) async -> Double? {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return nil }
        let now = Date()
        let startTime = now.addingTimeInterval(-Double(minutes * 60))
        let predicate = HKQuery.predicateForSamples(withStart: startTime, end: now, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                let steps = result?.sumQuantity()?.doubleValue(for: .count())
                continuation.resume(returning: steps)
            }
            healthStore.execute(query)
        }
    }
    
    /// Fetches step counts for each minute in the last N minutes
    /// Used to calculate real step variability (std) for activity classification
    /// Returns: Array of step counts per minute, e.g. [12, 15, 8, 20, 14] for 5 minutes
    func fetchStepsPerMinuteBuckets(_ minutes: Int) async -> [Double] {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return [] }
        let now = Date()
        let calendar = Calendar.current
        
        var buckets: [Double] = []
        
        // Fetch steps for each 1-minute interval
        for i in 0..<minutes {
            let endTime = calendar.date(byAdding: .minute, value: -i, to: now)!
            let startTime = calendar.date(byAdding: .minute, value: -(i + 1), to: now)!
            let predicate = HKQuery.predicateForSamples(withStart: startTime, end: endTime, options: .strictStartDate)
            
            let steps = await withCheckedContinuation { continuation in
                let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                    let count = result?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                    continuation.resume(returning: count)
                }
                healthStore.execute(query)
            }
            buckets.append(steps)
        }
        
        return buckets.reversed() // Return in chronological order
    }
    
    /// Computes step statistics (mean and std) from minute buckets
    /// Used as accelerometer proxy for activity classification
    func fetchStepsStatistics(minutes: Int) async -> (mean: Double, std: Double) {
        let buckets = await fetchStepsPerMinuteBuckets(minutes)
        
        guard !buckets.isEmpty else {
            return (mean: 0.5, std: 0.5) // Fallback for no data
        }
        
        let mean = buckets.reduce(0, +) / Double(buckets.count)
        
        guard buckets.count >= 2 else {
            return (mean: mean, std: 0.5)
        }
        
        let variance = buckets.map { pow($0 - mean, 2) }.reduce(0, +) / Double(buckets.count - 1)
        let std = sqrt(variance)
        
        return (mean: mean, std: max(0.1, std)) // Minimum std of 0.1 to avoid division issues
    }
    
    private func fetchWeeklySteps() async -> [DailySteps] {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return [] }
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        guard let startDate = calendar.date(byAdding: .day, value: -6, to: startOfToday) else { return [] }
        var interval = DateComponents()
        interval.day = 1
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: stepType,
                quantitySamplePredicate: nil,
                options: .cumulativeSum,
                anchorDate: startDate,
                intervalComponents: interval
            )
            query.initialResultsHandler = { _, results, _ in
                var dailySteps: [DailySteps] = []
                results?.enumerateStatistics(from: startDate, to: now) { statistics, _ in
                    let steps = statistics.sumQuantity()?.doubleValue(for: .count()) ?? 0
                    dailySteps.append(DailySteps(date: statistics.startDate, steps: steps))
                }
                continuation.resume(returning: dailySteps)
            }
            healthStore.execute(query)
        }
    }
    
    // MARK: - Workout Session for HR Monitoring
    
    /// Starts a workout builder session to record the mindfulness activity.
    /// 
    /// ⚠️ IMPORTANT LIMITATION: This creates a workout record on the iPhone but does NOT
    /// trigger high-frequency HR sampling from Apple Watch. For high-frequency HR (every 5-6 sec),
    /// you need either:
    /// 1. A watchOS companion app with an active HKWorkoutSession on the Watch
    /// 2. The user to start a workout using Apple's Workout or Breathe app on Watch
    /// 
    /// Without a watchOS app, we rely on passive HR sampling (every 5-10 min) or any
    /// HR data recorded by other apps/activities during the session window.
    func startWorkoutSession() async {
        guard isHealthKitAvailable else { return }
        
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .mindAndBody
        configuration.locationType = .indoor
        
        do {
            workoutBuilder = HKWorkoutBuilder(healthStore: healthStore, configuration: configuration, device: .local())
            try await workoutBuilder?.beginCollection(at: Date())
            print("✅ Started workout builder (note: does not trigger Watch HR - use Breathe app on Watch for high-freq HR)")
        } catch {
            print("⚠️ Could not start workout session: \(error.localizedDescription)")
            // Continue anyway - we'll still try to get passive HR data
        }
    }
    
    /// Ends the current workout session and saves it to HealthKit
    func endWorkoutSession() async {
        guard let builder = workoutBuilder else { return }
        
        do {
            try await builder.endCollection(at: Date())
            let workout = try await builder.finishWorkout()
            print("✅ Ended workout session: \(workout?.duration ?? 0) seconds")
        } catch {
            print("⚠️ Could not end workout session: \(error.localizedDescription)")
        }
        
        workoutBuilder = nil
    }
    
    // MARK: - Activity Session Metrics Methods
    
    /// Fetches all heart rate samples within a given time range
    /// Uses expanded time window to catch samples that may have slightly offset timestamps
    func fetchHeartRateSamples(from startDate: Date, to endDate: Date) async -> [HeartRateSample] {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return [] }
        
        // Expand the time window to catch samples that might have offset timestamps
        // Apple Watch samples sometimes have timestamps slightly before/after the actual session
        // Using a larger window (60s) because Watch-to-iPhone sync can delay data availability
        let expandedStart = startDate.addingTimeInterval(-60) // 60 seconds before
        let expandedEnd = endDate.addingTimeInterval(60) // 60 seconds after
        
        // Use .strictStartDate to ensure we get samples that START within our window
        // This is more reliable for heart rate samples which are instantaneous
        let predicate = HKQuery.predicateForSamples(withStart: expandedStart, end: expandedEnd, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: heartRateType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error = error {
                    print("⚠️ HR fetch error: \(error.localizedDescription)")
                }
                let heartRateSamples = (samples as? [HKQuantitySample])?.map { sample in
                    HeartRateSample(
                        timestamp: sample.startDate,
                        bpm: sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
                    )
                } ?? []
                continuation.resume(returning: heartRateSamples)
            }
            healthStore.execute(query)
        }
    }
    
    /// Fetches HRV samples within a given time range
    /// Uses expanded time window to catch samples that may have slightly offset timestamps
    func fetchHRVSamples(from startDate: Date, to endDate: Date) async -> [HRVSample] {
        guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return [] }
        
        // Expand the time window to catch HRV samples which are calculated less frequently
        let expandedStart = startDate.addingTimeInterval(-60) // 1 minute before
        let expandedEnd = endDate.addingTimeInterval(60) // 1 minute after
        
        let predicate = HKQuery.predicateForSamples(withStart: expandedStart, end: expandedEnd, options: [])
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: hrvType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, _ in
                let hrvSamples = (samples as? [HKQuantitySample])?.map { sample in
                    HRVSample(
                        timestamp: sample.startDate,
                        sdnn: sample.quantity.doubleValue(for: .secondUnit(with: .milli))
                    )
                } ?? []
                continuation.resume(returning: hrvSamples)
            }
            healthStore.execute(query)
        }
    }
    
    /// Fetches active calories burned within a given time range
    func fetchCaloriesBurned(from startDate: Date, to endDate: Date) async -> Double? {
        guard let calorieType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: calorieType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                let calories = result?.sumQuantity()?.doubleValue(for: .kilocalorie())
                continuation.resume(returning: calories)
            }
            healthStore.execute(query)
        }
    }
    
    /// Fetches respiratory rate (if available) within a given time range
    func fetchRespiratoryRate(from startDate: Date, to endDate: Date) async -> Double? {
        guard let respType = HKQuantityType.quantityType(forIdentifier: .respiratoryRate) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: respType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
                let rate = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: HKUnit(from: "count/min"))
                continuation.resume(returning: rate)
            }
            healthStore.execute(query)
        }
    }
    
    /// Calculates RMSSD (Root Mean Square of Successive Differences) from heart rate samples
    /// RMSSD is a key HRV metric that reflects parasympathetic (rest & recovery) nervous system activity
    func calculateRMSSD(from heartRateSamples: [HeartRateSample]) -> Double? {
        guard heartRateSamples.count >= 3 else { return nil }
        
        // Convert heart rates to RR intervals (in ms)
        let rrIntervals = heartRateSamples.map { 60000.0 / $0.bpm }
        
        // Calculate successive differences
        var squaredDifferences: [Double] = []
        for i in 1..<rrIntervals.count {
            let diff = rrIntervals[i] - rrIntervals[i - 1]
            squaredDifferences.append(diff * diff)
        }
        
        guard !squaredDifferences.isEmpty else { return nil }
        
        // Calculate mean of squared differences
        let meanSquaredDiff = squaredDifferences.reduce(0, +) / Double(squaredDifferences.count)
        
        // Return square root (RMSSD)
        return sqrt(meanSquaredDiff)
    }
    
    /// Fetches complete activity session metrics for a given time period
    /// Includes retry logic to handle Apple Watch data sync delays
    func fetchActivitySessionMetrics(activityName: String, from startDate: Date, to endDate: Date, retryCount: Int = 0) async -> ActivitySessionMetrics {
        let dateFormatter = DateFormatter()
        dateFormatter.timeStyle = .medium
        let durationSeconds = Int(endDate.timeIntervalSince(startDate))
        let isLikelyGuidedSession = durationSeconds >= 240 // 4+ min sessions should usually have more than 1 sample when Watch workout data syncs
        
        print("📱 Fetching session metrics for '\(activityName)'")
        print("   └─ Time range: \(dateFormatter.string(from: startDate)) - \(dateFormatter.string(from: endDate))")
        
        // Fetch all data concurrently
        async let heartRateSamples = fetchHeartRateSamples(from: startDate, to: endDate)
        async let hrvSamples = fetchHRVSamples(from: startDate, to: endDate)
        async let calories = fetchCaloriesBurned(from: startDate, to: endDate)
        async let respiratoryRate = fetchRespiratoryRate(from: startDate, to: endDate)
        
        var hrSamples = await heartRateSamples
        let hrvData = await hrvSamples
        
        print("   └─ Found \(hrSamples.count) HR samples, \(hrvData.count) HRV samples")
        
        // Retry when data is missing OR suspiciously sparse.
        // Watch workout sync often arrives in chunks over several seconds.
        let hasSparseSamples = isLikelyGuidedSession && hrSamples.count <= 1
        if (hrSamples.isEmpty || hasSparseSamples) && retryCount < 8 {
            let waitTime: Double
            switch retryCount {
            case 0...1: waitTime = 2.0
            case 2...4: waitTime = 3.0
            default: waitTime = 4.0
            }
            let reason = hrSamples.isEmpty ? "No heart rate data" : "Only \(hrSamples.count) heart rate sample"
            print("⏳ \(reason), retrying in \(waitTime)s... (attempt \(retryCount + 1)/8)")
            try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
            return await fetchActivitySessionMetrics(activityName: activityName, from: startDate, to: endDate, retryCount: retryCount + 1)
        }
        
        // If still no HR samples, try to get the most recent HR reading from before/during session
        // This helps when passive HR sampling is infrequent
        if hrSamples.isEmpty {
            print("⚠️ No HR data in session window. Checking for recent HR samples...")
            let recentHR = await fetchMostRecentHeartRate(before: endDate, within: 30 * 60) // Last 30 min
            if let recent = recentHR {
                print("   └─ Found recent HR: \(Int(recent.bpm)) BPM at \(dateFormatter.string(from: recent.timestamp))")
                // Use this single sample as a reference point
                hrSamples = [recent]
            } else {
                print("   └─ No HR samples found in last 30 minutes")
                await printHRDiagnostics()
            }
        }
        
        // Calculate heart rate statistics
        let minHR = hrSamples.map { $0.bpm }.min()
        let maxHR = hrSamples.map { $0.bpm }.max()
        let avgHR = hrSamples.isEmpty ? nil : hrSamples.map { $0.bpm }.reduce(0, +) / Double(hrSamples.count)
        
        // Calculate HRV statistics
        let rmssd = calculateRMSSD(from: hrSamples)
        let avgHRV = hrvData.isEmpty ? nil : hrvData.map { $0.sdnn }.reduce(0, +) / Double(hrvData.count)
        
        let duration = durationSeconds
        
        // Log final results
        if let avg = avgHR {
            print("   └─ HR stats: avg=\(Int(avg)), min=\(Int(minHR ?? 0)), max=\(Int(maxHR ?? 0))")
        }
        if let rmssdVal = rmssd {
            print("   └─ Calculated RMSSD: \(String(format: "%.1f", rmssdVal))ms")
        }
        
        return ActivitySessionMetrics(
            activityName: activityName,
            startTime: startDate,
            endTime: endDate,
            durationSeconds: duration,
            heartRateSamples: hrSamples,
            minHeartRate: minHR,
            maxHeartRate: maxHR,
            avgHeartRate: avgHR,
            hrvSamples: hrvData,
            rmssd: rmssd,
            avgHRV: avgHRV,
            caloriesBurned: await calories,
            respiratoryRate: await respiratoryRate
        )
    }
    
    // MARK: - HR Diagnostic Helpers
    
    /// Fetches the most recent heart rate sample before a given date, within a time window
    func fetchMostRecentHeartRate(before date: Date, within seconds: TimeInterval) async -> HeartRateSample? {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return nil }
        
        let startDate = date.addingTimeInterval(-seconds)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: date, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: heartRateType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
                if let sample = samples?.first as? HKQuantitySample {
                    let hr = HeartRateSample(
                        timestamp: sample.startDate,
                        bpm: sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
                    )
                    continuation.resume(returning: hr)
                } else {
                    continuation.resume(returning: nil)
                }
            }
            self.healthStore.execute(query)
        }
    }
    
    /// Prints diagnostic information about available HR data in HealthKit
    func printHRDiagnostics() async {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }
        
        let now = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.timeStyle = .medium
        dateFormatter.dateStyle = .short
        
        print("\n🔬 HR Diagnostics:")
        
        // Check last 24 hours of HR data
        let oneDayAgo = now.addingTimeInterval(-24 * 60 * 60)
        let predicate = HKQuery.predicateForSamples(withStart: oneDayAgo, end: now, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let query = HKSampleQuery(sampleType: heartRateType, predicate: predicate, limit: 10, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error = error {
                    print("   └─ Error querying HR: \(error.localizedDescription)")
                    continuation.resume()
                    return
                }
                
                guard let hrSamples = samples as? [HKQuantitySample], !hrSamples.isEmpty else {
                    print("   └─ No HR samples found in last 24 hours!")
                    print("   └─ Possible causes:")
                    print("      • Apple Watch not worn or not connected")
                    print("      • HealthKit permissions not fully granted")
                    print("      • Watch battery depleted")
                    continuation.resume()
                    return
                }
                
                print("   └─ Found \(hrSamples.count) recent HR samples (showing last 10):")
                for sample in hrSamples.prefix(10) {
                    let hr = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
                    let source = sample.sourceRevision.source.name
                    print("      • \(Int(hr)) BPM at \(dateFormatter.string(from: sample.startDate)) from \(source)")
                }
                
                if let mostRecent = hrSamples.first {
                    let age = Int(now.timeIntervalSince(mostRecent.startDate) / 60)
                    print("   └─ Most recent HR was \(age) minutes ago")
                    if age > 10 {
                        print("   └─ ⚠️ HR data is stale. Watch may not be actively recording.")
                        print("      Tip: Start a workout on your Watch (Breathe app works well) for high-frequency HR")
                    }
                }
                
                continuation.resume()
            }
            self.healthStore.execute(query)
        }
    }
}
