import Foundation
import CoreGraphics

enum AppConstants {
    static let appName = "Prompt-Preflight"
    static let pinnedWindowID = "PinnedMainWindow"

    static let defaultSystemPrompt = """
Lossless compression task:

preserve 100% meaning
remove redundancy only
structure for machine parsing
output markdown only
no interpretation or omission
"""

    static let requestTimeoutSeconds: TimeInterval = 45
    static let serviceName = "PromptPreflight"
    static let minPanelWidth: CGFloat = 260
}
