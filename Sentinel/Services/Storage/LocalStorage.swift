import Foundation
import os.log

/// Handles local persistent storage of check-ins and user data
///
/// Manages saving and retrieving check-ins, safety plans, and user profiles.
/// Uses UserDefaults for small data and file storage for larger objects.
final class LocalStorage: Sendable {
    // MARK: - Properties

    private let userDefaults = UserDefaults.standard
    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // MARK: - Initialization

    init() {}

    // MARK: - Generic Codable Storage

    /// Save any Codable object to UserDefaults
    func save<T: Codable>(_ object: T, forKey key: String) {
        do {
            let data = try encoder.encode(object)
            userDefaults.set(data, forKey: key)
        } catch {
            Logger.storage.error("Failed to save \(key): \(error.localizedDescription)")
        }
    }

    /// Load any Codable object from UserDefaults
    func load<T: Codable>(forKey key: String) -> T? {
        guard let data = userDefaults.data(forKey: key) else {
            return nil
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            Logger.storage.error("Failed to load \(key): \(error.localizedDescription)")
            return nil
        }
    }

    /// Remove object from UserDefaults
    func remove(forKey key: String) {
        userDefaults.removeObject(forKey: key)
    }

    /// Check if key exists
    func exists(forKey key: String) -> Bool {
        userDefaults.object(forKey: key) != nil
    }

    // MARK: - Check-In Storage
    

    
    // MARK: - Storage Keys

    private enum Keys {
        static let userProfile = "sentinel.user.profile"
        static let safetyPlan = "sentinel.safety.plan"
        static let lcscState = "sentinel.lcsc.state"
        static let crisisHistory = "sentinel.crisis.history"
        static let crisisEnteredAt = "sentinel.crisis.enteredAt"
        static let hopeBox = "sentinel.hope.box"
    }

    // MARK: - Safety Plan Storage

    /// Saves the user's safety plan
    func saveSafetyPlan(_ plan: SafetyPlan) {
        save(plan, forKey: Keys.safetyPlan)
    }

    /// Retrieves the user's safety plan
    func fetchSafetyPlan() -> SafetyPlan? {
        load(forKey: Keys.safetyPlan)
    }

    // MARK: - User Profile Storage

    /// Retrieves the user's profile
    func loadUserProfile() -> UserProfile? {
        load(forKey: Keys.userProfile)
    }

    /// Saves the user's profile
    func saveUserProfile(_ profile: UserProfile) {
        save(profile, forKey: Keys.userProfile)
    }

    // MARK: - Hope Box Storage

    /// Saves the user's hope box
    func saveHopeBox(_ hopeBox: HopeBox) {
        save(hopeBox, forKey: Keys.hopeBox)
    }

    /// Retrieves the user's hope box
    func loadHopeBox() -> HopeBox? {
        load(forKey: Keys.hopeBox)
    }

    // MARK: - LCSC State Storage

    /// Saves LCSC state for longitudinal context
    func saveLCSCState(_ state: LCSCState) {
        save(state, forKey: Keys.lcscState)
    }

    /// Loads LCSC state
    func loadLCSCState() -> LCSCState? {
        load(forKey: Keys.lcscState)
    }

    // MARK: - Crisis Management

    /// Records crisis resolution event
    func recordCrisisResolution(startTime: Date, endTime: Date) {
        var history: [CrisisResolution] = load(forKey: Keys.crisisHistory) ?? []
        history.append(CrisisResolution(startTime: startTime, endTime: endTime))

        // Keep only last 30 days of crisis history
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        history = history.filter { $0.startTime > thirtyDaysAgo }

        save(history, forKey: Keys.crisisHistory)
    }

    /// Gets crisis count in last 24 hours (for pattern lock)
    func crisisCountInLast24Hours() -> Int {
        let history: [CrisisResolution] = load(forKey: Keys.crisisHistory) ?? []
        let oneDayAgo = Date().addingTimeInterval(-86400)
        return history.filter { $0.startTime > oneDayAgo }.count
    }

    // MARK: - Active Crisis Timestamp

    /// Persists the moment the current crisis episode began
    func saveCrisisEnteredAt(_ date: Date) {
        save(date, forKey: Keys.crisisEnteredAt)
    }

    /// Retrieves the persisted crisis start time, or nil if no active crisis
    func loadCrisisEnteredAt() -> Date? {
        load(forKey: Keys.crisisEnteredAt)
    }

    /// Clears the persisted crisis start time (called on resolution)
    func clearCrisisEnteredAt() {
        remove(forKey: Keys.crisisEnteredAt)
    }
    
    // MARK: - Developer Mode
    
    /// Clear all Sentinel data from UserDefaults (for developer mode reset)
    func clearAllSentinelData() {
        remove(forKey: Keys.userProfile)
        remove(forKey: Keys.safetyPlan)
        remove(forKey: Keys.lcscState)
        remove(forKey: Keys.crisisHistory)
        remove(forKey: Keys.crisisEnteredAt)
        // remove(forKey: Keys.hopeBox) // Preserved for Demo Mode 
        
        // Clear developer mode flags
        UserDefaults.standard.removeObject(forKey: DeveloperModeConstants.developerModeActiveKey)
        UserDefaults.standard.removeObject(forKey: DeveloperModeConstants.syntheticBaselineKey)
        
        // Clear onboarding flags
        UserDefaults.standard.removeObject(forKey: "onboarding.biometrics")
        
        Logger.storage.info("Cleared all Sentinel data from UserDefaults")
    }
}

// MARK: - Supporting Types

struct CrisisResolution: Codable {
    let startTime: Date
    let endTime: Date
    let id: UUID

    init(startTime: Date, endTime: Date, id: UUID = UUID()) {
        self.startTime = startTime
        self.endTime = endTime
        self.id = id
    }
}
