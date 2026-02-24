import Foundation
import Combine
import UIKit

/// Manages the Safety Plan (Stanley-Brown protocol)
///
/// Handles viewing, editing, and using the personalized safety plan
/// during moments of crisis or distress.
@MainActor
final class SafetyPlanViewModel: ObservableObject {
    // MARK: - Published State

    @Published var isLoading = false
    @Published var errorMessage: String?

    /// The user's safety plan
    @Published var safetyPlan: SafetyPlan?

    /// Whether currently in edit mode
    @Published var isEditing = false

    /// Current step being viewed/edited (1-7)
    @Published var currentStep: Int = 1

    /// Whether the plan has any content
    @Published var hasPlan: Bool = false

    /// OCR processing state
    @Published var isProcessingOCR = false
    @Published var ocrProgress: Double = 0

    // MARK: - Dependencies

    private let localStorage: LocalStorage
    private let ocrService: SafetyPlanOCRService

    // MARK: - Constants

    let totalSteps = 7

    /// Step titles for the wizard
    let stepTitles: [Int: String] = [
        1: "Warning Signs",
        2: "Coping Strategies",
        3: "Social Distractions",
        4: "Support Contacts",
        5: "Professional Help",
        6: "Environment Safety",
        7: "Reasons for Living"
    ]

    /// Step descriptions for the wizard
    let stepDescriptions: [Int: String] = [
        1: "Recognize the signs that you might be headed toward a crisis",
        2: "Things you can do to take your mind off problems without contacting another person",
        3: "People and places that provide healthy distraction and help you feel better",
        4: "People you can reach out to when you need help",
        5: "Professionals and agencies that can help during a crisis",
        6: "Steps to make your environment safer by limiting access to lethal means",
        7: "The things that are most important to you and worth living for"
    ]

    // MARK: - Initialization

    init(localStorage: LocalStorage = LocalStorage()) {
        self.localStorage = localStorage
        self.ocrService = SafetyPlanOCRService()
    }

    // MARK: - Public Methods

    /// Loads the safety plan from storage
    func loadSafetyPlan() async {
        isLoading = true
        defer { isLoading = false }

        safetyPlan = localStorage.fetchSafetyPlan()

        // Create new if doesn't exist
        if safetyPlan == nil {
            safetyPlan = SafetyPlan()
        }

        updateHasPlan()
    }

    /// Saves the safety plan
    func saveSafetyPlan() {
        guard var plan = safetyPlan else { return }

        plan.lastUpdated = Date()
        localStorage.saveSafetyPlan(plan)
        safetyPlan = plan
        isEditing = false
        updateHasPlan()
    }

    /// Save without exiting edit mode (for auto-save)
    func autoSave() {
        guard var plan = safetyPlan else { return }
        plan.lastUpdated = Date()
        localStorage.saveSafetyPlan(plan)
        safetyPlan = plan
        updateHasPlan()
    }

    /// Starts editing mode
    func startEditing() {
        isEditing = true
    }

    /// Cancels editing and reverts changes
    func cancelEditing() async {
        isEditing = false
        await loadSafetyPlan()
    }

    /// Check if plan has meaningful content
    private func updateHasPlan() {
        guard let plan = safetyPlan else {
            hasPlan = false
            return
        }

        hasPlan = !plan.warningSigns.isEmpty ||
                  !plan.copingStrategies.isEmpty ||
                  !plan.socialDistractions.isEmpty ||
                  !plan.supportContacts.isEmpty ||
                  !plan.professionalContacts.isEmpty ||
                  !plan.environmentSafetySteps.isEmpty ||
                  !plan.reasonsForLiving.isEmpty
    }

    // MARK: - Navigation

    /// Move to next step
    func nextStep() {
        if currentStep < totalSteps {
            currentStep += 1
            autoSave()
        }
    }

    /// Move to previous step
    func previousStep() {
        if currentStep > 1 {
            currentStep -= 1
        }
    }

    /// Jump to specific step
    func goToStep(_ step: Int) {
        guard step >= 1 && step <= totalSteps else { return }
        currentStep = step
    }

    /// Check if can proceed to next step (has at least one item)
    func canProceed() -> Bool {
        guard let plan = safetyPlan else { return false }

        switch currentStep {
        case 1: return !plan.warningSigns.isEmpty
        case 2: return !plan.copingStrategies.isEmpty
        case 3: return !plan.socialDistractions.isEmpty
        case 4: return !plan.supportContacts.isEmpty
        case 5: return !plan.professionalContacts.isEmpty
        case 6: return !plan.environmentSafetySteps.isEmpty
        case 7: return !plan.reasonsForLiving.isEmpty
        default: return true
        }
    }

    // MARK: - OCR Processing

    /// Process an image using OCR and merge results
    func processOCRImage(_ image: UIImage) async {
        isProcessingOCR = true
        ocrProgress = 0
        errorMessage = nil

        do {
            let scannedPlan = try await ocrService.processImage(image)
            ocrProgress = ocrService.progress
            mergeSafetyPlan(scannedPlan)
            isProcessingOCR = false
        } catch {
            isProcessingOCR = false
            errorMessage = error.localizedDescription
        }
    }

    /// Process multiple images using OCR
    func processOCRImages(_ images: [UIImage]) async {
        isProcessingOCR = true
        ocrProgress = 0
        errorMessage = nil

        do {
            let scannedPlan = try await ocrService.processImages(images)
            ocrProgress = ocrService.progress
            mergeSafetyPlan(scannedPlan)
            isProcessingOCR = false
        } catch {
            isProcessingOCR = false
            errorMessage = error.localizedDescription
        }
    }

    /// Merge OCR results into current plan (doesn't overwrite existing items)
    private func mergeSafetyPlan(_ scanned: SafetyPlan) {
        guard var plan = safetyPlan else {
            safetyPlan = scanned
            autoSave()
            return
        }

        // Merge string arrays (warning signs, coping strategies, etc.)
        plan.warningSigns = mergeStrings(existing: plan.warningSigns, new: scanned.warningSigns)
        plan.copingStrategies = mergeStrings(existing: plan.copingStrategies, new: scanned.copingStrategies)
        plan.environmentSafetySteps = mergeStrings(existing: plan.environmentSafetySteps, new: scanned.environmentSafetySteps)
        plan.reasonsForLiving = mergeStrings(existing: plan.reasonsForLiving, new: scanned.reasonsForLiving)

        // Merge contacts (using name as key, with update support)
        plan.socialDistractions = mergeContacts(existing: plan.socialDistractions, new: scanned.socialDistractions)
        plan.supportContacts = mergeContacts(existing: plan.supportContacts, new: scanned.supportContacts)
        plan.professionalContacts = mergeProfessionalContacts(existing: plan.professionalContacts, new: scanned.professionalContacts)

        safetyPlan = plan
        autoSave()
    }

    /// Merge two string arrays, avoiding case-insensitive duplicates
    private func mergeStrings(existing: [String], new: [String]) -> [String] {
        var result = existing
        for item in new {
            if !result.contains(where: { $0.lowercased() == item.lowercased() }) {
                result.append(item)
            }
        }
        return result
    }

    /// Merge social contacts, updating existing contacts if new data has more info
    private func mergeContacts(existing: [SocialContact], new: [SocialContact]) -> [SocialContact] {
        var result = existing
        for newContact in new {
            if let existingIndex = result.firstIndex(where: { $0.name.lowercased() == newContact.name.lowercased() }) {
                // Update existing contact if new one has phone and existing doesn't
                if result[existingIndex].phoneNumber == nil && newContact.phoneNumber != nil {
                    result[existingIndex] = SocialContact(
                        id: result[existingIndex].id,
                        name: result[existingIndex].name,
                        phoneNumber: newContact.phoneNumber,
                        relationship: result[existingIndex].relationship ?? newContact.relationship
                    )
                }
            } else {
                result.append(newContact)
            }
        }
        return result
    }

    /// Merge professional contacts, updating existing contacts if new data has more info
    private func mergeProfessionalContacts(existing: [ProfessionalContact], new: [ProfessionalContact]) -> [ProfessionalContact] {
        var result = existing
        for newContact in new {
            if let existingIndex = result.firstIndex(where: { $0.name.lowercased() == newContact.name.lowercased() }) {
                // Update existing contact if new one has better data
                var updated = result[existingIndex]
                if updated.phoneNumber == "Unknown" && newContact.phoneNumber != "Unknown" {
                    updated = ProfessionalContact(
                        id: updated.id,
                        name: updated.name,
                        phoneNumber: newContact.phoneNumber,
                        organization: updated.organization ?? newContact.organization,
                        isEmergency: updated.isEmergency || newContact.isEmergency,
                        isTextOnly: updated.isTextOnly || newContact.isTextOnly
                    )
                    result[existingIndex] = updated
                }
            } else {
                result.append(newContact)
            }
        }
        return result
    }

    // MARK: - Warning Signs (Step 1)

    func addWarningSign(_ sign: String) {
        guard !sign.isEmpty else { return }
        safetyPlan?.warningSigns.append(sign)
    }

    func removeWarningSign(at index: Int) {
        safetyPlan?.warningSigns.remove(at: index)
    }

    // MARK: - Coping Strategies (Step 2)

    func addCopingStrategy(_ strategy: String) {
        guard !strategy.isEmpty else { return }
        safetyPlan?.copingStrategies.append(strategy)
    }

    func removeCopingStrategy(at index: Int) {
        safetyPlan?.copingStrategies.remove(at: index)
    }

    // MARK: - Social Contacts (Steps 3-4)

    func addSocialDistraction(_ contact: SocialContact) {
        safetyPlan?.socialDistractions.append(contact)
    }

    func removeSocialDistraction(at index: Int) {
        safetyPlan?.socialDistractions.remove(at: index)
    }

    func addSupportContact(_ contact: SocialContact) {
        safetyPlan?.supportContacts.append(contact)
    }

    func removeSupportContact(at index: Int) {
        safetyPlan?.supportContacts.remove(at: index)
    }

    // MARK: - Professional Contacts (Step 5)

    func addProfessionalContact(_ contact: ProfessionalContact) {
        safetyPlan?.professionalContacts.append(contact)
    }

    func removeProfessionalContact(at index: Int) {
        safetyPlan?.professionalContacts.remove(at: index)
    }

    // MARK: - Environment Safety (Step 6)

    func addEnvironmentSafetyStep(_ step: String) {
        guard !step.isEmpty else { return }
        safetyPlan?.environmentSafetySteps.append(step)
    }

    func removeEnvironmentSafetyStep(at index: Int) {
        safetyPlan?.environmentSafetySteps.remove(at: index)
    }

    // MARK: - Reasons for Living

    func addReasonForLiving(_ reason: String) {
        guard !reason.isEmpty else { return }
        safetyPlan?.reasonsForLiving.append(reason)
    }

    func removeReasonForLiving(at index: Int) {
        safetyPlan?.reasonsForLiving.remove(at: index)
    }

    // MARK: - Battle Buddy

    func setBattleBuddy(_ contact: SocialContact) {
        safetyPlan?.battleBuddy = contact
    }

    func removeBattleBuddy() {
        safetyPlan?.battleBuddy = nil
    }

    // MARK: - Quick Actions

    /// Calls the battle buddy
    func callBattleBuddy() -> URL? {
        guard let phone = safetyPlan?.battleBuddy?.phoneNumber else { return nil }
        return URL(string: "tel://\(phone)")
    }

    /// Gets the 988 crisis line URL
    func call988() -> URL? {
        return URL(string: "tel://988")
    }
}
