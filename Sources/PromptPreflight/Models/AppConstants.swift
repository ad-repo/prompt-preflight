import Foundation
import CoreGraphics

enum AppConstants {
    static let appName = "Prompt-Preflight"

    static let defaultSystemPrompt = """
Lossless compression task:

preserve 100% meaning
remove redundancy only
structure for machine parsing
output markdown only
no interpretation or omission
"""

    static let defaultRequestTimeoutSeconds: TimeInterval = 45
    static let ollamaRequestTimeoutSeconds: TimeInterval = 180
    static let minOllamaRequestTimeoutSeconds = 15
    static let maxOllamaRequestTimeoutSeconds = 900
    static let serviceName = "PromptPreflight"
    static let minPanelWidth: CGFloat = 260
}
