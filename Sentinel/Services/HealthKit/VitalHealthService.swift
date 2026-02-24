import Foundation
import HealthKit

/// Service for fetching vital signs from HealthKit (HRV, heart rate)
///
/// Provides heart rate variability and resting heart rate metrics
actor VitalHealthService {
    
    private let healthStore: HKHealthStore
    
    init(healthStore: HKHealthStore) {
        self.healthStore = healthStore
    }
    
    // MARK: - HRV Data
    
    /// Fetches the most recent HRV reading (SDNN in ms)
    func fetchHRV() async throws -> Double {
        let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
        let now = Date()
        let startDate = now.addingTimeInterval(-86400)
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: now,
            options: .strictStartDate
        )
        
        let sortDescriptor = NSSortDescriptor(
            key: HKSampleSortIdentifierEndDate,
            ascending: false
        )
        
        let samples = try await fetchSamples(
            type: hrvType,
            predicate: predicate,
            sortDescriptors: [sortDescriptor],
            limit: 1
        )
        
        guard let sample = samples.first as? HKQuantitySample else {
            throw HealthKitError.noDataAvailable
        }
        
        return sample.quantity.doubleValue(for: .secondUnit(with: .milli))
    }
    
    /// Fetches complete HRV metrics including resting heart rate
    func fetchHRVMetrics() async throws -> HRVMetrics {
        let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
        let rhrType = HKObjectType.quantityType(forIdentifier: .restingHeartRate)!
        let now = Date()
        let startDate = now.addingTimeInterval(-86400)
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: now,
            options: .strictStartDate
        )
        
        let sortDescriptor = NSSortDescriptor(
            key: HKSampleSortIdentifierEndDate,
            ascending: false
        )
        
        // Fetch HRV
        let hrvSamples = try await fetchSamples(
            type: hrvType,
            predicate: predicate,
            sortDescriptors: [sortDescriptor],
            limit: 1
        )
        
        guard let hrvSample = hrvSamples.first as? HKQuantitySample else {
            throw HealthKitError.noDataAvailable
        }
        
        let sdnn = hrvSample.quantity.doubleValue(for: .secondUnit(with: .milli))
        
        // Fetch resting heart rate (optional)
        var restingHR: Double?
        do {
            let rhrSamples = try await fetchSamples(
                type: rhrType,
                predicate: predicate,
                sortDescriptors: [sortDescriptor],
                limit: 1
            )
            if let rhrSample = rhrSamples.first as? HKQuantitySample {
                restingHR = rhrSample.quantity.doubleValue(for: .count().unitDivided(by: .minute()))
            }
        } catch {
            // Resting HR is optional, continue without it
        }
        
        return HRVMetrics(
            date: now,
            sdnn: sdnn,
            restingHeartRate: restingHR,
            measurementTime: hrvSample.endDate
        )
    }
    
    // MARK: - Helper Methods
    
    /// Executes an HKSampleQuery and returns results
    private func fetchSamples(
        type: HKSampleType,
        predicate: NSPredicate,
        sortDescriptors: [NSSortDescriptor]? = nil,
        limit: Int = HKObjectQueryNoLimit
    ) async throws -> [HKSample] {
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: limit,
                sortDescriptors: sortDescriptors
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
