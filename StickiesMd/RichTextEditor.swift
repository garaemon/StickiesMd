import SwiftUI
import AppKit
import OrgKit

struct RichTextEditor: View {
    let textStorage: NSTextStorage
    var format: FileFormat
    var isEditable: Bool = true
    
    // Create a default theme matching system colors somewhat
    @State private var theme = EditorTheme(
        text: .init(color: .black.toSRGB),
        insertionPoint: .black.toSRGB,
        invisibles: .init(color: .tertiaryLabelColor.toSRGB),
        background: .clear.toSRGB, // Transparent background
        lineHighlight: .clear.toSRGB,
        selection: .selectedTextBackgroundColor.toSRGB,
        keywords: .init(color: .systemPink.toSRGB, bold: true),
        commands: .init(color: .systemBlue.toSRGB),
        types: .init(color: .systemTeal.toSRGB),
        attributes: .init(color: .systemBrown.toSRGB),
        variables: .init(color: .systemPurple.toSRGB),
        values: .init(color: .systemOrange.toSRGB),
        numbers: .init(color: .systemGreen.toSRGB),
        strings: .init(color: .systemRed.toSRGB),
        characters: .init(color: .systemRed.toSRGB),
        comments: .init(color: .secondaryLabelColor.toSRGB)
    )
    
    @State private var state = SourceEditorState(cursorPositions: [CursorPosition(line: 0, column: 0)])

    var body: some View {
        SourceEditor(
            textStorage,
            language: language,
            configuration: configuration,
            state: $state
        )
        .transparentScrolling()
    }
    
    var configuration: SourceEditorConfiguration {
        SourceEditorConfiguration(
            appearance: SourceEditorConfiguration.Appearance(
                theme: theme,
                useThemeBackground: true, // Respect theme colors including transparency
                font: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular),
                wrapLines: true
            ),
            behavior: SourceEditorConfiguration.Behavior(
                isEditable: isEditable
            )
        )
    }
    
    var language: CodeLanguage {
        switch format {
        case .markdown: return .markdown
        case .org: return .markdown // Temporary workaround: use markdown for org to avoid crash with .default
        }
    }
}

extension View {
    func transparentScrolling() -> some View {
        self.background(TransparentBackgroundView())
    }
}

struct TransparentBackgroundView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            // Traverse up to find the hosting view, then search for NSTextView
            guard let window = nsView.window else { return }
            
            // We search for scroll views in the window content view.
            // Since StickiesMd usually has one editor per window, this global search within window is acceptable.
            if let contentView = window.contentView {
                self.makeTransparent(view: contentView)
            }
        }
    }
    
    func makeTransparent(view: NSView) {
        if let scrollView = view as? NSScrollView {
            scrollView.drawsBackground = false
            scrollView.backgroundColor = .clear
            
            // Also handle the clip view just in case
            scrollView.contentView.drawsBackground = false
            scrollView.contentView.backgroundColor = .clear
            
            if let textView = scrollView.documentView as? NSTextView {
                textView.drawsBackground = false
                textView.backgroundColor = .clear
            }
        }
        
        for subview in view.subviews {
            makeTransparent(view: subview)
        }
    }
}
