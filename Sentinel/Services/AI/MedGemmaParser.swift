import Foundation
import os.log

/// Parses LLM output from MedGemma into structured MedGemmaResponse
///
/// Handles multiple output formats:
/// - Structured color + reasoning (primary): "green\nExplanation..."
/// - MedGemma completion JSON: [{"prompt":"...","completion":"..."}]
/// - Legacy JSON with riskTier field (fallback)
/// - Keyword-based risk inference (last resort)
struct MedGemmaParser {

    // MARK: - Tier Detection Keywords

    /// Color words and level names that map to risk tiers (ordered high→low for safety)
    private static let tierKeywords: [(word: String, tier: RiskTier)] = [
        ("red", .crisis),
        ("crisis", .crisis),
        ("orange", .highMonitoring),
        ("yellow", .moderate),
        ("green", .low),
    ]

    /// Phrases that indicate risk level when no explicit tier word is found
    private static let riskPhrases: [(phrase: String, tier: RiskTier)] = [
        ("high risk", .highMonitoring),
        ("elevated risk", .highMonitoring),
        ("significant risk", .highMonitoring),
        ("significant distress", .highMonitoring),
        ("immediate risk", .crisis),
        ("imminent risk", .crisis),
        ("acute risk", .crisis),
        ("moderate risk", .moderate),
        ("low risk", .low),
        ("minimal risk", .low),
        ("no significant risk", .low),
    ]

    // MARK: - Main Parser

    /// Parse LLM response into MedGemmaResponse
    /// - Parameter text: Raw LLM output
    /// - Returns: Parsed response with risk tier and insights
    /// - Throws: MedGemmaError.invalidResponse if parsing fails
    static func parse(_ text: String) throws -> MedGemmaResponse {
        // Step 1: Extract the actual content — handle MedGemma completion JSON wrapper
        let content = extractContent(from: text)
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let lines = trimmed.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        // Step 2: Check first line for an explicit tier word
        let firstLine = lines.first?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var detectedTier: RiskTier?
        var reasoning: String = ""

        for (word, tier) in tierKeywords {
            if firstLine == word || firstLine.hasPrefix("\(word) ") || firstLine.hasPrefix("\(word)\n") {
                detectedTier = tier
                break
            }
        }

        // Step 3: If first line isn't a clean tier word, scan content for tier keywords
        if detectedTier == nil {
            let lowercased = content.lowercased()
            for (word, tier) in tierKeywords {
                if lowercased.contains(word) {
                    detectedTier = tier
                    break
                }
            }
        }

        // Step 4: If still no match, try risk-indicating phrases
        if detectedTier == nil {
            let lowercased = content.lowercased()
            for (phrase, tier) in riskPhrases {
                if lowercased.contains(phrase) {
                    detectedTier = tier
                    Logger.ai.info("Parser: inferred tier '\(tier.displayName)' from phrase '\(phrase)'")
                    break
                }
            }
        }

        // Extract reasoning from all lines except a standalone tier word on the first line
        if let tier = detectedTier {
            let firstLineIsTierWord = tierKeywords.contains(where: { firstLine == $0.word })
            if firstLineIsTierWord && lines.count > 1 {
                reasoning = lines.dropFirst().joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                // The entire content is the reasoning
                reasoning = trimmed
            }

            // Truncate reasoning to first 2 sentences max — prevents rambling
            reasoning = truncateToSentences(reasoning, max: 2)

            var response = MedGemmaResponse(rawOutput: text)
            response.assessedRisk = tier
            response.confidence = firstLineIsTierWord ? 0.9 : 0.7
            response.insights = reasoning.isEmpty ? ["Risk assessment: \(tier.displayName)"] : [reasoning]
            return response
        }

        // Step 5: Try legacy JSON with riskTier field
        if let jsonResponse = try? parseJSONFallback(text) {
            return jsonResponse
        }

        throw MedGemmaError.invalidResponse
    }

    // MARK: - Reasoning Truncation

    /// Truncate text to at most `max` sentences.
    /// Prevents verbose LLM output from polluting insights.
    static func truncateToSentences(_ text: String, max: Int) -> String {
        guard max > 0 else { return "" }
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return "" }

        // Split on sentence-ending punctuation followed by space or end-of-string
        var sentences: [String] = []
        var current = ""
        for char in cleaned {
            current.append(char)
            if (char == "." || char == "!" || char == "?") {
                let trimmed = current.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    sentences.append(trimmed)
                }
                current = ""
                if sentences.count >= max { break }
            }
        }
        // If there's leftover text and we haven't hit the limit, include it
        let leftover = current.trimmingCharacters(in: .whitespaces)
        if sentences.count < max && !leftover.isEmpty {
            sentences.append(leftover)
        }

        return sentences.joined(separator: " ")
    }

    // MARK: - Thinking Block Removal

    /// Strip chain-of-thought / thinking blocks from LLM output.
    ///
    /// MedGemma sometimes produces reasoning text before the actual answer.
    /// Patterns handled:
    /// - `<think>...</think>actual answer`  (formal Gemma thinking tokens)
    /// - `thought\n...long reasoning...\nActual answer`  (informal prefix)
    /// - `**thinking**\n...`  (markdown-style)
    ///
    /// This is a public utility so callers outside the parser (e.g. risk explanation)
    /// can sanitize output before displaying to the user.
    static func stripThinkingBlock(_ text: String) -> String {
        var result = text

        // 0. Aggressive Strip for Echoed Prompts
        // If the output contains the prompt's ending marker (e.g., "UPDATED SUMMARY:"),
        // we should take everything *after* the last occurrence of that marker.
        if let range = result.range(of: "UPDATED SUMMARY:", options: .backwards) {
            let properContent = result[range.upperBound...]
            result = String(properContent)
        }

        // 1. Formal <think>...</think> blocks
        if let regex = try? NSRegularExpression(pattern: "<think>[\\s\\S]*?</think>", options: []) {
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: ""
            )
        }

        // 2. Informal "thought\n" prefix — everything from "thought\n" until
        //    the last paragraph that doesn't look like reasoning.
        //    Heuristic: the actual answer is the final paragraph (after last double-newline).
        let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("thought") {
            // Find the last substantive paragraph — split on double newline
            let paragraphs = trimmed.components(separatedBy: "\n\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            if paragraphs.count > 1 {
                // Take the last paragraph as the actual answer
                result = paragraphs.last ?? trimmed
                Logger.ai.info("Parser: stripped informal thinking block (\(paragraphs.count - 1) paragraphs removed)")
            } else {
                // Single paragraph starting with "thought" — strip the prefix line
                let lines = trimmed.components(separatedBy: .newlines)
                if lines.count > 1 {
                    result = lines.dropFirst().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Content Extraction

    /// Extract the actual response content from various wrapper formats.
    /// Handles: JSON wrappers, code fences, thinking blocks.
    private static func extractContent(from text: String) -> String {
        // Strip markdown code fences
        var cleaned = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Try to decode as JSON array with "completion" field
        if cleaned.hasPrefix("["), let data = cleaned.data(using: .utf8) {
            struct CompletionEntry: Decodable { let completion: String }
            if let entries = try? JSONDecoder().decode([CompletionEntry].self, from: data),
               let first = entries.first {
                Logger.ai.info("Parser: extracted content from completion JSON wrapper")
                return stripThinkingBlock(first.completion)
            }
        }

        // Try single JSON object with "completion" field
        if cleaned.hasPrefix("{"), let data = cleaned.data(using: .utf8) {
            struct CompletionEntry: Decodable { let completion: String }
            if let entry = try? JSONDecoder().decode(CompletionEntry.self, from: data) {
                Logger.ai.info("Parser: extracted content from completion JSON object")
                return stripThinkingBlock(entry.completion)
            }
        }

        // Strip thinking blocks from raw text
        return stripThinkingBlock(text)
    }

    // MARK: - Fallback JSON Parser

    /// Parse legacy JSON format with riskTier field
    private static func parseJSONFallback(_ text: String) throws -> MedGemmaResponse {
        let pattern = "\\{(?:[^{}]|\\{[^{}]*\\})*\\}"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]),
              let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)),
              let range = Range(match.range, in: text) else {
            throw MedGemmaError.invalidResponse
        }

        let jsonString = String(text[range])
        guard let data = jsonString.data(using: .utf8) else {
            throw MedGemmaError.invalidResponse
        }

        return try decodeJSON(data: data, originalText: text)
    }

    /// Decode JSON data into MedGemmaResponse
    private static func decodeJSON(data: Data, originalText: String) throws -> MedGemmaResponse {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let parsed = try decoder.decode(ParsedModelResponse.self, from: data)

        var response = MedGemmaResponse(rawOutput: originalText)
        response.assessedRisk = RiskTier.from(string: parsed.riskTier)
        response.confidence = (parsed.riskScore ?? 5.0) / 10.0
        response.insights = [parsed.reasoning]
        response.recommendations = parsed.action.map { [$0] } ?? []
        response.hasSignificantDeviation = !(parsed.keyDeviations ?? []).isEmpty

        response.detectedPatterns = (parsed.keyDeviations ?? []).map { deviation in
            DetectedPattern(
                type: PatternType.from(string: deviation),
                description: "Deviation detected in \(deviation)",
                severity: .moderate,
                dataSource: DataSource.from(string: deviation)
            )
        }

        return response
    }
}
