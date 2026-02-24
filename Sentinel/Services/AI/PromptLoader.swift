import Foundation
import os.log

enum PromptType: String, CaseIterable {
    case riskAssessment
    case compression
    case report
    case contextIngestion
    case explainRisk
    case rerankSafetyPlan
}

class PromptLoader {
    static let shared = PromptLoader()

    private var prompts: [String: String] = [:]

    private init() {
        loadPrompts()
    }

    private func loadPrompts() {
        guard let url = Bundle.main.url(forResource: "Prompts", withExtension: "json") else {
            Logger.ai.warning("Warning: Prompts.json not found in bundle, using default prompts.")
            loadDefaults()
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let loadedPromptArrays = try JSONDecoder().decode([String: [String]].self, from: data)
            let loadedPrompts = loadedPromptArrays.mapValues { $0.joined(separator: "\n") }

            // Validate that all required keys are present
            let requiredKeys = Set(PromptType.allCases.map { $0.rawValue })
            let loadedKeys = Set(loadedPrompts.keys)

            if requiredKeys.isSubset(of: loadedKeys) {
                self.prompts = loadedPrompts
            } else {
                Logger.ai.error("Prompts.json is missing one or more required keys, using default prompts.")
                loadDefaults()
            }
        } catch {
            Logger.ai.error("Failed to load or parse Prompts.json: \(error.localizedDescription), using default prompts.")
            loadDefaults()
        }
    }

    private func loadDefaults() {
        self.prompts = [
            "riskAssessment": """
Assess mental health risk. Combine history + current data.

HISTORY (LCSC):
{{HISTORY_CONTEXT}}

CURRENT DATA:
- Health: {{HEALTH_SUMMARY}}
- Speech: "{{TRANSCRIPT}}" ({{WPM}} WPM)
- Visual: {{VISUAL_LOG}}
- C-SSRS: {{CSSRS_SUMMARY}}{{VIGILANCE_NOTE}}

TASK:
Assess current risk level based on ALL data above.

RESPONSE FORMAT (STRICT):
- First word must be: green, yellow, orange, or red
- Second line: Short explanation (1 sentence)
- NO JSON, NO other formatting

Example response:
red
Active suicidal ideation detected.

YOUR RESPONSE:
""",
            "compression": """
You are updating a clinical continuity note. Merge the PAST CONTEXT with TODAY'S DATA into a concise, updated summary (max 3 sentences).

PAST CONTEXT:
{{PREVIOUS_SUMMARY}}

TODAY'S DATA:
- Risk: {{RISK_TIER}}
- Check-in Type: {{CHECKIN_TYPE}}
- Transcript: {{TRANSCRIPT}}
- Sleep: {{SLEEP_HOURS}}h (Trend: {{SLEEP_TREND}})

TASK:
1. Identify if the patient is improving, worsening, or stable vs Past Context.
2. Highlight persistent issues (e.g. "Sleep remains poor").
3. Drop irrelevant old details to save space.

UPDATED SUMMARY:
""",
            "report": """
You are a clinical medical scribe. Write a professional SBAR (Situation, Background, Assessment, Recommendation) secure message to a {{RECIPIENT}}.

PATIENT: {{PATIENT_NAME}}
DATA:
{{RISK_CONTEXT}}
{{HEALTH_CONTEXT}}

STRICT RULES:
1. Audience: This is for {{RECIPIENT}}. Tailor the language accordingly.
2. USE ONLY THE DATA PROVIDED. Do not invent symptoms.
3. Format strictly as SBAR with exactly four sections.
4. STOP IMMEDIATELY after the RECOMMENDATION section. Do not add any additional text, commentary, or follow-up.

FORMAT:
SITUATION: [State current risk tier]
BACKGROUND: [Summarize data]
ASSESSMENT: [Clinical summary of provided data]
RECOMMENDATION: Requesting non-urgent follow-up with {{RECIPIENT}}.

Write the SBAR report now. Stop after RECOMMENDATION.
""",
            "contextIngestion": """
<start_of_turn>user
You are maintaining a clinical summary for a veteran.

CURRENT SUMMARY:
{{CURRENT_SUMMARY}}

NEW DOCUMENT (Discharge Summary):
{{NEW_CONTEXT}}

TASK:
Update the CURRENT SUMMARY to include key medical history, diagnoses, and risk factors from the NEW DOCUMENT.
Keep the summary concise (under 300 words). Do not lose existing important details.

UPDATED SUMMARY:<end_of_turn>
<start_of_turn>model
""",
            "explainRisk": """
<start_of_turn>user
You are a clinical AI explainability engine. Explain WHY the patient is currently at {{RISK_LEVEL}} risk level.

PATIENT HISTORY:
{{HISTORY_CONTEXT}}

RECENT RISK FACTORS:
{{RISK_FACTORS}}

HEALTH DATA:
{{HEALTH_CONTEXT}}

LATEST DATA IS FROM: {{TIME_AGO}}
SOURCE OF RISK: {{DATA_SOURCE}} (e.g. C-SSRS, AI Model, Manual)

TASK:
Provide a 2-sentence explanation for the risk level. Do NOT analyze. Do NOT think. detailed analysis is forbidden.

RULES:
1. Start immediately with the explanation.
2. If C-SSRS flags exist, cite them.
3. If recent data is poor (e.g. 0 hours sleep), cite it.
4. NO <thought> tags. NO internal monologue.

EXPLANATION:<end_of_turn>
<start_of_turn>model
""",
            "rerankSafetyPlan": """
Reorder safety plan sections for a veteran in crisis. Output ONLY a comma-separated list of numbers. Do NOT think. Do NOT explain.

SECTIONS:
1=Warning Signs, 2=Coping Strategies, 3=Social Distractions, 4=Support Contacts, 5=Professional Help, 6=Lethal Means Reduction, 7=Reasons for Living

CLINICAL CONTEXT:
Trajectory: {{TRAJECTORY}}
Primary Driver: {{PRIMARY_DRIVER}}
Risk Tier: {{RISK_TIER}}

RULES:
1. Output EXACTLY 7 numbers separated by commas, most relevant section FIRST.
2. Every number 1-7 must appear EXACTLY once.
3. No JSON. No explanation. ONLY the 7 numbers.

Example: 6,5,2,7,4,3,1

ORDER:
"""
        ]
    }

    func getPrompt(_ type: PromptType) -> String {
        guard let prompt = prompts[type.rawValue], !prompt.isEmpty else {
            Logger.ai.critical("Prompt for '\(type.rawValue)' is missing or empty. This indicates a configuration error.")
            assertionFailure("Missing prompt for \(type.rawValue). Check Prompts.json and default prompts.")
            return ""
        }
        return prompt
    }
}
