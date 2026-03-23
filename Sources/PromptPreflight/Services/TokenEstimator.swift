import Foundation

struct TokenPreflightResult: Equatable {
    let estimatedTokens: Int
    let limitTokens: Int

    var exceedsLimit: Bool {
        estimatedTokens > limitTokens
    }
}

enum TokenEstimator {
    static func estimateTokens(for text: String) -> Int {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }
        return max(1, Int(ceil(Double(trimmed.count) / 4.0)))
    }

    static func preflight(provider: LLMProvider, model: String, input: String) -> TokenPreflightResult {
        let estimated = estimateTokens(for: input)
        let limit = tokenLimit(provider: provider, model: model)
        return TokenPreflightResult(estimatedTokens: estimated, limitTokens: limit)
    }

    static func tokenLimit(provider: LLMProvider, model: String) -> Int {
        let normalizedModel = model.lowercased()

        switch provider {
        case .openAI:
            if normalizedModel.contains("gpt-4.1") { return 128_000 }
            if normalizedModel.contains("gpt-4o") { return 128_000 }
            if normalizedModel.contains("o") { return 200_000 }
            return provider.defaultTokenLimit
        case .gemini:
            if normalizedModel.contains("2.5") { return 1_000_000 }
            if normalizedModel.contains("2.0") { return 1_000_000 }
            return provider.defaultTokenLimit
        case .anthropic:
            if normalizedModel.contains("claude-3") || normalizedModel.contains("claude-sonnet") {
                return 200_000
            }
            return provider.defaultTokenLimit
        case .ollama:
            if normalizedModel.contains("32k") { return 32_000 }
            if normalizedModel.contains("16k") { return 16_000 }
            return provider.defaultTokenLimit
        }
    }

    static func autoSplit(markdown: String, targetTokenLimit: Int) -> String {
        let maxCharacters = max(1, targetTokenLimit * 4)
        guard markdown.count > maxCharacters else { return markdown }

        var output: [String] = []
        var currentChunk = ""
        var chunkIndex = 1

        let paragraphs = markdown.components(separatedBy: "\n\n")
        for paragraph in paragraphs {
            if paragraph.count > maxCharacters {
                if !currentChunk.isEmpty {
                    output.append("## Part \(chunkIndex)\n\n\(currentChunk)")
                    chunkIndex += 1
                    currentChunk = ""
                }

                var start = paragraph.startIndex
                while start < paragraph.endIndex {
                    let end = paragraph.index(start, offsetBy: maxCharacters, limitedBy: paragraph.endIndex) ?? paragraph.endIndex
                    let segment = String(paragraph[start ..< end])
                    output.append("## Part \(chunkIndex)\n\n\(segment)")
                    chunkIndex += 1
                    start = end
                }
                continue
            }

            let candidate = currentChunk.isEmpty ? paragraph : "\(currentChunk)\n\n\(paragraph)"
            if candidate.count > maxCharacters, !currentChunk.isEmpty {
                output.append("## Part \(chunkIndex)\n\n\(currentChunk)")
                chunkIndex += 1
                currentChunk = paragraph
            } else {
                currentChunk = candidate
            }
        }

        if !currentChunk.isEmpty {
            output.append("## Part \(chunkIndex)\n\n\(currentChunk)")
        }

        return output.joined(separator: "\n\n")
    }
}
