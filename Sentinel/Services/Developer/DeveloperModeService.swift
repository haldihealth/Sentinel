import Foundation
import SwiftData
import os.log

/// Service for managing developer mode demo scenarios
///
/// Provides functionality to reset the app to a clean state and load
/// synthetic data for the MedGemma Kaggle Impact Competition demo.
actor DeveloperModeService {
    // MARK: - Singleton
    
    static let shared = DeveloperModeService()
    
    // MARK: - Properties
    
    private let localStorage = LocalStorage()
    private let fileManager = FileManager.default
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Main Activation
    
    /// Activates developer mode by clearing all data and loading demo scenario
    /// - Parameter modelContext: SwiftData model context for clearing records
    func activateDemoMode(modelContext: ModelContext?) async {
        Logger.ai.warning("🎬 DEVELOPER MODE: Activating demo scenario...")
        
        // 1. Clear all existing data
        await clearAllData(modelContext: modelContext)
        
        // 2. Copy discharge summary to Documents directory
        copyDischargeSummary()
        
        // 3. Create and save synthetic HealthKit baseline
        createSyntheticHealthKitBaseline()
        
        // 4. Create and save demo user profile
        createDemoUserProfile()
        
        // 5. Create and save demo safety plan
        createDemoSafetyPlan()
        
        // 6. Set developer mode active flag
        UserDefaults.standard.set(true, forKey: DeveloperModeConstants.developerModeActiveKey)
        
        Logger.ai.warning("✅ Developer mode activated. Timeline: 48h post-discharge. Patient: SENTINEL-DEMO")
    }
    
    // MARK: - Data Clearing
    
    /// Clears all user data from SwiftData and UserDefaults
    private func clearAllData(modelContext: ModelContext?) async {
        Logger.ai.info("Clearing all existing data...")
        
        // Clear SwiftData if context available
        if let context = modelContext {
            await MainActor.run {
                // Delete all CheckInRecords (cascade deletes FacialBiomarkers and AudioMetadata)
                do {
                    try context.delete(model: CheckInRecord.self)
                    try context.save()
                    Logger.ai.info("Deleted all SwiftData records")
                } catch {
                    Logger.ai.error("Failed to delete SwiftData records: \(error.localizedDescription)")
                }
            }
        }
        
        // Clear UserDefaults
        localStorage.clearAllSentinelData()
    }
    
    // MARK: - Discharge Summary
    
    /// Copies discharge summary from Resources to Documents directory
    private func copyDischargeSummary() {
        Logger.ai.info("Copying discharge summary to Documents directory...")
        
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            Logger.ai.error("Failed to get Documents directory")
            return
        }
        
        let targetURL = documentsURL.appendingPathComponent(DeveloperModeConstants.targetFilename)
        
        // Remove existing file if present
        if fileManager.fileExists(atPath: targetURL.path) {
            try? fileManager.removeItem(at: targetURL)
        }
        
        do {
            try DeveloperModeConstants.demoDischargeSummaryJSON.write(to: targetURL, atomically: true, encoding: .utf8)
            Logger.ai.info("✅ Copied discharge summary to: \(targetURL.path)")
        } catch {
            Logger.ai.error("Failed to copy discharge summary: \(error.localizedDescription)")
        }
    }
    
    // MARK: - HealthKit Baseline
    
    /// Creates and saves synthetic HealthKit baseline for z-score calculations
    private func createSyntheticHealthKitBaseline() {
        Logger.ai.info("Creating synthetic HealthKit baseline...")
        
        let baseline = DeveloperModeConstants.createSyntheticBaseline()
        localStorage.save(baseline, forKey: DeveloperModeConstants.syntheticBaselineKey)
        
        Logger.ai.info("✅ Synthetic baseline created:")
        Logger.ai.info("   Sleep: \(baseline.currentSleepHours)h (avg: \(baseline.avgSleepHours)h)")
        Logger.ai.info("   Steps: \(Int(baseline.currentSteps)) (avg: \(Int(baseline.avgSteps)))")
        Logger.ai.info("   HRV: \(baseline.currentHRV)ms (avg: \(baseline.avgHRV)ms)")
    }
    
    // MARK: - User Profile
    
    /// Creates and saves demo user profile
    private func createDemoUserProfile() {
        Logger.ai.info("Creating demo user profile...")
        
        let profile = UserProfile(
            id: UUID(),
            createdAt: DeveloperModeConstants.dischargeDate,
            callsign: DeveloperModeConstants.demoCallsign,
            isVeteran: true
        )
        
        var mutableProfile = profile
        mutableProfile.displayName = DeveloperModeConstants.demoName
        mutableProfile.branchOfService = DeveloperModeConstants.demoBranch
        mutableProfile.yearsOfService = DeveloperModeConstants.demoYearsOfService
        mutableProfile.hasCompletedOnboarding = true
        mutableProfile.hasConfiguredSafetyPlan = true
        mutableProfile.hasGrantedHealthKitAccess = true
        
        localStorage.saveUserProfile(mutableProfile)
        
        Logger.ai.info("✅ Demo profile created: \(DeveloperModeConstants.demoCallsign)")
    }
    
    // MARK: - Safety Plan
    
    /// Creates and saves demo safety plan
    private func createDemoSafetyPlan() {
        Logger.ai.info("Creating demo safety plan...")
        
        let safetyPlan = SafetyPlan(
            id: UUID(),
            lastUpdated: Date(),
            warningSigns: DeveloperModeConstants.warningSigns,
            copingStrategies: DeveloperModeConstants.copingStrategies,
            socialDistractions: DeveloperModeConstants.socialDistractions,
            supportContacts: DeveloperModeConstants.supportContacts,
            professionalContacts: DeveloperModeConstants.professionalContacts,
            environmentSafetySteps: DeveloperModeConstants.environmentSafetySteps,
            reasonsForLiving: DeveloperModeConstants.reasonsForLiving
        )
        
        localStorage.saveSafetyPlan(safetyPlan)
        
        Logger.ai.info("✅ Demo safety plan created with \(safetyPlan.professionalContacts.count) professional contacts")
    }
}
