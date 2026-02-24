import Foundation

/// Constants for developer mode demo scenario
///
/// Provides all synthetic data needed for the MedGemma Kaggle Impact Competition demo.
/// Scenario: 48h post-ED discharge with SSRI activation syndrome.
enum DeveloperModeConstants {
    // MARK: - User Profile
    
    static let demoCallsign = "SENTINEL-DEMO"
    static let demoName = "John Doe"
    static let demoBranch = MilitaryBranch.army
    static let demoYearsOfService = 8
    
    // MARK: - Timeline
    
    /// Discharge date (48 hours ago)
    static var dischargeDate: Date {
        Date().addingTimeInterval(-48 * 3600)
    }
    
    // MARK: - HealthKit Synthetic Baseline
    
    /// Creates synthetic baseline that produces significant z-scores
    static func createSyntheticBaseline() -> SyntheticHealthKitBaseline {
        SyntheticHealthKitBaseline(
            avgSleepHours: 7.0,
            sleepStdDev: 0.8,
            avgSteps: 8000,
            stepsStdDev: 1500,
            avgHRV: 60.0,
            hrvStdDev: 12.0,
            currentSleepHours: 1.5,  // Z-score: -6.9 SD (CRITICAL)
            currentSteps: 2000,       // Z-score: -4.0 SD (CONCERNING)
            currentHRV: 35.0,         // Z-score: -2.1 SD (SIGNIFICANT)
            lastUpdated: dischargeDate
        )
    }
    
    // MARK: - Safety Plan Items
    
    static let warningSigns = [
        "Feeling wired or restless",
        "Unable to sleep for days",
        "Racing thoughts",
        "Increased irritability"
    ]
    
    static let copingStrategies = [
        "Deep breathing exercises (4-7-8 technique)",
        "Listen to calming music",
        "Take a short walk outside",
        "Progressive muscle relaxation"
    ]
    
    static let socialDistractions = [
        SocialContact(
            name: "Mike",
            phoneNumber: "(555) 234-5678",
            relationship: "Battle Buddy"
        )
    ]
    
    static let supportContacts = [
        SocialContact(
            name: "Mom",
            phoneNumber: "(555) 987-6543",
            relationship: "Mother"
        ),
        SocialContact(
            name: "Sarah",
            phoneNumber: "(555) 456-7890",
            relationship: "Sister"
        )
    ]
    
    static let professionalContacts = [
        ProfessionalContact(
            name: "VA Crisis Line",
            phoneNumber: "988",
            organization: "Veterans Crisis Line",
            isEmergency: true,
            isTextOnly: false
        ),
        ProfessionalContact(
            name: "VA Mental Health Clinic",
            phoneNumber: "(555) 123-4567",
            organization: "Outpatient Psychiatry",
            isEmergency: false,
            isTextOnly: false
        )
    ]
    
    static let environmentSafetySteps = [
        "Lock firearms in secure safe with buddy holding key",
        "Remove pills from bedside and store in locked cabinet",
        "Have Battle Buddy check in daily for first week"
    ]
    
    static let reasonsForLiving = [
        "My family depends on me",
        "I promised my buddy I'd stay strong",
        "My service taught me to never give up",
        "I want to see my niece graduate"
    ]
    
    // MARK: - Storage Keys
    
    static let developerModeActiveKey = "developer_mode_active"
    static let syntheticBaselineKey = "synthetic_healthkit_baseline"
    
    // MARK: - Discharge Summary
    
    /// Filename for the discharge summary in Resources
    static let resourceFilename = "va-ed-discharge-summary.json"
    
    /// Filename expected by ClinicalDocumentManager
    static let targetFilename = "synthetic_discharge_summary.json"
    
    /// The raw FHIR JSON for the synthetic discharge summary
    static let demoDischargeSummaryJSON = """
    {
        "resourceType": "Composition",
        "status": "final",
        "type": {
            "text": "Discharge Summary"
        },
        "subject": {
            "display": "John Doe"
        },
        "date": "2024-02-08T10:00:00Z",
        "author": [
            {
                "display": "Dr. Smith, Psychiatric Unit"
            }
        ],
        "title": "Hospital Discharge Summary",
        "text": {
            "status": "generated",
            "div": "<div><h1>Discharge Summary</h1><p><strong>Diagnosis:</strong> Major Depressive Disorder, recurrent, severe without psychotic features.</p><p><strong>Hospitalization Course:</strong> Patient admitted following a crisis event. Responded well to medication adjustment (Sertraline increased to 100mg) and intensive group therapy. Risk assessment at discharge indicates stable mood with no active suicidal ideation, but history of impulsive behavior is noted.</p><p><strong>Follow-up Plan:</strong> Weekly outpatient therapy and safety planning. Patient advised to use Sentinel app for daily monitoring.</p><p><strong>Flags:</strong> High risk of relapse during first 30 days post-discharge. Recommend close monitoring of sleep patterns and social withdrawal.</p></div>"
        }
    }
    """
}
