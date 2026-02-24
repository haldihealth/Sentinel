import Foundation

/// Pre-populated suggestion chips for Safety Plan steps
/// Based on common responses from Stanley-Brown Safety Plan clinical use
enum SafetyPlanSuggestions {

    // MARK: - Step 1: Warning Signs

    /// Common warning signs that a crisis may be developing
    static let warningSigns: [String] = [
        "Feeling hopeless",
        "Isolating from others",
        "Increased irritability",
        "Racing thoughts",
        "Trouble sleeping",
        "Nightmares",
        "Feeling like a burden",
        "Drinking more alcohol",
        "Anger outbursts",
        "Feeling numb",
        "Flashbacks",
        "Avoiding people",
        "Not eating",
        "Crying spells",
        "Feeling trapped",
        "Thoughts of death"
    ]

    // MARK: - Step 2: Internal Coping Strategies

    /// Things to do without contacting another person
    static let copingStrategies: [String] = [
        "Go for a walk or run",
        "Deep breathing exercises",
        "Listen to music",
        "Take a shower",
        "Watch a favorite show",
        "Play video games",
        "Work out",
        "Write in a journal",
        "Pray or meditate",
        "Play with my pet",
        "Clean or organize",
        "Cook a meal",
        "Work on a hobby",
        "Go for a drive",
        "Read a book",
        "Do yard work"
    ]

    // MARK: - Step 6: Environment Safety

    /// Common steps to make environment safer
    static let environmentSafetySteps: [String] = [
        "Lock up firearms at a friend's house",
        "Give firearms to trusted person",
        "Store medications with someone else",
        "Limit access to alcohol",
        "Remove sharp objects",
        "Ask someone to hold my keys",
        "Install gun lock",
        "Use medication lockbox",
        "Remove ropes/cords",
        "Ask family to secure items",
        "Store ammunition separately",
        "Dispose of old medications"
    ]

    // MARK: - Step 7: Reasons for Living

    /// Common reasons for living
    static let reasonsForLiving: [String] = [
        "My children",
        "My spouse/partner",
        "My parents",
        "My pets",
        "My faith",
        "My friends",
        "Future goals",
        "My siblings",
        "Grandchildren",
        "Military brothers/sisters",
        "Making a difference",
        "Seeing kids grow up",
        "Travel plans",
        "Career goals",
        "Sports/hobbies",
        "Music"
    ]

    // MARK: - Contact Role Suggestions

    /// Common roles for support contacts
    static let contactRoles: [String] = [
        "Battle Buddy",
        "Spouse",
        "Parent",
        "Sibling",
        "Best Friend",
        "Coworker",
        "Neighbor",
        "Church Member",
        "Veteran Friend",
        "Mentor"
    ]

    /// Common roles for professional contacts
    static let professionalRoles: [String] = [
        "Therapist",
        "Psychiatrist",
        "VA Counselor",
        "Primary Care",
        "Chaplain",
        "Vet Center",
        "Crisis Line"
    ]

    // MARK: - Default Professional Contacts

    /// Pre-populated crisis resources
    static let defaultProfessionalContacts: [ProfessionalContact] = [
        ProfessionalContact(
            name: "Veterans Crisis Line",
            phoneNumber: "988",
            organization: "VA",
            isEmergency: true
        ),
        ProfessionalContact(
            name: "Crisis Text Line",
            phoneNumber: "741741",
            organization: "Text HOME to this number",
            isEmergency: true,
            isTextOnly: true
        )
    ]
}
