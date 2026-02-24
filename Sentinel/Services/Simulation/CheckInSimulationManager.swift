import Foundation

/// Manages simulated data for Check-Ins based on clinical scenarios
final class CheckInSimulationManager: Sendable {
    
    /// Returns a simulated transcript based on the scenario
    func getSimulatedTranscript(for scenario: SimulationScenario) -> String {
        switch scenario {
        case .doingWell:
            return "I've been feeling really good lately. Sleeping well, staying active, and connecting with friends. No major stressors."
        case .decompensating:
            return "I'm really struggling. I can't sleep, I don't want to get out of bed, and everything feels hopeless. I don't know what to do."
        case .erratic:
            return "One minute I'm fine, the next I'm angry or crying. My sleep is all over the place. I feel like I'm losing control."
        case .normal:
            return "Things are okay. Just a normal week, busy with work but managing fine."
        case .highRisk:
            return "I'm in a dark place. I have thoughts about ending it. I have a plan but I haven't done anything yet."
        case .sleepDeprived:
            return "I'm just so tired. I haven't slept in days. It's hard to focus on anything."
        case .sedentary:
            return "I haven't left the house in a week. Just don't have the energy to move."
        }
    }
    
    /// Returns simulated WPM
    func getSimulatedWPM(for scenario: SimulationScenario) -> Double {
        switch scenario {
        case .doingWell, .normal:
            return 140.0 // Normal conversational speed
        case .decompensating, .sleepDeprived, .highRisk:
            return 110.0 // Slower, more lethargic
        case .erratic:
            return 160.0 // Fast, potentially manic or anxious
        case .sedentary:
            return 120.0
        }
    }
    
    /// Returns simulated facial telemetry
    func getSimulatedTelemetry(for scenario: SimulationScenario) -> [FaceTelemetry] {
        var points: [FaceTelemetry] = []
        let duration = 30
        
        for i in 0..<duration {
            let t = Double(i)
            let point: FaceTelemetry
            
            switch scenario {
            case .doingWell, .normal:
                point = FaceTelemetry(timestamp: t, eyeOpenness: 0.9, headPitch: 0.0, gazeDeviation: 0.1)
            case .decompensating, .highRisk, .sedentary, .sleepDeprived:
                // Downward gaze, less eye openness
                point = FaceTelemetry(timestamp: t, eyeOpenness: 0.6, headPitch: -0.2, gazeDeviation: 0.4)
            case .erratic:
                // Highly variable
                point = FaceTelemetry(
                    timestamp: t,
                    eyeOpenness: Double.random(in: 0.5...1.0),
                    headPitch: Double.random(in: -0.3...0.3),
                    gazeDeviation: Double.random(in: 0.0...0.8)
                )
            }
            points.append(point)
        }
        return points
    }
    
    /// Suggested C-SSRS answers for the scenario
    func getSuggestedCSSRSAnswers(for scenario: SimulationScenario) -> [Bool] {
        switch scenario {
        case .doingWell, .normal, .sedentary, .sleepDeprived:
            return [false, false, false, false, false, false]
        case .decompensating:
            // Q1 (Wish dead), Q2 (Thoughts) -> True
            return [true, true, false, false, false, false]
        case .erratic:
            // Q1, Q2, maybe Q3
            return [true, true, true, false, false, false]
        case .highRisk:
            // Crisis level
            return [true, true, true, true, true, false]
        }
    }
}
