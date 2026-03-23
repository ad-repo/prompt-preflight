import Foundation

struct ConversionArtifact: Equatable {
    let markdown: String
    let warnings: [String]
    let metadataBlocks: [String]
}
