import AppKit
import SwiftUI
import WebKit

struct CodePreviewPayload: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let htmlDocument: String
    let sourceLabel: String
}

struct MessageBodyView: View {
    let text: String
    let isStreaming: Bool
    var onPreview: (CodePreviewPayload) -> Void

    private var segments: [MessageSegment] {
        MarkdownCodeParser.segments(from: text)
    }

    private var hasCodeBlocks: Bool {
        segments.contains { if case .code = $0 { true } else { false } }
    }

    var body: some View {
        if text.isEmpty {
            EmptyView()
        } else if !hasCodeBlocks {
            Text(text)
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                    switch segment {
                    case .prose(let prose):
                        if !prose.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(prose)
                                .font(.body)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    case .code(let language, let content):
                        CodeBlockView(
                            language: language,
                            content: content,
                            canPreview: !isStreaming && MarkdownCodeParser.isPreviewable(language: language, content: content),
                            onCopy: { copyToPasteboard(content) },
                            onPreview: {
                                presentPreview(focusing: content, language: language)
                            }
                        )
                    }
                }

                if !isStreaming, MarkdownCodeParser.messageHasPreviewableCode(text) {
                    Button {
                        presentPreview(focusing: nil, language: nil)
                    } label: {
                        Label("Preview result", systemImage: "eye")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Open a visual preview of HTML, React, or SwiftUI from this reply")
                }
            }
        }
    }

    private func presentPreview(focusing content: String?, language: String?) {
        let document = MarkdownCodeParser.previewDocument(from: segments, focusing: content)
        guard let document else { return }
        let label: String
        if let content {
            label = MarkdownCodeParser.previewSourceLabel(for: language, content: content)
        } else {
            let kinds = segments.compactMap { segment -> PreviewableKind? in
                guard case .code(let language, let block) = segment else { return nil }
                return MarkdownCodeParser.previewKind(for: language, content: block)
            }
            if kinds.contains(.react) {
                label = "React"
            } else if kinds.contains(.swiftUI) {
                label = "SwiftUI"
            } else {
                label = "HTML / CSS / JS"
            }
        }
        onPreview(
            CodePreviewPayload(
                title: "Code Preview",
                htmlDocument: document,
                sourceLabel: label
            )
        )
    }

    private func copyToPasteboard(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }
}

struct CodeBlockView: View {
    let language: String?
    let content: String
    let canPreview: Bool
    var onCopy: () -> Void
    var onPreview: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text(displayLanguage)
                    .font(.caption.weight(.semibold).monospaced())
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                if canPreview {
                    Button(action: onPreview) {
                        Label("Preview", systemImage: "eye")
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    .help("Preview this code visually")
                }
                Button(action: onCopy) {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .help("Copy this code block")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.05))

            ScrollView(.horizontal, showsIndicators: true) {
                Text(content)
                    .font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
            }
            .frame(maxHeight: 280, alignment: .top)
        }
        .background(Color(nsColor: .textBackgroundColor).opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private var displayLanguage: String {
        guard let language, !language.isEmpty else { return "code" }
        return language
    }
}

struct CodePreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let payload: CodePreviewPayload

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(payload.title)
                        .font(.title3.weight(.semibold))
                    Text("Live result · \(payload.sourceLabel)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Divider()

            CodePreviewWebView(html: payload.htmlDocument)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            Text(footerCopy)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
        }
        .frame(minWidth: 640, idealWidth: 820, minHeight: 480, idealHeight: 600)
    }

    private var footerCopy: String {
        let label = payload.sourceLabel.lowercased()
        if label.contains("react") {
            return "React preview compiles JSX/TSX in a sandboxed web view (React + Babel from unpkg). Needs network once to load those runtimes."
        }
        if label.contains("swiftui") {
            return "SwiftUI preview is an approximate layout for directing changes — not a live SwiftUI runtime."
        }
        return "Preview runs in a sandboxed web view. A richer gen-UI library can plug in here later."
    }
}

struct CodePreviewWebView: NSViewRepresentable {
    let html: String

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = false
        webView.allowsMagnification = true
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.lastHTML != html else { return }
        context.coordinator.lastHTML = html
        webView.loadHTMLString(html, baseURL: nil)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var lastHTML: String?

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction
        ) async -> WKNavigationActionPolicy {
            guard let url = navigationAction.request.url else {
                return .cancel
            }

            // Initial HTML string load.
            if navigationAction.navigationType == .other,
               url.scheme == "about" || url.absoluteString.isEmpty {
                return .allow
            }

            // React preview runtimes (script navigations / redirected loads).
            if navigationAction.navigationType == .other,
               url.host == "unpkg.com",
               url.scheme == "https" {
                return .allow
            }

            return .cancel
        }
    }
}
