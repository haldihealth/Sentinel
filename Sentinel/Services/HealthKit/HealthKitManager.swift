import Foundation
import HealthKit
import os.log

/// Manages HealthKit authorization and data fetching
///
/// Coordinates all HealthKit requests for sleep, activity, HRV, and other metrics.
/// All methods are actor-isolated for thread safety.
actor HealthKitManager {
    // MARK: - Properties

    private let healthStore = HKHealthStore()
    
    // Specialized Services
    private lazy var sleepService = SleepHealthService(healthStore: healthStore)
    private lazy var activityService = ActivityHealthService(healthStore: healthStore)
    private lazy var vitalService = VitalHealthService(healthStore: healthStore)

    // MARK: - Type Definitions

    /// All HealthKit types we need to read
    private var requiredTypes: Set<HKSampleType> {
        [
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!
        ]
    }

    // MARK: - Availability Check

    /// Checks if HealthKit is available on this device
    var isHealthKitAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    // MARK: - Authorization

    /// Requests HealthKit permissions for all required data types
    func requestAuthorization() async throws -> Bool {
        Logger.healthKit.info("requestAuthorization() START")
        guard isHealthKitAvailable else {
            Logger.healthKit.warning("HealthKit not available")
            throw HealthKitError.notAvailable
        }

        do {
            Logger.healthKit.debug("Calling healthStore.requestAuthorization...")
            try await healthStore.requestAuthorization(
                toShare: [],
                read: requiredTypes
            )
            Logger.healthKit.info("Authorization granted")
            return true
        } catch {
            Logger.healthKit.error("Authorization failed: \(error.localizedDescription)")
            // Re-throw as our error type for consistent handling
            throw HealthKitError.authorizationFailed(error.localizedDescription)
        }
    }

    // MARK: - Sleep Data

    /// Fetches sleep data for the past 24 hours
    // MARK: - Sleep Data (delegated to SleepHealthService)
    
    /// Fetches sleep hours for the past 24 hours
    /// - Returns: Total sleep hours (asleep time, not in-bed time)
    func fetchSleepHours() async throws -> Double {
        return try await sleepService.fetchSleepHours()
    }
    
    /// Fetches detailed sleep metrics for the past 24 hours
    func fetchSleepMetrics() async throws -> SleepMetrics {
        return try await sleepService.fetchSleepMetrics()
    }


    // MARK: - Activity Data (delegated to ActivityHealthService)
    
    /// Fetches step count for the past 24 hours
    func fetchStepCount() async throws -> Int {
        return try await activityService.fetchStepCount()
    }
    
    /// Fetches active calories burned for the past 24 hours
    func fetchActiveCalories() async throws -> Double {
        return try await activityService.fetchActiveCalories()
    }
    
    /// Fetches distance walked/run for the past 24 hours
    func fetchDistance() async throws -> Double {
        return try await activityService.fetchDistance()
    }
    
    /// Fetches complete activity metrics for the past 24 hours
    func fetchActivityMetrics() async throws -> ActivityMetrics {
        return try await activityService.fetchActivityMetrics()
    }


    // MARK: - HRV Data (delegated to VitalHealthService)
    
    /// Fetches the most recent HRV reading (SDNN in ms)
    func fetchHRV() async throws -> Double {
        return try await vitalService.fetchHRV()
    }
    
    /// Fetches complete HRV metrics including resting heart rate
    func fetchHRVMetrics() async throws ->HRVMetrics {
        return try await vitalService.fetchHRVMetrics()
    }


    // MARK: - Baseline Calculations (30-day rolling average)

    /// Fetches 30 days of sleep data and calculates baseline
    func fetchSleepBaseline() async throws -> (average: Double, stdDev: Double) {
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let now = Date()
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: now)!

        // Get daily sleep totals for the past 30 days
        var dailySleep: [Double] = []

        for dayOffset in 0..<30 {
            let dayStart = Calendar.current.date(byAdding: .day, value: -(dayOffset + 1), to: now)!
            let dayEnd = Calendar.current.date(byAdding: .day, value: -dayOffset, to: now)!

            let predicate = HKQuery.predicateForSamples(
                withStart: dayStart,
                end: dayEnd,
                options: .strictStartDate
            )

            do {
                let samples = try await fetchSamples(type: sleepType, predicate: predicate)
                let sleepSamples = samples.compactMap { $0 as? HKCategorySample }
                    .filter { sample in
                        let value = sample.value
                        return value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue ||
                               value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                               value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                               value == HKCategoryValueSleepAnalysis.asleepREM.rawValue
                    }

                let totalSeconds = sleepSamples.reduce(0.0) { total, sample in
                    total + sample.endDate.timeIntervalSince(sample.startDate)
                }

                let hours = totalSeconds / 3600.0
                if hours > 0 {
                    dailySleep.append(hours)
                }
            } catch {
                // Skip days with no data
            }
        }

        guard !dailySleep.isEmpty else {
            throw HealthKitError.noDataAvailable
        }

        return calculateMeanAndStdDev(dailySleep)
    }

    /// Fetches 30 days of step data and calculates baseline
    func fetchStepsBaseline() async throws -> (average: Double, stdDev: Double) {
        let stepType = HKObjectType.quantityType(forIdentifier: .stepCount)!
        let now = Date()

        var dailySteps: [Double] = []

        for dayOffset in 0..<30 {
            let dayStart = Calendar.current.startOfDay(
                for: Calendar.current.date(byAdding: .day, value: -(dayOffset + 1), to: now)!
            )
            let dayEnd = Calendar.current.startOfDay(
                for: Calendar.current.date(byAdding: .day, value: -dayOffset, to: now)!
            )

            let predicate = HKQuery.predicateForSamples(
                withStart: dayStart,
                end: dayEnd,
                options: .strictStartDate
            )

            do {
                let statistics = try await fetchStatistics(
                    type: stepType,
                    predicate: predicate,
                    options: .cumulativeSum
                )

                if let sum = statistics.sumQuantity() {
                    dailySteps.append(sum.doubleValue(for: .count()))
                }
            } catch {
                // Skip days with no data
            }
        }

        guard !dailySteps.isEmpty else {
            throw HealthKitError.noDataAvailable
        }

        return calculateMeanAndStdDev(dailySteps)
    }

    /// Fetches 30 days of HRV data and calculates baseline
    func fetchHRVBaseline() async throws -> (average: Double, stdDev: Double) {
        let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
        let now = Date()
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: now)!

        let predicate = HKQuery.predicateForSamples(
            withStart: thirtyDaysAgo,
            end: now,
            options: .strictStartDate
        )

        let samples = try await fetchSamples(type: hrvType, predicate: predicate)
        let hrvValues = samples.compactMap { $0 as? HKQuantitySample }
            .map { $0.quantity.doubleValue(for: .secondUnit(with: .milli)) }

        guard !hrvValues.isEmpty else {
            throw HealthKitError.noDataAvailable
        }

        return calculateMeanAndStdDev(hrvValues)
    }

    /// Fetches complete baseline for all metrics
    func fetchBaseline() async throws -> Baseline {
        var baseline = Baseline()

        // Fetch all baselines concurrently
        async let sleepBaseline = fetchSleepBaseline()
        async let stepsBaseline = fetchStepsBaseline()
        async let hrvBaseline = fetchHRVBaseline()

        // Sleep baseline
        if let (avg, stdDev) = try? await sleepBaseline {
            baseline.avgSleepHours = avg
            baseline.sleepStdDev = stdDev
        }

        // Steps baseline
        if let (avg, stdDev) = try? await stepsBaseline {
            baseline.avgSteps = avg
            baseline.stepsStdDev = stdDev
        }

        // HRV baseline
        if let (avg, stdDev) = try? await hrvBaseline {
            baseline.avgHRV = avg
            baseline.hrvStdDev = stdDev
        }

        baseline.lastUpdated = Date()
        return baseline
    }

    // MARK: - Simulation Support
    
    /// Use simulated data instead of real HealthKit data
    private var isSimulationMode: Bool = false
    
    /// The data to return when in simulation mode
    private var simulatedData: HealthData?
    
    /// Enable simulation mode with specific data
    func enableSimulation(with data: HealthData) {
        self.isSimulationMode = true
        self.simulatedData = data
        Logger.healthKit.warning("HealthKit Simulation Enabled via enableSimulation")
    }
    
    /// Disable simulation mode
    func disableSimulation() {
        self.isSimulationMode = false
        self.simulatedData = nil
        Logger.healthKit.info("HealthKit Simulation Disabled")
    }
    
    /// Check if simulation is active
    var isSimulationActive: Bool {
        isSimulationMode
    }

    // MARK: - Aggregate Health Data

    /// Fetches all health data needed for a check-in
    /// - Parameter timeout: Optional timeout in seconds. If nil, waits indefinitely (or system default).
    func fetchHealthData(timeout: TimeInterval? = nil) async throws -> HealthData {
        // Check for simulation mode
        if isSimulationMode, let data = simulatedData {
            Logger.healthKit.warning("Returning SIMULATED HealthKit Data: Sleep=\(data.sleep.totalSleepHours)h, Steps=\(data.activity.stepCount), HRV=\(data.hrv.sdnn)ms")
            return data
        }
        
        if let timeout = timeout {
            return try await AsyncHelpers.withTimeout(seconds: timeout) {
                try await self.performHealthDataFetch()
            }
        } else {
            return try await performHealthDataFetch()
        }
    }

    /// Internal implementation of health data fetch
    private func performHealthDataFetch() async throws -> HealthData {
        // Check for developer mode synthetic baseline
        if UserDefaults.standard.bool(forKey: DeveloperModeConstants.developerModeActiveKey) == true,
           let synthetic: SyntheticHealthKitBaseline = LocalStorage().load(forKey: DeveloperModeConstants.syntheticBaselineKey) {
            
            Logger.healthKit.warning("🎬 DEVELOPER MODE: Returning synthetic baseline with z-scores")
            
            // Convert synthetic baseline to HealthData
            let sleepMetrics = SleepMetrics(
                date: Date(),
                totalSleepHours: synthetic.currentSleepHours,
                timeInBedHours: nil
            )
            
            let activityMetrics = ActivityMetrics(
                date: Date(),
                stepCount: Int(synthetic.currentSteps),
                activeCalories: 0,
                distanceMeters: 0
            )
            
            let hrvMetrics = HRVMetrics(
                date: Date(),
                sdnn: synthetic.currentHRV,
                restingHeartRate: nil,
                measurementTime: Date()
            )
            
            let baseline = Baseline(lastUpdated: synthetic.lastUpdated)
            var mutableBaseline = baseline
            mutableBaseline.avgSleepHours = synthetic.avgSleepHours
            mutableBaseline.sleepStdDev = synthetic.sleepStdDev
            mutableBaseline.avgSteps = synthetic.avgSteps
            mutableBaseline.stepsStdDev = synthetic.stepsStdDev
            mutableBaseline.avgHRV = synthetic.avgHRV
            mutableBaseline.hrvStdDev = synthetic.hrvStdDev
            
            let data = HealthData(
                sleep: sleepMetrics,
                activity: activityMetrics,
                hrv: hrvMetrics,
                baseline: mutableBaseline
            )
            
            // Log z-scores for console output in video
            if let sleepZ = mutableBaseline.sleepZScore(current: synthetic.currentSleepHours) {
                Logger.healthKit.warning("📊 Sleep Z-Score: \(String(format: "%.1f", sleepZ)) SD (CRITICAL)")
            }
            if let stepsZ = mutableBaseline.stepsZScore(current: synthetic.currentSteps) {
                Logger.healthKit.warning("📊 Activity Z-Score: \(String(format: "%.1f", stepsZ)) SD (CONCERNING)")
            }
            if let hrvZ = mutableBaseline.hrvZScore(current: synthetic.currentHRV) {
                Logger.healthKit.warning("📊 HRV Z-Score: \(String(format: "%.1f", hrvZ)) SD (SIGNIFICANT)")
            }
            
            return data
        }
        
        // Otherwise, proceed with real HealthKit fetch
        Logger.healthKit.info("fetchHealthData() - starting parallel fetches")

        // Fetch with graceful error handling - missing data is not a fatal error
        Logger.healthKit.debug("Fetching sleep...")
        let sleepMetrics: SleepMetrics
        do {
            sleepMetrics = try await fetchSleepMetrics()
            Logger.healthKit.debug("Sleep done: \(sleepMetrics.totalSleepHours)h")
        } catch {
            Logger.healthKit.warning("Sleep fetch failed (using defaults): \(error.localizedDescription)")
            sleepMetrics = SleepMetrics(date: Date(), totalSleepHours: 0, timeInBedHours: nil)
        }

        Logger.healthKit.debug("Fetching activity...")
        let activityMetrics: ActivityMetrics
        do {
            activityMetrics = try await fetchActivityMetrics()
            Logger.healthKit.debug("Activity done: \(activityMetrics.stepCount) steps")
        } catch {
            Logger.healthKit.warning("Activity fetch failed (using defaults): \(error.localizedDescription)")
            activityMetrics = ActivityMetrics(date: Date(), stepCount: 0, activeCalories: 0, distanceMeters: 0)
        }

        Logger.healthKit.debug("Fetching HRV...")
        let hrvMetrics: HRVMetrics
        do {
            hrvMetrics = try await fetchHRVMetrics()
            Logger.healthKit.debug("HRV done: \(hrvMetrics.sdnn)ms")
        } catch {
            Logger.healthKit.warning("HRV fetch failed (using defaults): \(error.localizedDescription)")
            hrvMetrics = HRVMetrics(date: Date(), sdnn: 0, restingHeartRate: nil, measurementTime: Date())
        }

        Logger.healthKit.debug("Fetching baseline...")
        let baselineData: Baseline
        do {
            baselineData = try await fetchBaseline()
            Logger.healthKit.debug("Baseline done")
        } catch {
            Logger.healthKit.warning("Baseline fetch failed (using defaults): \(error.localizedDescription)")
            var defaultBaseline = Baseline()
            defaultBaseline.avgSleepHours = 7.0
            defaultBaseline.avgSteps = 5000
            defaultBaseline.avgHRV = 50.0
            baselineData = defaultBaseline
        }

        Logger.healthKit.info("All fetches complete")
        return HealthData(
            sleep: sleepMetrics,
            activity: activityMetrics,
            hrv: hrvMetrics,
            baseline: baselineData
        )
    }

    // MARK: - Private Helpers

    /// Generic sample fetching with async/await
    // Thread-safe wrapper to manage HKQuery state and continuation
    private class HealthKitQueryGuard: @unchecked Sendable {
        private var query: HKQuery?
        private var continuation: CheckedContinuation<[HKSample], Error>?
        private var isResumed = false
        private var isCancelled = false
        private let lock = NSLock()
        
        // Returns true if query was set successfully (not cancelled yet).
        // Returns false if already cancelled (caller should stop query immediately).
        func setQuery(_ query: HKQuery) -> Bool {
            lock.lock()
            defer { lock.unlock() }
            self.query = query
            return !isCancelled
        }
        
        func setContinuation(_ continuation: CheckedContinuation<[HKSample], Error>) -> Bool {
            lock.lock()
            defer { lock.unlock() }
            if isCancelled {
                continuation.resume(throwing: CancellationError())
                isResumed = true
                return false // Should not execute query
            }
            self.continuation = continuation
            return true // Proceed
        }
        
        func finish(with result: Result<[HKSample], Error>) {
            lock.lock()
            defer { lock.unlock() }
            guard !isResumed else { return }
            
            switch result {
            case .success(let data): continuation?.resume(returning: data)
            case .failure(let error): continuation?.resume(throwing: error)
            }
            isResumed = true
            continuation = nil // Release
        }
        
        func cancel() -> HKQuery? {
            lock.lock()
            defer { lock.unlock() }
            isCancelled = true
            guard !isResumed else { return query }
            
            continuation?.resume(throwing: CancellationError())
            isResumed = true
            continuation = nil
            return query
        }
    }

    private func fetchSamples(
        type: HKSampleType,
        predicate: NSPredicate,
        sortDescriptors: [NSSortDescriptor]? = nil,
        limit: Int = HKObjectQueryNoLimit
    ) async throws -> [HKSample] {
        Logger.healthKit.debug("fetchSamples for \(type.identifier) - Preparing query")
        
        let guardWrapper = HealthKitQueryGuard()
        // Capture healthStore for cancellation handler
        let store = self.healthStore
        
        return try await withTaskCancellationHandler {
            return try await withCheckedThrowingContinuation { continuation in
                // 1. Register continuation
                let shouldExecute = guardWrapper.setContinuation(continuation)
                guard shouldExecute else {
                    Logger.healthKit.warning("fetchSamples already cancelled during setup.")
                    return
                }
                
                // 2. Create Query
                let query = HKSampleQuery(
                    sampleType: type,
                    predicate: predicate,
                    limit: limit,
                    sortDescriptors: sortDescriptors
                ) { _, samples, error in
                    // 4. Handle Completion
                    Logger.healthKit.debug("fetchSamples callback for \(type.identifier). Error: \(String(describing: error)), Samples: \(samples?.count ?? 0)")
                    if let error = error {
                        guardWrapper.finish(with: .failure(error))
                    } else {
                        guardWrapper.finish(with: .success(samples ?? []))
                    }
                }
                
                // Register query. If already cancelled, stop immediately.
                if !guardWrapper.setQuery(query) {
                    Logger.healthKit.warning("fetchSamples cancelled before execution - Stopping query.")
                    store.stop(query)
                } 
                
                // 3. Execute
                Logger.healthKit.debug("Executing query for \(type.identifier)")
                store.execute(query)
            }
        } onCancel: {
            Logger.healthKit.warning("fetchSamples cancelled for \(type.identifier) - SAFE Cancel Triggered.")
            // 5. Handle Cancellation
            if let query = guardWrapper.cancel() {
                store.stop(query)
            }
        }
    }

    /// Statistics query with async/await
    private func fetchStatistics(
        type: HKQuantityType,
        predicate: NSPredicate,
        options: HKStatisticsOptions
    ) async throws -> HKStatistics {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: options
            ) { _, statistics, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let statistics = statistics {
                    continuation.resume(returning: statistics)
                } else {
                    continuation.resume(throwing: HealthKitError.noDataAvailable)
                }
            }

            healthStore.execute(query)
        }
    }

    /// Calculates mean and standard deviation for an array of values
    private func calculateMeanAndStdDev(_ values: [Double]) -> (average: Double, stdDev: Double) {
        // Guard against divide-by-zero
        guard !values.isEmpty else {
            return (average: 0.0, stdDev: 0.0)
        }
        
        let count = Double(values.count)
        let mean = values.reduce(0, +) / count

        let variance = values.reduce(0) { sum, value in
            sum + pow(value - mean, 2)
        } / count

        let stdDev = sqrt(variance)
        return (mean, stdDev)
    }
}

// MARK: - Error Types

enum HealthKitError: LocalizedError {
    case notAvailable
    case noDataAvailable
    case authorizationDenied
    case authorizationFailed(String)
    case queryFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "HealthKit is not available on this device"
        case .noDataAvailable:
            return "No health data available for the requested time period"
        case .authorizationDenied:
            return "HealthKit authorization was denied"
        case .authorizationFailed(let reason):
            return "HealthKit authorization failed: \(reason)"
        case .queryFailed(let error):
            return "Failed to query HealthKit: \(error.localizedDescription)"
        }
    }
}

// MARK: - Aggregate Data Structure

/// Bundles all health metrics for a check-in
struct HealthData: Sendable {
    let sleep: SleepMetrics
    let activity: ActivityMetrics
    let hrv: HRVMetrics
    let baseline: Baseline

    /// Calculates z-scores for deviation detection
    var deviations: HealthDeviations {
        HealthDeviations(
            sleepZScore: baseline.sleepZScore(current: sleep.totalSleepHours),
            stepsZScore: baseline.stepsZScore(current: Double(activity.stepCount)),
            hrvZScore: baseline.hrvZScore(current: hrv.sdnn)
        )
    }
}

/// Z-score deviations from baseline
struct HealthDeviations: Sendable {
    let sleepZScore: Double?
    let stepsZScore: Double?
    let hrvZScore: Double?

    /// Returns true if any metric shows significant negative deviation (> 2 std dev)
    var hasSignificantDeviation: Bool {
        if let sleep = sleepZScore, sleep < -2.0 { return true }
        if let steps = stepsZScore, steps < -2.0 { return true }
        if let hrv = hrvZScore, hrv < -2.0 { return true }
        return false
    }

    /// Count of metrics showing concerning deviation (> 1.5 std dev below baseline)
    var concerningDeviationCount: Int {
        var count = 0
        if let sleep = sleepZScore, sleep < -1.5 { count += 1 }
        if let steps = stepsZScore, steps < -1.5 { count += 1 }
        if let hrv = hrvZScore, hrv < -1.5 { count += 1 }
        return count
    }
}
