import AppKit
import SwiftUI

/// Renders model replies that arrive as Markdown plain text into readable rich text.
struct MarkdownContentView: View {
    let markdown: String
    var isStreaming: Bool = false

    var body: some View {
        let blocks = MarkdownRenderer.blocks(from: markdown)
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(isStreaming && markdown.isEmpty ? 0.7 : 1)
    }

    @ViewBuilder
    private func blockView(_ block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            Text(MarkdownRenderer.inlineAttributed(text))
                .font(headingFont(level))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .paragraph(let text):
            Text(MarkdownRenderer.inlineAttributed(text))
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .bulletList(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("•")
                            .font(.body)
                        Text(MarkdownRenderer.inlineAttributed(item))
                            .font(.body)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        case .numberedList(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(index + 1).")
                            .font(.body.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Text(MarkdownRenderer.inlineAttributed(item))
                            .font(.body)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        case .blockquote(let text):
            HStack(alignment: .top, spacing: 10) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.accentColor.opacity(0.55))
                    .frame(width: 3)
                Text(MarkdownRenderer.inlineAttributed(text))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .code(let language, let code):
            CodeBlockView(language: language, code: code)
        case .image(let alt, let url):
            VStack(alignment: .leading, spacing: 4) {
                Label(alt.isEmpty ? "Image" : alt, systemImage: "photo")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                if let url {
                    Text(url)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .textSelection(.enabled)
                        .lineLimit(2)
                }
            }
        case .thematicBreak:
            Divider()
                .padding(.vertical, 2)
        }
    }

    private func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: .title2.weight(.semibold)
        case 2: .title3.weight(.semibold)
        case 3: .headline
        default: .body.weight(.semibold)
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
    case heading(level: Int, text: String)
    case paragraph(String)
    case bulletList([String])
    case numberedList([String])
    case blockquote(String)
    case code(language: String?, code: String)
    case image(alt: String, url: String?)
    case thematicBreak
}

enum MarkdownRenderer {
    static func blocks(from source: String) -> [MarkdownBlock] {
        let normalized = MarkdownNormalizer.normalize(source)
        let unwrapped = MarkdownNormalizer.unwrapMarkdownFences(normalized)
        return parseBlocks(unwrapped)
    }

    /// Inline-only Markdown (bold, italic, code, links) — block structure is handled separately.
    static func inlineAttributed(_ markdown: String) -> AttributedString {
        var options = AttributedString.MarkdownParsingOptions()
        options.interpretedSyntax = .inlineOnlyPreservingWhitespace
        options.failurePolicy = .returnPartiallyParsedIfPossible

        do {
            return try AttributedString(markdown: markdown, options: options)
        } catch {
            return AttributedString(markdown)
        }
    }

    private static func parseBlocks(_ source: String) -> [MarkdownBlock] {
        guard !source.isEmpty else { return [] }

        var blocks: [MarkdownBlock] = []
        let lines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var index = 0

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                index += 1
                continue
            }

            if trimmed.hasPrefix("```") {
                let language = String(trimmed.dropFirst(3))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                index += 1
                var codeLines: [String] = []
                while index < lines.count {
                    let codeLine = lines[index]
                    if codeLine.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                        index += 1
                        break
                    }
                    codeLines.append(codeLine)
                    index += 1
                }
                let code = codeLines.joined(separator: "\n")
                let lang = language.isEmpty ? nil : language
                if MarkdownNormalizer.shouldRenderFencedMarkdown(language: lang, code: code) {
                    // Nested markdown demo fence — render contents, don't show as code.
                    blocks.append(contentsOf: parseBlocks(code))
                } else {
                    blocks.append(.code(language: lang, code: code))
                }
                continue
            }

            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                blocks.append(.thematicBreak)
                index += 1
                continue
            }

            if let image = parseImage(trimmed) {
                blocks.append(image)
                index += 1
                continue
            }

            if let heading = parseHeading(trimmed) {
                blocks.append(heading)
                index += 1
                continue
            }

            if trimmed.hasPrefix(">") {
                var quoteLines: [String] = []
                while index < lines.count {
                    let q = lines[index].trimmingCharacters(in: .whitespaces)
                    guard q.hasPrefix(">") else { break }
                    let content = q.dropFirst().trimmingCharacters(in: .whitespaces)
                    quoteLines.append(content)
                    index += 1
                }
                blocks.append(.blockquote(quoteLines.joined(separator: "\n")))
                continue
            }

            if isBullet(trimmed) {
                var items: [String] = []
                while index < lines.count {
                    let itemLine = lines[index].trimmingCharacters(in: .whitespaces)
                    guard isBullet(itemLine) else { break }
                    items.append(stripBullet(itemLine))
                    index += 1
                }
                blocks.append(.bulletList(items))
                continue
            }

            if isNumbered(trimmed) {
                var items: [String] = []
                while index < lines.count {
                    let itemLine = lines[index].trimmingCharacters(in: .whitespaces)
                    guard isNumbered(itemLine) else { break }
                    items.append(stripNumbered(itemLine))
                    index += 1
                }
                blocks.append(.numberedList(items))
                continue
            }

            // Paragraph: gather until blank line or next block marker.
            var paragraphLines: [String] = [trimmed]
            index += 1
            while index < lines.count {
                let next = lines[index]
                let nextTrimmed = next.trimmingCharacters(in: .whitespaces)
                if nextTrimmed.isEmpty { break }
                if nextTrimmed.hasPrefix("```")
                    || nextTrimmed.hasPrefix("#")
                    || nextTrimmed.hasPrefix(">")
                    || nextTrimmed == "---"
                    || nextTrimmed == "***"
                    || nextTrimmed == "___"
                    || isBullet(nextTrimmed)
                    || isNumbered(nextTrimmed)
                    || parseImage(nextTrimmed) != nil {
                    break
                }
                paragraphLines.append(nextTrimmed)
                index += 1
            }
            blocks.append(.paragraph(paragraphLines.joined(separator: " ")))
        }

        return blocks
    }

    private static func parseHeading(_ line: String) -> MarkdownBlock? {
        guard line.hasPrefix("#") else { return nil }
        var level = 0
        for character in line {
            if character == "#" { level += 1 } else { break }
        }
        guard level >= 1, level <= 6 else { return nil }
        let rest = line.dropFirst(level)
        guard rest.first == " " || rest.isEmpty else { return nil }
        let text = rest.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }
        return .heading(level: level, text: text)
    }

    private static func parseImage(_ line: String) -> MarkdownBlock? {
        // ![alt](url)
        guard line.hasPrefix("![") else { return nil }
        guard let altClose = line.firstIndex(of: "]"),
              altClose < line.endIndex,
              line[line.index(after: altClose)] == "("
        else { return nil }
        let altStart = line.index(line.startIndex, offsetBy: 2)
        let alt = String(line[altStart..<altClose])
        let urlStart = line.index(after: line.index(after: altClose))
        guard let urlClose = line[urlStart...].firstIndex(of: ")") else { return nil }
        let url = String(line[urlStart..<urlClose]).trimmingCharacters(in: .whitespaces)
        return .image(alt: alt, url: url.isEmpty ? nil : url)
    }

    private static func isBullet(_ line: String) -> Bool {
        line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ")
    }

    private static func stripBullet(_ line: String) -> String {
        String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
    }

    private static func isNumbered(_ line: String) -> Bool {
        guard let dot = line.firstIndex(of: ".") else { return false }
        let number = line[line.startIndex..<dot]
        guard !number.isEmpty, number.allSatisfy(\.isNumber) else { return false }
        let after = line[dot...]
        return after.hasPrefix(". ")
    }

    private static func stripNumbered(_ line: String) -> String {
        guard let dot = line.firstIndex(of: ".") else { return line }
        let after = line[line.index(after: dot)...]
        return after.trimmingCharacters(in: .whitespaces)
    }
}

enum MarkdownNormalizer {
    /// Turns common model-output quirks into parseable Markdown.
    static func normalize(_ raw: String) -> String {
        var text = raw

        // Some replies arrive with literal escape sequences instead of real newlines.
        if text.contains("\\n"), text.filter({ $0 == "\n" }).count < 2 {
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

    /// Models often wrap demo Markdown in ```markdown fences — unwrap those so content renders.
    static func unwrapMarkdownFences(_ source: String) -> String {
        let lines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var result: [String] = []
        var index = 0

        while index < lines.count {
            let openLine = lines[index]
            let trimmed = openLine.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("```") else {
                result.append(openLine)
                index += 1
                continue
            }

            let language = String(trimmed.dropFirst(3))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let lang = language.isEmpty ? nil : language
            let openIndex = index
            index += 1

            var codeLines: [String] = []
            var closed = false
            while index < lines.count {
                let inner = lines[index]
                if inner.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    index += 1
                    closed = true
                    break
                }
                codeLines.append(inner)
                index += 1
            }

            let code = codeLines.joined(separator: "\n")
            if shouldRenderFencedMarkdown(language: lang, code: code) {
                result.append(contentsOf: codeLines)
            } else {
                // Keep real code fences intact (including an unclosed streaming fence).
                result.append(openLine)
                result.append(contentsOf: codeLines)
                if closed {
                    let closeIndex = openIndex + 1 + codeLines.count
                    if closeIndex < lines.count {
                        result.append(lines[closeIndex])
                    }
                }
            }
        }

        return result.joined(separator: "\n")
    }

    /// True for `markdown` / `md` / `gfm` (and info strings like `markdown title=…`),
    /// or bare fences whose body is clearly Markdown demo content (not source code).
    static func shouldRenderFencedMarkdown(language: String?, code: String) -> Bool {
        if isMarkdownLanguage(language) { return true }
        // Bare ``` … ``` demos — only unwrap when the body looks like Markdown, not code.
        if language == nil || language?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
            return looksLikeMarkdownDemo(code)
        }
        return false
    }

    static func isMarkdownLanguage(_ language: String?) -> Bool {
        guard let language else { return false }
        let firstToken = language
            .lowercased()
            .split(whereSeparator: { $0.isWhitespace || $0 == "," })
            .first
            .map(String.init) ?? ""
        return firstToken == "markdown" || firstToken == "md" || firstToken == "gfm"
    }

    /// Heuristic for unlabeled fences that are Markdown samples, not programming code.
    static func looksLikeMarkdownDemo(_ code: String) -> Bool {
        let lines = code
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard lines.count >= 2 else { return false }

        var markers = 0
        for line in lines {
            if line.hasPrefix("#")
                || line.hasPrefix(">")
                || line.hasPrefix("- ")
                || line.hasPrefix("* ")
                || line.hasPrefix("+ ")
                || line.hasPrefix("![")
                || (line.hasPrefix("[") && line.contains("](")) {
                markers += 1
                continue
            }
            // numbered list "1. "
            if let dot = line.firstIndex(of: "."),
               line[line.startIndex..<dot].allSatisfy(\.isNumber),
               line[dot...].hasPrefix(". ") {
                markers += 1
            }
        }

        // Require a solid Markdown signal so Swift/Python fences stay as code.
        return markers >= 2 && markers * 3 >= lines.count
    }
}
