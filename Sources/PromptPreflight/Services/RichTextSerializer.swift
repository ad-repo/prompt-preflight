import AppKit
import Foundation

final class RichTextSerializer {
    func convert(_ attributedString: NSAttributedString) -> ConversionArtifact {
        guard attributedString.length > 0 else {
            return ConversionArtifact(markdown: "", warnings: [], metadataBlocks: [])
        }

        var markdown = ""
        var warnings: [String] = []
        var metadataBlocks: [String] = []

        attributedString.enumerateAttributes(in: NSRange(location: 0, length: attributedString.length)) { attributes, range, _ in
            if let attachment = attributes[.attachment] as? NSTextAttachment {
                let attachmentName = attachment.fileWrapper?.preferredFilename ?? "attachment"
                let placeholder = "[attachment: \(attachmentName)]"
                markdown.append(placeholder)

                let warning = "Attachment at index \(range.location) was preserved as metadata."
                warnings.append(warning)
                metadataBlocks.append(metadataBlock(type: "attachment", location: range.location, detail: attachmentName))
                return
            }

            let substring = attributedString.attributedSubstring(from: range).string
            guard !substring.isEmpty else { return }

            var chunk = escapeMarkdown(substring)

            if let link = attributes[.link] {
                let urlString = String(describing: link)
                chunk = "[\(chunk)](\(urlString))"
            }

            if hasUnsupportedColorAttributes(attributes) {
                let warning = "Color styling at index \(range.location) is preserved via metadata."
                warnings.append(warning)
                metadataBlocks.append(metadataBlock(type: "color-style", location: range.location, detail: "foreground/background color"))
            }

            if hasUnsupportedParagraphAttributes(attributes) {
                let warning = "Paragraph style details at index \(range.location) are preserved via metadata."
                warnings.append(warning)
                metadataBlocks.append(metadataBlock(type: "paragraph-style", location: range.location, detail: "non-default paragraph attributes"))
            }

            let style = styleForAttributes(attributes)
            chunk = applyStyle(style, to: chunk)
            markdown.append(chunk)
        }

        let dedupedWarnings = Array(Set(warnings)).sorted()
        if !metadataBlocks.isEmpty {
            let metadataSection = metadataBlocks.joined(separator: "\n\n")
            markdown = "\(markdown)\n\n---\n\n\(metadataSection)"
        }

        return ConversionArtifact(markdown: markdown, warnings: dedupedWarnings, metadataBlocks: metadataBlocks)
    }

    private func styleForAttributes(_ attributes: [NSAttributedString.Key: Any]) -> TextStyle {
        var style = TextStyle()

        if let font = attributes[.font] as? NSFont {
            let traits = font.fontDescriptor.symbolicTraits
            if traits.contains(.bold) { style.bold = true }
            if traits.contains(.italic) { style.italic = true }
            let lowerName = font.fontName.lowercased()
            if traits.contains(.monoSpace) || lowerName.contains("mono") || lowerName.contains("menlo") {
                style.code = true
            }
        }

        if let strikethrough = attributes[.strikethroughStyle] as? NSNumber, strikethrough.intValue != 0 {
            style.strikethrough = true
        }

        if let underline = attributes[.underlineStyle] as? NSNumber, underline.intValue != 0 {
            style.underline = true
        }

        return style
    }

    private func applyStyle(_ style: TextStyle, to text: String) -> String {
        var value = text

        if style.code {
            value = "`\(value)`"
        }

        if style.bold {
            value = "**\(value)**"
        }

        if style.italic {
            value = "*\(value)*"
        }

        if style.strikethrough {
            value = "~~\(value)~~"
        }

        if style.underline {
            value = "<u>\(value)</u>"
        }

        return value
    }

    private func hasUnsupportedColorAttributes(_ attributes: [NSAttributedString.Key: Any]) -> Bool {
        attributes[.foregroundColor] != nil || attributes[.backgroundColor] != nil
    }

    private func hasUnsupportedParagraphAttributes(_ attributes: [NSAttributedString.Key: Any]) -> Bool {
        guard let paragraphStyle = attributes[.paragraphStyle] as? NSParagraphStyle else { return false }
        return paragraphStyle.firstLineHeadIndent != 0 || paragraphStyle.headIndent != 0 || paragraphStyle.tailIndent != 0
    }

    private func metadataBlock(type: String, location: Int, detail: String) -> String {
        """
        ```preflight-metadata
        type: \(type)
        location: \(location)
        detail: \(detail)
        ```
        """
    }

    private func escapeMarkdown(_ text: String) -> String {
        var escaped = ""
        for scalar in text.unicodeScalars {
            switch scalar {
            case "\\", "`", "*", "_", "[", "]":
                escaped.append("\\")
                escaped.append(String(scalar))
            default:
                escaped.append(String(scalar))
            }
        }
        return escaped
    }
}

private struct TextStyle {
    var bold = false
    var italic = false
    var code = false
    var strikethrough = false
    var underline = false
}
