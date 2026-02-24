import Foundation
import SwiftUI

/// Represents the 7 Stanley-Brown safety plan sections as a reorderable unit.
/// MedGemma reranks these based on clinical context during crisis.
enum SafetyPlanSection: Int, CaseIterable, Identifiable, Equatable {
    case warningSigns = 1
    case copingStrategies = 2
    case socialDistractions = 3
    case supportContacts = 4
    case professionalContacts = 5
    case environmentSafety = 6
    case reasonsForLiving = 7

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .warningSigns: return "WARNING SIGNS"
        case .copingStrategies: return "COPING STRATEGIES"
        case .socialDistractions: return "SOCIAL DISTRACTIONS"
        case .supportContacts: return "SUPPORT CONTACTS"
        case .professionalContacts: return "PROFESSIONAL HELP"
        case .environmentSafety: return "LETHAL MEANS REDUCTION"
        case .reasonsForLiving: return "REASONS FOR LIVING"
        }
    }

    var icon: String {
        switch self {
        case .warningSigns: return "exclamationmark.triangle"
        case .copingStrategies: return "brain"
        case .socialDistractions: return "person.2"
        case .supportContacts: return "phone.arrow.up.right"
        case .professionalContacts: return "cross.case"
        case .environmentSafety: return "lock.shield"
        case .reasonsForLiving: return "heart.fill"
        }
    }

    /// Default crisis order (lethal means first, matching current behavior)
    static let defaultCrisisOrder: [SafetyPlanSection] = [
        .environmentSafety,
        .professionalContacts,
        .supportContacts,
        .copingStrategies,
        .socialDistractions,
        .reasonsForLiving,
        .warningSigns
    ]

    // MARK: - Item Counting

    /// Returns the number of items in this section from the given safety plan
    func itemCount(from plan: SafetyPlan?) -> Int {
        guard let plan else { return 0 }
        switch self {
        case .warningSigns: return plan.warningSigns.count
        case .copingStrategies: return plan.copingStrategies.count
        case .socialDistractions: return plan.socialDistractions.count
        case .supportContacts: return plan.supportContacts.count
        case .professionalContacts: return plan.professionalContacts.count
        case .environmentSafety: return plan.environmentSafetySteps.count
        case .reasonsForLiving: return plan.reasonsForLiving.count
        }
    }

    /// Whether this section has no items in the given plan
    func isEmpty(from plan: SafetyPlan?) -> Bool {
        itemCount(from: plan) == 0
    }

    // MARK: - Priority Accent

    /// Maps a rank position (0 = highest priority) to an accent color
    static func priorityAccentColor(forRank rank: Int) -> Color {
        switch rank {
        case 0: return Theme.emergency           // red
        case 1: return Theme.riskHighMonitoring   // orange
        case 2: return Theme.riskModerate         // yellow
        default: return Theme.primary             // teal
        }
    }

    /// Rule-based fallback ordering when MedGemma is unavailable
    static func fallbackOrder(for driver: LCSCState.RiskDriver?) -> [SafetyPlanSection] {
        switch driver {
        case .cssrs:
            return [.environmentSafety, .professionalContacts, .supportContacts, .reasonsForLiving, .copingStrategies, .socialDistractions, .warningSigns]
        case .sleep, .hrv:
            return [.copingStrategies, .reasonsForLiving, .socialDistractions, .supportContacts, .environmentSafety, .professionalContacts, .warningSigns]
        case .activity:
            return [.socialDistractions, .supportContacts, .copingStrategies, .reasonsForLiving, .environmentSafety, .professionalContacts, .warningSigns]
        case .mood:
            return [.reasonsForLiving, .copingStrategies, .socialDistractions, .supportContacts, .environmentSafety, .professionalContacts, .warningSigns]
        case .combined, .none:
            return defaultCrisisOrder
        }
    }
}
