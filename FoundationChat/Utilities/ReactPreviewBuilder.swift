import Foundation

enum ReactPreviewBuilder {
    /// Builds an HTML document that compiles JSX/TSX with Babel Standalone and renders with React 18.
    static func document(source: String, css: String = "", title: String = "React Preview") -> String {
        let prepared = prepareSource(source)
        let escapedCSS = css // already author CSS; keep raw inside <style>
        let componentHint = detectComponentName(in: source)

        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="utf-8" />
          <meta name="viewport" content="width=device-width, initial-scale=1" />
          <meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src data: blob: https:; style-src 'unsafe-inline'; script-src 'unsafe-inline' 'unsafe-eval' https://unpkg.com; connect-src https://unpkg.com; font-src data: https:;" />
          <title>\(title)</title>
          <style>
            :root { color-scheme: light dark; }
            html, body {
              margin: 0;
              min-height: 100%;
              font: 15px/1.45 -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif;
              background: Canvas;
              color: CanvasText;
            }
            #root { padding: 16px; box-sizing: border-box; min-height: 100%; }
            #fc-react-error {
              display: none;
              margin: 16px;
              padding: 12px 14px;
              border-radius: 10px;
              background: rgba(255, 59, 48, 0.12);
              color: #b00020;
              white-space: pre-wrap;
              font: 13px/1.4 ui-monospace, SFMono-Regular, Menlo, monospace;
            }
            #fc-react-error.visible { display: block; }
            \(escapedCSS)
          </style>
          <script crossorigin src="https://unpkg.com/react@18.3.1/umd/react.development.js"></script>
          <script crossorigin src="https://unpkg.com/react-dom@18.3.1/umd/react-dom.development.js"></script>
          <script src="https://unpkg.com/@babel/standalone@7.26.10/babel.min.js"></script>
        </head>
        <body>
          <div id="fc-react-error"></div>
          <div id="root"></div>
          <script>
            window.__FC_REACT_COMPONENT_HINT__ = \(jsonString(componentHint));
            window.addEventListener('error', function (event) {
              var box = document.getElementById('fc-react-error');
              if (!box) return;
              box.textContent = (event.error && event.error.stack) ? event.error.stack : (event.message || 'React preview error');
              box.classList.add('visible');
            });
          </script>
          <script type="text/babel" data-presets="env,react,typescript">
        \(prepared)

        (function () {
          const hint = window.__FC_REACT_COMPONENT_HINT__;
          const candidates = [hint, 'App', 'Main', 'Preview', 'Component', 'Demo', 'Example', '__FC_DEFAULT__']
            .filter(Boolean);
          let Component = window.__FC_REACT_COMPONENT__ || null;
          for (const name of candidates) {
            const value = window[name];
            if (typeof value === 'function' || (value && typeof value === 'object')) {
              Component = value;
              break;
            }
          }
          const mount = document.getElementById('root');
          const errorBox = document.getElementById('fc-react-error');
          if (!Component) {
            errorBox.textContent = 'Could not find a React component to render. Export a default component or name it App.';
            errorBox.classList.add('visible');
            return;
          }
          try {
            const root = ReactDOM.createRoot(mount);
            root.render(React.createElement(Component));
          } catch (error) {
            errorBox.textContent = error && error.stack ? error.stack : String(error);
            errorBox.classList.add('visible');
          }
        })();
          </script>
        </body>
        </html>
        """
    }

    private static func prepareSource(_ source: String) -> String {
        var lines = source.components(separatedBy: .newlines)
        lines = lines.map { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("import ") { return "// " + line }
            if trimmed.hasPrefix("export {") || trimmed.hasPrefix("export *") { return "// " + line }
            return line
                .replacingOccurrences(of: "export default function", with: "function")
                .replacingOccurrences(of: "export default class", with: "class")
                .replacingOccurrences(of: "export function", with: "function")
                .replacingOccurrences(of: "export class", with: "class")
                .replacingOccurrences(of: "export const", with: "const")
                .replacingOccurrences(of: "export let", with: "let")
                .replacingOccurrences(of: "export var", with: "var")
                .replacingOccurrences(of: "export default ", with: "const __FC_DEFAULT__ = ")
        }

        var body = lines.joined(separator: "\n")
        if body.contains("__FC_DEFAULT__") {
            body += """

            const App = (typeof App !== 'undefined' ? App : __FC_DEFAULT__);
            """
        }

        body += """

        ;(() => {
          const g = globalThis;
          const names = ['App', 'Main', 'Preview', 'Component', 'Demo', 'Example', '__FC_DEFAULT__'];
          for (const name of names) {
            try {
              const value = eval(name);
              if (typeof value === 'function' || (value && typeof value === 'object')) {
                g[name] = value;
                g.__FC_REACT_COMPONENT__ = g.__FC_REACT_COMPONENT__ || value;
              }
            } catch (_) {}
          }
          if (typeof __FC_DEFAULT__ !== 'undefined') {
            g.__FC_REACT_COMPONENT__ = g.__FC_REACT_COMPONENT__ || __FC_DEFAULT__;
          }
        })();
        """

        return body
    }

    private static func detectComponentName(in source: String) -> String? {
        let patterns = [
            #"export\s+default\s+function\s+([A-Z][A-Za-z0-9_]*)"#,
            #"export\s+default\s+([A-Z][A-Za-z0-9_]*)"#,
            #"function\s+([A-Z][A-Za-z0-9_]*)\s*\("#,
            #"const\s+([A-Z][A-Za-z0-9_]*)\s*=\s*(?:\(|function|React\.forwardRef)"#,
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: source, range: NSRange(source.startIndex..., in: source)),
               let range = Range(match.range(at: 1), in: source) {
                return String(source[range])
            }
        }
        return nil
    }

    private static func jsonString(_ value: String?) -> String {
        guard let value else { return "null" }
        let data = try? JSONSerialization.data(withJSONObject: value, options: [])
        return data.flatMap { String(data: $0, encoding: .utf8) } ?? "null"
    }
}
