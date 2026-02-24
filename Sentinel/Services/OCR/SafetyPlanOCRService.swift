import Foundation
import Vision
import UIKit
import Combine

/// OCR service for parsing paper Safety Plan worksheets
/// Uses Apple Vision framework for text recognition
@MainActor
final class SafetyPlanOCRService: ObservableObject {

    // MARK: - Published State

    @Published var isProcessing = false
    @Published var progress: Double = 0
    @Published var errorMessage: String?

    // MARK: - Pre-compiled Regex Patterns (for performance)

    /// Regex for list item prefixes (e.g., "1. ", "• ", "- ")
    private static let prefixPatterns: [NSRegularExpression] = [
        try! NSRegularExpression(pattern: "^\\d+\\.\\s*"),     // "1. "
        try! NSRegularExpression(pattern: "^\\d+\\)\\s*"),     // "1) "
        try! NSRegularExpression(pattern: "^[•●○]\\s*"),       // Bullet points
        try! NSRegularExpression(pattern: "^[-–—]\\s*"),       // Dashes
        try! NSRegularExpression(pattern: "^\\*\\s*")          // Asterisks
    ]

    /// Regex for phone numbers (US format)
    private static let phoneRegex = try! NSRegularExpression(
        pattern: "\\(?\\d{3}\\)?[-.\\s]?\\d{3}[-.\\s]?\\d{4}"
    )

    /// Regex for phone numbers including short codes (988, 911)
    private static let phoneWithShortCodesRegex = try! NSRegularExpression(
        pattern: "\\(?\\d{3}\\)?[-.\\s]?\\d{3}[-.\\s]?\\d{4}|\\b988\\b|\\b911\\b"
    )

    /// Regex for trailing separators
    private static let trailingSeparatorRegex = try! NSRegularExpression(
        pattern: "[-–—:,]$"
    )

    // MARK: - Section Markers

    /// Keywords that indicate section starts
    private let sectionMarkers: [Int: [String]] = [
        1: ["step 1", "warning signs", "headed toward a crisis"],
        2: ["step 2", "internal coping", "coping strategies", "distract from"],
        3: ["step 3", "people, places", "social settings", "healthy distraction"],
        4: ["step 4", "people i can contact", "ask for help", "family members, friends"],
        5: ["step 5", "professionals", "agencies", "during a crisis"],
        6: ["step 6", "environment safe", "lethal means", "limiting access"],
        7: ["step 7", "reasons for living", "worth living"]
    ]

    // MARK: - Public Methods

    /// Process an image and extract Safety Plan data
    /// - Parameter image: UIImage of the safety plan form
    /// - Returns: Partially populated SafetyPlan
    func processImage(_ image: UIImage) async throws -> SafetyPlan {
        isProcessing = true
        progress = 0
        errorMessage = nil

        defer {
            isProcessing = false
            progress = 1.0
        }

        // Convert to CGImage
        guard let cgImage = image.cgImage else {
            throw OCRError.invalidImage
        }

        progress = 0.1

        // Perform text recognition
        let recognizedText = try await recognizeText(in: cgImage)
        progress = 0.5

        // Parse into sections
        let sections = parseIntoSections(recognizedText)
        progress = 0.8

        // Build SafetyPlan
        let plan = buildSafetyPlan(from: sections)
        progress = 1.0

        return plan
    }

    /// Process multiple images (multi-page form)
    func processImages(_ images: [UIImage]) async throws -> SafetyPlan {
        isProcessing = true
        progress = 0
        errorMessage = nil

        defer {
            isProcessing = false
            progress = 1.0
        }

        var allText: [String] = []
        let progressPerImage = 0.6 / Double(images.count)

        for (index, image) in images.enumerated() {
            guard let cgImage = image.cgImage else { continue }

            let text = try await recognizeText(in: cgImage)
            allText.append(contentsOf: text)
            progress = 0.1 + (Double(index + 1) * progressPerImage)
        }

        let sections = parseIntoSections(allText)
        progress = 0.9

        let plan = buildSafetyPlan(from: sections)
        progress = 1.0

        return plan
    }

    // MARK: - Private Methods

    /// Perform OCR on image
    private func recognizeText(in image: CGImage) async throws -> [String] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: OCRError.recognitionFailed(error.localizedDescription))
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                // Extract text from observations, sorted by vertical position
                let sortedObservations = observations.sorted { $0.boundingBox.minY > $1.boundingBox.minY }

                let lines = sortedObservations.compactMap { observation -> String? in
                    observation.topCandidates(1).first?.string
                }

                continuation.resume(returning: lines)
            }

            // Configure for accuracy
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: image, options: [:])

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: OCRError.recognitionFailed(error.localizedDescription))
            }
        }
    }

    /// Parse recognized text into sections
    private func parseIntoSections(_ lines: [String]) -> [Int: [String]] {
        var sections: [Int: [String]] = [:]
        var currentSection: Int = 0

        for line in lines {
            let lowercased = line.lowercased()

            // Check if this line marks a new section
            var foundSection = false
            for (section, markers) in sectionMarkers {
                if markers.contains(where: { lowercased.contains($0) }) {
                    currentSection = section
                    foundSection = true
                    break
                }
            }

            // If we're in a section and this isn't a header, add the content
            if !foundSection && currentSection > 0 {
                let cleaned = cleanLine(line)
                if !cleaned.isEmpty && !isHeaderLine(cleaned) {
                    if sections[currentSection] == nil {
                        sections[currentSection] = []
                    }
                    sections[currentSection]?.append(cleaned)
                }
            }
        }

        return sections
    }

    /// Clean up a line of text
    private func cleanLine(_ line: String) -> String {
        var cleaned = line.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove common list prefixes using pre-compiled patterns
        for regex in Self.prefixPatterns {
            let range = NSRange(cleaned.startIndex..., in: cleaned)
            cleaned = regex.stringByReplacingMatches(in: cleaned, range: range, withTemplate: "")
        }

        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Check if a line is likely a header/label
    private func isHeaderLine(_ line: String) -> Bool {
        let lowercased = line.lowercased()

        let headerKeywords = [
            "name and phone",
            "phone number",
            "clinician/agency",
            "local emergency",
            "continued",
            "safety plan worksheet",
            "purpose:",
            "step"
        ]

        return headerKeywords.contains { lowercased.contains($0) }
    }

    /// Build SafetyPlan from parsed sections
    private func buildSafetyPlan(from sections: [Int: [String]]) -> SafetyPlan {
        // Section 1: Warning Signs
        let warningSigns = sections[1] ?? []

        // Section 2: Coping Strategies
        let copingStrategies = sections[2] ?? []

        // Section 3: Social Distractions (people/places)
        let socialDistractionStrings = sections[3] ?? []
        let socialDistractions = socialDistractionStrings.map { str in
            parseContact(from: str)
        }

        // Section 4: Support Contacts
        let supportStrings = sections[4] ?? []
        let supportContacts = supportStrings.map { str in
            parseContact(from: str)
        }

        // Section 5: Professional Contacts
        let professionalStrings = sections[5] ?? []
        let professionalContacts = professionalStrings.map { str in
            parseProfessionalContact(from: str)
        }

        // Section 6: Environment Safety
        let environmentSafetySteps = sections[6] ?? []

        // Section 7: Reasons for Living
        let reasonsForLiving = sections[7] ?? []

        return SafetyPlan(
            warningSigns: warningSigns,
            copingStrategies: copingStrategies,
            socialDistractions: socialDistractions,
            supportContacts: supportContacts,
            professionalContacts: professionalContacts,
            environmentSafetySteps: environmentSafetySteps,
            reasonsForLiving: reasonsForLiving
        )
    }

    /// Parse a contact string (may contain name and phone)
    private func parseContact(from string: String) -> SocialContact {
        let range = NSRange(string.startIndex..., in: string)

        // Try to extract phone number using pre-compiled regex
        if let match = Self.phoneRegex.firstMatch(in: string, range: range) {
            let phoneRange = Range(match.range, in: string)!
            let phone = String(string[phoneRange])

            // Name is everything before the phone
            var name = string
            if let phoneStart = string.range(of: phone)?.lowerBound {
                name = String(string[..<phoneStart]).trimmingCharacters(in: .whitespacesAndNewlines)
            }

            // Clean up trailing separators using pre-compiled regex
            let nameRange = NSRange(name.startIndex..., in: name)
            name = Self.trailingSeparatorRegex.stringByReplacingMatches(
                in: name, range: nameRange, withTemplate: ""
            ).trimmingCharacters(in: .whitespacesAndNewlines)

            return SocialContact(name: name.isEmpty ? "Contact" : name, phoneNumber: phone)
        }

        // No phone found, treat whole string as name/place
        return SocialContact(name: string, phoneNumber: nil)
    }

    /// Parse a professional contact string
    /// Attempts to extract name, phone number, and organization
    private func parseProfessionalContact(from string: String) -> ProfessionalContact {
        let range = NSRange(string.startIndex..., in: string)

        var name = string
        var phone = ""
        var organization: String?

        // Try to extract phone number using pre-compiled regex
        if let match = Self.phoneWithShortCodesRegex.firstMatch(in: string, range: range) {
            let phoneRange = Range(match.range, in: string)!
            phone = String(string[phoneRange])

            if let phoneStart = string.range(of: phone)?.lowerBound {
                name = String(string[..<phoneStart]).trimmingCharacters(in: .whitespacesAndNewlines)
            }

            // Clean up trailing separators
            let nameRange = NSRange(name.startIndex..., in: name)
            name = Self.trailingSeparatorRegex.stringByReplacingMatches(
                in: name, range: nameRange, withTemplate: ""
            ).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Try to extract organization from parentheses or after comma
        // e.g., "Dr. Smith (VA Mental Health)" or "Dr. Smith, VA Mental Health"
        if let parenStart = name.firstIndex(of: "("),
           let parenEnd = name.firstIndex(of: ")") {
            organization = String(name[name.index(after: parenStart)..<parenEnd])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            name = String(name[..<parenStart]).trimmingCharacters(in: .whitespacesAndNewlines)
        } else if let commaIndex = name.firstIndex(of: ",") {
            let afterComma = String(name[name.index(after: commaIndex)...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            // Only treat as org if it looks like one (not a title like "Jr." or "MD")
            if afterComma.count > 3 && !afterComma.hasSuffix(".") {
                organization = afterComma
                name = String(name[..<commaIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        // Check if emergency
        let lowercased = string.lowercased()
        let isEmergency = lowercased.contains("emergency") ||
                          lowercased.contains("crisis") ||
                          phone == "988" ||
                          phone == "911"

        return ProfessionalContact(
            name: name.isEmpty ? "Professional" : name,
            phoneNumber: phone.isEmpty ? "Unknown" : phone,
            organization: organization,
            isEmergency: isEmergency
        )
    }
}

// MARK: - Error Types

enum OCRError: LocalizedError {
    case invalidImage
    case recognitionFailed(String)
    case parsingFailed

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Could not process the image. Please try again with a clearer photo."
        case .recognitionFailed(let reason):
            return "Text recognition failed: \(reason)"
        case .parsingFailed:
            return "Could not parse the safety plan format. You can still edit manually."
        }
    }
}
