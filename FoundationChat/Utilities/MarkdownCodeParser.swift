import Foundation

enum MessageSegment: Equatable, Identifiable, Sendable {
    case prose(String)
    case code(language: String?, content: String)

    var id: String {
        switch self {
        case .prose(let text):
            "prose-\(text.hashValue)"
        case .code(let language, let content):
            "code-\(language ?? "")-\(content.hashValue)"
        }
    }
}

enum PreviewableKind: String, Sendable {
    case html
    case css
    case javascript
    case svg
    case react
    case swiftUI
}

enum MarkdownCodeParser {
    /// Parses fenced code blocks (` ```lang ... ``` `) from markdown-ish assistant text.
    static func segments(from text: String) -> [MessageSegment] {
        guard text.contains("```") else {
            return text.isEmpty ? [] : [.prose(text)]
        }

        var result: [MessageSegment] = []
        var remaining = text[...]

        while let openRange = remaining.range(of: "```") {
            let before = String(remaining[..<openRange.lowerBound])
            if !before.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                result.append(.prose(before))
            } else if !before.isEmpty, !result.isEmpty {
                result.append(.prose(before))
            }

            remaining = remaining[openRange.upperBound...]

            var language: String?
            if let newline = remaining.firstIndex(of: "\n") {
                let languageLine = remaining[..<newline]
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !languageLine.isEmpty, !languageLine.contains(" ") {
                    language = languageLine.lowercased()
                }
                remaining = remaining[remaining.index(after: newline)...]
            } else {
                break
            }

            if let closeRange = remaining.range(of: "```") {
                let content = String(remaining[..<closeRange.lowerBound])
                    .trimmingCharacters(in: .newlines)
                result.append(.code(language: language, content: content))
                remaining = remaining[closeRange.upperBound...]
                if remaining.first == "\n" {
                    remaining = remaining.dropFirst()
                }
            } else {
                let content = String(remaining).trimmingCharacters(in: .newlines)
                if !content.isEmpty {
                    result.append(.code(language: language, content: content))
                }
                remaining = ""
                break
            }
        }

        let trailing = String(remaining)
        if !trailing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            result.append(.prose(trailing))
        }

        return result.isEmpty ? [.prose(text)] : result
    }

    static func previewKind(for language: String?, content: String) -> PreviewableKind? {
        guard let language else { return nil }
        switch language.lowercased() {
        case "html", "htm", "xhtml":
            return .html
        case "css":
            return .css
        case "js", "javascript", "mjs":
            return .javascript
        case "svg":
            return .svg
        case "react", "jsx", "tsx", "reactjsx", "react.ts":
            return .react
        case "swiftui":
            return .swiftUI
        case "swift":
            return SwiftUIPreviewRenderer.looksLikeSwiftUI(content) ? .swiftUI : nil
        default:
            return nil
        }
    }

    static func isPreviewable(language: String?, content: String) -> Bool {
        previewKind(for: language, content: content) != nil
    }

    static func previewSourceLabel(for language: String?, content: String) -> String {
        switch previewKind(for: language, content: content) {
        case .react: return "React"
        case .swiftUI: return "SwiftUI"
        case .html: return "HTML"
        case .css: return "CSS"
        case .javascript: return "JavaScript"
        case .svg: return "SVG"
        case .none:
            if let language, !language.isEmpty { return language.uppercased() }
            return "Preview"
        }
    }

    /// Builds a preview document from previewable fences in a message.
    static func previewDocument(from segments: [MessageSegment], focusing focusedContent: String? = nil) -> String? {
        var htmlBlocks: [String] = []
        var cssBlocks: [String] = []
        var jsBlocks: [String] = []
        var svgBlocks: [String] = []
        var reactBlocks: [String] = []
        var swiftUIBlocks: [String] = []
        var focusedKind: PreviewableKind?

        for segment in segments {
            guard case .code(let language, let content) = segment else { continue }
            guard let kind = previewKind(for: language, content: content) else { continue }
            if content == focusedContent {
                focusedKind = kind
            }

            switch kind {
            case .html: htmlBlocks.append(content)
            case .css: cssBlocks.append(content)
            case .javascript: jsBlocks.append(content)
            case .svg: svgBlocks.append(content)
            case .react: reactBlocks.append(content)
            case .swiftUI: swiftUIBlocks.append(content)
            }
        }

        if htmlBlocks.isEmpty, cssBlocks.isEmpty, jsBlocks.isEmpty, svgBlocks.isEmpty,
           reactBlocks.isEmpty, swiftUIBlocks.isEmpty {
            return nil
        }

        if let focusedContent, let focusedKind {
            switch focusedKind {
            case .html:
                htmlBlocks = [focusedContent]
                svgBlocks = []
                reactBlocks = []
                swiftUIBlocks = []
            case .svg:
                svgBlocks = [focusedContent]
                htmlBlocks = []
                reactBlocks = []
                swiftUIBlocks = []
            case .react:
                reactBlocks = [focusedContent]
                swiftUIBlocks = []
            case .swiftUI:
                swiftUIBlocks = [focusedContent]
                reactBlocks = []
            case .css, .javascript:
                break
            }
        }

        // Prefer focused / available React or SwiftUI previews over generic HTML.
        if let focusedKind {
            if focusedKind == .react, let source = reactBlocks.first {
                return ReactPreviewBuilder.document(source: source, css: cssBlocks.joined(separator: "\n"))
            }
            if focusedKind == .swiftUI, let source = swiftUIBlocks.first {
                return SwiftUIPreviewRenderer.document(from: source)
            }
        } else {
            if let source = reactBlocks.first {
                return ReactPreviewBuilder.document(source: source, css: cssBlocks.joined(separator: "\n"))
            }
            if let source = swiftUIBlocks.first {
                return SwiftUIPreviewRenderer.document(from: source)
            }
        }

        if htmlBlocks.count == 1,
           cssBlocks.isEmpty,
           jsBlocks.isEmpty,
           svgBlocks.isEmpty,
           looksLikeFullHTMLDocument(htmlBlocks[0]) {
            return htmlBlocks[0]
        }

        let bodyHTML: String
        if !htmlBlocks.isEmpty {
            bodyHTML = htmlBlocks.joined(separator: "\n")
        } else if !svgBlocks.isEmpty {
            bodyHTML = svgBlocks.joined(separator: "\n")
        } else if !cssBlocks.isEmpty || !jsBlocks.isEmpty {
            bodyHTML = """
            <div class="fc-preview-placeholder">
              <p>Styles and scripts from this reply are applied below.</p>
            </div>
            """
        } else {
            return nil
        }

        let css = cssBlocks.joined(separator: "\n")
        let js = jsBlocks.joined(separator: "\n")

        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="utf-8" />
          <meta name="viewport" content="width=device-width, initial-scale=1" />
          <meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src data: blob:; style-src 'unsafe-inline'; script-src 'unsafe-inline'; font-src data:;" />
          <style>
            :root { color-scheme: light dark; }
            html, body {
              margin: 0;
              padding: 0;
              min-height: 100%;
              font: 15px/1.45 -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif;
              background: Canvas;
              color: CanvasText;
            }
            .fc-preview-root { padding: 16px; box-sizing: border-box; }
            .fc-preview-placeholder { opacity: 0.7; }
            \(css)
          </style>
        </head>
        <body>
          <div class="fc-preview-root">
            \(bodyHTML)
          </div>
          <script>
          \(js)
          </script>
        </body>
        </html>
        """
    }

    static func messageHasPreviewableCode(_ text: String) -> Bool {
        segments(from: text).contains { segment in
            if case .code(let language, let content) = segment {
                return isPreviewable(language: language, content: content)
            }
            return false
        }
    }

    private static func looksLikeFullHTMLDocument(_ html: String) -> Bool {
        let lower = html.lowercased()
        return lower.contains("<html") || lower.contains("<!doctype")
    }
}
