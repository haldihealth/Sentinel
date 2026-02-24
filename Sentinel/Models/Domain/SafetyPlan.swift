import Foundation

/// Stanley-Brown Safety Plan for crisis intervention
///
/// A personalized safety plan following the evidence-based Stanley-Brown protocol.
/// Contains warning signs, coping strategies, and emergency contacts.
struct SafetyPlan: Identifiable, Codable {
    // MARK: - Properties

    let id: UUID
    var lastUpdated: Date

    // MARK: - Step 1: Warning Signs

    /// Personal warning signs that a crisis may be developing
    var warningSigns: [String]

    // MARK: - Step 2: Internal Coping Strategies

    /// Things I can do to take my mind off problems without others
    var copingStrategies: [String]

    // MARK: - Step 3: Social Distractions

    /// People and places that provide distraction
    var socialDistractions: [SocialContact]

    // MARK: - Step 4: People to Ask for Help

    /// People I can ask for help (not professionals)
    var supportContacts: [SocialContact]

    // MARK: - Step 5: Professionals/Agencies

    /// Professional contacts and crisis lines
    var professionalContacts: [ProfessionalContact]

    // MARK: - Step 6: Making Environment Safe

    /// Steps to make environment safe (remove means)
    var environmentSafetySteps: [String]

    // MARK: - Reasons for Living

    /// Personal reasons for living
    var reasonsForLiving: [String]

    // MARK: - Battle Buddy

    /// Primary emergency contact (Battle Buddy)
    var battleBuddy: SocialContact?

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        lastUpdated: Date = Date(),
        warningSigns: [String] = [],
        copingStrategies: [String] = [],
        socialDistractions: [SocialContact] = [],
        supportContacts: [SocialContact] = [],
        professionalContacts: [ProfessionalContact] = [],
        environmentSafetySteps: [String] = [],
        reasonsForLiving: [String] = []
    ) {
        self.id = id
        self.lastUpdated = lastUpdated
        self.warningSigns = warningSigns
        self.copingStrategies = copingStrategies
        self.socialDistractions = socialDistractions
        self.supportContacts = supportContacts
        self.professionalContacts = professionalContacts
        self.environmentSafetySteps = environmentSafetySteps
        self.reasonsForLiving = reasonsForLiving
    }
}

// MARK: - Supporting Types

/// A social contact for the safety plan
struct SocialContact: Identifiable, Codable {
    let id: UUID
    var name: String
    var phoneNumber: String?
    var relationship: String?

    init(
        id: UUID = UUID(),
        name: String,
        phoneNumber: String? = nil,
        relationship: String? = nil
    ) {
        self.id = id
        self.name = name
        self.phoneNumber = phoneNumber
        self.relationship = relationship
    }
}

/// A professional contact (therapist, crisis line, etc.)
struct ProfessionalContact: Identifiable, Codable {
    let id: UUID
    var name: String
    var phoneNumber: String
    var organization: String?
    var isEmergency: Bool
    var isTextOnly: Bool

    init(
        id: UUID = UUID(),
        name: String,
        phoneNumber: String,
        organization: String? = nil,
        isEmergency: Bool = false,
        isTextOnly: Bool = false
    ) {
        self.id = id
        self.name = name
        self.phoneNumber = phoneNumber
        self.organization = organization
        self.isEmergency = isEmergency
        self.isTextOnly = isTextOnly
    }
}
