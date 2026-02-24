import Foundation

/// User profile containing veteran information and preferences
///
/// Stores user-specific data, preferences, and onboarding status.
struct UserProfile: Codable {
    // MARK: - Properties

    let id: UUID
    var createdAt: Date

    // MARK: - Basic Info

    var callsign: String
    var displayName: String?
    var preferredName: String?

    // MARK: - Veteran Status

    var isVeteran: Bool
    var branchOfService: MilitaryBranch?
    var yearsOfService: Int?

    // MARK: - App State

    var hasCompletedOnboarding: Bool
    var hasConfiguredSafetyPlan: Bool
    var hasGrantedHealthKitAccess: Bool

    // MARK: - Preferences

    var preferredCheckInTime: DateComponents?
    var enableNotifications: Bool
    var enableBattleBuddyAlerts: Bool

    // MARK: - Streaks

    var currentStreak: Int
    var longestStreak: Int
    var lastCheckInDate: Date?

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        callsign: String = "SENTINEL-1",
        isVeteran: Bool = true
    ) {
        self.id = id
        self.createdAt = createdAt
        self.callsign = callsign
        self.isVeteran = isVeteran
        self.hasCompletedOnboarding = false
        self.hasConfiguredSafetyPlan = false
        self.hasGrantedHealthKitAccess = false
        self.enableNotifications = true
        self.enableBattleBuddyAlerts = true
        self.currentStreak = 0
        self.longestStreak = 0
    }
}

// MARK: - Supporting Types

/// Military branch of service
enum MilitaryBranch: String, Codable, CaseIterable {
    case army = "Army"
    case navy = "Navy"
    case airForce = "Air Force"
    case marines = "Marines"
    case coastGuard = "Coast Guard"
    case spaceForce = "Space Force"
    case nationalGuard = "National Guard"
    case reserves = "Reserves"
}
