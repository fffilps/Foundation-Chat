import AppKit
import SwiftUI

/// Renders model replies that arrive as Markdown plain text into readable rich text.
struct MarkdownContentView: View {
    let markdown: String
    var isStreaming: Bool = false

    var body: some View {
        let blocks = MarkdownBlockParser.blocks(from: markdown)
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                switch block {
                case .markdown(let text):
                    Text(Self.attributed(from: text, streaming: isStreaming))
                        .font(.body)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                case .code(let language, let code):
                    CodeBlockView(language: language, code: code)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    static func attributed(from markdown: String, streaming: Bool) -> AttributedString {
        let normalized = MarkdownNormalizer.normalize(markdown)
        var options = AttributedString.MarkdownParsingOptions()
        options.interpretedSyntax = streaming ? .inlineOnlyPreservingWhitespace : .full
        options.failurePolicy = .returnPartiallyParsedIfPossible

        do {
            return try AttributedString(
                markdown: normalized,
                options: options
            )
        } catch {
            return AttributedString(normalized)
        }
    }
}

private struct CodeBlockView: View {
    let language: String?
    let code: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                if let language, !language.isEmpty {
                    Text(language)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                }
                Spacer(minLength: 8)
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(code, forType: .string)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.caption)
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Copy code")
            }

            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor).opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

enum MarkdownBlock: Equatable {
    case markdown(String)
    case code(language: String?, code: String)
}

enum MarkdownBlockParser {
    /// Splits fenced code blocks out so they can be styled separately from inline markdown.
    static func blocks(from source: String) -> [MarkdownBlock] {
        let text = MarkdownNormalizer.normalize(source)
        guard text.contains("```") else {
            return text.isEmpty ? [] : [.markdown(text)]
        }

        var blocks: [MarkdownBlock] = []
        var remainder = text[...]

        while let openRange = remainder.range(of: "```") {
            let before = String(remainder[..<openRange.lowerBound])
            if !before.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                blocks.append(.markdown(before))
            }

            let afterFence = remainder[openRange.upperBound...]
            let headerEnd = afterFence.firstIndex(of: "\n") ?? afterFence.endIndex
            let language = String(afterFence[..<headerEnd])
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let bodyStart = headerEnd == afterFence.endIndex
                ? afterFence.endIndex
                : afterFence.index(after: headerEnd)
            let bodySlice = afterFence[bodyStart...]

            if let closeRange = bodySlice.range(of: "```") {
                var code = String(bodySlice[..<closeRange.lowerBound])
                if code.hasSuffix("\n") {
                    code.removeLast()
                }
                blocks.append(.code(language: language.isEmpty ? nil : language, code: code))
                remainder = bodySlice[closeRange.upperBound...]
                if remainder.first == "\n" {
                    remainder = remainder.dropFirst()
                }
            } else {
                // Unclosed fence while streaming — show remaining text as a live code block.
                let code = String(bodySlice)
                blocks.append(.code(language: language.isEmpty ? nil : language, code: code))
                remainder = ""
                break
            }
        }

        let trailing = String(remainder)
        if !trailing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            blocks.append(.markdown(trailing))
        }

        return blocks.isEmpty ? [.markdown(text)] : blocks
    }
}

enum MarkdownNormalizer {
    /// Turns common model-output quirks into parseable Markdown.
    static func normalize(_ raw: String) -> String {
        var text = raw

        // Some replies arrive with literal escape sequences instead of real newlines.
        if text.contains("\\n") && !text.contains("\n") {
            text = text
                .replacingOccurrences(of: "\\n", with: "\n")
                .replacingOccurrences(of: "\\t", with: "\t")
                .replacingOccurrences(of: "\\\"", with: "\"")
        }

        // Trim a single wrapping pair of quotes around the whole reply.
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count >= 2,
           (trimmed.hasPrefix("\"") && trimmed.hasSuffix("\""))
            || (trimmed.hasPrefix("'") && trimmed.hasSuffix("'")) {
            text = String(trimmed.dropFirst().dropLast())
        }

        return text
    }
}
