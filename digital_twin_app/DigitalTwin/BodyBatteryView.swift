import SwiftUI

// MARK: - Body Battery Data Models

/// Represents a de-stress activity that can boost battery
struct DestressActivity: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let duration: Int // in minutes
    let batteryGain: Int // percentage points
    let description: String
    let color: Color
    let activityType: DestressType
    
    enum DestressType {
        case breathing
        case walking
        case meditation
        case stretching
        case hydration
        case nap
        case rest
    }
}

/// Stress type classification
enum StressType: String, Codable {
    case cognitive = "Cognitive"
    case physical = "Physical"
    case mixed = "Mixed"
    case none = "None"
    
    var icon: String {
        switch self {
        case .cognitive: return "brain.head.profile"
        case .physical: return "figure.run"
        case .mixed: return "bolt.fill"
        case .none: return "checkmark.circle"
        }
    }
    
    var color: Color {
        switch self {
        case .cognitive: return .ptInfo
        case .physical: return .ptWarning
        case .mixed: return .ptError
        case .none: return .ptSage
        }
    }
    
    /// Battery drain multiplier for this stress type
    var drainMultiplier: Double {
        switch self {
        case .cognitive: return 1.2  // Mental work drains a bit more
        case .physical: return 1.0   // Physical activity has standard drain
        case .mixed: return 1.5      // Combined stress drains most
        case .none: return 0.1       // Minimal drain when relaxed
        }
    }
}

/// Represents a 15-minute stress prediction interval
struct StressPrediction: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let predictedStressLevel: Int // 0-100
    let stressType: StressType
    let hrvValue: Double?
    let heartRate: Double?
    let batteryDrain: Int
    
    init(id: UUID = UUID(), timestamp: Date = Date(), predictedStressLevel: Int, stressType: StressType, hrvValue: Double? = nil, heartRate: Double? = nil, batteryDrain: Int) {
        self.id = id
        self.timestamp = timestamp
        self.predictedStressLevel = predictedStressLevel
        self.stressType = stressType
        self.hrvValue = hrvValue
        self.heartRate = heartRate
        self.batteryDrain = batteryDrain
    }
}

/// Recharge event (sleep, nap, rest, mindfulness)
struct RechargeEvent: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let type: RechargeType
    let duration: TimeInterval // in seconds
    let batteryGained: Int
    let sleepStages: [String]? // For sleep events
    
    init(id: UUID = UUID(), timestamp: Date = Date(), type: RechargeType, duration: TimeInterval, batteryGained: Int, sleepStages: [String]? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.type = type
        self.duration = duration
        self.batteryGained = batteryGained
        self.sleepStages = sleepStages
    }
    
    enum RechargeType: String, Codable {
        case nightSleep = "Night Sleep"
        case nap = "Nap"
        case rest = "Rest"
        case mindfulness = "Mindfulness"
        case breathing = "Breathing"
        case meditation = "Meditation"
        
        var icon: String {
            switch self {
            case .nightSleep: return "moon.zzz.fill"
            case .nap: return "powersleep"
            case .rest: return "figure.mind.and.body"
            case .mindfulness: return "brain.head.profile"
            case .breathing: return "wind"
            case .meditation: return "sparkles"
            }
        }
        
        var color: Color {
            switch self {
            case .nightSleep: return .ptTeal
            case .nap: return .ptInfo
            case .rest: return .ptSageLight
            case .mindfulness: return .ptTeal
            case .breathing: return .ptMint
            case .meditation: return .ptSage
            }
        }
    }
}

/// Represents a day's battery history with detailed tracking
struct BatteryHistoryEntry: Identifiable, Codable {
    let id: UUID
    let date: Date
    var startingBattery: Int // Battery at start of day (after sleep)
    var currentBattery: Int
    var minBattery: Int
    var maxBattery: Int
    var totalDrain: Int
    var totalRecharge: Int
    var stressPredictions: [StressPrediction]
    var rechargeEvents: [RechargeEvent]
    var isUnloggedDay: Bool
    
    init(id: UUID = UUID(), date: Date, startingBattery: Int = 100, currentBattery: Int? = nil, minBattery: Int? = nil, maxBattery: Int? = nil, totalDrain: Int = 0, totalRecharge: Int = 0, stressPredictions: [StressPrediction] = [], rechargeEvents: [RechargeEvent] = [], isUnloggedDay: Bool = false) {
        self.id = id
        self.date = date
        self.startingBattery = startingBattery
        self.currentBattery = currentBattery ?? startingBattery
        self.minBattery = minBattery ?? startingBattery
        self.maxBattery = maxBattery ?? startingBattery
        self.totalDrain = totalDrain
        self.totalRecharge = totalRecharge
        self.stressPredictions = stressPredictions
        self.rechargeEvents = rechargeEvents
        self.isUnloggedDay = isUnloggedDay
    }
}

/// Represents a completed recovery activity
struct CompletedRecoveryActivity: Identifiable, Codable {
    let id: UUID
    let activityName: String
    let completedAt: Date
    let batteryGained: Int
    var sessionMetricsId: UUID? // Optional link to saved session metrics
    
    init(id: UUID = UUID(), activityName: String, completedAt: Date = Date(), batteryGained: Int, sessionMetricsId: UUID? = nil) {
        self.id = id
        self.activityName = activityName
        self.completedAt = completedAt
        self.batteryGained = batteryGained
        self.sessionMetricsId = sessionMetricsId
    }
}

/// Detailed sleep recovery score with sub-components
struct SleepRecoveryScore: Codable {
    let date: Date
    let totalScore: Double          // Combined 0-1 score
    let quantityScore: Double       // Sleep duration score
    let continuityScore: Double     // Sleep fragmentation score
    let stageScore: Double          // Deep + REM quality score
    let physioScore: Double         // HRV/HR recovery score
    
    // Raw data
    let totalSleepMinutes: Double
    let awakeMinutes: Double
    let deepSleepMinutes: Double
    let remSleepMinutes: Double
    let overnightHRV: Double?
    let overnightHR: Double?
    
    // Computed recharge
    let rechargePoints: Int
    let sleepDebtChange: Double
    
    var totalSleepHours: Double {
        totalSleepMinutes / 60.0
    }
    
    var scoreDescription: String {
        switch totalScore {
        case 0.8...1.0: return "Excellent"
        case 0.6..<0.8: return "Good"
        case 0.4..<0.6: return "Fair"
        case 0.2..<0.4: return "Poor"
        default: return "Very Poor"
        }
    }
    
    var scoreColor: String {
        switch totalScore {
        case 0.8...1.0: return "green"
        case 0.6..<0.8: return "blue"
        case 0.4..<0.6: return "yellow"
        case 0.2..<0.4: return "orange"
        default: return "red"
        }
    }
}

/// Saved session metrics for persistence
struct SavedSessionMetrics: Identifiable, Codable {
    let id: UUID
    let activityName: String
    let startTime: Date
    let endTime: Date
    let durationSeconds: Int
    let minHeartRate: Double?
    let maxHeartRate: Double?
    let avgHeartRate: Double?
    let rmssd: Double?
    let avgHRV: Double?
    let caloriesBurned: Double?
    let relaxationScore: Int
    
    init(from metrics: ActivitySessionMetrics) {
        self.id = metrics.id
        self.activityName = metrics.activityName
        self.startTime = metrics.startTime
        self.endTime = metrics.endTime
        self.durationSeconds = metrics.durationSeconds
        self.minHeartRate = metrics.minHeartRate
        self.maxHeartRate = metrics.maxHeartRate
        self.avgHeartRate = metrics.avgHeartRate
        self.rmssd = metrics.rmssd
        self.avgHRV = metrics.avgHRV
        self.caloriesBurned = metrics.caloriesBurned
        self.relaxationScore = metrics.relaxationScore
    }
}

/// Tracks an active recovery session in progress
struct ActiveRecoverySession {
    let activity: DestressActivity
    let startTime: Date
    
    var elapsedSeconds: Int {
        Int(Date().timeIntervalSince(startTime))
    }
}

// MARK: - Body Battery Manager

@MainActor
class BodyBatteryManager: ObservableObject {
    static let shared = BodyBatteryManager()
    
    // Reference to HealthKitManager for pipeline access
    private weak var healthKitManager: HealthKitManager?
    
    // Persistence keys
    private let batteryKey = "bodyBatteryLevel"
    private let historyKey = "batteryHistory_v2"
    private let recoveryKey = "recoveryActivities"
    private let sessionMetricsKey = "savedSessionMetrics"
    private let lastLoggedDayKey = "lastLoggedDay"
    private let stressPredictionsKey = "todayStressPredictions"
    private let sleepDebtKey = "sleepDebtHours"
    private let hrvBaselineKey = "hrvBaseline"
    private let rhrBaselineKey = "rhrBaseline"
    private let lastSleepScoreKey = "lastSleepRecoveryScore"
    private let lastSleepRechargeDayKey = "lastSleepRechargeDay"
    
    // Sleep algorithm constants
    private let sleepTargetHours: Double = 7.5  // Target sleep hours
    private let maxOvernightRecharge: Int = 80  // Max recharge from sleep
    private let minBatteryCap: Int = 60         // Minimum battery cap from sleep debt
    private let sleepDebtDecayRate: Double = 0.5 // How fast debt decays when oversleeping
    
    // Stress threshold for classification
    // NOTE: Pipeline has it at 60
    // NOTE: Dhyay had this at 40 — change back if 40 is better for real-world sensitivity
    private let stressThreshold: Int = 60 // Above this = stressed (matches pipeline base)
    
    // Published properties
    @Published var currentBattery: Int = 100
    @Published var batteryHistory: [BatteryHistoryEntry] = []
    @Published var completedRecoveryActivities: [CompletedRecoveryActivity] = []
    @Published var savedSessionMetrics: [SavedSessionMetrics] = []
    @Published var todayStressPredictions: [StressPrediction] = []
    @Published var lastStressPrediction: StressPrediction?
    @Published var currentStressLevel: Int = 0
    @Published var currentStressType: StressType = .none
    
    // Sleep metrics
    @Published var sleepDebtHours: Double = 0
    @Published var lastSleepRecoveryScore: SleepRecoveryScore?
    @Published var hrvBaseline: Double = 50  // Rolling HRV baseline (ms)
    @Published var rhrBaseline: Double = 60  // Rolling RHR baseline (bpm)
    
    // Session tracking
    @Published var activeSession: ActiveRecoverySession? = nil
    
    // Timer for stress predictions (every 15 min)
    private var stressPredictionTimer: Timer?
    private var isStressTimerStarted = false
    private var lastDrainAppliedAt: Date?
    /// Dedup window must be slightly smaller than the prediction interval so
    /// that the timer tick is never skipped, but duplicate pipeline-background
    /// + pipeline-timer calls within the same interval are caught.
    private let drainDeduplicationWindowSeconds: TimeInterval = 13 * 60
    
    /// Serialisation flag — prevents re-entrant battery mutations when
    /// the pipeline timer and a background observer fire close together.
    private var isMutatingBattery = false
    
    // Fractional drain accumulator: tracks sub-integer drain between ticks
    // so that small per-interval drains (e.g. 0.37) aren't lost to rounding.
    private var fractionalDrainAccumulator: Double = 0.0
    
    let destressActivities: [DestressActivity] = [
        DestressActivity(
            name: "Deep Breathing",
            icon: "wind",
            duration: 5,
            batteryGain: 8,
            description: "5 minutes of guided breathing to calm your mind",
            color: .ptMint,
            activityType: .breathing
        ),
        DestressActivity(
            name: "Take a Walk",
            icon: "figure.walk",
            duration: 15,
            batteryGain: 12,
            description: "A short walk to refresh and recharge",
            color: .ptSage,
            activityType: .walking
        ),
        DestressActivity(
            name: "Quick Meditation",
            icon: "brain.head.profile",
            duration: 10,
            batteryGain: 10,
            description: "Clear your mind with a brief meditation",
            color: .ptInfo,
            activityType: .meditation
        ),
        DestressActivity(
            name: "Stretch Break",
            icon: "figure.flexibility",
            duration: 5,
            batteryGain: 6,
            description: "Release tension with gentle stretches",
            color: .ptWarning,
            activityType: .stretching
        ),
        DestressActivity(
            name: "Power Nap",
            icon: "powersleep",
            duration: 20,
            batteryGain: 25,
            description: "A quick nap to restore energy",
            color: .ptTeal,
            activityType: .nap
        ),
        DestressActivity(
            name: "Rest & Relax",
            icon: "figure.mind.and.body",
            duration: 10,
            batteryGain: 8,
            description: "Simply rest and let your body recover",
            color: .ptSageLight,
            activityType: .rest
        ),
        DestressActivity(
            name: "Hydrate",
            icon: "drop.fill",
            duration: 1,
            batteryGain: 3,
            description: "Drink a glass of water",
            color: .ptTeal,
            activityType: .hydration
        )
    ]
    
    private init() {
        loadData()
        rolloverToTodayIfNeeded()
    }
    
    /// Configure with HealthKitManager to enable stress pipeline.
    /// The pipeline is owned by HealthKitManager (single instance);
    /// BodyBatteryManager receives results via updateFromPipelineResult().
    func configure(with healthKitManager: HealthKitManager) {
        self.healthKitManager = healthKitManager
        rolloverToTodayIfNeeded()
        startStressPredictionTimerIfNeeded()
        debugLog("✅ BodyBatteryManager configured (pipeline owned by HealthKitManager)")
    }
    
    deinit {
        stressPredictionTimer?.invalidate()
    }
    
    // MARK: - Stress Prediction System
    
    /// Prediction interval in seconds
    /// 15 minutes balances HRV responsiveness with battery life and keeps data compact.
    /// The UI aggregates predictions into hourly averages for display.
    private let stressPredictionIntervalSeconds: TimeInterval = 15 * 60  // 15 minutes
    
    /// Starts the stress prediction timer
    private func startStressPredictionTimerIfNeeded() {
        guard !isStressTimerStarted else { return }
        guard healthKitManager != nil else { return }
        isStressTimerStarted = true

        // Predict immediately on start
        Task {
            await predictCurrentStress()
        }
        
        // Then predict at configured interval
        stressPredictionTimer = Timer.scheduledTimer(withTimeInterval: stressPredictionIntervalSeconds, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.predictCurrentStress()
            }
        }
    }
    
    // MARK: - Missed Prediction Catch-Up
    
    /// Fills in drain for stress-prediction intervals that were missed while the
    /// app was suspended in the background or after a cold re-launch on the same
    /// day.  Uses a conservative moderate stress level (35) because real sensor
    /// data is unavailable for the gap window.
    ///
    /// Called from:
    ///  • `predictCurrentStress()` — right before the live prediction runs
    ///  • `DigitalTwinApp.onChange(of: scenePhase)` — when the app returns to `.active`
    func catchUpMissedPredictions() {
        let now = Date()
        let calendar = Calendar.current
        
        // Determine the last time we actively tracked stress
        let lastActiveTime: Date
        if let lastPrediction = todayStressPredictions.last?.timestamp {
            lastActiveTime = lastPrediction
        } else if let lastDrain = lastDrainAppliedAt {
            lastActiveTime = lastDrain
        } else {
            // No reference point for today — nothing to catch up
            return
        }
        
        // Only catch up within the same calendar day; cross-day gaps are handled
        // by rolloverToTodayIfNeeded() with its own conservative estimate.
        guard calendar.isDate(lastActiveTime, inSameDayAs: now) else { return }
        
        let elapsed = now.timeIntervalSince(lastActiveTime)
        // Subtract 1 because the current live prediction tick covers the latest interval
        let missedIntervals = Int(elapsed / stressPredictionIntervalSeconds) - 1
        
        guard missedIntervals > 0 else { return }
        
        // Cap at 24 intervals (6 hours) to avoid runaway drain after very long gaps
        let intervalsToApply = min(missedIntervals, 24)
        
        // Conservative moderate stress: awake but not highly stressed
        let conservativeStressLevel = 35
        let conservativeStressType: StressType = .mixed
        
        debugLog("🔄 Catching up \(intervalsToApply) missed stress intervals (\(Int(elapsed / 60)) min gap)")
        
        var totalCatchUpDrain = 0
        for i in 0..<intervalsToApply {
            let intervalTime = lastActiveTime.addingTimeInterval(
                stressPredictionIntervalSeconds * Double(i + 1)
            )
            let drain = calculateIntervalDrain(
                stressLevel: conservativeStressLevel,
                stressType: conservativeStressType
            )
            if drain > 0 {
                applyStressDrain(drain, at: intervalTime, source: "catch-up")
                totalCatchUpDrain += drain
            }
        }
        
        if totalCatchUpDrain > 0 {
            debugLog("🔄 Catch-up complete: total drain = -\(totalCatchUpDrain)%, battery now \(currentBattery)%")
            saveData()
        }
    }
    
    // MARK: - Hourly Stress Averages
    
    /// Represents one hour's aggregated stress data for compact UI display.
    struct HourlyStressAverage: Identifiable {
        let id = UUID()
        let hour: Int              // 0-23
        let hourLabel: String      // e.g. "9 AM"
        let avgStressLevel: Int
        let dominantType: StressType
        let sampleCount: Int
        let totalDrain: Int
    }
    
    /// Aggregates `todayStressPredictions` into hourly averages for the UI.
    var hourlyStressAverages: [HourlyStressAverage] {
        let calendar = Calendar.current
        // Group predictions by hour-of-day
        let grouped = Dictionary(grouping: todayStressPredictions) { prediction in
            calendar.component(.hour, from: prediction.timestamp)
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "h a" // e.g. "9 AM"
        
        return grouped.keys.sorted().compactMap { hour in
            guard let preds = grouped[hour], !preds.isEmpty else { return nil }
            let avgLevel = preds.reduce(0) { $0 + $1.predictedStressLevel } / preds.count
            let drain = preds.reduce(0) { $0 + $1.batteryDrain }
            
            // Dominant type for the hour
            var typeCounts: [StressType: Int] = [:]
            for p in preds {
                typeCounts[p.stressType, default: 0] += 1
            }
            let dominant = typeCounts.max(by: { $0.value < $1.value })?.key ?? .none
            
            // Build hour label
            var comps = DateComponents()
            comps.hour = hour
            let refDate = calendar.date(from: comps) ?? Date()
            let label = formatter.string(from: refDate)
            
            return HourlyStressAverage(
                hour: hour,
                hourLabel: label,
                avgStressLevel: avgLevel,
                dominantType: dominant,
                sampleCount: preds.count,
                totalDrain: drain
            )
        }
    }
    
    /// Predicts current stress level using the full DC/AC stress pipeline
    /// Uses 3-stage pipeline: Activity Classification → Sleep Adjustment → DC/AC Stress Metrics
    func predictCurrentStress(hrv: Double? = nil, heartRate: Double? = nil, activeEnergy: Double? = nil) async {
        rolloverToTodayIfNeeded()
        
        // Fill in drain for any intervals missed while the app was backgrounded/killed
        catchUpMissedPredictions()

        guard let linkedHealthKitManager = healthKitManager else {
            debugLog("⌛ Skipping stress prediction — HealthKit not linked yet")
            return
        }

        // Skip stress prediction during active recovery sessions
        // These sessions have their own metrics collection and stress calculation would be inaccurate
        // because the workout session triggers high-frequency HR sampling that needs to sync from Watch
        if activeSession != nil {
            debugLog("📊 Skipping stress prediction - active recovery session in progress")
            return
        }
        
        // Skip stress prediction if Apple Watch data is stale or unavailable
        if !linkedHealthKitManager.hasFreshAppleWatchData() {
            debugLog("⌚ Skipping stress prediction — Apple Watch data is stale or unavailable")
            return
        }
        
        // Delegate to HealthKitManager's single pipeline instance.
        // This avoids duplicate pipelines and ensures consistency.
        await linkedHealthKitManager.runActivityClassificationIfNeeded()
        // If the pipeline ran, results were already pushed via updateFromPipelineResult().
        // If it was throttled (ran recently), the most recent result is still current.
        // Fall back to simplified method only when pipeline hasn't produced any result yet.
        if latestActivityType(from: linkedHealthKitManager) == nil {
            await predictCurrentStressFallback(hrv: hrv, heartRate: heartRate, activeEnergy: activeEnergy)
        }
    }
    
    /// Helper to check whether HealthKitManager has produced a pipeline result yet.
    private func latestActivityType(from hkm: HealthKitManager) -> String? {
        return hkm.latestActivityType
    }
    
    /// Fallback stress prediction when pipeline is not configured
    /// Uses simplified HRV/HR-based calculation
    private func predictCurrentStressFallback(hrv: Double?, heartRate: Double?, activeEnergy: Double?) async {
        var stressLevel: Int = 30 // Base stress level
        var stressType: StressType = .none
        
        // Factor 1: HRV (lower HRV = higher stress)
        if let hrv = hrv {
            if hrv < 20 {
                stressLevel += 40
            } else if hrv < 35 {
                stressLevel += 25
            } else if hrv < 50 {
                stressLevel += 10
            }
        }
        
        // Factor 2: Heart Rate (higher resting HR = higher stress)
        if let hr = heartRate {
            if hr > 100 {
                stressLevel += 30
                stressType = .physical
            } else if hr > 85 {
                stressLevel += 20
            } else if hr > 75 {
                stressLevel += 10
            }
        }
        
        // Factor 3: Active Energy (high energy = physical stress)
        if let energy = activeEnergy, energy > 300 {
            stressType = stressType == .none ? .physical : .mixed
            stressLevel += 15
        }
        
        // Classify stress type
        if stressLevel >= stressThreshold && stressType == .none {
            stressType = .mixed
        } else if stressLevel < stressThreshold {
            stressType = .none
        }
        
        // Cap at 100
        stressLevel = min(100, stressLevel)
        
        // Calculate battery drain
        let drain = calculateIntervalDrain(stressLevel: stressLevel, stressType: stressType)

        let fallbackTimestamp = Date()
        let shouldDrain = true  // Drain for all states including physical
        let appliedDrain: Int
        if shouldDrain && drain > 0 && shouldApplyStressDrain(
            at: fallbackTimestamp,
            source: "fallback"
        ) {
            applyStressDrain(drain, at: fallbackTimestamp, source: "fallback")
            appliedDrain = drain
        } else {
            appliedDrain = 0
        }
        
        // Create prediction
        let prediction = StressPrediction(
            predictedStressLevel: stressLevel,
            stressType: stressType,
            hrvValue: hrv,
            heartRate: heartRate,
            batteryDrain: appliedDrain
        )
        
        // Update state
        currentStressLevel = stressLevel
        currentStressType = stressType
        lastStressPrediction = prediction
        todayStressPredictions.append(prediction)
        
        // Save
        saveData()
        
        debugLog("📊 Fallback Stress: Level=\(stressLevel), Type=\(stressType.rawValue), Drain=\(drain)% (pipeline not configured)")
    }
    
    /// Calculates battery drain for one timer interval using a super-linear curve.
    ///
    /// Hourly drain targets (cognitive, multiplier 1.2):
    ///   Stress   0 → ~2.5 %/hr  (basal metabolic drain)
    ///   Stress  40 → ~5.4 %/hr  (~86 % over 16 hr → end ≈ 14 %)
    ///   Stress  60 → ~8.1 %/hr
    ///   Stress  80 → ~11.6 %/hr
    ///   Stress 100 → ~16.9 %/hr
    ///
    /// Timer fires every 15 min (1/4 hr), so per-tick values are hourly ÷ 4.
    /// Uses a fractional accumulator so sub-1 % ticks aren't lost to rounding.
    private func calculateIntervalDrain(stressLevel: Int, stressType: StressType) -> Int {
        let stressFraction = Double(stressLevel) / 100.0
        let typeMul = stressType.drainMultiplier
        
        // Super-linear curve: meaningful basal drain, moderate ramp at high stress
        let baseDrainPerHour = 2.5   // Basal drain even at zero stress (awake metabolic cost)
        let stressScale = 12.0       // Controls steepness of the curve
        let hourlyDrain = baseDrainPerHour + stressScale * pow(stressFraction, 1.5) * typeMul
        
        // Convert hourly rate to the actual timer interval (5 min = 1/12 hr)
        let intervalHours = stressPredictionIntervalSeconds / 3600.0
        let intervalDrain = hourlyDrain * intervalHours
        
        // Accumulate fractional drain; only return whole points
        fractionalDrainAccumulator += intervalDrain
        let wholeDrain = Int(fractionalDrainAccumulator)
        fractionalDrainAccumulator -= Double(wholeDrain)
        
        return wholeDrain
    }
    
    /// Applies stress drain to current battery
    private func applyStressDrain(_ drain: Int, at timestamp: Date, source: String) {
        guard !isMutatingBattery else {
            debugLog("⚠️ Skipping re-entrant battery mutation (source=\(source))")
            return
        }
        isMutatingBattery = true
        defer { isMutatingBattery = false }
        
        currentBattery = max(5, currentBattery - drain)
        lastDrainAppliedAt = timestamp
        updateTodayHistory(drain: drain)
        debugLog("🔋 Applied stress drain: -\(drain)% (source=\(source))")
    }

    private func shouldApplyStressDrain(at timestamp: Date, source: String) -> Bool {
        // Only deduplication guard — threshold/type gating removed so drain is always
        // proportional to stress level via the quadratic formula.
        if let lastApplied = lastDrainAppliedAt,
           timestamp.timeIntervalSince(lastApplied) < drainDeduplicationWindowSeconds {
            debugLog("⏭️ Skipping duplicate drain (source=\(source), delta=\(Int(timestamp.timeIntervalSince(lastApplied)))s)")
            return false
        }

        return true
    }
    
    // MARK: - Sleep & Recharge System
    
    /// Comprehensive sleep recovery algorithm
    /// Computes a Sleep Recovery Score (0-1) from 4 sub-scores and converts to recharge points
    ///
    /// Sleep-night attribution: sleep is attributed to the night you went to bed.
    /// If you sleep from 2 AM to 6 AM on March 3, the "sleep night" is March 2-3,
    /// keyed by the START-OF-DAY of the WAKE date (March 3). This way:
    ///   - 11 PM → 7 AM sleep is keyed to the wake day
    ///   - 2 AM → 6 AM sleep is also keyed to the wake day (today)
    /// The dedup guard prevents double-application for the same night.
    func processSleepRecharge(
        sleepHours: Double,
        sleepStages: [SleepStageData] = [],
        overnightHRV: Double? = nil,
        overnightHR: Double? = nil,
        sleepDate: Date = Date()
    ) {
        // Determine the "wake day" for dedup. sleepDate is the end of the sleep
        // session (latest sample endDate). We key by the calendar day of waking.
        let calendar = Calendar.current
        let wakeDay = calendar.startOfDay(for: sleepDate)

        if let lastSleepRechargeDay = UserDefaults.standard.data(forKey: lastSleepRechargeDayKey),
           let lastDay = try? JSONDecoder().decode(Date.self, from: lastSleepRechargeDay),
           calendar.isDate(lastDay, inSameDayAs: wakeDay) {
            debugLog("😴 Sleep recharge already applied for night ending \(wakeDay). Skipping duplicate.")
            return
        }

        let totalSleepMinutes = sleepHours * 60.0
        
        // Extract stage durations from sleep data
        let awakeMinutes = sleepStages.filter { $0.stage == .awake }.reduce(0.0) { $0 + $1.duration / 60.0 }
        let deepSleepMinutes = sleepStages.filter { $0.stage == .deep }.reduce(0.0) { $0 + $1.duration / 60.0 }
        let remSleepMinutes = sleepStages.filter { $0.stage == .rem }.reduce(0.0) { $0 + $1.duration / 60.0 }
        
        // Step 1: Compute 4 sub-scores
        let quantityScore = calculateQuantityScore(sleepHours: sleepHours)
        let continuityScore = calculateContinuityScore(awakeMinutes: awakeMinutes, totalSleepMinutes: totalSleepMinutes)
        let stageScore = calculateStageScore(deepMinutes: deepSleepMinutes, remMinutes: remSleepMinutes, totalSleepMinutes: totalSleepMinutes)
        let physioScore = calculatePhysioScore(overnightHRV: overnightHRV, overnightHR: overnightHR)
        
        // Combine scores with weights: 35% Quantity, 20% Continuity, 20% Stage, 25% Physio
        let totalScore = (0.35 * quantityScore) + (0.20 * continuityScore) + (0.20 * stageScore) + (0.25 * physioScore)
        
        // Step 2: Convert score to recharge points
        let rechargePoints = Int(Double(maxOvernightRecharge) * totalScore)
        
        // Step 3: Update sleep debt
        let sleepDebtChange = updateSleepDebt(sleepHours: sleepHours)
        
        // Calculate battery cap based on sleep debt
        let batteryCap = max(minBatteryCap, 100 - Int(5.0 * sleepDebtHours))
        
        // Apply recharge with debt cap
        let batteryBeforeSleep = currentBattery
        let uncappedBattery = min(100, batteryBeforeSleep + rechargePoints)
        currentBattery = min(uncappedBattery, batteryCap)
        
        let actualRecharge = currentBattery - batteryBeforeSleep
        
        // Create and save the sleep recovery score
        let sleepScore = SleepRecoveryScore(
            date: Date(),
            totalScore: totalScore,
            quantityScore: quantityScore,
            continuityScore: continuityScore,
            stageScore: stageScore,
            physioScore: physioScore,
            totalSleepMinutes: totalSleepMinutes,
            awakeMinutes: awakeMinutes,
            deepSleepMinutes: deepSleepMinutes,
            remSleepMinutes: remSleepMinutes,
            overnightHRV: overnightHRV,
            overnightHR: overnightHR,
            rechargePoints: rechargePoints,
            sleepDebtChange: sleepDebtChange
        )
        lastSleepRecoveryScore = sleepScore
        
        // Update HRV/HR baselines if we have data
        if let hrv = overnightHRV {
            updateHRVBaseline(newValue: hrv)
        }
        if let hr = overnightHR {
            updateRHRBaseline(newValue: hr)
        }
        
        // Record recharge event
        let rechargeEvent = RechargeEvent(
            type: .nightSleep,
            duration: sleepHours * 3600,
            batteryGained: max(0, actualRecharge),
            sleepStages: sleepStages.map { $0.stage.rawValue }
        )
        recordRechargeEvent(rechargeEvent)

        if let encodedWakeDay = try? JSONEncoder().encode(wakeDay) {
            UserDefaults.standard.set(encodedWakeDay, forKey: lastSleepRechargeDayKey)
        }
        
        // Save data
        saveData()
        
        debugLog("""
        😴 Sleep Recovery Analysis:
           Total Score: \(String(format: "%.2f", totalScore)) (\(sleepScore.scoreDescription))
           - Quantity: \(String(format: "%.2f", quantityScore)) (\(String(format: "%.1f", sleepHours))h)
           - Continuity: \(String(format: "%.2f", continuityScore)) (\(String(format: "%.0f", awakeMinutes))min awake)
           - Stage Quality: \(String(format: "%.2f", stageScore)) (Deep: \(String(format: "%.0f", deepSleepMinutes))min, REM: \(String(format: "%.0f", remSleepMinutes))min)
           - Physio Recovery: \(String(format: "%.2f", physioScore))
           Recharge: +\(rechargePoints)pts (actual: +\(actualRecharge)%)
           Sleep Debt: \(String(format: "%.1f", sleepDebtHours))h (cap: \(batteryCap)%)
           Battery: \(batteryBeforeSleep)% → \(currentBattery)%
        """)
    }
    
    // MARK: - Sleep Score Sub-calculations
    
    /// A) Quantity Score: Maps TST to 0-1 with soft clamp (4h→0, 7.5h→1)
    private func calculateQuantityScore(sleepHours: Double) -> Double {
        let minHours = 4.0
        let optimalHours = sleepTargetHours
        
        if sleepHours <= minHours {
            return 0.0
        } else if sleepHours >= optimalHours {
            // Slight bonus for oversleeping up to 9h, then diminishing returns
            let extraHours = sleepHours - optimalHours
            let bonus = min(0.1, extraHours * 0.05)
            return min(1.0, 1.0 + bonus)
        } else {
            // Linear interpolation between min and optimal
            return (sleepHours - minHours) / (optimalHours - minHours)
        }
    }
    
    /// B) Continuity Score: Penalizes fragmented sleep (more awake time → lower score)
    private func calculateContinuityScore(awakeMinutes: Double, totalSleepMinutes: Double) -> Double {
        guard totalSleepMinutes > 0 else { return 0.5 }
        
        // Awake percentage of total time in bed
        let awakePercentage = awakeMinutes / (totalSleepMinutes + awakeMinutes)
        
        // Score: 0% awake → 1.0, 15%+ awake → 0.0
        // Typical healthy sleep has 5-10% awake time
        let maxAwakePercent = 0.15
        let score = max(0, 1.0 - (awakePercentage / maxAwakePercent))
        
        return score
    }
    
    /// C) Stage Score: Rewards Deep + REM sleep (restorative stages)
    private func calculateStageScore(deepMinutes: Double, remMinutes: Double, totalSleepMinutes: Double) -> Double {
        guard totalSleepMinutes > 0 else { return 0.5 }
        
        // Optimal targets (for 7.5h sleep):
        // Deep: 60-90 minutes (13-20% of sleep)
        // REM: 90-120 minutes (20-25% of sleep)
        
        let optimalDeepMinutes = 75.0  // ~1.25 hours
        let optimalREMMinutes = 105.0  // ~1.75 hours
        
        // Deep sleep score (0-1): more important for physical recovery
        let deepScore = min(1.0, deepMinutes / optimalDeepMinutes)
        
        // REM score (0-1): important for cognitive recovery
        let remScore = min(1.0, remMinutes / optimalREMMinutes)
        
        // If no stage data available (older devices), use neutral score
        if deepMinutes == 0 && remMinutes == 0 {
            return 0.5
        }
        
        // Weighted combination: Deep slightly more important
        return (0.55 * deepScore) + (0.45 * remScore)
    }
    
    /// D) Physio Score: Compares overnight HRV/HR to rolling baseline
    private func calculatePhysioScore(overnightHRV: Double?, overnightHR: Double?) -> Double {
        var score = 0.5 // Neutral if no data
        var hasData = false
        
        // HRV comparison (higher than baseline = better recovery)
        if let hrv = overnightHRV, hrvBaseline > 0 {
            hasData = true
            let hrvRatio = hrv / hrvBaseline
            
            // HRV 20%+ above baseline → excellent (1.0)
            // HRV at baseline → good (0.6)
            // HRV 20%+ below baseline → poor (0.2)
            if hrvRatio >= 1.2 {
                score = 1.0
            } else if hrvRatio >= 1.0 {
                score = 0.6 + (hrvRatio - 1.0) * 2.0 // 0.6 to 1.0
            } else if hrvRatio >= 0.8 {
                score = 0.2 + (hrvRatio - 0.8) * 2.0 // 0.2 to 0.6
            } else {
                score = max(0, hrvRatio * 0.25) // Below 0.2
            }
        }
        
        // HR comparison (lower than baseline = better recovery)
        if let hr = overnightHR, rhrBaseline > 0 {
            let hrRatio = hr / rhrBaseline
            
            // HR 10%+ below baseline → excellent recovery indicator
            // HR at baseline → neutral
            // HR 10%+ above baseline → poor recovery
            var hrScore: Double
            if hrRatio <= 0.9 {
                hrScore = 1.0
            } else if hrRatio <= 1.0 {
                hrScore = 0.6 + (1.0 - hrRatio) * 4.0 // 0.6 to 1.0
            } else if hrRatio <= 1.1 {
                hrScore = 0.2 + (1.1 - hrRatio) * 4.0 // 0.2 to 0.6
            } else {
                hrScore = max(0, 0.2 - (hrRatio - 1.1) * 2.0)
            }
            
            if hasData {
                // Average HRV and HR scores
                score = (score + hrScore) / 2.0
            } else {
                score = hrScore
            }
        }
        
        return score
    }
    
    // MARK: - Sleep Debt Management
    
    /// Updates sleep debt based on last night's sleep
    /// Returns the change in debt (positive = debt increased, negative = paid off)
    private func updateSleepDebt(sleepHours: Double) -> Double {
        let deficit = sleepTargetHours - sleepHours
        var debtChange: Double
        
        if deficit > 0 {
            // Slept less than target - accumulate debt
            debtChange = deficit
            sleepDebtHours += deficit
        } else {
            // Slept more than target - pay off debt (with decay rate)
            let excess = -deficit
            let payoff = min(sleepDebtHours, excess * sleepDebtDecayRate)
            debtChange = -payoff
            sleepDebtHours = max(0, sleepDebtHours - payoff)
        }
        
        // Cap sleep debt at reasonable maximum (2 weeks of 2h deficit)
        sleepDebtHours = min(sleepDebtHours, 28.0)
        
        return debtChange
    }
    
    /// Updates HRV rolling baseline (exponential moving average)
    private func updateHRVBaseline(newValue: Double) {
        let alpha = 0.2 // Smoothing factor
        if hrvBaseline == 0 {
            hrvBaseline = newValue
        } else {
            hrvBaseline = (alpha * newValue) + ((1 - alpha) * hrvBaseline)
        }
    }
    
    /// Updates RHR rolling baseline (exponential moving average)
    private func updateRHRBaseline(newValue: Double) {
        let alpha = 0.2 // Smoothing factor
        if rhrBaseline == 0 {
            rhrBaseline = newValue
        } else {
            rhrBaseline = (alpha * newValue) + ((1 - alpha) * rhrBaseline)
        }
    }
    
    /// Gets current battery cap based on sleep debt
    var currentBatteryCap: Int {
        max(minBatteryCap, 100 - Int(5.0 * sleepDebtHours))
    }
    
    /// Sleep debt description for UI
    var sleepDebtDescription: String {
        switch sleepDebtHours {
        case 0..<2: return "Fully rested"
        case 2..<5: return "Mild sleep debt"
        case 5..<10: return "Moderate sleep debt"
        case 10..<20: return "Significant sleep debt"
        default: return "Severe sleep debt"
        }
    }
    
    /// Processes a nap recharge
    func processNapRecharge(durationMinutes: Int) {
        rolloverToTodayIfNeeded()

        // Naps: 2% per 5 minutes, capped at 30% for a 20-minute power nap
        let rechargePercent = min(30, (durationMinutes / 5) * 2)
        let recharge = min(rechargePercent, 100 - currentBattery)
        currentBattery = min(100, currentBattery + recharge)
        
        let rechargeEvent = RechargeEvent(
            type: .nap,
            duration: Double(durationMinutes * 60),
            batteryGained: recharge
        )
        
        recordRechargeEvent(rechargeEvent)
        debugLog("💤 Nap Recharge: +\(recharge)% from \(durationMinutes) min nap")
    }
    
    /// Processes a mindfulness session recharge
    func processMindfulnessRecharge(durationMinutes: Int) {
        rolloverToTodayIfNeeded()

        // Mindfulness: 1% per minute, capped at 15%
        let rechargePercent = min(15, durationMinutes)
        let recharge = min(rechargePercent, 100 - currentBattery)
        currentBattery = min(100, currentBattery + recharge)
        
        let rechargeEvent = RechargeEvent(
            type: .mindfulness,
            duration: Double(durationMinutes * 60),
            batteryGained: recharge
        )
        
        recordRechargeEvent(rechargeEvent)
        debugLog("🧘 Mindfulness Recharge: +\(recharge)% from \(durationMinutes) min session")
    }
    
    /// Records a recharge event to today's history
    private func recordRechargeEvent(_ event: RechargeEvent) {
        rolloverToTodayIfNeeded()

        let today = Calendar.current.startOfDay(for: Date())
        
        if let index = batteryHistory.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: today) }) {
            batteryHistory[index].rechargeEvents.append(event)
            batteryHistory[index].totalRecharge += event.batteryGained
            batteryHistory[index].currentBattery = currentBattery
            batteryHistory[index].maxBattery = max(batteryHistory[index].maxBattery, currentBattery)
        }
        
        saveData()
    }
    
    // MARK: - Day Management
    
    /// Checks for a new day and handles unlogged days.
    /// When a new day starts, immediately checks for overnight sleep data and
    /// applies recharge BEFORE starting drain — fixing the off-by-one timing
    /// issue where sleep recharge arrived late.
    private func rolloverToTodayIfNeeded() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        guard let lastLoggedData = UserDefaults.standard.data(forKey: lastLoggedDayKey),
              let lastLogged = try? JSONDecoder().decode(Date.self, from: lastLoggedData) else {
            // First launch — try applying sleep recharge proactively
            applySleepRechargeOnRollover()
            ensureTodayHistoryEntry(startingBattery: currentBattery)
            if let encodedDate = try? JSONEncoder().encode(today) {
                UserDefaults.standard.set(encodedDate, forKey: lastLoggedDayKey)
            }
            todayStressPredictions = todayStressPredictions.filter {
                calendar.isDate($0.timestamp, inSameDayAs: today)
            }
            lastStressPrediction = todayStressPredictions.last
            saveData()
            return
        }
        
        let lastLoggedDay = calendar.startOfDay(for: lastLogged)
        let daysBetween = calendar.dateComponents([.day], from: lastLoggedDay, to: today).day ?? 0

        if daysBetween > 1 {
            // Multiple unlogged days: use a conservative estimate instead of
            // assuming 100%. The user might have had poor sleep / high stress.
            // Use 70% as a conservative middle-ground.
            let conservativeEstimate = 70
            debugLog("⚠️ Detected \(daysBetween - 1) unlogged days. Setting battery to \(conservativeEstimate)% (conservative estimate)")
            currentBattery = conservativeEstimate

            for dayOffset in 1..<daysBetween {
                guard let unloggedDate = calendar.date(byAdding: .day, value: dayOffset, to: lastLoggedDay) else { continue }
                if !batteryHistory.contains(where: { calendar.isDate($0.date, inSameDayAs: unloggedDate) }) {
                    let unloggedEntry = BatteryHistoryEntry(
                        date: unloggedDate,
                        startingBattery: conservativeEstimate,
                        currentBattery: conservativeEstimate,
                        minBattery: conservativeEstimate,
                        maxBattery: conservativeEstimate,
                        isUnloggedDay: true
                    )
                    batteryHistory.insert(unloggedEntry, at: 0)
                }
            }
        }

        if daysBetween >= 1 {
            // New day detected — apply sleep recharge BEFORE starting today's drain.
            // This fixes the off-by-one where sleep recharge was only applied when
            // onAppear fired or background delivery pushed sleep data (often late).
            debugLog("🌅 New day started with battery at \(currentBattery)% — checking for overnight sleep")
            applySleepRechargeOnRollover()
        }

        ensureTodayHistoryEntry(startingBattery: currentBattery)
        
        if let encodedDate = try? JSONEncoder().encode(today) {
            UserDefaults.standard.set(encodedDate, forKey: lastLoggedDayKey)
        }
        
        if daysBetween > 0 {
            todayStressPredictions.removeAll()
            lastStressPrediction = nil
        } else {
            todayStressPredictions = todayStressPredictions.filter {
                calendar.isDate($0.timestamp, inSameDayAs: today)
            }
            lastStressPrediction = todayStressPredictions.last
        }
        
        saveData()
    }

    /// Proactively checks HealthKit for overnight sleep data and applies
    /// sleep recharge during day rollover. This runs synchronously on the
    /// main actor and kicks off an async fetch — the recharge is applied
    /// as soon as sleep data is available.
    private func applySleepRechargeOnRollover() {
        guard let hkm = healthKitManager else { return }

        Task { @MainActor in
            // Trigger a fresh sleep fetch so we have the latest data
            await hkm.refreshSleepData()

            guard let sleepHours = hkm.lastNightSleep, sleepHours > 0 else {
                debugLog("🌅 No overnight sleep data available yet for rollover recharge")
                return
            }

            // Determine the "sleep night" for dedup purposes:
            // Use the sleep end date (wake time) to identify the night.
            let sleepDate = hkm.sleepMetric.lastUpdated ?? Date()

            self.processSleepRecharge(
                sleepHours: sleepHours,
                sleepStages: hkm.sleepStages,
                overnightHRV: hkm.overnightHRVMetric.value,
                overnightHR: hkm.overnightRestingHeartRateMetric.value,
                sleepDate: sleepDate
            )
            debugLog("🌅 Applied rollover sleep recharge: \(String(format: "%.1f", sleepHours))h → battery now \(currentBattery)%")
        }
    }

    private func ensureTodayHistoryEntry(startingBattery: Int) {
        let today = Calendar.current.startOfDay(for: Date())
        guard !batteryHistory.contains(where: { Calendar.current.isDate($0.date, inSameDayAs: today) }) else { return }

        let todayEntry = BatteryHistoryEntry(
            date: today,
            startingBattery: startingBattery,
            currentBattery: startingBattery,
            minBattery: startingBattery,
            maxBattery: startingBattery
        )
        batteryHistory.insert(todayEntry, at: 0)
    }
    
    /// Updates today's history entry
    private func updateTodayHistory(drain: Int = 0, recharge: Int = 0) {
        rolloverToTodayIfNeeded()

        let today = Calendar.current.startOfDay(for: Date())

        if !batteryHistory.contains(where: { Calendar.current.isDate($0.date, inSameDayAs: today) }) {
            ensureTodayHistoryEntry(startingBattery: currentBattery)
        }
        
        if let index = batteryHistory.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: today) }) {
            batteryHistory[index].currentBattery = currentBattery
            batteryHistory[index].minBattery = min(batteryHistory[index].minBattery, currentBattery)
            batteryHistory[index].maxBattery = max(batteryHistory[index].maxBattery, currentBattery)
            batteryHistory[index].totalDrain += drain
            batteryHistory[index].totalRecharge += recharge
            
            if let lastPrediction = lastStressPrediction {
                batteryHistory[index].stressPredictions.append(lastPrediction)
            }
        }
        
        // Keep only last 60 days
        if batteryHistory.count > 60 {
            batteryHistory = Array(batteryHistory.prefix(60))
        }
    }
    
    // MARK: - Active Session Management
    
    /// Starts a new recovery activity session
    func startActivitySession(for activity: DestressActivity) {
        activeSession = ActiveRecoverySession(
            activity: activity,
            startTime: Date()
        )
    }
    
    /// Ends the current activity session and saves metrics
    func endActivitySession(with metrics: ActivitySessionMetrics?) {
        guard let session = activeSession else { return }
        
        var sessionMetricsId: UUID? = nil
        
        // Save metrics if available
        if let metrics = metrics {
            let savedMetrics = SavedSessionMetrics(from: metrics)
            sessionMetricsId = savedMetrics.id
            savedSessionMetrics.insert(savedMetrics, at: 0)
            
            // Keep only last 50 sessions
            if savedSessionMetrics.count > 50 {
                savedSessionMetrics = Array(savedSessionMetrics.prefix(50))
            }
        }
        
        // Add battery gain
        let gained = session.activity.batteryGain
        currentBattery = min(100, currentBattery + gained)
        HapticManager.success()
        
        // Record completed activity
        let completed = CompletedRecoveryActivity(
            activityName: session.activity.name,
            batteryGained: gained,
            sessionMetricsId: sessionMetricsId
        )
        completedRecoveryActivities.insert(completed, at: 0)
        
        // Record as recharge event
        let rechargeType: RechargeEvent.RechargeType
        switch session.activity.activityType {
        case .breathing: rechargeType = .breathing
        case .meditation: rechargeType = .meditation
        case .nap: rechargeType = .nap
        case .rest: rechargeType = .rest
        default: rechargeType = .mindfulness
        }
        
        let rechargeEvent = RechargeEvent(
            type: rechargeType,
            duration: Double(session.activity.duration * 60),
            batteryGained: gained
        )
        recordRechargeEvent(rechargeEvent)
        
        activeSession = nil
        saveData()
    }
    
    /// Cancels the current activity session without saving
    func cancelActivitySession() {
        activeSession = nil
    }
    
    // MARK: - Legacy Methods (for compatibility)
    
    /// Calculate battery drain based on stress level and duration
    func calculateBatteryDrain(stressLevel: Int, durationMinutes: Int) -> Int {
        let drainPerTenMinutes = Double(stressLevel) * 0.2
        let totalDrain = (Double(durationMinutes) / 10.0) * drainPerTenMinutes
        return Int(ceil(totalDrain))
    }
    
    /// Apply stress to battery (legacy method)
    func applyStress(stressLevel: Int, durationMinutes: Int) {
        rolloverToTodayIfNeeded()

        let drain = calculateBatteryDrain(stressLevel: stressLevel, durationMinutes: durationMinutes)
        currentBattery = max(5, currentBattery - drain)
        updateTodayHistory(drain: drain)
        saveData()
    }
    
    /// Complete a recovery activity (legacy method)
    func completeRecoveryActivity(_ activity: DestressActivity) {
        rolloverToTodayIfNeeded()

        let gained = activity.batteryGain
        currentBattery = min(100, currentBattery + gained)
        HapticManager.success()
        
        let completed = CompletedRecoveryActivity(
            activityName: activity.name,
            batteryGained: gained
        )
        completedRecoveryActivities.insert(completed, at: 0)
        
        updateTodayHistory(recharge: gained)
        saveData()
    }
    
    /// Get history for a specific date
    func historyForDate(_ date: Date) -> BatteryHistoryEntry? {
        batteryHistory.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }
    
    /// Get weekly average battery
    var weeklyAverageBattery: Int? {
        let weekEntries = batteryHistory.prefix(7)
        guard !weekEntries.isEmpty else { return nil }
        let total = weekEntries.reduce(0) { $0 + $1.currentBattery }
        return total / weekEntries.count
    }
    
    // MARK: - Insights
    
    var batteryInsight: String {
        switch currentBattery {
        case 80...100:
            return "You're fully charged! Great time for challenging tasks."
        case 60..<80:
            return "Good energy levels. Pace yourself throughout the day."
        case 40..<60:
            return "Battery getting low. Consider taking a break soon."
        case 20..<40:
            return "Low energy. Time to recharge with a recovery activity."
        default:
            return "Critical! Please take immediate steps to recover."
        }
    }
    
    var stressInsight: String {
        // Insights aligned with DC/AC pipeline stress levels:
        // 0-29 = Low, 30-49 = Moderate, 50-69 = High, 70+ = Very High
        switch currentStressLevel {
        case 0..<30:
            return "You're relaxed. DC metrics show strong vagal tone."
        case 30..<50:
            return "Moderate stress. Your nervous system is balanced."
        case 50..<70:
            return "High stress detected. Consider a recovery activity."
        default:
            return "Very high stress. Your body needs immediate recovery."
        }
    }
    
    var recommendedActivity: DestressActivity {
        if currentBattery < 30 {
            return destressActivities.first { $0.activityType == .breathing }
                ?? destressActivities[0]
        } else if currentBattery < 50 {
            return destressActivities.first { $0.activityType == .nap }
                ?? destressActivities.first { $0.activityType == .walking }
                ?? destressActivities[0]
        } else {
            return destressActivities.first { $0.activityType == .hydration }
                ?? destressActivities[0]
        }
    }
    
    /// Today's stress summary
    var todayStressSummary: (avgStress: Int, dominantType: StressType, totalDrain: Int) {
        guard !todayStressPredictions.isEmpty else {
            return (0, .none, 0)
        }
        
        let avgStress = todayStressPredictions.reduce(0) { $0 + $1.predictedStressLevel } / todayStressPredictions.count
        let totalDrain = todayStressPredictions.reduce(0) { $0 + $1.batteryDrain }
        
        // Find dominant stress type
        var typeCounts: [StressType: Int] = [:]
        for prediction in todayStressPredictions {
            typeCounts[prediction.stressType, default: 0] += 1
        }
        let dominantType = typeCounts.max(by: { $0.value < $1.value })?.key ?? .none
        
        return (avgStress, dominantType, totalDrain)
    }
    
    // MARK: - Persistence
    
    private func saveData() {
        // Small scalars stay in UserDefaults
        UserDefaults.standard.set(currentBattery, forKey: batteryKey)
        UserDefaults.standard.set(sleepDebtHours, forKey: sleepDebtKey)
        UserDefaults.standard.set(hrvBaseline, forKey: hrvBaselineKey)
        UserDefaults.standard.set(rhrBaseline, forKey: rhrBaselineKey)
        
        // Large arrays → file storage
        PersistenceManager.save(batteryHistory, filename: PersistenceManager.File.batteryHistory)
        PersistenceManager.save(completedRecoveryActivities, filename: PersistenceManager.File.recoveryActivities)
        PersistenceManager.save(savedSessionMetrics, filename: PersistenceManager.File.sessionMetrics)
        PersistenceManager.save(todayStressPredictions, filename: PersistenceManager.File.stressPredictions)
        
        if let sleepScore = lastSleepRecoveryScore {
            PersistenceManager.save(sleepScore, filename: PersistenceManager.File.sleepScore)
        }
    }
    
    private func loadData() {
        // Small scalars from UserDefaults
        currentBattery = UserDefaults.standard.integer(forKey: batteryKey)
        if currentBattery == 0 { currentBattery = 100 } // Start at 100% for new users
        
        sleepDebtHours = UserDefaults.standard.double(forKey: sleepDebtKey)
        hrvBaseline = UserDefaults.standard.double(forKey: hrvBaselineKey)
        rhrBaseline = UserDefaults.standard.double(forKey: rhrBaselineKey)
        
        // Set defaults if not previously saved
        if hrvBaseline == 0 { hrvBaseline = 50 }
        if rhrBaseline == 0 { rhrBaseline = 60 }
        
        // Large arrays from file storage
        if let history: [BatteryHistoryEntry] = PersistenceManager.load([BatteryHistoryEntry].self, filename: PersistenceManager.File.batteryHistory) {
            batteryHistory = history
        }
        
        if let activities: [CompletedRecoveryActivity] = PersistenceManager.load([CompletedRecoveryActivity].self, filename: PersistenceManager.File.recoveryActivities) {
            completedRecoveryActivities = activities
        }
        
        if let metrics: [SavedSessionMetrics] = PersistenceManager.load([SavedSessionMetrics].self, filename: PersistenceManager.File.sessionMetrics) {
            savedSessionMetrics = metrics
        }
        
        if let predictions: [StressPrediction] = PersistenceManager.load([StressPrediction].self, filename: PersistenceManager.File.stressPredictions) {
            todayStressPredictions = predictions
            lastStressPrediction = predictions.last
        }
        
        if let sleepScore: SleepRecoveryScore = PersistenceManager.load(SleepRecoveryScore.self, filename: PersistenceManager.File.sleepScore) {
            lastSleepRecoveryScore = sleepScore
        }
    }
    
    /// Retrieves saved metrics for a completed activity
    func getSessionMetrics(for activityId: UUID?) -> SavedSessionMetrics? {
        guard let id = activityId else { return nil }
        return savedSessionMetrics.first { $0.id == id }
    }
    
    /// Manually trigger stress prediction with current health data
    func updateStressPrediction(hrv: Double?, heartRate: Double?, activeEnergy: Double?) {
        Task {
            await predictCurrentStress(hrv: hrv, heartRate: heartRate, activeEnergy: activeEnergy)
        }
    }
    
    /// Update stress state directly from pipeline result (called by HealthKitManager background updates)
    /// This allows background pipeline runs to reflect in the UI without re-running the pipeline
    func updateFromPipelineResult(
        stressScore: Int,
        activityType: String,
        dc: Double?,
        ac: Double?,
        sdnn: Double?,
        adjustedThreshold: Int,
        isStressed: Bool,
        timestamp: Date
    ) {
        rolloverToTodayIfNeeded()

        guard let linkedHealthKitManager = healthKitManager,
              linkedHealthKitManager.hasFreshAppleWatchData() else {
            debugLog("⌚ Skipping background pipeline battery update — stale Apple Watch data")
            return
        }

        // Map activity type to stress type
        let stressType: StressType
        if activityType == "PHYSICAL" {
            stressType = .physical
        } else if stressScore < 0 {
            // -1 sentinel: insufficient data — don't classify as stressed
            stressType = .none
        } else if stressScore < stressThreshold {
            stressType = .none
        } else {
            stressType = .cognitive
        }
        
        // Skip drain entirely when there was insufficient data to compute stress
        guard stressScore >= 0 else {
            debugLog("⚠️ Skipping battery update — insufficient data for stress calculation")
            return
        }
        
        // Calculate potential drain (proportional via super-linear formula)
        let drain = calculateIntervalDrain(stressLevel: stressScore, stressType: stressType)
        let shouldDrain = true  // Drain for all activity types including physical
        let appliedDrain: Int
        if shouldDrain && drain > 0 && shouldApplyStressDrain(
            at: timestamp,
            source: "pipeline-background"
        ) {
            applyStressDrain(drain, at: timestamp, source: "pipeline-background")
            appliedDrain = drain
        } else {
            appliedDrain = 0
        }
        
        // Create prediction
        let prediction = StressPrediction(
            timestamp: timestamp,
            predictedStressLevel: stressScore,
            stressType: stressType,
            hrvValue: sdnn,
            heartRate: nil,
            batteryDrain: appliedDrain
        )
        
        // Update state
        currentStressLevel = stressScore
        currentStressType = stressType
        lastStressPrediction = prediction
        todayStressPredictions.append(prediction)
        
        saveData()
        
        let dcStr = dc != nil ? String(format: "%.2f", dc!) : "N/A"
        let acStr = ac != nil ? String(format: "%.2f", ac!) : "N/A"
        debugLog("📊 Background Pipeline Update: Stress=\(stressScore), Type=\(stressType.rawValue), DC=\(dcStr), AC=\(acStr)")
    }
    
    // MARK: - Baseline Export/Import
    
    /// Data structure for exporting all personalized baselines
    struct BaselineExportData: Codable {
        let exportDate: Date
        let appVersion: String
        let calibrationDays: Int
        
        // HRV/HR baselines
        let hrvBaseline: Double
        let rhrBaseline: Double
        
        // Sleep data
        let sleepDebtHours: Double
        
        // DC/AC baselines (from StressCalculator)
        let dcBaselineValues: [Double]
        let sdnnBaselineValues: [Double]
        
        // Battery history (last 30 days)
        let recentBatteryHistory: [BatteryHistoryEntry]
        
        // Metadata
        let totalStressPredictions: Int
        let averageDailySleep: Double?
    }
    
    /// Exports all baseline data as JSON
    /// Returns: JSON data that can be saved to file or shared
    func exportBaselineData() -> Data? {
        // Fetch DC/AC baselines from StressCalculator
        let dcValues = UserDefaults.standard.array(forKey: "StressCalculator_BaselineDC") as? [Double] ?? []
        let sdnnValues = UserDefaults.standard.array(forKey: "StressCalculator_BaselineSDNN") as? [Double] ?? []
        
        // Calculate average daily sleep from history
        let sleepEntries = batteryHistory.compactMap { $0.rechargeEvents.first(where: { $0.type == .nightSleep })?.duration }
        let avgSleep = sleepEntries.isEmpty ? nil : sleepEntries.reduce(0, +) / Double(sleepEntries.count) / 3600.0
        
        let exportData = BaselineExportData(
            exportDate: Date(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
            calibrationDays: dcValues.count,
            hrvBaseline: hrvBaseline,
            rhrBaseline: rhrBaseline,
            sleepDebtHours: sleepDebtHours,
            dcBaselineValues: dcValues,
            sdnnBaselineValues: sdnnValues,
            recentBatteryHistory: Array(batteryHistory.prefix(30)),
            totalStressPredictions: batteryHistory.reduce(0) { $0 + $1.stressPredictions.count },
            averageDailySleep: avgSleep
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        return try? encoder.encode(exportData)
    }
    
    /// Exports baseline data as a shareable JSON string
    func exportBaselineAsString() -> String? {
        guard let data = exportBaselineData() else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    /// Imports baseline data from JSON
    /// - Parameter jsonData: The JSON data to import
    /// - Returns: true if import was successful
    func importBaselineData(from jsonData: Data) -> Bool {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        guard let importedData = try? decoder.decode(BaselineExportData.self, from: jsonData) else {
            debugLog("❌ Failed to decode baseline data")
            return false
        }
        
        // Restore HRV/HR baselines
        hrvBaseline = importedData.hrvBaseline
        rhrBaseline = importedData.rhrBaseline
        sleepDebtHours = importedData.sleepDebtHours
        
        // Restore DC/AC baselines to UserDefaults (for StressCalculator)
        UserDefaults.standard.set(importedData.dcBaselineValues, forKey: "StressCalculator_BaselineDC")
        UserDefaults.standard.set(importedData.sdnnBaselineValues, forKey: "StressCalculator_BaselineSDNN")
        
        // Optionally restore battery history (merge or replace)
        // For now, we merge to preserve local data
        for entry in importedData.recentBatteryHistory {
            if !batteryHistory.contains(where: { Calendar.current.isDate($0.date, inSameDayAs: entry.date) }) {
                batteryHistory.append(entry)
            }
        }
        batteryHistory.sort { $0.date > $1.date }
        
        saveData()
        
        debugLog("""
        ✅ Baseline data imported successfully:
           - Calibration days: \(importedData.calibrationDays)
           - HRV baseline: \(importedData.hrvBaseline) ms
           - RHR baseline: \(importedData.rhrBaseline) bpm
           - Sleep debt: \(importedData.sleepDebtHours) hours
           - DC values: \(importedData.dcBaselineValues.count)
           - SDNN values: \(importedData.sdnnBaselineValues.count)
        """)
        
        return true
    }
    
    /// Imports baseline data from a JSON string
    func importBaselineFromString(_ jsonString: String) -> Bool {
        guard let data = jsonString.data(using: .utf8) else { return false }
        return importBaselineData(from: data)
    }
    
    /// Returns true if user has completed minimum calibration period (7 days)
    var isCalibrated: Bool {
        let dcValues = UserDefaults.standard.array(forKey: "StressCalculator_BaselineDC") as? [Double] ?? []
        return dcValues.count >= 5
    }
    
    /// Returns calibration progress (0.0 to 1.0)
    var calibrationProgress: Double {
        let dcValues = UserDefaults.standard.array(forKey: "StressCalculator_BaselineDC") as? [Double] ?? []
        let minRequired = 5  // Minimum readings for baseline
        let targetDays = 14  // Ideal calibration period
        return min(1.0, Double(dcValues.count) / Double(targetDays))
    }
    
    /// Resets all baselines (for testing or recalibration)
    func resetAllBaselines() {
        hrvBaseline = 50
        rhrBaseline = 60
        sleepDebtHours = 0
        UserDefaults.standard.removeObject(forKey: "StressCalculator_BaselineDC")
        UserDefaults.standard.removeObject(forKey: "StressCalculator_BaselineSDNN")
        saveData()
        debugLog("🔄 All baselines reset to defaults")
    }
}

// MARK: - Body Battery View

struct BodyBatteryView: View {
    @StateObject private var batteryManager = BodyBatteryManager.shared
    @ObservedObject private var activityManager = ActivityManager.shared
    @EnvironmentObject var healthKitManager: HealthKitManager

    @State private var selectedDate = Date()
    @State private var showingBreathingExercise = false
    @State private var showingCalendar = false
    @State private var showingCitations = false
    @State private var showingSettings = false
    @State private var activeSection: String = "Stress"

    private let sections = ["Stress", "Sleep", "Activity", "Insights", "Health"]

    var batteryColor: Color {
        switch batteryManager.currentBattery {
        case 70...100: return .ptSage
        case 40..<70: return .ptWarning
        case 20..<40: return .orange
        default: return .ptError
        }
    }

    var backgroundColor: LinearGradient {
        let battery = batteryManager.currentBattery
        switch battery {
        case 70...100:
            return LinearGradient(colors: [Color.ptSage.opacity(0.08), Color(.systemBackground)], startPoint: .top, endPoint: .bottom)
        case 40..<70:
            return LinearGradient(colors: [Color.ptWarning.opacity(0.08), Color(.systemBackground)], startPoint: .top, endPoint: .bottom)
        case 20..<40:
            return LinearGradient(colors: [Color.orange.opacity(0.08), Color(.systemBackground)], startPoint: .top, endPoint: .bottom)
        default:
            return LinearGradient(colors: [Color.ptError.opacity(0.1), Color(.systemBackground)], startPoint: .top, endPoint: .bottom)
        }
    }

    var body: some View {
        NavigationView {
            if !healthKitManager.isAuthorized {
                // MARK: - HealthKit Denied / Not Connected Empty State
                VStack(spacing: 24) {
                    Spacer()
                    
                    Image(systemName: "heart.slash.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.ptError.opacity(0.6))
                    
                    Text("Health Data Required")
                        .font(.title2.bold())
                    
                    Text("PhysioTwin needs access to your Apple Health data to track your body battery, stress levels, and recovery. Without this data the app cannot function.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    
                    VStack(spacing: 12) {
                        Button {
                            HapticManager.medium()
                            healthKitManager.requestAuthorization()
                        } label: {
                            Label("Connect Apple Health", systemImage: "heart.text.square.fill")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.ptTeal)
                                .cornerRadius(14)
                        }
                        .padding(.horizontal, 40)
                        
                        Button {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            Text("Open Settings to Grant Permissions")
                                .font(.subheadline)
                                .foregroundColor(.ptTeal)
                        }
                    }
                    
                    Spacer()
                }
                .navigationTitle("Body Battery")
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Health data required. Connect Apple Health or open Settings to grant permissions.")
            } else {
            ScrollView {
                VStack(spacing: 16) {
                    // Apple Watch Not Connected Banner
                    if !healthKitManager.isAppleWatchConnected {
                        HStack(spacing: 12) {
                            Image(systemName: "applewatch.slash")
                                .font(.title2)
                                .foregroundColor(.ptWarning)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Apple Watch Not Detected")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text("Stress tracking and battery drain calculations require an Apple Watch.")
                                    .font(.caption)
                                    .foregroundColor(.ptMuted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer()
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.ptWarning.opacity(0.12))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.ptWarning.opacity(0.3), lineWidth: 1)
                        )
                        .padding(.horizontal)
                    }

                    // ── HERO: Battery Figure ──
                    BatteryHumanView(
                        batteryLevel: batteryManager.currentBattery,
                        batteryColor: batteryColor
                    )
                    .padding(.horizontal)

                    // ── PILL NAVIGATION ──
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(sections, id: \.self) { section in
                                Button {
                                    HapticManager.selection()
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        activeSection = section
                                    }
                                } label: {
                                    Text(section)
                                        .font(.system(size: 13, weight: .semibold))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(
                                            Capsule()
                                                .fill(activeSection == section ? Color.ptTeal : Color(.systemGray5))
                                        )
                                        .foregroundColor(activeSection == section ? .white : .secondary)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 4)

                    // ── SECTION CONTENT (switches based on active pill) ──
                    Group {
                        switch activeSection {
                        case "Stress":
                            VStack(spacing: 16) {
                                CurrentStressCard(batteryManager: batteryManager)
                                    .padding(.horizontal)

                                StressTypeBreakdownCard(batteryManager: batteryManager)
                                    .padding(.horizontal)
                            }

                        case "Sleep":
                            VStack(spacing: 16) {
                                if let sleepScore = batteryManager.lastSleepRecoveryScore {
                                    SleepRecoveryCard(
                                        sleepScore: sleepScore,
                                        sleepDebt: batteryManager.sleepDebtHours,
                                        batteryCap: batteryManager.currentBatteryCap
                                    )
                                    .padding(.horizontal)
                                } else {
                                    VStack(spacing: 12) {
                                        Image(systemName: "moon.zzz.fill")
                                            .font(.system(size: 40))
                                            .foregroundColor(.ptMuted)
                                        Text("No sleep data yet")
                                            .font(.subheadline)
                                            .foregroundColor(.ptMuted)
                                        Text("Sleep recovery will appear after your first tracked night")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .multilineTextAlignment(.center)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(40)
                                }
                            }

                        case "Activity":
                            VStack(spacing: 16) {
                                TodayActivityImpactCard(
                                    activities: activityManager.todaysActivities,
                                    batteryManager: batteryManager
                                )
                                .padding(.horizontal)

                                RecoveryActivitiesSection(
                                    batteryManager: batteryManager,
                                    showingBreathingExercise: $showingBreathingExercise
                                )
                                .padding(.horizontal)
                            }

                        case "Insights":
                            VStack(spacing: 16) {
                                InsightCard(
                                    insight: batteryManager.batteryInsight,
                                    batteryLevel: batteryManager.currentBattery
                                )
                                .padding(.horizontal)

                                WeeklyTrendsCard(batteryManager: batteryManager)
                                    .padding(.horizontal)

                                TodayStressSummaryCard(batteryManager: batteryManager)
                                    .padding(.horizontal)

                                BatteryCalendarCard(
                                    batteryManager: batteryManager,
                                    selectedDate: $selectedDate,
                                    showingCalendar: $showingCalendar
                                )
                                .padding(.horizontal)
                            }

                        case "Health":
                            VStack(spacing: 16) {
                                CompactHealthMetricsSection(healthKitManager: healthKitManager)
                                    .padding(.horizontal)
                            }

                        default:
                            EmptyView()
                        }
                    }
                    .transition(.opacity)

                    Spacer(minLength: 40)
                }
                .padding(.top)
            }
            .background(backgroundColor.ignoresSafeArea())
            .navigationTitle("Body Battery")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 16))
                            .foregroundColor(.ptTeal)
                    }
                    .accessibilityLabel("Settings")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingCitations = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 16))
                            .foregroundColor(.ptTeal)
                    }
                    .accessibilityLabel("Sources & Citations")
                }
            }
            .refreshable {
                await healthKitManager.refreshAllData()
                batteryManager.updateStressPrediction(
                    hrv: healthKitManager.latestHRV,
                    heartRate: healthKitManager.latestHeartRate,
                    activeEnergy: healthKitManager.activeCalories
                )
                // Process sleep recharge after fresh data is available
                if let sleepHours = healthKitManager.lastNightSleep {
                    batteryManager.processSleepRecharge(
                        sleepHours: sleepHours,
                        sleepStages: healthKitManager.sleepStages,
                        overnightHRV: healthKitManager.overnightHRVMetric.value,
                        overnightHR: healthKitManager.overnightRestingHeartRateMetric.value,
                        sleepDate: healthKitManager.sleepMetric.lastUpdated ?? Date()
                    )
                }
            }
            .onAppear {
                batteryManager.configure(with: healthKitManager)
                batteryManager.updateStressPrediction(
                    hrv: healthKitManager.latestHRV,
                    heartRate: healthKitManager.latestHeartRate,
                    activeEnergy: healthKitManager.activeCalories
                )
                // Fetch sleep data asynchronously on appear, then process recharge.
                // Without this, lastNightSleep is nil on a cold launch because
                // refreshAllData() is only called on first auth or pull-to-refresh.
                Task {
                    await healthKitManager.refreshAllData()
                    if let sleepHours = healthKitManager.lastNightSleep {
                        batteryManager.processSleepRecharge(
                            sleepHours: sleepHours,
                            sleepStages: healthKitManager.sleepStages,
                            overnightHRV: healthKitManager.overnightHRVMetric.value,
                            overnightHR: healthKitManager.overnightRestingHeartRateMetric.value,
                            sleepDate: healthKitManager.sleepMetric.lastUpdated ?? Date()
                        )
                    }
                }
            }
            // Also react to sleep data arriving via background delivery
            .onChange(of: healthKitManager.lastNightSleep) { _, newSleep in
                if let sleepHours = newSleep {
                    batteryManager.processSleepRecharge(
                        sleepHours: sleepHours,
                        sleepStages: healthKitManager.sleepStages,
                        overnightHRV: healthKitManager.overnightHRVMetric.value,
                        overnightHR: healthKitManager.overnightRestingHeartRateMetric.value,
                        sleepDate: healthKitManager.sleepMetric.lastUpdated ?? Date()
                    )
                }
            }
            } // end else (authorized)
        }
        .sheet(isPresented: $showingBreathingExercise) {
            BreathingExerciseView(batteryManager: batteryManager)
        }
        .sheet(isPresented: $showingCitations) {
            CitationsView()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environmentObject(healthKitManager)
        }
    }
}

// MARK: - Stress Type Breakdown Card
struct StressTypeBreakdownCard: View {
    @ObservedObject var batteryManager: BodyBatteryManager

    private var cognitiveEpisodes: [StressPrediction] {
        batteryManager.todayStressPredictions.filter { $0.stressType == .cognitive && $0.predictedStressLevel >= 30 }
    }

    private var physicalEpisodes: [StressPrediction] {
        batteryManager.todayStressPredictions.filter { $0.stressType == .physical && $0.predictedStressLevel >= 30 }
    }

    private var cognitiveAvg: Int {
        guard !cognitiveEpisodes.isEmpty else { return 0 }
        return cognitiveEpisodes.reduce(0) { $0 + $1.predictedStressLevel } / cognitiveEpisodes.count
    }

    private var physicalAvg: Int {
        guard !physicalEpisodes.isEmpty else { return 0 }
        return physicalEpisodes.reduce(0) { $0 + $1.predictedStressLevel } / physicalEpisodes.count
    }

    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.pie.fill")
                    .font(.title2)
                    .foregroundColor(.ptTeal)
                Text("Stress Breakdown")
                    .font(.headline)
                Spacer()
                Text("Today")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 16) {
                // Cognitive
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "brain.head.profile")
                            .font(.subheadline)
                            .foregroundColor(.ptInfo)
                        Text("Cognitive")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    Text("\(cognitiveEpisodes.count) episode\(cognitiveEpisodes.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.ptMuted)
                    if !cognitiveEpisodes.isEmpty {
                        Text("Avg \(cognitiveAvg)")
                            .font(.caption)
                            .foregroundColor(.ptInfo)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.ptInfo.opacity(0.08))
                .cornerRadius(12)

                // Physical
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "figure.run")
                            .font(.subheadline)
                            .foregroundColor(.ptWarning)
                        Text("Physical")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    Text("\(physicalEpisodes.count) episode\(physicalEpisodes.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.ptMuted)
                    if !physicalEpisodes.isEmpty {
                        Text("Avg \(physicalAvg)")
                            .font(.caption)
                            .foregroundColor(.ptWarning)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.ptWarning.opacity(0.08))
                .cornerRadius(12)
            }

            // Hourly detected episodes (aggregated)
            let allEpisodes = (cognitiveEpisodes + physicalEpisodes)
                .sorted { $0.timestamp < $1.timestamp }

            if !allEpisodes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("HOURLY BREAKDOWN")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    let hourlyGroups = Dictionary(grouping: allEpisodes) { episode in
                        Calendar.current.component(.hour, from: episode.timestamp)
                    }

                    ForEach(hourlyGroups.keys.sorted(), id: \.self) { hour in
                        let episodes = hourlyGroups[hour, default: []]
                        let avgLevel = episodes.isEmpty ? 0 : episodes.reduce(0) { $0 + $1.predictedStressLevel } / episodes.count
                        // Dominant type for the hour
                        let typeCounts = Dictionary(grouping: episodes, by: { $0.stressType })
                        let dominant = typeCounts.max(by: { $0.value.count < $1.value.count })?.key ?? .none
                        let hourLabel: String = {
                            let f = DateFormatter()
                            f.dateFormat = "h a"
                            var c = DateComponents()
                            c.hour = hour
                            return f.string(from: Calendar.current.date(from: c) ?? Date())
                        }()

                        HStack(spacing: 10) {
                            Image(systemName: dominant.icon)
                                .font(.caption)
                                .foregroundColor(dominant.color)
                                .frame(width: 22, height: 22)
                                .background(dominant.color.opacity(0.12))
                                .cornerRadius(6)

                            Text(dominant.rawValue)
                                .font(.caption)
                                .foregroundColor(dominant.color)
                                .fontWeight(.medium)

                            Spacer()

                            Text("Avg \(avgLevel)")
                                .font(.caption2)
                                .foregroundColor(.secondary)

                            Text(hourLabel)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                        }
                    }
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.ptSage)
                    Text("No significant stress episodes detected today")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Compact Health Metrics Section
struct CompactHealthMetricsSection: View {
    @ObservedObject var healthKitManager: HealthKitManager

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "heart.text.square.fill")
                    .font(.title2)
                    .foregroundColor(.ptTeal)
                Text("Health Metrics")
                    .font(.headline)
                Spacer()
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                CompactMetricTile(
                    icon: "heart",
                    iconColor: .ptError,
                    title: "Resting HR",
                    value: healthKitManager.restingHeartRateMetric.value != nil
                        ? String(format: "%.0f", healthKitManager.restingHeartRateMetric.value!)
                        : "--",
                    unit: "BPM",
                    lastMeasured: healthKitManager.restingHeartRateMetric.formattedTimestamp
                )

                CompactMetricTile(
                    icon: "heart.fill",
                    iconColor: .ptError,
                    title: "Heart Rate",
                    value: healthKitManager.heartRateMetric.value != nil
                        ? String(format: "%.0f", healthKitManager.heartRateMetric.value!)
                        : "--",
                    unit: "BPM",
                    lastMeasured: healthKitManager.heartRateMetric.formattedTimestamp
                )

                CompactMetricTile(
                    icon: "flame.fill",
                    iconColor: .ptWarning,
                    title: "Active Energy",
                    value: healthKitManager.activeEnergyMetric.value != nil
                        ? String(format: "%.0f", healthKitManager.activeEnergyMetric.value!)
                        : "--",
                    unit: "kcal",
                    lastMeasured: healthKitManager.activeEnergyMetric.formattedTimestamp
                )

                CompactMetricTile(
                    icon: "waveform.path.ecg",
                    iconColor: .ptInfo,
                    title: "HRV (SDNN)",
                    value: healthKitManager.hrvMetric.value != nil
                        ? String(format: "%.0f", healthKitManager.hrvMetric.value!)
                        : "--",
                    unit: "ms",
                    lastMeasured: healthKitManager.hrvMetric.formattedTimestamp
                )

                CompactMetricTile(
                    icon: "lungs.fill",
                    iconColor: .ptTeal,
                    title: "Resp. Rate",
                    value: healthKitManager.respiratoryRateMetric.value != nil
                        ? String(format: "%.1f", healthKitManager.respiratoryRateMetric.value!)
                        : "--",
                    unit: "br/min",
                    lastMeasured: healthKitManager.respiratoryRateMetric.formattedTimestamp
                )
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Compact Metric Tile
struct CompactMetricTile: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    let unit: String
    let lastMeasured: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(iconColor)
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Text(unit)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 3) {
                Image(systemName: "clock")
                    .font(.system(size: 9))
                Text(lastMeasured)
                    .font(.system(size: 10))
                    .lineLimit(1)
            }
            .foregroundColor(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(value) \(unit), last measured \(lastMeasured)")
    }
}

// MARK: - Current Stress Card
struct CurrentStressCard: View {
    @ObservedObject var batteryManager: BodyBatteryManager
    
    var stressColor: Color {
        switch batteryManager.currentStressLevel {
        case 0..<30: return .ptSage
        case 30..<50: return .ptInfo
        case 50..<70: return .ptWarning
        default: return .ptError
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: batteryManager.currentStressType.icon)
                    .font(.title2)
                    .foregroundColor(batteryManager.currentStressType.color)
                
                Text("Current Stress")
                    .font(.headline)
                
                Spacer()
                
                Text(batteryManager.currentStressType.rawValue)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(batteryManager.currentStressType.color)
                    .cornerRadius(8)
            }
            
            HStack(alignment: .bottom, spacing: 8) {
                Text("\(batteryManager.currentStressLevel)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(stressColor)
                
                Text("/ 100")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 8)
                
                Spacer()
                
                // Stress gauge
                StressGauge(level: batteryManager.currentStressLevel)
                    .frame(width: 80, height: 80)
            }
            
            Text(batteryManager.stressInsight)
                .font(.caption)
                .foregroundColor(.secondary)
            
            if let lastPrediction = batteryManager.lastStressPrediction {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                    Text("Last checked: \(formatTime(lastPrediction.timestamp))")
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Current stress level \(batteryManager.currentStressLevel) out of 100")
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Stress Gauge
struct StressGauge: View {
    let level: Int
    
    var color: Color {
        switch level {
        case 0..<30: return .ptSage
        case 30..<50: return .ptInfo
        case 50..<70: return .ptWarning
        default: return .ptError
        }
    }
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(.systemGray5), lineWidth: 8)
            
            Circle()
                .trim(from: 0, to: CGFloat(level) / 100.0)
                .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
            
            VStack(spacing: 0) {
                Image(systemName: level >= 40 ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(color)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Stress gauge, level \(level) out of 100")
    }
}

// MARK: - Today's Stress Summary Card
struct TodayStressSummaryCard: View {
    @ObservedObject var batteryManager: BodyBatteryManager
    
    var summary: (avgStress: Int, dominantType: StressType, totalDrain: Int) {
        batteryManager.todayStressSummary
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.title2)
                    .foregroundColor(.ptTeal)
                
                Text("Today's Summary")
                    .font(.headline)
                
                Spacer()
            }
            
            HStack(spacing: 20) {
                // Average Stress
                VStack(alignment: .leading, spacing: 4) {
                    Text("Avg Stress")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(summary.avgStress)")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                Divider().frame(height: 40)
                
                // Dominant Type
                VStack(alignment: .leading, spacing: 4) {
                    Text("Main Type")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(spacing: 4) {
                        Image(systemName: summary.dominantType.icon)
                            .foregroundColor(summary.dominantType.color)
                        Text(summary.dominantType.rawValue)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                }
                
                Divider().frame(height: 40)
                
                // Total Drain
                VStack(alignment: .leading, spacing: 4) {
                    Text("Drained")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("-\(summary.totalDrain)%")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.ptError)
                }

                Spacer()
            }

            // Stress timeline (simplified)
            if !batteryManager.todayStressPredictions.isEmpty {
                StressTimelineView(predictions: batteryManager.todayStressPredictions)
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Stress Timeline View (Hourly Averages)
struct StressTimelineView: View {
    let predictions: [StressPrediction]
    
    /// Aggregate raw predictions into hourly buckets for a compact display.
    private var hourlyBuckets: [(hour: String, avgLevel: Int)] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: predictions) { p in
            calendar.component(.hour, from: p.timestamp)
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "ha" // e.g. "9AM"
        
        return grouped.keys.sorted().compactMap { hour in
            guard let preds = grouped[hour], !preds.isEmpty else { return nil }
            let avg = preds.reduce(0) { $0 + $1.predictedStressLevel } / preds.count
            var comps = DateComponents()
            comps.hour = hour
            let refDate = calendar.date(from: comps) ?? Date()
            return (hour: formatter.string(from: refDate), avgLevel: avg)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("HOURLY STRESS")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            GeometryReader { geometry in
                HStack(spacing: 4) {
                    ForEach(Array(hourlyBuckets.enumerated()), id: \.offset) { _, bucket in
                        VStack(spacing: 2) {
                            Rectangle()
                                .fill(colorForStress(bucket.avgLevel))
                                .frame(height: heightForStress(bucket.avgLevel, maxHeight: 30))
                                .cornerRadius(3)
                            Text(bucket.hour)
                                .font(.system(size: 8))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 44)
        }
    }
    
    private func colorForStress(_ level: Int) -> Color {
        switch level {
        case 0..<20: return .ptSage
        case 20..<40: return .ptInfo
        case 40..<60: return .ptWarning
        case 60..<80: return .orange
        default: return .ptError
        }
    }
    
    private func heightForStress(_ level: Int, maxHeight: CGFloat) -> CGFloat {
        max(4, CGFloat(level) / 100.0 * maxHeight)
    }
}

// MARK: - Sleep Recovery Card
struct SleepRecoveryCard: View {
    let sleepScore: SleepRecoveryScore
    let sleepDebt: Double
    let batteryCap: Int
    
    var scoreColor: Color {
        switch sleepScore.totalScore {
        case 0.8...1.0: return .ptSage
        case 0.6..<0.8: return .ptInfo
        case 0.4..<0.6: return .ptWarning
        case 0.2..<0.4: return .orange
        default: return .ptError
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "moon.zzz.fill")
                    .font(.title2)
                    .foregroundColor(.ptTeal)
                
                Text("Sleep Recovery")
                    .font(.headline)
                
                Spacer()
                
                // Overall score badge
                Text(sleepScore.scoreDescription)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(scoreColor)
                    .cornerRadius(8)
            }
            
            // Main score display
            HStack(alignment: .bottom, spacing: 8) {
                Text("\(Int(sleepScore.totalScore * 100))")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(scoreColor)
                
                Text("/ 100")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 8)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("+\(sleepScore.rechargePoints)%")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.ptSage)
                    Text("recharged")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Sub-scores breakdown
            VStack(spacing: 12) {
                SleepScoreRow(
                    icon: "clock.fill",
                    title: "Duration",
                    score: sleepScore.quantityScore,
                    detail: String(format: "%.1fh sleep", sleepScore.totalSleepHours),
                    color: .ptInfo
                )

                SleepScoreRow(
                    icon: "waveform.path",
                    title: "Continuity",
                    score: sleepScore.continuityScore,
                    detail: String(format: "%.0fmin awake", sleepScore.awakeMinutes),
                    color: .ptTeal
                )

                SleepScoreRow(
                    icon: "brain.head.profile",
                    title: "Sleep Stages",
                    score: sleepScore.stageScore,
                    detail: "Deep: \(Int(sleepScore.deepSleepMinutes))m, REM: \(Int(sleepScore.remSleepMinutes))m",
                    color: .ptSage
                )

                SleepScoreRow(
                    icon: "heart.fill",
                    title: "Physio Recovery",
                    score: sleepScore.physioScore,
                    detail: sleepScore.overnightHRV != nil ? "HRV: \(Int(sleepScore.overnightHRV!))ms" : "No HRV data",
                    color: .ptError
                )
            }
            
            Divider()
            
            // Sleep debt info
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sleep Debt")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1fh", sleepDebt))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(sleepDebt > 5 ? .ptWarning : .primary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Battery Cap")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(batteryCap)%")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(batteryCap < 80 ? .ptWarning : .primary)
                }
            }
            
            if sleepDebt > 2 {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.ptWarning)
                    Text("Sleep debt is limiting your max battery capacity")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Sleep recovery card")
    }
}

// MARK: - Sleep Score Row
struct SleepScoreRow: View {
    let icon: String
    let title: String
    let score: Double
    let detail: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
                .frame(width: 20)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 6)
                        .cornerRadius(3)
                    
                    Rectangle()
                        .fill(color)
                        .frame(width: geometry.size.width * CGFloat(score), height: 6)
                        .cornerRadius(3)
                }
            }
            .frame(height: 6)
            
            Text(String(format: "%.0f%%", score * 100))
                .font(.caption)
                .fontWeight(.medium)
                .frame(width: 35, alignment: .trailing)
            
            Text(detail)
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(width: 90, alignment: .trailing)
                .lineLimit(1)
        }
    }
}

// MARK: - Battery Human View

struct BatteryHumanView: View {
    let batteryLevel: Int
    let batteryColor: Color
    
    @State private var pulseAnimation = false
    @State private var fillAnimation: CGFloat = 0
    
    var displayedBattery: Int { batteryLevel }
    var displayColor: Color { batteryColor }
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                // Background glow
                Circle()
                    .fill(displayColor.opacity(0.2))
                    .frame(width: 220, height: 220)
                    .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: pulseAnimation)
                
                // Human figure outline
                ZStack {
                    // Body silhouette background
                    Image(systemName: "figure.stand")
                        .font(.system(size: 120, weight: .thin))
                        .foregroundColor(Color(.systemGray4))
                    
                    // Filled portion based on battery
                    Image(systemName: "figure.stand")
                        .font(.system(size: 120, weight: .regular))
                        .foregroundColor(displayColor)
                        .mask(
                            VStack(spacing: 0) {
                                Spacer()
                                Rectangle()
                                    .frame(height: 150 * fillAnimation)
                            }
                            .frame(height: 150)
                        )
                }
                
                // Battery percentage ring
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 12)
                    .frame(width: 200, height: 200)
                
                Circle()
                    .trim(from: 0, to: CGFloat(displayedBattery) / 100.0)
                    .stroke(
                        displayColor,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1), value: displayedBattery)
            }
            .onAppear {
                pulseAnimation = true
                withAnimation(.easeInOut(duration: 1.5)) {
                    fillAnimation = CGFloat(batteryLevel) / 100.0
                }
            }
            .onChange(of: batteryLevel) { oldValue, newValue in
                withAnimation(.easeInOut(duration: 0.8)) {
                    fillAnimation = CGFloat(newValue) / 100.0
                }
            }
            
            // Battery percentage text
            VStack(spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(displayedBattery)")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundColor(displayColor)
                    Text("%")
                        .font(.title)
                        .foregroundColor(.secondary)
                }
                
                Text("Body Battery")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 20)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Body Battery level \(displayedBattery) percent")
    }
}

// MARK: - Insight Card

struct InsightCard: View {
    let insight: String
    let batteryLevel: Int
    
    var iconName: String {
        switch batteryLevel {
        case 70...100: return "bolt.fill"
        case 40..<70: return "battery.75"
        case 20..<40: return "battery.25"
        default: return "battery.0"
        }
    }
    
    var iconColor: Color {
        switch batteryLevel {
        case 70...100: return .ptSage
        case 40..<70: return .ptWarning
        case 20..<40: return .orange
        default: return .ptError
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: iconName)
                .font(.title)
                .foregroundColor(iconColor)
                .frame(width: 50, height: 50)
                .background(iconColor.opacity(0.15))
                .cornerRadius(12)
            
            Text(insight)
                .font(.subheadline)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Weekly Trends Card

struct WeeklyTrendsCard: View {
    @ObservedObject var batteryManager: BodyBatteryManager
    @Environment(\.colorScheme) private var colorScheme

    private let calendar = Calendar.current

    private var weekData: [(day: String, battery: Int?, stressCount: Int)] {
        let today = Date()
        return (0..<7).reversed().map { offset in
            let date = calendar.date(byAdding: .day, value: -offset, to: today)!
            let dayName = offset == 0 ? "Today" : {
                let fmt = DateFormatter()
                fmt.dateFormat = "EEE"
                return fmt.string(from: date)
            }()
            let entry = batteryManager.historyForDate(date)
            return (day: dayName, battery: entry?.currentBattery, stressCount: entry?.stressPredictions.count ?? 0)
        }
    }

    private var avgBattery: Int {
        let levels = weekData.compactMap(\.battery)
        guard !levels.isEmpty else { return 0 }
        return levels.reduce(0, +) / levels.count
    }

    private var totalStress: Int {
        weekData.reduce(0) { $0 + $1.stressCount }
    }

    private var trendText: String {
        let levels = weekData.compactMap(\.battery)
        guard levels.count >= 2 else { return "Not enough data yet" }
        let recent = levels.suffix(3).reduce(0, +) / min(3, levels.count)
        let earlier = levels.prefix(3).reduce(0, +) / min(3, levels.count)
        let diff = recent - earlier
        if diff > 5 { return "Your energy is trending up this week" }
        if diff < -5 { return "Your energy has been declining — prioritize recovery" }
        return "Your energy levels have been stable"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.title2)
                    .foregroundColor(.ptTeal)
                Text("Weekly Trends")
                    .font(.headline)
                Spacer()
            }

            // Mini bar chart
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(Array(weekData.enumerated()), id: \.offset) { _, item in
                    VStack(spacing: 4) {
                        if let level = item.battery {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(barColor(for: level))
                                .frame(width: 28, height: max(8, CGFloat(level) / 100.0 * 60))
                        } else {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.ptBorder)
                                .frame(width: 28, height: 8)
                        }
                        Text(item.day)
                            .font(.system(size: 9))
                            .foregroundColor(.ptMuted)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80, alignment: .bottom)

            // Trend insight
            HStack(spacing: 10) {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.ptWarning)
                    .font(.caption)
                Text(trendText)
                    .font(.caption)
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.9) : .ptBody)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(colorScheme == .dark ? Color(.tertiarySystemBackground) : Color.ptSurface)
            .cornerRadius(10)

            // Stats row
            HStack(spacing: 0) {
                VStack(spacing: 2) {
                    Text("\(avgBattery)%")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.ptTeal)
                    Text("Avg Battery")
                        .font(.caption2)
                        .foregroundColor(.ptMuted)
                }
                .frame(maxWidth: .infinity)

                Divider()
                    .frame(height: 30)

                VStack(spacing: 2) {
                    Text("\(totalStress)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.ptWarning)
                    Text("Stress Events")
                        .font(.caption2)
                        .foregroundColor(.ptMuted)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }

    private func barColor(for level: Int) -> Color {
        switch level {
        case 70...100: return .ptSage
        case 40..<70: return .ptWarning
        case 20..<40: return .orange
        default: return .ptError
        }
    }
}

// MARK: - Battery Calendar Card

struct BatteryCalendarCard: View {
    @ObservedObject var batteryManager: BodyBatteryManager
    @Binding var selectedDate: Date
    @Binding var showingCalendar: Bool
    
    let calendar = Calendar.current
    
    var weekDates: [Date] {
        let today = Date()
        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today)
        }.reversed()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.ptTeal)
                Text("Battery History")
                    .font(.headline)
                Spacer()

                Button(action: { showingCalendar.toggle() }) {
                    Text(showingCalendar ? "Week" : "Month")
                        .font(.caption)
                        .foregroundColor(.ptTeal)
                }
            }
            
            if showingCalendar {
                // Month Calendar View
                CalendarGridView(
                    batteryManager: batteryManager,
                    selectedDate: $selectedDate
                )
            } else {
                // Week View
                HStack(spacing: 8) {
                    ForEach(weekDates, id: \.self) { date in
                        DayBatteryView(
                            date: date,
                            entry: batteryManager.historyForDate(date),
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate)
                        )
                        .onTapGesture {
                            selectedDate = date
                        }
                    }
                }
            }
            
            // Selected day details
            if let entry = batteryManager.historyForDate(selectedDate) {
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(formattedDate(selectedDate))
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack(spacing: 20) {
                        StatItem(title: "Battery", value: "\(entry.currentBattery)%", icon: "battery.75", color: batteryColor(for: entry.currentBattery))
                        StatItem(title: "Stress", value: "\(entry.stressPredictions.count)", icon: "exclamationmark.triangle", color: .ptWarning)
                        StatItem(title: "Recovery", value: "\(entry.rechargeEvents.count)", icon: "heart.fill", color: .ptSage)
                    }
                    
                    if entry.minBattery != entry.maxBattery {
                        Text("Range: \(entry.minBattery)% - \(entry.maxBattery)%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                Text("No data for \(formattedDate(selectedDate))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
    
    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = calendar.isDateInToday(date) ? "'Today'" : "EEEE, MMM d"
        return formatter.string(from: date)
    }
    
    func batteryColor(for level: Int) -> Color {
        switch level {
        case 70...100: return .ptSage
        case 40..<70: return .ptWarning
        case 20..<40: return .orange
        default: return .ptError
        }
    }
}

struct DayBatteryView: View {
    let date: Date
    let entry: BatteryHistoryEntry?
    let isSelected: Bool
    
    var dayAbbrev: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return String(formatter.string(from: date).prefix(1))
    }
    
    var batteryColor: Color {
        guard let level = entry?.currentBattery else { return .gray }
        switch level {
        case 70...100: return .ptSage
        case 40..<70: return .ptWarning
        case 20..<40: return .orange
        default: return .ptError
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            Text(dayAbbrev)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            ZStack {
                Circle()
                    .fill(batteryColor.opacity(0.2))
                    .frame(width: 36, height: 36)
                
                if let level = entry?.currentBattery {
                    Circle()
                        .trim(from: 0, to: CGFloat(level) / 100.0)
                        .stroke(batteryColor, lineWidth: 3)
                        .frame(width: 32, height: 32)
                        .rotationEffect(.degrees(-90))
                    
                    Text("\(level)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(batteryColor)
                } else {
                    Text("--")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(isSelected ? Color(.systemGray5) : Color.clear)
        .cornerRadius(10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(dayAbbrev), battery level \(entry.map { "\($0.currentBattery) percent" } ?? "no data")\(isSelected ? ", selected" : "")")
    }
}

struct StatItem: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Calendar Grid View

struct CalendarGridView: View {
    @ObservedObject var batteryManager: BodyBatteryManager
    @Binding var selectedDate: Date
    
    let calendar = Calendar.current
    @State private var currentMonth = Date()
    
    var monthDates: [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth),
              let monthFirstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start) else {
            return []
        }
        
        var dates: [Date] = []
        var currentDate = monthFirstWeek.start
        
        while dates.count < 42 { // 6 weeks max
            dates.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return dates
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Month Navigation
            HStack {
                Button(action: { moveMonth(-1) }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.ptTeal)
                }

                Spacer()

                Text(monthYearString)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Button(action: { moveMonth(1) }) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.ptTeal)
                }
            }
            
            // Day headers
            HStack(spacing: 0) {
                ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { day in
                    Text(day)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Calendar grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(monthDates, id: \.self) { date in
                    CalendarDayCell(
                        date: date,
                        currentMonth: currentMonth,
                        entry: batteryManager.historyForDate(date),
                        isSelected: calendar.isDate(date, inSameDayAs: selectedDate)
                    )
                    .onTapGesture {
                        selectedDate = date
                    }
                }
            }
        }
    }
    
    var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentMonth)
    }
    
    func moveMonth(_ offset: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: offset, to: currentMonth) {
            currentMonth = newMonth
        }
    }
}

struct CalendarDayCell: View {
    let date: Date
    let currentMonth: Date
    let entry: BatteryHistoryEntry?
    let isSelected: Bool
    
    let calendar = Calendar.current
    
    var isCurrentMonth: Bool {
        calendar.isDate(date, equalTo: currentMonth, toGranularity: .month)
    }
    
    var batteryColor: Color {
        guard let level = entry?.currentBattery else { return .clear }
        switch level {
        case 70...100: return .ptSage
        case 40..<70: return .ptWarning
        case 20..<40: return .orange
        default: return .ptError
        }
    }

    var body: some View {
        ZStack {
            if isSelected {
                Circle()
                    .fill(Color.ptTeal.opacity(0.2))
            }
            
            if entry != nil {
                Circle()
                    .fill(batteryColor.opacity(0.3))
                    .frame(width: 28, height: 28)
            }
            
            Text("\(calendar.component(.day, from: date))")
                .font(.caption)
                .foregroundColor(isCurrentMonth ? .primary : .secondary.opacity(0.5))
        }
        .frame(height: 32)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Day \(calendar.component(.day, from: date))\(entry != nil ? ", battery \(entry!.currentBattery) percent" : "")\(isSelected ? ", selected" : "")")
    }
}

// MARK: - Recovery Activities Section

struct RecoveryActivitiesSection: View {
    @ObservedObject var batteryManager: BodyBatteryManager
    @Binding var showingBreathingExercise: Bool
    @State private var showingWalkSession = false
    @State private var showingMeditationSession = false
    @State private var showingStretchSession = false
    @State private var showingNapSession = false
    @State private var showingRestSession = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.ptSage)
                Text("Recharge Your Battery")
                    .font(.headline)
                Spacer()
            }
            
            Text("Complete these activities to boost your energy")
                .font(.caption)
                .foregroundColor(.secondary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(batteryManager.destressActivities) { activity in
                        RecoveryActivityCard(
                            activity: activity,
                            onTap: {
                                switch activity.activityType {
                                case .breathing:
                                    showingBreathingExercise = true
                                case .walking:
                                    showingWalkSession = true
                                case .meditation:
                                    showingMeditationSession = true
                                case .stretching:
                                    showingStretchSession = true
                                case .nap:
                                    showingNapSession = true
                                case .rest:
                                    showingRestSession = true
                                case .hydration:
                                    // Hydrate is quick - just mark as complete
                                    batteryManager.completeRecoveryActivity(activity)
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 4)
            }
            
            // Recently completed
            if !batteryManager.completedRecoveryActivities.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent Recovery")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ForEach(batteryManager.completedRecoveryActivities.prefix(3)) { activity in
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.ptSage)
                            Text(activity.activityName)
                                .font(.caption)
                            Spacer()

                            if activity.sessionMetricsId != nil {
                                Image(systemName: "heart.text.square")
                                    .foregroundColor(.ptError)
                                    .font(.caption)
                            }

                            Text("+\(activity.batteryGained)%")
                                .font(.caption)
                                .foregroundColor(.ptSage)
                        }
                    }

                }
                .padding(.top, 8)
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
        .sheet(isPresented: $showingWalkSession) {
            if let activity = batteryManager.destressActivities.first(where: { $0.activityType == .walking }) {
                ActivitySessionView(activity: activity, batteryManager: batteryManager)
            }
        }
        .sheet(isPresented: $showingMeditationSession) {
            if let activity = batteryManager.destressActivities.first(where: { $0.activityType == .meditation }) {
                ActivitySessionView(activity: activity, batteryManager: batteryManager)
            }
        }
        .sheet(isPresented: $showingStretchSession) {
            if let activity = batteryManager.destressActivities.first(where: { $0.activityType == .stretching }) {
                ActivitySessionView(activity: activity, batteryManager: batteryManager)
            }
        }
        .sheet(isPresented: $showingNapSession) {
            if let activity = batteryManager.destressActivities.first(where: { $0.activityType == .nap }) {
                ActivitySessionView(activity: activity, batteryManager: batteryManager)
            }
        }
        .sheet(isPresented: $showingRestSession) {
            if let activity = batteryManager.destressActivities.first(where: { $0.activityType == .rest }) {
                ActivitySessionView(activity: activity, batteryManager: batteryManager)
            }
        }
    }
}

struct RecoveryActivityCard: View {
    let activity: DestressActivity
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                Image(systemName: activity.icon)
                    .font(.title)
                    .foregroundColor(activity.color)
                    .frame(width: 50, height: 50)
                    .background(activity.color.opacity(0.15))
                    .cornerRadius(12)

                VStack(spacing: 4) {
                    Text(activity.name)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Text("\(activity.duration) min")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Text("+\(activity.batteryGain)%")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.ptSage)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.ptSage.opacity(0.15))
                    .cornerRadius(8)
            }
            .frame(width: 100)
            .padding(.vertical, 16)
            .background(Color(.systemGray6))
            .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("\(activity.name), \(activity.duration) minutes, plus \(activity.batteryGain) percent battery")
        .accessibilityHint("Double tap to start this recovery activity")
    }
}

// MARK: - Today's Activity Impact Card

struct TodayActivityImpactCard: View {
    let activities: [ActivityEntry]
    let batteryManager: BodyBatteryManager

    var totalDrain: Int {
        activities.reduce(0) { total, activity in
            total + batteryManager.calculateBatteryDrain(
                stressLevel: activity.stressLevel,
                durationMinutes: activity.durationMinutes
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "list.bullet.rectangle")
                    .foregroundColor(.ptWarning)
                Text("Today's Stress Impact")
                    .font(.headline)
                Spacer()

                Text("-\(totalDrain)%")
                    .font(.headline)
                    .foregroundColor(.ptError)
            }

            if activities.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle")
                        .foregroundColor(.ptSage)
                    Text("No stressful activities logged today")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                ForEach(activities.prefix(5)) { activity in
                    HStack {
                        Image(systemName: activity.activityType.icon)
                            .foregroundColor(activity.activityType.color)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(activity.activityName)
                                .font(.subheadline)
                            Text("\(activity.durationString) • Stress: \(activity.stressLevel)/10")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        let drain = batteryManager.calculateBatteryDrain(
                            stressLevel: activity.stressLevel,
                            durationMinutes: activity.durationMinutes
                        )
                        Text("-\(drain)%")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.ptError)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Activity Session View
                    
                    /// A view that guides users through a timed recovery activity while recording physiological metrics
                    struct ActivitySessionView: View {
                        let activity: DestressActivity
                        @ObservedObject var batteryManager: BodyBatteryManager
                        @EnvironmentObject var healthKitManager: HealthKitManager
                        @Environment(\.dismiss) private var dismiss
                        
                        @State private var sessionState: SessionState = .ready
                        @State private var secondsElapsed: Int = 0
                        @State private var timer: Timer?
                        @State private var startTime: Date?
                        @State private var sessionMetrics: ActivitySessionMetrics?
                        @State private var pulseAnimation = false
                        @State private var isLoadingMetrics = false
                        
                        enum SessionState {
                            case ready
                            case inProgress
                            case completing
                            case showingResults
                        }
                        
                        var targetDurationSeconds: Int {
                            activity.duration * 60
                        }
                        
                        var progress: Double {
                            min(1.0, Double(secondsElapsed) / Double(targetDurationSeconds))
                        }
                        
                        var formattedTime: String {
                            let minutes = secondsElapsed / 60
                            let seconds = secondsElapsed % 60
                            return String(format: "%d:%02d", minutes, seconds)
                        }
                        
                        var targetTime: String {
                            let minutes = targetDurationSeconds / 60
                            return "\(minutes):00"
                        }
                        
                        var body: some View {
                            NavigationView {
                                ZStack {
                                    // Dynamic background based on activity type
                                    activityGradient
                                        .ignoresSafeArea()
                                    
                                    VStack(spacing: 30) {
                                        Spacer()
                                        
                                        // Activity progress visualization
                                        ZStack {
                                            // Outer pulse ring
                                            Circle()
                                                .fill(activity.color.opacity(0.1))
                                                .frame(width: 280, height: 280)
                                                .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                                                .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: pulseAnimation)
                                            
                                            // Progress ring background
                                            Circle()
                                                .stroke(activity.color.opacity(0.2), lineWidth: 12)
                                                .frame(width: 220, height: 220)
                                            
                                            // Progress ring
                                            Circle()
                                                .trim(from: 0, to: progress)
                                                .stroke(activity.color, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                                                .frame(width: 220, height: 220)
                                                .rotationEffect(.degrees(-90))
                                                .animation(.linear(duration: 1), value: progress)
                                            
                                            // Center content
                                            VStack(spacing: 8) {
                                                Image(systemName: activity.icon)
                                                    .font(.system(size: 50))
                                                    .foregroundColor(activity.color)
                                                
                                                if sessionState == .inProgress {
                                                    Text(formattedTime)
                                                        .font(.system(size: 44, weight: .bold, design: .rounded))
                                                        .foregroundColor(.primary)
                                                    
                                                    Text("/ \(targetTime)")
                                                        .font(.subheadline)
                                                        .foregroundColor(.secondary)
                                                } else if sessionState == .ready {
                                                    Text(activity.name)
                                                        .font(.title2)
                                                        .fontWeight(.semibold)
                                                } else if sessionState == .completing {
                                                    ProgressView()
                                                        .scaleEffect(1.5)
                                                    Text("Analyzing...")
                                                        .font(.subheadline)
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                        }
                                        
                                        // Recording indicator
                                        if sessionState == .inProgress {
                                            HStack(spacing: 8) {
                                                Circle()
                                                    .fill(Color.red)
                                                    .frame(width: 10, height: 10)
                                                    .opacity(pulseAnimation ? 1.0 : 0.5)
                                                Text("Recording physiological data...")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            .padding(.vertical, 8)
                                            .padding(.horizontal, 16)
                                            .background(Color(.systemGray6))
                                            .cornerRadius(20)
                                        }
                                        
                                        Spacer()
                                        
                                        // Instructions
                                        VStack(spacing: 8) {
                                            Text(instructionTitle)
                                                .font(.headline)
                                            Text(instructionText)
                                                .font(.body)
                                                .foregroundColor(.secondary)
                                                .multilineTextAlignment(.center)
                                                .padding(.horizontal, 40)
                                        }
                                        
                                        // Control buttons
                                        VStack(spacing: 16) {
                                            Button(action: handlePrimaryAction) {
                                                Text(primaryButtonText)
                                                    .font(.headline)
                                                    .foregroundColor(.white)
                                                    .frame(maxWidth: .infinity)
                                                    .padding(.vertical, 18)
                                                    .background(activity.color)
                                                    .cornerRadius(16)
                                            }
                                            .disabled(sessionState == .completing)
                                            
                                            if sessionState == .inProgress {
                                                Button(action: { endSessionEarly() }) {
                                                    Text("End Early")
                                                        .font(.subheadline)
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                        }
                                        .padding(.horizontal, 24)
                                        .padding(.bottom, 40)
                                    }
                                }
                                .navigationTitle(activity.name)
                                .navigationBarTitleDisplayMode(.inline)
                                .toolbar {
                                    ToolbarItem(placement: .cancellationAction) {
                                        Button("Cancel") {
                                            cancelSession()
                                        }
                                    }
                                }
                                .sheet(isPresented: Binding(
                                    get: { sessionState == .showingResults && sessionMetrics != nil },
                                    set: { if !$0 { dismiss() } }
                                )) {
                                    if let metrics = sessionMetrics {
                                        SessionMetricsSummaryView(
                                            metrics: metrics,
                                            activity: activity,
                                            batteryManager: batteryManager
                                        )
                                    }
                                }
                            }
                            .onAppear {
                                pulseAnimation = true
                            }
                            .onDisappear {
                                timer?.invalidate()
                            }
                        }
                        
                        var activityGradient: LinearGradient {
                            LinearGradient(
                                colors: [activity.color.opacity(0.2), activity.color.opacity(0.05), Color(.systemBackground)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        }
                        
                        var instructionTitle: String {
                            switch sessionState {
                            case .ready:
                                return "Ready to begin?"
                            case .inProgress:
                                return activityGuideTitle
                            case .completing:
                                return "Great job!"
                            case .showingResults:
                                return "Session Complete"
                            }
                        }
                        
                        var instructionText: String {
                            switch sessionState {
                            case .ready:
                                return activity.description
                            case .inProgress:
                                return activityGuideText
                            case .completing:
                                return "Analyzing your physiological response..."
                            case .showingResults:
                                return "View your session metrics"
                            }
                        }
                        
                        var activityGuideTitle: String {
                            switch activity.activityType {
                            case .walking:
                                return "Keep walking"
                            case .meditation:
                                return "Stay focused"
                            case .stretching:
                                return "Breathe and stretch"
                            default:
                                return "Keep going"
                            }
                        }
                        
                        var activityGuideText: String {
                            switch activity.activityType {
                            case .walking:
                                return "Maintain a comfortable pace. Focus on your breathing and surroundings."
                            case .meditation:
                                return "Clear your mind. Focus on your breath and let thoughts pass by."
                            case .stretching:
                                return "Move slowly through each stretch. Hold each position for 15-30 seconds."
                            default:
                                return activity.description
                            }
                        }
                        
                        var primaryButtonText: String {
                            switch sessionState {
                            case .ready:
                                return "Start \(activity.name)"
                            case .inProgress:
                                return "Complete Activity"
                            case .completing:
                                return "Analyzing..."
                            case .showingResults:
                                return "View Results"
                            }
                        }
                        
                        func handlePrimaryAction() {
                            switch sessionState {
                            case .ready:
                                startSession()
                            case .inProgress:
                                completeSession()
                            case .showingResults:
                                dismiss()
                            default:
                                break
                            }
                        }
                        
                        func startSession() {
                            startTime = Date()
                            sessionState = .inProgress
                            batteryManager.startActivitySession(for: activity)
                            
                            // Start workout session for high-frequency HR monitoring
                            Task {
                                await healthKitManager.startWorkoutSession()
                            }
                            
                            // Start the timer
                            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                                secondsElapsed += 1
                                
                                // Auto-complete when target duration is reached
                                if secondsElapsed >= targetDurationSeconds {
                                    completeSession()
                                }
                            }
                        }
                        
                        func completeSession() {
                            timer?.invalidate()
                            timer = nil
                            sessionState = .completing
                            
                            guard let start = startTime else {
                                dismiss()
                                return
                            }
                            
                            let endTime = Date()
                            
                            // End workout session and fetch metrics from HealthKit
                            Task {
                                // End workout session first
                                await healthKitManager.endWorkoutSession()
                                
                                // Wait for Apple Watch data to sync to iPhone
                                // HealthKit data from Watch commonly takes several seconds to appear
                                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                                
                                let metrics = await healthKitManager.fetchActivitySessionMetrics(
                                    activityName: activity.name,
                                    from: start,
                                    to: endTime
                                )
                                
                                await MainActor.run {
                                    self.sessionMetrics = metrics
                                    batteryManager.endActivitySession(with: metrics)
                                    sessionState = .showingResults
                                }
                            }
                        }
                        
                        func endSessionEarly() {
                            // End the session even if not at target duration
                            completeSession()
                        }
                        
                        func cancelSession() {
                            timer?.invalidate()
                            timer = nil
                            batteryManager.cancelActivitySession()
                            
                            // End workout session
                            Task {
                                await healthKitManager.endWorkoutSession()
                            }
                            
                            dismiss()
                        }
                    }
                    
                    // MARK: - Session Metrics Summary View
                    
                    /// Displays the recorded physiological metrics after completing a recovery activity
                    struct SessionMetricsSummaryView: View {
                        let metrics: ActivitySessionMetrics
                        let activity: DestressActivity
                        @ObservedObject var batteryManager: BodyBatteryManager
                        @Environment(\.dismiss) private var dismiss
                        
                        var body: some View {
                            NavigationView {
                                ScrollView {
                                    VStack(spacing: 24) {
                                        // Success header
                                        VStack(spacing: 16) {
                                            ZStack {
                                                Circle()
                                                    .fill(Color.ptSage.opacity(0.2))
                                                    .frame(width: 100, height: 100)

                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.system(size: 60))
                                                    .foregroundColor(.ptSage)
                                            }
                                            
                                            Text("Session Complete!")
                                                .font(.title)
                                                .fontWeight(.bold)
                                            
                                            Text(activity.name)
                                                .font(.headline)
                                                .foregroundColor(activity.color)
                                            
                                            HStack(spacing: 20) {
                                                VStack {
                                                    Text(metrics.formattedDuration)
                                                        .font(.title2)
                                                        .fontWeight(.semibold)
                                                    Text("Duration")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
                                                
                                                Divider()
                                                    .frame(height: 40)
                                                
                                                VStack {
                                                    Text("+\(activity.batteryGain)%")
                                                        .font(.title2)
                                                        .fontWeight(.semibold)
                                                        .foregroundColor(.ptSage)
                                                    Text("Battery Gained")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                            .padding(.top, 8)
                                        }
                                        .padding(.top, 20)
                                        
                                        // Show appropriate content based on data availability
                                        if metrics.hasAnyData {
                                            // Relaxation Score Card (only show if we have HR data)
                                            if metrics.hasHeartRateData {
                                                relaxationScoreCard
                                            }
                                            
                                            // Heart Rate Metrics Card
                                            heartRateCard
                                            
                                            // HRV Metrics Card (only if we have data)
                                            if metrics.rmssd != nil || metrics.avgHRV != nil {
                                                hrvCard
                                            }
                                            
                                            // Additional Metrics Card (if available)
                                            if metrics.caloriesBurned != nil || metrics.respiratoryRate != nil {
                                                additionalMetricsCard
                                            }
                                        } else {
                                            // No data available - show helpful message
                                            limitedDataCard
                                        }
                                        
                                        // Done button
                                        Button(action: { dismiss() }) {
                                            Text("Done")
                                                .font(.headline)
                                                .foregroundColor(.white)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 18)
                                                .background(activity.color)
                                                .cornerRadius(16)
                                        }
                                        .padding(.horizontal, 24)
                                        .padding(.bottom, 40)
                                    }
                                }
                                .background(Color(.systemGroupedBackground).ignoresSafeArea())
                                .navigationTitle("Session Results")
                                .navigationBarTitleDisplayMode(.inline)
                            }
                        }
                        
                        // MARK: - Limited Data Card
                        
                        private var limitedDataCard: some View {
                            VStack(spacing: 16) {
                                Image(systemName: "applewatch.side.right")
                                    .font(.system(size: 50))
                                    .foregroundColor(.secondary)
                                
                                Text("Limited Data Available")
                                    .font(.headline)
                                
                                Text("Your Apple Watch didn't record enough heart rate samples during this session.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                
                                VStack(alignment: .leading, spacing: 12) {
                                    tipRow(icon: "applewatch", text: "Make sure your Apple Watch is worn snugly")
                                    tipRow(icon: "hand.raised", text: "Keep your wrist still during the exercise")
                                    tipRow(icon: "clock", text: "Sessions of 2+ minutes provide more data")
                                    tipRow(icon: "arrow.clockwise", text: "Try opening the Heart Rate app on your Watch before starting")
                                }
                                .font(.caption)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                            }
                            .padding(20)
                            .background(Color(.systemBackground))
                            .cornerRadius(16)
                            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
                            .padding(.horizontal)
                        }
                        
                        private func tipRow(icon: String, text: String) -> some View {
                            HStack(spacing: 12) {
                                Image(systemName: icon)
                                    .foregroundColor(.ptTeal)
                                    .frame(width: 24)
                                Text(text)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // MARK: - Relaxation Score Card
                        
                        private var relaxationScoreCard: some View {
                            VStack(spacing: 12) {
                                HStack {
                                    Image(systemName: "brain.head.profile")
                                        .foregroundColor(.ptInfo)
                                    Text("Relaxation Analysis")
                                        .font(.headline)
                                    Spacer()
                                }

                                ZStack {
                                    Circle()
                                        .stroke(Color.ptInfo.opacity(0.2), lineWidth: 10)
                                        .frame(width: 120, height: 120)

                                    Circle()
                                        .trim(from: 0, to: Double(metrics.relaxationScore) / 100.0)
                                        .stroke(Color.ptInfo, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                                        .frame(width: 120, height: 120)
                                        .rotationEffect(.degrees(-90))

                                    VStack(spacing: 2) {
                                        Text("\(metrics.relaxationScore)")
                                            .font(.system(size: 32, weight: .bold))
                                            .foregroundColor(.ptInfo)
                                        Text(metrics.relaxationLevel)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.vertical, 8)
                                
                                Text("Based on your heart rate patterns and HRV during the session")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(20)
                            .background(Color(.systemBackground))
                            .cornerRadius(16)
                            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
                            .padding(.horizontal)
                        }
                        
                        // MARK: - Heart Rate Card
                        
                        private var heartRateCard: some View {
                            VStack(spacing: 16) {
                                HStack {
                                    Image(systemName: "heart.fill")
                                        .foregroundColor(.ptError)
                                    Text("Heart Rate Metrics")
                                        .font(.headline)
                                    Spacer()
                                }
                                
                                if metrics.hasHeartRateData {
                                    HStack(spacing: 16) {
                                        MetricBox(
                                            title: "Min",
                                            value: metrics.minHeartRate != nil ? "\(Int(metrics.minHeartRate!))" : "--",
                                            unit: "BPM",
                                            icon: "arrow.down",
                                            color: .ptSage
                                        )

                                        MetricBox(
                                            title: "Avg",
                                            value: metrics.avgHeartRate != nil ? "\(Int(metrics.avgHeartRate!))" : "--",
                                            unit: "BPM",
                                            icon: "heart.fill",
                                            color: .ptError
                                        )

                                        MetricBox(
                                            title: "Max",
                                            value: metrics.maxHeartRate != nil ? "\(Int(metrics.maxHeartRate!))" : "--",
                                            unit: "BPM",
                                            icon: "arrow.up",
                                            color: .ptWarning
                                        )
                                    }
                                    
                                    Text("\(metrics.heartRateSamples.count) measurements recorded")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    HStack {
                                        Image(systemName: "waveform.slash")
                                            .foregroundColor(.secondary)
                                        Text("No heart rate data recorded")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.vertical, 20)
                                }
                            }
                            .padding(20)
                            .background(Color(.systemBackground))
                            .cornerRadius(16)
                            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
                            .padding(.horizontal)
                        }
                        
                        // MARK: - HRV Card
                        
                        private var hrvCard: some View {
                            VStack(spacing: 16) {
                                HStack {
                                    Image(systemName: "waveform.path.ecg")
                                        .foregroundColor(.ptError)
                                    Text("Heart Rate Variability (HRV)")
                                        .font(.headline)
                                    Spacer()
                                }

                                HStack(spacing: 16) {
                                    if metrics.rmssd != nil {
                                        VStack(spacing: 8) {
                                            Text("RMSSD")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Text(metrics.heartRateVariability)
                                                .font(.title2)
                                                .fontWeight(.bold)
                                                .foregroundColor(.ptError)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                        .background(Color.ptError.opacity(0.1))
                                        .cornerRadius(12)
                                    }

                                    if let avgHRV = metrics.avgHRV {
                                        VStack(spacing: 8) {
                                            Text("Avg SDNN")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Text(String(format: "%.1f ms", avgHRV))
                                                .font(.title2)
                                                .fontWeight(.bold)
                                                .foregroundColor(.ptInfo)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                        .background(Color.ptInfo.opacity(0.1))
                                        .cornerRadius(12)
                                    }
                                }
                                
                                // HRV interpretation
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("What this means:")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    Text(metrics.hrvInterpretation)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                            }
                            .padding(20)
                            .background(Color(.systemBackground))
                            .cornerRadius(16)
                            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
                            .padding(.horizontal)
                        }
                        
                        // MARK: - Additional Metrics Card
                        
                        private var additionalMetricsCard: some View {
                            VStack(spacing: 16) {
                                HStack {
                                    Image(systemName: "chart.bar.fill")
                                        .foregroundColor(.ptTeal)
                                    Text("Additional Metrics")
                                        .font(.headline)
                                    Spacer()
                                }

                                HStack(spacing: 16) {
                                    if let calories = metrics.caloriesBurned {
                                        VStack(spacing: 8) {
                                            Image(systemName: "flame.fill")
                                                .foregroundColor(.ptWarning)
                                            Text(String(format: "%.1f", calories))
                                                .font(.title3)
                                                .fontWeight(.semibold)
                                            Text("kcal burned")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(Color.ptWarning.opacity(0.1))
                                        .cornerRadius(12)
                                    }

                                    if let respRate = metrics.respiratoryRate {
                                        VStack(spacing: 8) {
                                            Image(systemName: "lungs.fill")
                                                .foregroundColor(.ptMint)
                                            Text(String(format: "%.0f", respRate))
                                                .font(.title3)
                                                .fontWeight(.semibold)
                                            Text("breaths/min")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(Color.ptMint.opacity(0.1))
                                        .cornerRadius(12)
                                    }
                                }
                            }
                            .padding(20)
                            .background(Color(.systemBackground))
                            .cornerRadius(16)
                            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
                            .padding(.horizontal)
                        }
                    }
                    
                    // MARK: - Metric Box Component
                    
                    struct MetricBox: View {
                        let title: String
                        let value: String
                        let unit: String
                        let icon: String
                        let color: Color
                        
                        var body: some View {
                            VStack(spacing: 8) {
                                Image(systemName: icon)
                                    .foregroundColor(color)
                                Text(value)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text(unit)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text(title)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(color.opacity(0.1))
                            .cornerRadius(12)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("\(title), \(value) \(unit)")
                        }
                    }
                    
                    // MARK: - Breathing Exercise View
                    
                    struct BreathingExerciseView: View {
                        @ObservedObject var batteryManager: BodyBatteryManager
                        @EnvironmentObject var healthKitManager: HealthKitManager
                        @Environment(\.dismiss) private var dismiss
                        
                        @State private var breathPhase: BreathPhase = .ready
                        @State private var circleScale: CGFloat = 1.0
                        @State private var secondsRemaining: Int = 300 // 5 minutes
                        @State private var currentCycle = 0
                        @State private var timer: Timer?
                        @State private var breathTimer: Timer?
                        @State private var startTime: Date?
                        @State private var sessionMetrics: ActivitySessionMetrics?
                        @State private var showingMetrics = false
                        
                        enum BreathPhase: String {
                            case ready = "Get Ready"
                            case inhale = "Breathe In"
                            case hold = "Hold"
                            case exhale = "Breathe Out"
                            case completing = "Analyzing..."
                            case complete = "Complete!"
                        }
                        
                        var breathingActivity: DestressActivity? {
                            batteryManager.destressActivities.first { $0.activityType == .breathing }
                        }
                        
                        var formattedTime: String {
                            let minutes = secondsRemaining / 60
                            let seconds = secondsRemaining % 60
                            return String(format: "%d:%02d", minutes, seconds)
                        }
                        
                        var body: some View {
                            NavigationView {
                                ZStack {
                                    // Background gradient
                                    LinearGradient(
                                        colors: [.ptMint.opacity(0.3), .ptTeal.opacity(0.2), .ptInfo.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                    .ignoresSafeArea()
                                    
                                    VStack(spacing: 40) {
                                        Spacer()
                                        
                                        // Recording indicator with Watch tip
                                        if breathPhase == .ready {
                                            VStack(spacing: 8) {
                                                HStack(spacing: 6) {
                                                    Image(systemName: "applewatch")
                                                        .foregroundColor(.ptTeal)
                                                    Text("Tip: Start Breathe app on Watch for best HR tracking")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 10)
                                            .background(Color.ptTeal.opacity(0.1))
                                            .cornerRadius(12)
                                        } else if breathPhase != .complete && breathPhase != .completing {
                                            HStack(spacing: 8) {
                                                Circle()
                                                    .fill(Color.red)
                                                    .frame(width: 8, height: 8)
                                                Text("Recording heart data")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(Color.white.opacity(0.8))
                                            .cornerRadius(20)
                                        }
                                        
                                        // Breathing circle
                                        ZStack {
                                            Circle()
                                                .fill(Color.ptMint.opacity(0.2))
                                                .frame(width: 250, height: 250)
                                                .scaleEffect(circleScale)

                                            Circle()
                                                .stroke(Color.ptMint, lineWidth: 4)
                                                .frame(width: 200, height: 200)
                                                .scaleEffect(circleScale)
                                            
                                            VStack(spacing: 8) {
                                                if breathPhase == .completing {
                                                    ProgressView()
                                                        .scaleEffect(1.5)
                                                        .padding(.bottom, 8)
                                                }
                                                
                                                Text(breathPhase.rawValue)
                                                    .font(.title)
                                                    .fontWeight(.medium)
                                                    .foregroundColor(.primary)
                                                
                                                if breathPhase != .ready && breathPhase != .complete && breathPhase != .completing {
                                                    Text(formattedTime)
                                                        .font(.system(size: 48, weight: .bold, design: .rounded))
                                                        .foregroundColor(.ptMint)
                                                }
                                            }
                                        }

                                        // Cycle counter
                                        if breathPhase != .ready && breathPhase != .complete && breathPhase != .completing {
                                            Text("Cycle \(currentCycle + 1)")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        // Instructions
                                        VStack(spacing: 8) {
                                            Text(instructionText)
                                                .font(.body)
                                                .foregroundColor(.secondary)
                                                .multilineTextAlignment(.center)
                                                .padding(.horizontal, 40)
                                        }
                                        
                                        // Control Button
                                        Button(action: handleButtonTap) {
                                            Text(buttonText)
                                                .font(.headline)
                                                .foregroundColor(.white)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 18)
                                                .background(Color.ptMint)
                                                .cornerRadius(16)
                                        }
                                        .disabled(breathPhase == .completing)
                                        .padding(.horizontal, 24)
                                        .padding(.bottom, 40)
                                    }
                                }
                                .navigationTitle("Deep Breathing")
                                .navigationBarTitleDisplayMode(.inline)
                                .toolbar {
                                    ToolbarItem(placement: .cancellationAction) {
                                        Button("Close") {
                                            stopExercise()
                                            dismiss()
                                        }
                                    }
                                }
                                .sheet(isPresented: $showingMetrics) {
                                    if let metrics = sessionMetrics, let activity = breathingActivity {
                                        SessionMetricsSummaryView(
                                            metrics: metrics,
                                            activity: activity,
                                            batteryManager: batteryManager
                                        )
                                    }
                                }
                                .onChange(of: showingMetrics) { _, newValue in
                                    if !newValue && breathPhase == .complete {
                                        dismiss()
                                    }
                                }
                            }
                            .onDisappear {
                                stopExercise()
                            }
                        }
                        
                        var instructionText: String {
                            switch breathPhase {
                            case .ready:
                                return "Take a moment to find a comfortable position. When you're ready, tap Start."
                            case .inhale:
                                return "Slowly breathe in through your nose"
                            case .hold:
                                return "Gently hold your breath"
                            case .exhale:
                                return "Slowly release through your mouth"
                            case .completing:
                                return "Analyzing your physiological response..."
                            case .complete:
                                return "Great job! You've completed the breathing exercise."
                            }
                        }
                        
                        var buttonText: String {
                            switch breathPhase {
                            case .ready: return "Start Breathing"
                            case .completing: return "Analyzing..."
                            case .complete: return "View Results"
                            default: return "End & View Results"
                            }
                        }
                        
                        func handleButtonTap() {
                            switch breathPhase {
                            case .ready:
                                startExercise()
                            case .complete:
                                showingMetrics = true
                            case .completing:
                                break
                            default:
                                completeExercise()
                            }
                        }
                        
                        func startExercise() {
                            startTime = Date()
                            breathPhase = .inhale
                            currentCycle = 0
                            
                            // Start session tracking
                            if let activity = breathingActivity {
                                batteryManager.startActivitySession(for: activity)
                            }
                            
                            // Start workout session for high-frequency HR monitoring
                            Task {
                                await healthKitManager.startWorkoutSession()
                            }
                            
                            animateBreath()
                            
                            // Main countdown timer
                            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                                if secondsRemaining > 0 {
                                    secondsRemaining -= 1
                                } else {
                                    completeExercise()
                                }
                            }
                        }
                        
                        func animateBreath() {
                            // 4-7-8 breathing pattern
                            breathPhase = .inhale
                            HapticManager.soft()
                            withAnimation(.easeInOut(duration: 4)) {
                                circleScale = 1.5
                            }
                            
                            breathTimer = Timer.scheduledTimer(withTimeInterval: 4, repeats: false) { _ in
                                breathPhase = .hold
                                HapticManager.soft()
                                
                                breathTimer = Timer.scheduledTimer(withTimeInterval: 7, repeats: false) { _ in
                                    breathPhase = .exhale
                                    HapticManager.soft()
                                    withAnimation(.easeInOut(duration: 8)) {
                                        circleScale = 1.0
                                    }
                                    
                                    breathTimer = Timer.scheduledTimer(withTimeInterval: 8, repeats: false) { _ in
                                        currentCycle += 1
                                        if secondsRemaining > 0 {
                                            animateBreath()
                                        }
                                    }
                                }
                            }
                        }
                        
                        func stopExercise() {
                            timer?.invalidate()
                            timer = nil
                            breathTimer?.invalidate()
                            breathTimer = nil
                            batteryManager.cancelActivitySession()
                            
                            // End workout session
                            Task {
                                await healthKitManager.endWorkoutSession()
                            }
                            
                            breathPhase = .ready
                            secondsRemaining = 300
                            circleScale = 1.0
                        }
                        
                        func completeExercise() {
                            timer?.invalidate()
                            timer = nil
                            breathTimer?.invalidate()
                            breathTimer = nil
                            breathPhase = .completing
                            
                            guard let start = startTime else {
                                breathPhase = .complete
                                showingMetrics = true
                                return
                            }
                            
                            let endTime = Date()
                            
                            // End workout session and fetch metrics from HealthKit
                            Task {
                                // End workout session first
                                await healthKitManager.endWorkoutSession()
                                
                                // Wait for Apple Watch data to sync to iPhone
                                // HealthKit data from Watch commonly takes several seconds to appear
                                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                                
                                let metrics = await healthKitManager.fetchActivitySessionMetrics(
                                    activityName: "Deep Breathing",
                                    from: start,
                                    to: endTime
                                )
                                
                                await MainActor.run {
                                    self.sessionMetrics = metrics
                                    batteryManager.endActivitySession(with: metrics)
                                    breathPhase = .complete
                                    withAnimation(.spring()) {
                                        circleScale = 1.2
                                    }
                                    showingMetrics = true
                                }
                            }
                        }
                    }
                    
                    // MARK: - Preview
                    
                    #Preview {
                        BodyBatteryView()
                            .environmentObject(HealthKitManager())
                    }
                
