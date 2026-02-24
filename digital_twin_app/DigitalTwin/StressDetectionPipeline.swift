//
//  StressDetectionPipeline.swift
//
//  Complete 3-Stage Stress Detection Pipeline for iOS.
//  Drop this file into the Xcode project alongside HealthKitManager.swift.
//
//  Stage 1 (ML):      ActivityClassifier.mlmodel → PHYSICAL or COGNITIVE
//  Stage 2 (Rules):   Sleep quality → adjust stress threshold
//  Stage 3 (Formulas): DC/AC metrics → stress score → Body Battery drain
//
//  Requirements:
//    - ActivityClassifier.mlmodel added to Xcode project 
//    - ActivityClassifier_preprocessing.json in app bundle
//    - HealthKitManager.swift (already exists in project)
//
//  Usage in ContentView or BodyBatteryView:
//    let pipeline = StressDetectionPipeline(healthKitManager: healthManager)
//    let result = await pipeline.runFullPipeline()
//    // result.stressScore → feed into BodyBatteryView drain formula
//
//  For Dhyay:
//    Wire result.stressScore into calculateBatteryDrain()
//    Wire result.activityType into ActivityManager logging
//

import Foundation
import CoreML
import HealthKit


// MARK: - Pipeline Result Types

struct PipelineResult {
    let timestamp: Date

    // Stage 1: Activity
    let activityType: ClassifiedActivityType        // .physical or .cognitive
    let activityConfidence: Double         // 0-1 confidence from model

    // Stage 2: Sleep adjustment
    let sleepHours: Double?
    let sleepQuality: SleepQuality
    let adjustedThreshold: Int            // Base 60, adjusted by sleep

    // Stage 3: Stress metrics (nil if Stage 1 = PHYSICAL)
    let dc: Double?                       // Deceleration Capacity (ms)
    let ac: Double?                       // Acceleration Capacity (ms)
    let sdnn: Double?                     // Standard deviation of NN (ms)
    let rmssd: Double?                    // Root mean square successive diff (ms)
    let stressScore: Int                  // 0-100
    let stressLevel: StressLevel
    let isStressed: Bool

    // Recovery (post-activity)
    let recoverySlope: Double?            // DC increase rate after activity
}

enum ClassifiedActivityType: String {
    case physical = "PHYSICAL"
    case cognitive = "COGNITIVE"
    case unknown = "UNKNOWN"
}

enum SleepQuality: String {
    case veryPoor = "very_poor"
    case poor = "poor"
    case normal = "normal"
    case good = "good"
    case excellent = "excellent"
    case unknown = "unknown"
}

enum StressLevel: String {
    case low = "low"
    case moderate = "moderate"
    case high = "high"
    case veryHigh = "very_high"
    case insufficientData = "insufficient_data"
    case physicalActivity = "physical_activity"  // Stage 1 filtered this out
}


// MARK: - Stage 1: Activity Classifier (CoreML)

/// Calls the ActivityClassifier.mlmodel with proper preprocessing.
/// The model expects z-score standardized inputs.
class ActivityClassifier_Stage1 {

    private var model: MLModel?

    // Preprocessing params from ActivityClassifier_preprocessing.json
    // These MUST match the values from export_stage1_model.py
    private let imputerFillValues: [String: Double] = [
        "HR_mean": 96.3528,
        "HR_std": 1.2719,
        "ACC_mean": 3.4330,
        "ACC_std": 1.2207
    ]

    private let scalerMeans: [String: Double] = [
        "HR_mean": 96.3528,
        "HR_std": 1.2719,
        "ACC_mean": 3.4330,
        "ACC_std": 1.2207
    ]

    private let scalerStds: [String: Double] = [
        "HR_mean": 26.6446,
        "HR_std": 1.4456,
        "ACC_mean": 2.4551,
        "ACC_std": 0.9666
    ]

    init() {
        loadModel()
    }

    private func loadModel() {
        do {
            let config = MLModelConfiguration()
            config.computeUnits = .cpuOnly  // Lightweight model, CPU is fine

            // Xcode auto-generates the class from .mlmodel file name
            // If your .mlmodel is named "ActivityClassifier", Xcode creates
            // a class called ActivityClassifier. Use that directly:
            //   let classifier = try ActivityClassifier(configuration: config)
            //   model = classifier.model
            //
            // OR load by URL (more flexible):
            if let modelURL = Bundle.main.url(forResource: "ActivityClassifier",
                                               withExtension: "mlmodelc") {
                model = try MLModel(contentsOf: modelURL, configuration: config)
            }
        } catch {
            print("Failed to load ActivityClassifier.mlmodel: \(error)")
        }
    }

    /// Classify activity from heart rate and movement features.
    ///
    /// - Parameters:
    ///   - hrMean: Mean heart rate (BPM) in the window
    ///   - hrStd: Std deviation of heart rate in the window
    ///   - accMean: Mean accelerometer magnitude (or steps-per-minute proxy)
    ///   - accStd: Std deviation of accelerometer (or steps variability)
    ///
    /// - Returns: (ClassifiedActivityType, confidence 0-1)
    func classify(hrMean: Double?, hrStd: Double?,
                  accMean: Double?, accStd: Double?) -> (ClassifiedActivityType, Double) {
        guard let model = model else {
            return (ClassifiedActivityType.unknown, 0.0)
        }

        // Step 1: Impute NaN/nil with training means
        let rawHRMean = hrMean ?? imputerFillValues["HR_mean"]!
        let rawHRStd = hrStd ?? imputerFillValues["HR_std"]!
        let rawACCMean = accMean ?? imputerFillValues["ACC_mean"]!
        let rawACCStd = accStd ?? imputerFillValues["ACC_std"]!

        // Step 2: Z-score standardize: (value - mean) / std
        let zHRMean = (rawHRMean - scalerMeans["HR_mean"]!) / scalerStds["HR_mean"]!
        let zHRStd = (rawHRStd - scalerMeans["HR_std"]!) / scalerStds["HR_std"]!
        let zACCMean = (rawACCMean - scalerMeans["ACC_mean"]!) / scalerStds["ACC_mean"]!
        let zACCStd = (rawACCStd - scalerMeans["ACC_std"]!) / scalerStds["ACC_std"]!

        // Step 3: Create model input
        do {
            let input = try MLDictionaryFeatureProvider(dictionary: [
                "HR_mean": MLFeatureValue(double: zHRMean),
                "HR_std": MLFeatureValue(double: zHRStd),
                "ACC_mean": MLFeatureValue(double: zACCMean),
                "ACC_std": MLFeatureValue(double: zACCStd),
            ])

            // Step 4: Predict
            let output = try model.prediction(from: input)

            let predictedClass = output.featureValue(for: "activity_type")?.stringValue ?? "UNKNOWN"

            // Get confidence from probability dictionary
            var confidence = 0.5
            if let scores = output.featureValue(for: "activity_scores")?.dictionaryValue {
                if let prob = scores[predictedClass] as? Double {
                    confidence = prob
                }
            }

            let activityType = ClassifiedActivityType(rawValue: predictedClass) ?? .unknown
            return (activityType, confidence)

        } catch {
            print("Prediction failed: \(error)")
            return (ClassifiedActivityType.unknown, 0.0)
        }
    }
}


// MARK: - Stage 2: Sleep-Based Threshold Adjustment

/// Adjusts the stress detection threshold based on last night's sleep.
/// No ML — simple rules 
struct SleepThresholdAdjuster {

    static let baseThreshold = 60

    /// Adjust stress threshold based on sleep quality.
    ///
    /// - Parameters:
    ///   - sleepHours: Hours slept last night (from fetchLastNightSleep)
    ///   - baselineHours: Personal average sleep (default 7.0)
    ///
    /// - Returns: (adjustedThreshold, sleepQuality)
    static func adjust(sleepHours: Double?,
                       baselineHours: Double = 7.0) -> (Int, SleepQuality) {
        guard let hours = sleepHours, hours > 0, baselineHours > 0 else {
            return (baseThreshold, .unknown)
        }

        let ratio = hours / baselineHours

        if ratio < 0.75 {
            // Very poor sleep → much more sensitive
            return (Int(Double(baseThreshold) * 0.80), .veryPoor)   // 48
        } else if ratio < 0.90 {
            // Poor sleep → more sensitive
            return (Int(Double(baseThreshold) * 0.85), .poor)       // 51
        } else if ratio <= 1.10 {
            // Normal
            return (baseThreshold, .normal)                          // 60
        } else if ratio <= 1.20 {
            // Good sleep
            return (Int(Double(baseThreshold) * 1.05), .good)       // 63
        } else {
            // Excellent sleep
            return (Int(Double(baseThreshold) * 1.08), .excellent)  // 65
        }
    }
}


// MARK: - Stage 3: DC/AC Stress Calculation

/// Computes stress metrics from RR intervals using PRSA method.
/// Reference: Bauer 2006, validated by Velmovitsky 2022 on Apple Watch.
struct StressMetrics {
    let dc: Double?       // Deceleration Capacity (higher = calmer)
    let ac: Double?       // Acceleration Capacity (more negative = more stressed)
    let sdnn: Double?     // Std dev of NN intervals
    let rmssd: Double?    // Root mean square successive differences
    let meanHR: Double?
    let stressScore: Int  // 0-100
    let stressLevel: StressLevel
}

class StressCalculator_Stage3 {

    /// Max allowed % change between consecutive RR intervals.
    /// Intervals exceeding this are noise/ectopic beats (Bauer 2006).
    let ectopicThreshold: Double = 0.20

    /// Personal baseline DC and SDNN values (built over 7-14 days)
    private var baselineDCValues: [Double] = []
    private var baselineSDNNValues: [Double] = []
    private let maxBaselineSamples = 50
    
    // UserDefaults keys for persistence
    private let baselineDCKey = "StressCalculator_BaselineDC"
    private let baselineSDNNKey = "StressCalculator_BaselineSDNN"
    
    init() {
        loadBaselinesFromStorage()
    }

    var baselineDC: Double? {
        guard baselineDCValues.count >= 5 else { return nil }
        return baselineDCValues.reduce(0, +) / Double(baselineDCValues.count)
    }

    var baselineSDNN: Double? {
        guard baselineSDNNValues.count >= 5 else { return nil }
        return baselineSDNNValues.reduce(0, +) / Double(baselineSDNNValues.count)
    }

    var hasBaseline: Bool {
        return baselineDCValues.count >= 5
    }
    
    // MARK: - Baseline Persistence
    
    private func loadBaselinesFromStorage() {
        if let dcValues = UserDefaults.standard.array(forKey: baselineDCKey) as? [Double] {
            baselineDCValues = dcValues
        }
        if let sdnnValues = UserDefaults.standard.array(forKey: baselineSDNNKey) as? [Double] {
            baselineSDNNValues = sdnnValues
        }
        print("✅ Loaded \(baselineDCValues.count) DC baselines and \(baselineSDNNValues.count) SDNN baselines from storage")
    }
    
    private func saveBaselinesToStorage() {
        UserDefaults.standard.set(baselineDCValues, forKey: baselineDCKey)
        UserDefaults.standard.set(baselineSDNNValues, forKey: baselineSDNNKey)
    }

    // MARK: - Core DC/AC Formula (PRSA)

    /// Compute DC and AC from RR intervals using Phase-Rectified Signal Averaging.
    ///
    /// Algorithm:
    ///   1. Filter ectopic beats (>20% change)
    ///   2. Find deceleration anchors (RR_i > RR_{i-1})
    ///   3. DC = mean of (RR_i + RR_{i+1} - RR_{i-1} - RR_{i-2}) / 4
    ///      at all deceleration anchor points
    ///   4. AC = same formula at acceleration anchors (RR_i < RR_{i-1})
    func computeDCAC(rrIntervals: [Double]) -> (dc: Double?, ac: Double?) {
        guard rrIntervals.count >= 5 else { return (nil, nil) }

        // Step 1: Filter ectopic beats
        var valid: [Double] = []
        var validMask = [Bool](repeating: true, count: rrIntervals.count)

        for i in 1..<rrIntervals.count {
            let pctChange = abs(rrIntervals[i] - rrIntervals[i - 1]) / rrIntervals[i - 1]
            if pctChange > ectopicThreshold {
                validMask[i] = false
                validMask[i - 1] = false
            }
        }

        for (i, isValid) in validMask.enumerated() {
            if isValid {
                valid.append(rrIntervals[i])
            }
        }

        guard valid.count >= 5 else { return (nil, nil) }

        // Step 2-3: Compute PRSA at anchor points
        var dcValues: [Double] = []
        var acValues: [Double] = []

        for i in 2..<(valid.count - 1) {
            let prev = valid[i - 1]
            let curr = valid[i]

            let prsa = (valid[i] + valid[i + 1] - valid[i - 1] - valid[i - 2]) / 4.0

            if curr > prev {
                // Deceleration anchor (heart slowing — vagal activity)
                dcValues.append(prsa)
            } else if curr < prev {
                // Acceleration anchor (heart speeding — sympathetic activity)
                acValues.append(prsa)
            }
        }

        let dc = dcValues.isEmpty ? nil : dcValues.reduce(0, +) / Double(dcValues.count)
        let ac = acValues.isEmpty ? nil : acValues.reduce(0, +) / Double(acValues.count)

        return (dc, ac)
    }

    // MARK: - HRV Metrics

    func computeSDNN(rrIntervals: [Double]) -> Double? {
        guard rrIntervals.count >= 2 else { return nil }
        let mean = rrIntervals.reduce(0, +) / Double(rrIntervals.count)
        let variance = rrIntervals.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(rrIntervals.count - 1)
        return sqrt(variance)
    }

    func computeRMSSD(rrIntervals: [Double]) -> Double? {
        guard rrIntervals.count >= 2 else { return nil }
        var sumSqDiff = 0.0
        for i in 1..<rrIntervals.count {
            let diff = rrIntervals[i] - rrIntervals[i - 1]
            sumSqDiff += diff * diff
        }
        return sqrt(sumSqDiff / Double(rrIntervals.count - 1))
    }

    // MARK: - HR to RR conversion

    /// Convert heart rate samples (BPM) to RR intervals (ms).
    /// RR = 60000 / HR
    func hrToRR(heartRateSamples: [HeartRateSample]) -> [Double] {
        return heartRateSamples
            .filter { $0.bpm > 0 }
            .map { 60000.0 / $0.bpm }
    }

    // MARK: - Stress Scoring
    
    /// Compute stress using HR-only method (for real-time when HRV unavailable)
    /// This is more reliable than pseudo-RR conversion since HR samples are sparse
    ///
    /// Factors considered:
    /// 1. HR elevation above resting baseline
    /// 2. HR variability within the sample window
    /// 3. Absolute HR thresholds
    func computeStressFromHROnly(heartRateSamples: [HeartRateSample],
                                  restingHR: Double? = nil) -> StressMetrics {
        guard !heartRateSamples.isEmpty else {
            return StressMetrics(dc: nil, ac: nil, sdnn: nil, rmssd: nil,
                               meanHR: nil, stressScore: 50,
                               stressLevel: .insufficientData)
        }
        
        let hrValues = heartRateSamples.map { $0.bpm }
        let meanHR = hrValues.reduce(0, +) / Double(hrValues.count)
        
        // Calculate HR std if we have enough samples
        var hrStd: Double? = nil
        if hrValues.count >= 2 {
            let variance = hrValues.map { pow($0 - meanHR, 2) }.reduce(0, +) / Double(hrValues.count - 1)
            hrStd = sqrt(variance)
        }
        
        var score = 50
        
        // Factor 1: HR elevation above resting (most important)
        let baseline = restingHR ?? 65.0  // Default if no RHR available
        let hrElevation = (meanHR - baseline) / baseline
        
        if hrElevation > 0.5 {        // 50%+ above resting
            score += 35
        } else if hrElevation > 0.3 { // 30-50% above
            score += 25
        } else if hrElevation > 0.15 { // 15-30% above
            score += 15
        } else if hrElevation > 0.05 { // 5-15% above
            score += 5
        } else if hrElevation < -0.1 { // Below resting (very relaxed)
            score -= 15
        }
        
        // Factor 2: HR variability in sample window
        // High variability during supposed rest = stress response
        if let std = hrStd {
            if std > 15 { score += 15 }      // Very variable
            else if std > 10 { score += 10 } // Moderately variable
            else if std > 5 { score += 5 }   // Slightly variable
            else if std < 2 { score -= 5 }   // Very stable (relaxed)
        }
        
        // Factor 3: Absolute HR thresholds
        if meanHR > 100 { score += 10 }      // Tachycardic
        else if meanHR > 90 { score += 5 }   // Elevated
        else if meanHR < 55 { score -= 10 }  // Athletic/very relaxed
        
        score = max(0, min(100, score))
        
        let level: StressLevel
        switch score {
        case 0..<30: level = .low
        case 30..<50: level = .moderate
        case 50..<70: level = .high
        default: level = .veryHigh
        }
        
        return StressMetrics(dc: nil, ac: nil, sdnn: nil, rmssd: nil,
                            meanHR: meanHR, stressScore: score, stressLevel: level)
    }
    
    /// Compute stress using real SDNN from HealthKit (when available)
    /// More accurate than HR-only, but only available 1-3x per day passively
    func computeStressFromSDNN(sdnn: Double,
                                restingHR: Double? = nil,
                                currentHR: Double? = nil) -> StressMetrics {
        var score = 50
        
        // SDNN-based scoring (validated ranges from HRV research)
        // Lower SDNN = higher sympathetic activity = more stress
        if hasBaseline, let bSDNN = baselineSDNN {
            // Personalized: compare to user's baseline
            let pctChange = ((sdnn - bSDNN) / bSDNN) * 100
            score += Int(-pctChange * 0.6)  // Below baseline = positive score
        } else {
            // Population-based thresholds
            if sdnn < 20 { score += 35 }       // Very low HRV = high stress
            else if sdnn < 30 { score += 25 }  // Low HRV
            else if sdnn < 40 { score += 15 }  // Below average
            else if sdnn < 50 { score += 5 }   // Slightly below average
            else if sdnn > 80 { score -= 20 }  // High HRV = very relaxed
            else if sdnn > 60 { score -= 10 }  // Good HRV
        }
        
        // Adjust with current HR if available
        if let hr = currentHR, let rhr = restingHR {
            let hrElevation = (hr - rhr) / rhr
            if hrElevation > 0.3 { score += 15 }
            else if hrElevation > 0.15 { score += 8 }
            else if hrElevation < -0.05 { score -= 5 }
        }
        
        score = max(0, min(100, score))
        
        let level: StressLevel
        switch score {
        case 0..<30: level = .low
        case 30..<50: level = .moderate
        case 50..<70: level = .high
        default: level = .veryHigh
        }
        
        return StressMetrics(dc: nil, ac: nil, sdnn: sdnn, rmssd: nil,
                            meanHR: currentHR, stressScore: score, stressLevel: level)
    }
    
    /// Opportunistic stress calculation - uses best available data
    /// Smart priority system that balances data freshness with accuracy:
    /// - If we have fresh HR samples (10+), prefer those for real-time response
    /// - If HR samples are few but SDNN is very recent (<10min), use SDNN
    /// - If SDNN is somewhat recent (<30min) and no HR samples, use SDNN
    /// - Fall back to HR-only if we have any HR data at all
    ///
    /// - Parameters:
    ///   - heartRateSamples: Recent HR samples from HealthKit
    ///   - recentSDNN: SDNN value from HealthKit (if available)
    ///   - sdnnTimestamp: When the SDNN was recorded
    ///   - restingHR: User's resting heart rate baseline
    /// - Returns: StressMetrics with the most accurate calculation possible
    func computeStressOpportunistic(heartRateSamples: [HeartRateSample],
                                     recentSDNN: Double?,
                                     sdnnTimestamp: Date?,
                                     restingHR: Double?) -> StressMetrics {
        let now = Date()
        
        // Check SDNN freshness
        let sdnnAge: TimeInterval? = {
            guard let timestamp = sdnnTimestamp else { return nil }
            return now.timeIntervalSince(timestamp)
        }()
        let sdnnAgeMinutes = sdnnAge.map { Int($0 / 60) }
        
        // Log what data we have available
        print("📊 Stress calculation data available:")
        print("   ├─ HR samples: \(heartRateSamples.count)")
        if let sdnn = recentSDNN, let age = sdnnAgeMinutes {
            print("   ├─ SDNN: \(String(format: "%.1f", sdnn))ms (age: \(age)min)")
        } else {
            print("   ├─ SDNN: N/A")
        }
        print("   └─ Resting HR: \(restingHR != nil ? String(format: "%.0f", restingHR!) : "N/A")")
        
        // Priority 1: If we have enough HR samples (10+), prefer real-time HR-derived calculation
        // This gives us the most responsive stress tracking
        if heartRateSamples.count >= 10 {
            print("📊 → Using HR-derived metrics for stress calculation (\(heartRateSamples.count) samples)")
            return computeStress(heartRateSamples: heartRateSamples)
        }
        
        // Priority 2: If SDNN is very fresh (<10 min) and we have few HR samples,
        // use SDNN as it's likely from the same time period
        if let sdnn = recentSDNN,
           let age = sdnnAge,
           age < 10 * 60 {
            print("📊 → Using very recent SDNN for stress calculation (age: \(Int(age/60))min)")
            let currentHR = heartRateSamples.last?.bpm
            return computeStressFromSDNN(sdnn: sdnn, restingHR: restingHR, currentHR: currentHR)
        }
        
        // Priority 3: If we have some HR samples (3-9), use HR-only calculation
        // This is more responsive than stale SDNN
        if heartRateSamples.count >= 3 {
            print("📊 → Using HR-only stress calculation (\(heartRateSamples.count) samples)")
            return computeStressFromHROnly(heartRateSamples: heartRateSamples, restingHR: restingHR)
        }
        
        // Priority 4: Use SDNN if available and less than 30 minutes old
        if let sdnn = recentSDNN,
           let age = sdnnAge,
           age < 30 * 60 {
            print("📊 → Using older SDNN for stress calculation (age: \(Int(age/60))min, no fresh HR data)")
            let currentHR = heartRateSamples.last?.bpm
            return computeStressFromSDNN(sdnn: sdnn, restingHR: restingHR, currentHR: currentHR)
        }
        
        // Priority 5: HR-only calculation with whatever samples we have (even 1-2)
        if !heartRateSamples.isEmpty {
            print("📊 → Using limited HR-only calculation (\(heartRateSamples.count) samples)")
            return computeStressFromHROnly(heartRateSamples: heartRateSamples, restingHR: restingHR)
        }
        
        // No data available
        print("📊 → Insufficient data for stress calculation")
        return StressMetrics(dc: nil, ac: nil, sdnn: nil, rmssd: nil,
                            meanHR: nil, stressScore: 50,
                            stressLevel: .insufficientData)
    }

    /// Compute full stress metrics from heart rate samples.
    /// NOTE: This uses pseudo-RR intervals derived from sparse HR samples.
    /// The DC/AC values are approximations - real DC/AC requires beat-to-beat RR.
    func computeStress(heartRateSamples: [HeartRateSample],
                       threshold: Int = 60) -> StressMetrics {
        let rr = hrToRR(heartRateSamples: heartRateSamples)

        guard rr.count >= 5 else {
            return StressMetrics(dc: nil, ac: nil, sdnn: nil, rmssd: nil,
                               meanHR: nil, stressScore: 50,
                               stressLevel: .insufficientData)
        }

        let (dc, ac) = computeDCAC(rrIntervals: rr)
        let sdnn = computeSDNN(rrIntervals: rr)
        let rmssd = computeRMSSD(rrIntervals: rr)
        let meanRR = rr.reduce(0, +) / Double(rr.count)
        let meanHR = 60000.0 / meanRR

        // Score
        var score = 50

        if hasBaseline, let dc = dc, let bDC = baselineDC {
            // Personalized scoring
            let dcPctChange = ((dc - bDC) / bDC) * 100
            score += Int(-dcPctChange * 0.8)

            if let sdnn = sdnn, let bSDNN = baselineSDNN {
                let sdnnPctChange = ((sdnn - bSDNN) / bSDNN) * 100
                score += Int(-sdnnPctChange * 0.5)
            }
        } else if let dc = dc {
            // Population-based fallback
            if dc < 2.0 { score += 25 }
            else if dc < 5.0 { score += 10 }
            else if dc > 10.0 { score -= 15 }

            if let sdnn = sdnn {
                if sdnn < 20 { score += 20 }
                else if sdnn < 35 { score += 10 }
                else if sdnn > 60 { score -= 10 }
            }

            if meanHR > 90 { score += 10 }
            else if meanHR < 65 { score -= 10 }
        }

        score = max(0, min(100, score))

        let level: StressLevel
        switch score {
        case 0..<30: level = .low
        case 30..<50: level = .moderate
        case 50..<70: level = .high
        default: level = .veryHigh
        }

        return StressMetrics(dc: dc, ac: ac, sdnn: sdnn, rmssd: rmssd,
                            meanHR: meanHR, stressScore: score, stressLevel: level)
    }

    // MARK: - Baseline Management

    /// Add a calm-period reading to build the personal baseline.
    /// Call during the initial 7-14 day calibration or confirmed rest periods.
    func addBaselineReading(heartRateSamples: [HeartRateSample]) {
        let rr = hrToRR(heartRateSamples: heartRateSamples)
        guard rr.count >= 5 else { return }

        let (dc, _) = computeDCAC(rrIntervals: rr)
        let sdnn = computeSDNN(rrIntervals: rr)

        if let dc = dc, let sdnn = sdnn {
            baselineDCValues.append(dc)
            baselineSDNNValues.append(sdnn)

            if baselineDCValues.count > maxBaselineSamples {
                baselineDCValues.removeFirst()
                baselineSDNNValues.removeFirst()
            }
            
            // Persist to storage
            saveBaselinesToStorage()
        }
    }
    
    /// Clears all baseline data (for testing or reset purposes)
    func clearBaselines() {
        baselineDCValues.removeAll()
        baselineSDNNValues.removeAll()
        saveBaselinesToStorage()
    }
}


// MARK: - Full Pipeline Orchestrator

/// Runs the complete 3-stage pipeline.
/// Call this periodically (every 5 min) or on-demand.
@MainActor
class StressDetectionPipeline: ObservableObject {

    private let healthKitManager: HealthKitManager
    private let activityClassifier = ActivityClassifier_Stage1()
    private let stressCalculator = StressCalculator_Stage3()
    
    // MARK: - Configuration
    
    /// Window duration (in minutes) to fetch HR samples for stress calculation.
    /// Apple Watch records HR every ~5-10 min passively, so a larger window
    /// captures more samples for reliable stress estimation.
    /// Default: 15 minutes (typically yields 3-5+ samples)
    static let hrSampleWindowMinutes: Double = 15
    
    /// Minimum number of HR samples required for reliable stress calculation.
    /// If fewer samples are available, the calculation uses fallback methods.
    static let minHRSamplesForReliable: Int = 10
    static let minHRSamplesForBasic: Int = 3
    
    // Cached sleep baseline (fetched once per session)
    private var cachedSleepBaseline: Double?
    private var sleepBaselineFetched = false

    @Published var latestResult: PipelineResult?
    @Published var isRunning = false

    init(healthKitManager: HealthKitManager) {
        self.healthKitManager = healthKitManager
    }

    /// Run the full 3-stage pipeline once.
    ///
    /// 1. Fetch recent HR + Steps from HealthKit
    /// 2. Stage 1: Classify activity (PHYSICAL vs COGNITIVE)
    /// 3. Stage 2: Get sleep-adjusted threshold
    /// 4. Stage 3: If COGNITIVE → compute DC/AC stress metrics
    ///
    /// Returns PipelineResult for UI display and Body Battery integration.
    func runFullPipeline() async -> PipelineResult {
        // Skip if Apple Watch is not connected
        guard healthKitManager.isAppleWatchConnected else {
            print("⌚ Pipeline skipped — Apple Watch not connected")
            return PipelineResult(
                timestamp: Date(),
                activityType: .unknown,
                activityConfidence: 0,
                sleepHours: healthKitManager.lastNightSleep,
                sleepQuality: .unknown,
                adjustedThreshold: 60,
                dc: nil, ac: nil, sdnn: nil, rmssd: nil,
                stressScore: 0,
                stressLevel: .insufficientData,
                isStressed: false,
                recoverySlope: nil
            )
        }
        
        isRunning = true
        defer { isRunning = false }

        let now = Date()
        let windowMinutes = Self.hrSampleWindowMinutes
        let windowStart = now.addingTimeInterval(-windowMinutes * 60) // Configurable window (default 15 min)

        // Fetch data from HealthKit
        let hrSamples = await healthKitManager.fetchHeartRateSamples(
            from: windowStart, to: now
        )
        let sleepHours = healthKitManager.lastNightSleep
        
        // Diagnostic logging for debugging HR sample issues
        let dateFormatter = DateFormatter()
        dateFormatter.timeStyle = .medium
        print("🔍 Pipeline HR fetch: window \(Int(windowMinutes))min (\(dateFormatter.string(from: windowStart)) - \(dateFormatter.string(from: now)))")
        print("   └─ Found \(hrSamples.count) HR samples (need \(Self.minHRSamplesForReliable)+ for reliable, \(Self.minHRSamplesForBasic)+ for basic)")
        if let oldestSample = hrSamples.first,
           let newestSample = hrSamples.last {
            print("   └─ Sample range: \(dateFormatter.string(from: oldestSample.timestamp)) - \(dateFormatter.string(from: newestSample.timestamp))")
            print("   └─ HR range: \(Int(hrSamples.map { $0.bpm }.min() ?? 0)) - \(Int(hrSamples.map { $0.bpm }.max() ?? 0)) BPM")
        }

        // Compute HR stats for Stage 1
        let hrValues = hrSamples.map { $0.bpm }
        let hrMean = hrValues.isEmpty ? nil : hrValues.reduce(0, +) / Double(hrValues.count)
        let hrStd: Double? = {
            guard hrValues.count >= 2, let mean = hrMean else { return nil }
            let variance = hrValues.map { ($0 - mean) * ($0 - mean) }
                .reduce(0, +) / Double(hrValues.count - 1)
            return sqrt(variance)
        }()

        // Fetch real steps for the same window with proper statistics
        // This replaces the previous hardcoded stepsStd with real variability calculation
        let (stepsPerMin, stepsStd) = await healthKitManager.fetchStepsStatistics(minutes: Int(windowMinutes))

        // ── STAGE 1: Activity Classification ────────────────────────────
        let (activityType, confidence) = activityClassifier.classify(
            hrMean: hrMean,
            hrStd: hrStd,
            accMean: stepsPerMin,  // Real steps per minute mean from HealthKit
            accStd: stepsStd       // Real step variability from minute-by-minute buckets
        )

        // ── STAGE 2: Sleep Threshold Adjustment ─────────────────────────
        // Fetch 30-day sleep baseline if not cached
        if !sleepBaselineFetched {
            cachedSleepBaseline = await healthKitManager.fetchAverageSleepLast30Days()
            sleepBaselineFetched = true
            if let baseline = cachedSleepBaseline {
                print("✅ Personal sleep baseline: \\(String(format: \"%.1f\", baseline)) hours (30-day average)")
            } else {
                print("ℹ️ Using default sleep baseline of 7.0 hours (insufficient data)")
            }
        }
        
        let sleepBaseline = cachedSleepBaseline ?? 7.0  // Fallback for new users
        
        let (adjustedThreshold, sleepQuality) = SleepThresholdAdjuster.adjust(
            sleepHours: sleepHours,
            baselineHours: sleepBaseline
        )

        // ── STAGE 3: Stress Metrics (only if COGNITIVE) ─────────────────
        var dc: Double? = nil
        var ac: Double? = nil
        var sdnn: Double? = nil
        var rmssd: Double? = nil
        var stressScore = 0
        var stressLevel: StressLevel = .physicalActivity
        var isStressed = false

        if activityType == .cognitive {
            // Use opportunistic stress calculation:
            // - Real SDNN if available and recent (within 30 min)
            // - HR-derived metrics if 10+ samples
            // - HR-only if few samples
            let recentSDNN = healthKitManager.latestHRV
            let sdnnTimestamp = healthKitManager.hrvMetric.lastUpdated
            let restingHR = healthKitManager.restingHeartRate
            
            // Diagnostic: Log SDNN and RHR state
            if let sdnn = recentSDNN, let timestamp = sdnnTimestamp {
                let age = Int(now.timeIntervalSince(timestamp) / 60)
                print("📊 SDNN from HealthKitManager: \(String(format: "%.1f", sdnn))ms, age: \(age)min")
            } else {
                print("📊 SDNN from HealthKitManager: not available")
            }
            if let rhr = restingHR {
                print("📊 Resting HR: \(Int(rhr)) BPM")
            }
            
            let metrics = stressCalculator.computeStressOpportunistic(
                heartRateSamples: hrSamples,
                recentSDNN: recentSDNN,
                sdnnTimestamp: sdnnTimestamp,
                restingHR: restingHR
            )
            
            dc = metrics.dc
            ac = metrics.ac
            sdnn = metrics.sdnn
            rmssd = metrics.rmssd
            stressScore = metrics.stressScore
            stressLevel = metrics.stressLevel
            isStressed = stressScore > adjustedThreshold
        } else if activityType == .physical {
            stressLevel = .physicalActivity
            // Don't compute stress — data invalid during movement (Bonneval 2025)
        }

        let result = PipelineResult(
            timestamp: now,
            activityType: activityType,
            activityConfidence: confidence,
            sleepHours: sleepHours,
            sleepQuality: sleepQuality,
            adjustedThreshold: adjustedThreshold,
            dc: dc, ac: ac, sdnn: sdnn, rmssd: rmssd,
            stressScore: stressScore,
            stressLevel: stressLevel,
            isStressed: isStressed,
            recoverySlope: nil  // TODO: Compute after activity→stillness transition
        )

        latestResult = result
        return result
    }

    /// Add current readings to the personal baseline (call during calm periods).
    func calibrateBaseline() async {
        let now = Date()
        let windowStart = now.addingTimeInterval(-60) // Last 60 seconds
        let hrSamples = await healthKitManager.fetchHeartRateSamples(
            from: windowStart, to: now
        )
        stressCalculator.addBaselineReading(heartRateSamples: hrSamples)
    }
}


// MARK: - Integration Example for BodyBatteryView

/*
 In BodyBatteryView.swift, add this to connect the pipeline:

 @StateObject private var pipeline: StressDetectionPipeline

 init(healthKitManager: HealthKitManager) {
     _pipeline = StateObject(wrappedValue: StressDetectionPipeline(
         healthKitManager: healthKitManager
     ))
 }

 // In your timer or refresh function:
 func updateBattery() async {
     let result = await pipeline.runFullPipeline()

     if result.activityType == .cognitive && result.isStressed {
         // Drain battery using your existing formula:
         // stressLevel * 0.2 * (duration/10)
         let drainAmount = Double(result.stressScore) * 0.002
         currentBatteryLevel -= drainAmount
     }

     // Log to ActivityManager
     if result.activityType == .physical {
         // Log as exercise (already handled by ActivityManager)
     }
 }

 // During onboarding (first 7-14 days), add calibration readings:
 func onboardingCalibration() async {
     // User is sitting still for 60 seconds
     try? await Task.sleep(nanoseconds: 60_000_000_000)
     await pipeline.calibrateBaseline()
 }
*/
