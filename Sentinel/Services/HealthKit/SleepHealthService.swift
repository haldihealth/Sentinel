import Foundation
import HealthKit

/// Service for fetching sleep-related health data from HealthKit
///
/// Provides simple and detailed sleep metrics for analysis
actor SleepHealthService {
    
    private let healthStore: HKHealthStore
    
    init(healthStore: HKHealthStore) {
        self.healthStore = healthStore
    }
    
    // MARK: - Sleep Data
    
    /// Fetches total sleep hours for the past 24 hours
    /// - Returns: Total sleep hours (asleep time, not in-bed time)
    func fetchSleepHours() async throws -> Double {
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now.addingTimeInterval(-86400))
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: now,
            options: .strictStartDate
        )
        
        let samples = try await fetchSamples(
            type: sleepType,
            predicate: predicate
        )
        
        // Filter for actual sleep (not in-bed)
        let sleepSamples = samples.compactMap { $0 as? HKCategorySample }
            .filter { sample in
                let value = sample.value
                return value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue ||
                       value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                       value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                       value == HKCategoryValueSleepAnalysis.asleepREM.rawValue
            }
        
        // Calculate total sleep duration in hours
        let totalSeconds = sleepSamples.reduce(0.0) { total, sample in
            total + sample.endDate.timeIntervalSince(sample.startDate)
        }
        
        return totalSeconds / 3600.0
    }
    
    /// Fetches detailed sleep metrics for the past 24 hours
    func fetchSleepMetrics() async throws -> SleepMetrics {
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now.addingTimeInterval(-86400))
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: now,
            options: .strictStartDate
        )
        
        let samples = try await fetchSamples(type: sleepType, predicate: predicate)
        let sleepSamples = samples.compactMap { $0 as? HKCategorySample }
        
        var totalSleepSeconds: TimeInterval = 0
        var inBedSeconds: TimeInterval = 0
        var deepSleepSeconds: TimeInterval = 0
        var remSleepSeconds: TimeInterval = 0
        var coreSleepSeconds: TimeInterval = 0
        var awakeSeconds: TimeInterval = 0
        var earliestStart: Date?
        var latestEnd: Date?
        
        for sample in sleepSamples {
            let duration = sample.endDate.timeIntervalSince(sample.startDate)
            let value = sample.value
            
            // Track bedtime and wake time
            if earliestStart == nil || sample.startDate < earliestStart! {
                earliestStart = sample.startDate
            }
            if latestEnd == nil || sample.endDate > latestEnd! {
                latestEnd = sample.endDate
            }
            
            switch value {
            case HKCategoryValueSleepAnalysis.inBed.rawValue:
                inBedSeconds += duration
            case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
                totalSleepSeconds += duration
            case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                coreSleepSeconds += duration
                totalSleepSeconds += duration
            case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                deepSleepSeconds += duration
                totalSleepSeconds += duration
            case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                remSleepSeconds += duration
                totalSleepSeconds += duration
            case HKCategoryValueSleepAnalysis.awake.rawValue:
                awakeSeconds += duration
            default:
                break
            }
        }
        
        var metrics = SleepMetrics(
            date: now,
            totalSleepHours: totalSleepSeconds / 3600.0,
            timeInBedHours: inBedSeconds > 0 ? inBedSeconds / 3600.0 : nil
        )
        
        metrics.deepSleepHours = deepSleepSeconds > 0 ? deepSleepSeconds / 3600.0 : nil
        metrics.remSleepHours = remSleepSeconds > 0 ? remSleepSeconds / 3600.0 : nil
        metrics.lightSleepHours = coreSleepSeconds > 0 ? coreSleepSeconds / 3600.0 : nil
        metrics.awakeMinutes = awakeSeconds > 0 ? awakeSeconds / 60.0 : nil
        metrics.bedtime = earliestStart
        metrics.wakeTime = latestEnd
        
        return metrics
    }
    
    // MARK: - Helper Methods
    
    /// Executes an HKSampleQuery and returns results
    private func fetchSamples(
        type: HKSampleType,
        predicate: NSPredicate
    ) async throws -> [HKSample] {
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: samples ?? [])
                }
            }
            healthStore.execute(query)
        }
    }
}
