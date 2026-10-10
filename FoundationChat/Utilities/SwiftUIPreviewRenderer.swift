import Foundation

/// Approximate visual preview of SwiftUI view code → HTML/CSS.
/// Not a compiler: common stacks, text, buttons, and modifiers are mapped for iteration feedback.
enum SwiftUIPreviewRenderer {
    static func document(from source: String) -> String {
        let bodySource = extractViewBody(from: source) ?? source
        let html = renderViewExpression(bodySource.trimmingCharacters(in: .whitespacesAndNewlines))
        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="utf-8" />
          <meta name="viewport" content="width=device-width, initial-scale=1" />
          <meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src data:; style-src 'unsafe-inline'; font-src data:;" />
          <style>
            :root { color-scheme: light dark; }
            * { box-sizing: border-box; }
            html, body {
              margin: 0;
              min-height: 100%;
              font: 15px/1.35 -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif;
              background: #f2f2f7;
              color: #1c1c1e;
            }
            @media (prefers-color-scheme: dark) {
              html, body { background: #1c1c1e; color: #f2f2f7; }
              .sui-card { background: #2c2c2e !important; }
              .sui-field { background: #3a3a3c !important; border-color: #48484a !important; color: #f2f2f7 !important; }
              .sui-button { background: #0a84ff !important; }
            }
            .sui-shell {
              min-height: 100vh;
              padding: 20px;
              display: flex;
              justify-content: center;
              align-items: flex-start;
            }
            .sui-device {
              width: min(390px, 100%);
              min-height: 520px;
              border-radius: 28px;
              background: Canvas;
              color: CanvasText;
              box-shadow: 0 18px 50px rgba(0,0,0,0.18);
              overflow: hidden;
              border: 1px solid rgba(127,127,127,0.25);
            }
            .sui-chrome {
              padding: 14px 16px 10px;
              font-size: 12px;
              font-weight: 600;
              letter-spacing: 0.02em;
              opacity: 0.65;
              border-bottom: 1px solid rgba(127,127,127,0.18);
            }
            .sui-content { padding: 16px; }
            .sui-note {
              margin: 0 16px 16px;
              font-size: 11px;
              opacity: 0.55;
            }
            .sui-vstack { display: flex; flex-direction: column; align-items: stretch; }
            .sui-hstack { display: flex; flex-direction: row; align-items: center; }
            .sui-zstack { display: grid; }
            .sui-zstack > * { grid-area: 1 / 1; }
            .sui-list, .sui-form { display: flex; flex-direction: column; gap: 8px; }
            .sui-scroll { max-height: 420px; overflow: auto; }
            .sui-spacer { flex: 1 1 auto; min-width: 8px; min-height: 8px; }
            .sui-divider { height: 1px; background: rgba(127,127,127,0.28); border: 0; margin: 8px 0; }
            .sui-text { margin: 0; }
            .sui-button {
              appearance: none;
              border: 0;
              border-radius: 12px;
              padding: 10px 14px;
              background: #007aff;
              color: white;
              font: inherit;
              font-weight: 600;
              cursor: default;
            }
            .sui-label { display: inline-flex; align-items: center; gap: 8px; }
            .sui-symbol {
              width: 28px; height: 28px; border-radius: 8px;
              display: inline-flex; align-items: center; justify-content: center;
              background: rgba(127,127,127,0.16); font-size: 14px;
            }
            .sui-field {
              width: 100%;
              border: 1px solid rgba(127,127,127,0.35);
              border-radius: 10px;
              padding: 10px 12px;
              background: rgba(127,127,127,0.08);
              color: inherit;
              font: inherit;
            }
            .sui-toggle {
              width: 48px; height: 28px; border-radius: 999px;
              background: #34c759; position: relative; flex: 0 0 auto;
            }
            .sui-toggle::after {
              content: "";
              position: absolute; top: 2px; right: 2px;
              width: 24px; height: 24px; border-radius: 50%; background: white;
            }
            .sui-progress {
              height: 6px; border-radius: 999px;
              background: rgba(127,127,127,0.2); overflow: hidden;
            }
            .sui-progress > span {
              display: block; width: 55%; height: 100%; background: #007aff;
            }
            .sui-card {
              background: rgba(127,127,127,0.08);
              border-radius: 16px;
              padding: 12px;
            }
            .sui-unknown {
              border: 1px dashed rgba(127,127,127,0.45);
              border-radius: 10px;
              padding: 8px 10px;
              font: 12px/1.35 ui-monospace, SFMono-Regular, Menlo, monospace;
              opacity: 0.8;
              white-space: pre-wrap;
            }
          </style>
        </head>
        <body>
          <div class="sui-shell">
            <div class="sui-device">
              <div class="sui-chrome">SwiftUI preview (approximate)</div>
              <div class="sui-content">
                \(html)
              </div>
              <p class="sui-note">Approximate layout for directing changes — not a live SwiftUI runtime.</p>
            </div>
          </div>
        </body>
        </html>
        """
    }

    static func looksLikeSwiftUI(_ source: String) -> Bool {
        let markers = [
            "some View", "SwiftUI", "VStack", "HStack", "ZStack", "NavigationStack",
            "List {", "Form {", "ScrollView", ".padding(", "SystemImage", "systemName:"
        ]
        return markers.contains { source.contains($0) }
    }

    // MARK: - Extraction

    private static func extractViewBody(from source: String) -> String? {
        let patterns = [
            #"var\s+body\s*:\s*some\s+View\s*\{"#,
            #"var\s+body\s*:\s*some\s+View\s*\{\s*"#,
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: source, range: NSRange(source.startIndex..., in: source)),
                  let open = Range(match.range, in: source) else { continue }
            let fromBrace = source[open.upperBound...]
            // match already consumed up to `{` if pattern includes it
            if let body = balancedBracesContent(in: String(source[open.lowerBound...])) {
                return body
            }
            _ = fromBrace
        }

        // Fallback: find `body: some View { ... }`
        if let range = source.range(of: #"body\s*:\s*some\s+View\s*\{"#, options: .regularExpression) {
            let from = source[range.lowerBound...]
            if let body = balancedBracesContent(in: String(from)) {
                return body
            }
        }
        return nil
    }

    private static func balancedBracesContent(in text: String) -> String? {
        guard let openIdx = text.firstIndex(of: "{") else { return nil }
        var depth = 0
        var i = openIdx
        var inString: Character?
        var escaped = false
        while i < text.endIndex {
            let ch = text[i]
            if let quote = inString {
                if escaped {
                    escaped = false
                } else if ch == "\\" {
                    escaped = true
                } else if ch == quote {
                    inString = nil
                }
            } else {
                if ch == "\"" || ch == "'" {
                    inString = ch
                } else if ch == "{" {
                    depth += 1
                } else if ch == "}" {
                    depth -= 1
                    if depth == 0 {
                        let innerStart = text.index(after: openIdx)
                        return String(text[innerStart..<i])
                    }
                }
            }
            i = text.index(after: i)
        }
        return nil
    }

    // MARK: - Rendering

    private static func renderViewExpression(_ expression: String) -> String {
        let trimmed = stripComments(expression).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return #"<div class="sui-unknown">Empty view</div>"#
        }

        // Split top-level sibling views if the body is multiple statements.
        let siblings = splitTopLevelViews(trimmed)
        if siblings.count > 1 {
            let children = siblings.map { renderSingleView($0) }.joined(separator: "\n")
            return #"<div class="sui-vstack" style="gap:12px">\#(children)</div>"#
        }
        return renderSingleView(trimmed)
    }

    private static func renderSingleView(_ expression: String) -> String {
        var expr = expression.trimmingCharacters(in: .whitespacesAndNewlines)
        // Drop leading `return`
        if expr.hasPrefix("return ") {
            expr = String(expr.dropFirst(7)).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let (base, modifiers) = splitModifiers(expr)
        var html = renderBaseView(base)
        html = applyModifiers(html, modifiers: modifiers)
        return html
    }

    private static func renderBaseView(_ base: String) -> String {
        let trimmed = base.trimmingCharacters(in: .whitespacesAndNewlines)

        if let text = matchCall(trimmed, name: "Text") {
            let value = extractStringLiteral(from: text.args) ?? text.args.trimmingCharacters(in: .whitespacesAndNewlines)
            return #"<p class="sui-text">\#(escapeHTML(stripInterpolation(value)))</p>"#
        }

        if let button = matchCall(trimmed, name: "Button") {
            let label: String
            if let trailing = button.trailingClosure {
                label = plainText(fromSwiftUILabel: trailing)
            } else {
                label = extractStringLiteral(from: button.args) ?? "Button"
            }
            return #"<button class="sui-button" type="button">\#(escapeHTML(label))</button>"#
        }

        if let label = matchCall(trimmed, name: "Label") {
            let parts = splitTopLevelArguments(label.args)
            let title = parts.first.flatMap { extractStringLiteral(from: $0) } ?? "Label"
            return #"<div class="sui-label"><span class="sui-symbol">◆</span><span>\#(escapeHTML(title))</span></div>"#
        }

        if let image = matchCall(trimmed, name: "Image") {
            let symbol = firstArgumentValue(image.args, key: "systemName") ?? "◇"
            return #"<span class="sui-symbol" title="\#(escapeHTML(symbol))">\#(escapeHTML(shortSymbol(symbol)))</span>"#
        }

        if trimmed == "Spacer()" || trimmed.hasPrefix("Spacer(") {
            return #"<div class="sui-spacer"></div>"#
        }
        if trimmed == "Divider()" || trimmed.hasPrefix("Divider(") {
            return #"<hr class="sui-divider" />"#
        }
        if trimmed.hasPrefix("ProgressView") {
            return #"<div class="sui-progress"><span></span></div>"#
        }
        if let field = matchCall(trimmed, name: "TextField") {
            let placeholder = extractStringLiteral(from: field.args) ?? "Text"
            return #"<input class="sui-field" placeholder="\#(escapeHTML(placeholder))" />"#
        }
        if matchCall(trimmed, name: "SecureField") != nil {
            return #"<input class="sui-field" type="password" placeholder="Password" />"#
        }
        if matchCall(trimmed, name: "Toggle") != nil {
            return #"<div class="sui-hstack" style="gap:10px;justify-content:space-between"><span>Toggle</span><div class="sui-toggle"></div></div>"#
        }

        for container in ["VStack", "HStack", "ZStack", "List", "Form", "ScrollView", "NavigationStack", "Group", "Section"] {
            if let node = matchCall(trimmed, name: container) {
                let childrenSource = node.trailingClosure ?? ""
                let children = splitTopLevelViews(childrenSource)
                    .map { renderSingleView($0) }
                    .joined(separator: "\n")
                let cssClass: String
                switch container {
                case "HStack": cssClass = "sui-hstack"
                case "ZStack": cssClass = "sui-zstack"
                case "List", "Form": cssClass = "sui-list"
                case "ScrollView": cssClass = "sui-scroll sui-vstack"
                default: cssClass = "sui-vstack"
                }
                let gap = container == "HStack" || container == "VStack" ? " style=\"gap:10px\"" : ""
                return #"<div class="\#(cssClass)"\#(gap)>\#(children)</div>"#
            }
        }

        if trimmed.hasPrefix("Color.") || trimmed.hasPrefix("Color(") {
            let color = cssColor(fromSwift: trimmed) ?? "rgba(127,127,127,0.25)"
            return #"<div style="height:48px;border-radius:12px;background:\#(color)"></div>"#
        }

        let preview = String(trimmed.prefix(160))
        return #"<div class="sui-unknown">\#(escapeHTML(preview))</div>"#
    }

    // MARK: - Modifiers

    private static func splitModifiers(_ expression: String) -> (base: String, modifiers: [String]) {
        var parts: [String] = []
        var current = ""
        var depthParen = 0
        var depthBrace = 0
        var depthBracket = 0
        var inString: Character?
        var escaped = false
        let chars = Array(expression)
        var i = 0
        while i < chars.count {
            let ch = chars[i]
            if let quote = inString {
                current.append(ch)
                if escaped {
                    escaped = false
                } else if ch == "\\" {
                    escaped = true
                } else if ch == quote {
                    inString = nil
                }
                i += 1
                continue
            }
            if ch == "\"" || ch == "'" {
                inString = ch
                current.append(ch)
                i += 1
                continue
            }
            switch ch {
            case "(": depthParen += 1
            case ")": depthParen -= 1
            case "{": depthBrace += 1
            case "}": depthBrace -= 1
            case "[": depthBracket += 1
            case "]": depthBracket -= 1
            default: break
            }

            if ch == ".", depthParen == 0, depthBrace == 0, depthBracket == 0, !current.isEmpty {
                // Start of a modifier chain only when current looks like a completed view.
                parts.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
                current = "."
                i += 1
                continue
            }
            current.append(ch)
            i += 1
        }
        if !current.isEmpty {
            parts.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        guard let first = parts.first else { return (expression, []) }
        let modifiers = Array(parts.dropFirst()).map { $0.hasPrefix(".") ? $0 : "." + $0 }
        return (first, modifiers)
    }

    private static func applyModifiers(_ html: String, modifiers: [String]) -> String {
        var style: [String] = []
        var wrapped = html
        var fontWeight: String?
        var fontSize: String?

        for modifier in modifiers {
            if modifier.hasPrefix(".padding") {
                let amount = firstNumericArgument(modifier) ?? "16"
                style.append("padding:\(amount)px")
            } else if modifier.hasPrefix(".frame") {
                if let w = labeledNumericArgument(modifier, key: "width") {
                    style.append("width:\(w)px")
                }
                if let h = labeledNumericArgument(modifier, key: "height") {
                    style.append("height:\(h)px")
                }
                if modifier.contains("maxWidth: .infinity") || modifier.contains("maxWidth:.infinity") {
                    style.append("width:100%")
                }
            } else if modifier.hasPrefix(".background") {
                let inner = argumentList(modifier)
                if let color = cssColor(fromSwift: inner) {
                    style.append("background:\(color)")
                } else {
                    wrapped = #"<div class="sui-card">\#(wrapped)</div>"#
                }
            } else if modifier.hasPrefix(".foregroundStyle") || modifier.hasPrefix(".foregroundColor") {
                let inner = argumentList(modifier)
                if let color = cssColor(fromSwift: inner) {
                    style.append("color:\(color)")
                }
            } else if modifier.hasPrefix(".tint") {
                let inner = argumentList(modifier)
                if let color = cssColor(fromSwift: inner) {
                    style.append("--tint:\(color)")
                }
            } else if modifier.hasPrefix(".cornerRadius") || modifier.hasPrefix(".clipShape(RoundedRectangle") {
                let radius = firstNumericArgument(modifier) ?? "12"
                style.append("border-radius:\(radius)px")
                style.append("overflow:hidden")
            } else if modifier.hasPrefix(".opacity") {
                if let value = firstNumericArgument(modifier) {
                    style.append("opacity:\(value)")
                }
            } else if modifier.hasPrefix(".bold") {
                fontWeight = "700"
            } else if modifier.hasPrefix(".font") {
                if modifier.contains(".title") { fontSize = "28px"; fontWeight = fontWeight ?? "700" }
                else if modifier.contains(".headline") { fontSize = "17px"; fontWeight = fontWeight ?? "600" }
                else if modifier.contains(".subheadline") { fontSize = "15px" }
                else if modifier.contains(".caption") { fontSize = "12px" }
                else if modifier.contains(".largeTitle") { fontSize = "34px"; fontWeight = fontWeight ?? "700" }
                else if modifier.contains(".footnote") { fontSize = "13px" }
            } else if modifier.hasPrefix(".multilineTextAlignment(.center)") {
                style.append("text-align:center")
            }
        }

        if let fontWeight { style.append("font-weight:\(fontWeight)") }
        if let fontSize { style.append("font-size:\(fontSize)") }

        guard !style.isEmpty else { return wrapped }
        let joined = style.joined(separator: ";")
        return "<div style=\"\(joined)\">\(wrapped)</div>"
    }

    // MARK: - Parsing helpers

    private struct CallMatch {
        var args: String
        var trailingClosure: String?
    }

    private static func matchCall(_ expression: String, name: String) -> CallMatch? {
        let trimmed = expression.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix(name) else { return nil }
        let afterName = trimmed.dropFirst(name.count)
        guard let first = afterName.first else { return nil }

        if first == "(" {
            guard let close = indexOfMatchingDelimiter(in: String(afterName), open: "(", close: ")") else { return nil }
            let args = String(String(afterName)[String(afterName).index(after: String(afterName).startIndex)..<close])
            var rest = String(String(afterName)[String(afterName).index(after: close)...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            var trailing: String?
            if rest.hasPrefix("{") {
                if let body = balancedBracesContent(in: rest) {
                    trailing = body
                    // consume braces from rest for completeness
                    _ = rest
                }
            } else if rest.hasPrefix("label:") {
                // Button { } label: { }
                if let brace = rest.firstIndex(of: "{"),
                   let body = balancedBracesContent(in: String(rest[brace...])) {
                    trailing = body
                }
            }
            return CallMatch(args: args, trailingClosure: trailing)
        }

        if first == "{" {
            if let body = balancedBracesContent(in: String(afterName)) {
                return CallMatch(args: "", trailingClosure: body)
            }
        }
        return nil
    }

    private static func indexOfMatchingDelimiter(in text: String, open: Character, close: Character) -> String.Index? {
        var depth = 0
        var inString: Character?
        var escaped = false
        var i = text.startIndex
        while i < text.endIndex {
            let ch = text[i]
            if let quote = inString {
                if escaped { escaped = false }
                else if ch == "\\" { escaped = true }
                else if ch == quote { inString = nil }
            } else if ch == "\"" || ch == "'" {
                inString = ch
            } else if ch == open {
                depth += 1
            } else if ch == close {
                depth -= 1
                if depth == 0 { return i }
            }
            i = text.index(after: i)
        }
        return nil
    }

    private static func splitTopLevelViews(_ source: String) -> [String] {
        let cleaned = stripComments(source)
        var items: [String] = []
        var current = ""
        var depthParen = 0
        var depthBrace = 0
        var depthBracket = 0
        var inString: Character?
        var escaped = false

        for ch in cleaned {
            if let quote = inString {
                current.append(ch)
                if escaped { escaped = false }
                else if ch == "\\" { escaped = true }
                else if ch == quote { inString = nil }
                continue
            }
            if ch == "\"" || ch == "'" {
                inString = ch
                current.append(ch)
                continue
            }
            switch ch {
            case "(": depthParen += 1
            case ")": depthParen -= 1
            case "{": depthBrace += 1
            case "}": depthBrace -= 1
            case "[": depthBracket += 1
            case "]": depthBracket -= 1
            default: break
            }

            if ch == "\n", depthParen == 0, depthBrace == 0, depthBracket == 0 {
                let piece = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !piece.isEmpty, !piece.hasPrefix("//"), piece != "return" {
                    // Keep accumulating if line is clearly a modifier continuation
                    if piece.hasPrefix(".") {
                        current.append(ch)
                        continue
                    }
                    items.append(piece)
                    current = ""
                    continue
                }
            }
            current.append(ch)
        }
        let tail = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty { items.append(tail) }

        // Merge modifier-only fragments into previous
        var merged: [String] = []
        for item in items {
            if item.hasPrefix("."), let last = merged.popLast() {
                merged.append(last + item)
            } else {
                merged.append(item)
            }
        }
        return merged.filter { !$0.hasPrefix("#") && $0 != "EmptyView()" }
    }

    private static func splitTopLevelArguments(_ args: String) -> [String] {
        var parts: [String] = []
        var current = ""
        var depth = 0
        var inString: Character?
        var escaped = false
        for ch in args {
            if let quote = inString {
                current.append(ch)
                if escaped { escaped = false }
                else if ch == "\\" { escaped = true }
                else if ch == quote { inString = nil }
                continue
            }
            if ch == "\"" || ch == "'" {
                inString = ch
                current.append(ch)
                continue
            }
            if ch == "(" || ch == "{" || ch == "[" { depth += 1 }
            if ch == ")" || ch == "}" || ch == "]" { depth -= 1 }
            if ch == ",", depth == 0 {
                parts.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
                current = ""
                continue
            }
            current.append(ch)
        }
        let tail = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty { parts.append(tail) }
        return parts
    }

    private static func extractStringLiteral(from text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: #""([^"\\]|\\.)*""#),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range, in: text) else { return nil }
        let literal = String(text[range])
        return String(literal.dropFirst().dropLast())
            .replacingOccurrences(of: #"\""#, with: "\"")
    }

    private static func firstArgumentValue(_ args: String, key: String) -> String? {
        if let regex = try? NSRegularExpression(pattern: #"\#(key)\s*:\s*"([^"]*)""#),
           let match = regex.firstMatch(in: args, range: NSRange(args.startIndex..., in: args)),
           let range = Range(match.range(at: 1), in: args) {
            return String(args[range])
        }
        return extractStringLiteral(from: args)
    }

    private static func argumentList(_ modifier: String) -> String {
        guard let open = modifier.firstIndex(of: "("),
              let close = indexOfMatchingDelimiter(in: String(modifier[open...]), open: "(", close: ")") else {
            return ""
        }
        let local = String(modifier[open...])
        let innerStart = local.index(after: local.startIndex)
        return String(local[innerStart..<close])
    }

    private static func firstNumericArgument(_ modifier: String) -> String? {
        let args = argumentList(modifier)
        if let regex = try? NSRegularExpression(pattern: #"([0-9]+(?:\.[0-9]+)?)"#),
           let match = regex.firstMatch(in: args, range: NSRange(args.startIndex..., in: args)),
           let range = Range(match.range(at: 1), in: args) {
            return String(args[range])
        }
        // .padding() with no args
        if modifier.hasPrefix(".padding"), args.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "16"
        }
        return nil
    }

    private static func labeledNumericArgument(_ modifier: String, key: String) -> String? {
        let args = argumentList(modifier)
        if let regex = try? NSRegularExpression(pattern: #"\#(key)\s*:\s*([0-9]+(?:\.[0-9]+)?)"#),
           let match = regex.firstMatch(in: args, range: NSRange(args.startIndex..., in: args)),
           let range = Range(match.range(at: 1), in: args) {
            return String(args[range])
        }
        return nil
    }

    private static func cssColor(fromSwift text: String) -> String? {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let map: [String: String] = [
            ".red": "#ff3b30", "Color.red": "#ff3b30",
            ".blue": "#007aff", "Color.blue": "#007aff",
            ".green": "#34c759", "Color.green": "#34c759",
            ".orange": "#ff9500", "Color.orange": "#ff9500",
            ".yellow": "#ffcc00", "Color.yellow": "#ffcc00",
            ".purple": "#af52de", "Color.purple": "#af52de",
            ".pink": "#ff2d55", "Color.pink": "#ff2d55",
            ".gray": "#8e8e93", "Color.gray": "#8e8e93",
            ".primary": "CanvasText", "Color.primary": "CanvasText",
            ".secondary": "GrayText", "Color.secondary": "GrayText",
            ".white": "#ffffff", "Color.white": "#ffffff",
            ".black": "#000000", "Color.black": "#000000",
            ".clear": "transparent", "Color.clear": "transparent",
            ".accentColor": "#007aff", "Color.accentColor": "#007aff",
        ]
        for (key, value) in map where t.contains(key) {
            return value
        }
        if let regex = try? NSRegularExpression(pattern: #"Color\(\s*\.sRGB.*?red:\s*([0-9.]+).*?green:\s*([0-9.]+).*?blue:\s*([0-9.]+)"#, options: [.dotMatchesLineSeparators]),
           let match = regex.firstMatch(in: t, range: NSRange(t.startIndex..., in: t)),
           let r = Range(match.range(at: 1), in: t),
           let g = Range(match.range(at: 2), in: t),
           let b = Range(match.range(at: 3), in: t),
           let rv = Double(t[r]), let gv = Double(t[g]), let bv = Double(t[b]) {
            return "rgb(\(Int(rv * 255)), \(Int(gv * 255)), \(Int(bv * 255)))"
        }
        return nil
    }

    private static func plainText(fromSwiftUILabel source: String) -> String {
        if let text = extractStringLiteral(from: source) { return stripInterpolation(text) }
        if let rendered = source.range(of: #"Text\("([^"]*)"\)"#, options: .regularExpression) {
            return extractStringLiteral(from: String(source[rendered])) ?? "Button"
        }
        return "Button"
    }

    private static func stripInterpolation(_ text: String) -> String {
        text.replacingOccurrences(of: #"\\\(([^)]*)\)"#, with: "…", options: .regularExpression)
    }

    private static func shortSymbol(_ name: String) -> String {
        if name.contains("star") { return "★" }
        if name.contains("heart") { return "♥" }
        if name.contains("person") { return "☺" }
        if name.contains("house") { return "⌂" }
        if name.contains("gear") || name.contains("settings") { return "⚙" }
        if name.contains("plus") { return "+" }
        if name.contains("checkmark") { return "✓" }
        return "◇"
    }

    private static func stripComments(_ source: String) -> String {
        let noBlock = source.replacingOccurrences(of: #"/\*[\s\S]*?\*/"#, with: "", options: .regularExpression)
        let lines = noBlock.components(separatedBy: .newlines).map { line -> String in
            if let range = line.range(of: "//") {
                // naive: ignore // inside strings for preview purposes
                if !line[..<range.lowerBound].contains("\"") {
                    return String(line[..<range.lowerBound])
                }
            }
            return line
        }
        return lines.joined(separator: "\n")
    }

    private static func escapeHTML(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
