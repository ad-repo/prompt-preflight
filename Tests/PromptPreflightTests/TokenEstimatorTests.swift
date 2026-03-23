import XCTest
@testable import PromptPreflight

final class TokenEstimatorTests: XCTestCase {
    func testEstimateTokensUsesSimpleCharacterHeuristic() {
        let estimated = TokenEstimator.estimateTokens(for: String(repeating: "a", count: 40))
        XCTAssertEqual(estimated, 10)
    }

    func testPreflightDetectsOverflow() {
        let input = String(repeating: "b", count: 40_000)
        let preflight = TokenEstimator.preflight(provider: .ollama, model: "llama3.2", input: input)
        XCTAssertTrue(preflight.exceedsLimit)
    }

    func testAutoSplitCreatesPartsWhenOversized() {
        let input = String(repeating: "p", count: 10_000)
        let split = TokenEstimator.autoSplit(markdown: input, targetTokenLimit: 500)
        XCTAssertTrue(split.contains("## Part 1"))
        XCTAssertTrue(split.contains("## Part 2"))
    }
}
