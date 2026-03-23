import AppKit
import XCTest
@testable import PromptPreflight

final class RichTextSerializerTests: XCTestCase {
    func testBoldAndLinkStylesBecomeMarkdown() {
        let serializer = RichTextSerializer()
        let text = NSMutableAttributedString(string: "Swift")
        text.addAttribute(.font, value: NSFont.boldSystemFont(ofSize: 14), range: NSRange(location: 0, length: 5))
        text.addAttribute(.link, value: "https://swift.org", range: NSRange(location: 0, length: 5))

        let artifact = serializer.convert(text)

        XCTAssertEqual(artifact.markdown, "**[Swift](https://swift.org)**")
        XCTAssertTrue(artifact.warnings.isEmpty)
    }

    func testAttachmentProducesMetadataAndWarning() {
        let serializer = RichTextSerializer()
        let attributed = NSMutableAttributedString(string: "A")
        let attachment = NSTextAttachment()
        attributed.append(NSAttributedString(attachment: attachment))

        let artifact = serializer.convert(attributed)

        XCTAssertTrue(artifact.markdown.contains("[attachment:"))
        XCTAssertFalse(artifact.warnings.isEmpty)
        XCTAssertTrue(artifact.metadataBlocks.contains { $0.contains("type: attachment") })
    }
}
