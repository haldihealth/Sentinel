import Foundation

extension CheckInRecord {
    /// Returns a compact C-SSRS summary string (e.g., "Q1+, Q6+")
    func cssrsSummary() -> String {
        var flags: [String] = []
        if q1WishDead == true { flags.append("Q1+") }
        if q2SuicidalThoughts == true { flags.append("Q2+") }
        if q3ThoughtsWithMethod == true { flags.append("Q3+") }
        if q4Intent == true { flags.append("Q4+CRISIS") }
        if q5Plan == true { flags.append("Q5+CRISIS") }
        if q6RecentAttempt == true { flags.append("Q6+") }
        return flags.isEmpty ? "All negative" : flags.joined(separator: ", ")
    }

    /// Returns a list of positive C-SSRS findings with descriptions
    func riskFactorsString() -> String {
        let cssrsChecks: [(Bool?, String)] = [
            (q1WishDead, "- Reported passive death wish"),
            (q2SuicidalThoughts, "- Reported suicidal thoughts"),
            (q3ThoughtsWithMethod, "- Thoughts with method"),
            (q4Intent, "- Active intent declared"),
            (q5Plan, "- Specific plan declared"),
            (q6RecentAttempt, "- Recent attempt reported")
        ]
        let risks = cssrsChecks.compactMap { $0.0 == true ? $0.1 : nil }
        return risks.isEmpty ? "None reported in this check-in." : risks.joined(separator: "\n")
    }

    /// Returns a formatted string of C-SSRS flags for reports
    func reportFormat() -> String? {
         let cssrsChecks: [(Bool?, String)] = [
            (q1WishDead, "Passive death wish"),
            (q2SuicidalThoughts, "Suicidal thoughts"),
            (q3ThoughtsWithMethod, "Thoughts with method"),
            (q4Intent, "Active intent"),
            (q5Plan, "Specific plan"),
            (q6RecentAttempt, "Recent attempt reported")
        ]
        let positiveChecks = cssrsChecks.compactMap { $0.0 == true ? $0.1 : nil }
        return positiveChecks.isEmpty ? nil : "C-SSRS FLAGS: " + positiveChecks.joined(separator: ", ")
    }
}
