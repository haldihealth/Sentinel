import Foundation
import HealthKit

/// Service for fetching activity-related health data from HealthKit
///
/// Provides step count, calories, and distance metrics
actor ActivityHealthService {
    
    private let healthStore: HKHealthStore
    
    init(healthStore: HKHealthStore) {
        self.healthStore = healthStore
    }
    
    // MARK: - Activity Data
    
    /// Fetches step count for the past 24 hours
    func fetchStepCount() async throws -> Int {
        let steps = try await fetchCumulativeSum(for: .stepCount, unit: .count())
        return Int(steps)
    }
    
    /// Fetches active calories burned for the past 24 hours
    func fetchActiveCalories() async throws -> Double {
        return try await fetchCumulativeSum(for: .activeEnergyBurned, unit: .kilocalorie())
    }
    
    /// Fetches distance walked/run for the past 24 hours
    func fetchDistance() async throws -> Double {
        return try await fetchCumulativeSum(for: .distanceWalkingRunning, unit: HKUnit.meter())
    }
    
    /// Fetches complete activity metrics for the past 24 hours
    func fetchActivityMetrics() async throws -> ActivityMetrics {
        async let steps = fetchStepCount()
        async let calories = fetchActiveCalories()
        async let distance = fetchDistance()
        
        let (stepCount, activeCalories, distanceMeters) = try await (steps, calories, distance)
        
        return ActivityMetrics(
            date: Date(),
            stepCount: stepCount,
            activeCalories: activeCalories,
            distanceMeters: distanceMeters
        )
    }
    
    // MARK: - Helper Methods
    
    /// Generic helper to fetch cumulative sum for a given quantity type
    private func fetchCumulativeSum(for identifier: HKQuantityTypeIdentifier, unit: HKUnit) async throws -> Double {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else {
            throw HealthKitError.noDataAvailable
        }
        
        let now = Date()
        let startDate = now.addingTimeInterval(-24 * 3600)
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: now,
            options: .strictStartDate
        )
        
        let statistics = try await fetchStatistics(
            type: type,
            predicate: predicate,
            options: .cumulativeSum
        )
        
        guard let sum = statistics.sumQuantity() else {
            return 0
        }
        
        return sum.doubleValue(for: unit)
    }

    
    // MARK: - Helper Methods
    
    /// Executes an HKStatisticsQuery and returns results
    private func fetchStatistics(
        type: HKQuantityType,
        predicate: NSPredicate,
        options: HKStatisticsOptions
    ) async throws -> HKStatistics {
        return try await withCheckedThrowingContinuation { continuation in
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
}
