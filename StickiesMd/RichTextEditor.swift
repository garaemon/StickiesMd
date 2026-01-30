import SwiftUI
import AppKit
import OrgKit

struct RichTextEditor: View {
    let textStorage: NSTextStorage
    var format: FileFormat
    var isEditable: Bool = true
    var fontColor: String
    var showLineNumbers: Bool
    
    @State private var state = SourceEditorState(cursorPositions: [CursorPosition(line: 0, column: 0)])

    var body: some View {
        SourceEditor(
            textStorage,
            language: language,
            configuration: configuration,
            state: $state
        )
        .padding(.leading, showLineNumbers ? 0 : 8)
        .transparentScrolling(showLineNumbers: showLineNumbers)
    }
    
    var theme: EditorTheme {
        let primaryColor = NSColor(hex: fontColor)?.toSRGB ?? .black.toSRGB
        return EditorTheme(
            text: .init(color: primaryColor),
            insertionPoint: primaryColor,
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
            comments: .init(color: .secondaryLabelColor.toSRGB),
            heading1: .init(color: primaryColor, bold: true, fontSize: 22),
            heading2: .init(color: primaryColor, bold: true, fontSize: 20),
            heading3: .init(color: primaryColor, bold: true, fontSize: 18),
            heading4: .init(color: primaryColor, bold: true, fontSize: 16),
            heading5: .init(color: primaryColor, bold: true, fontSize: 15),
            heading6: .init(color: primaryColor, bold: true, fontSize: 14)
        )
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
            ),
            layout: SourceEditorConfiguration.Layout(
                additionalTextInsets: NSEdgeInsets(top: 1, left: showLineNumbers ? 0 : 4, bottom: 1, right: 8)
            ),
            peripherals: SourceEditorConfiguration.Peripherals(
                showGutter: showLineNumbers,
                showMinimap: false,
                showFoldingRibbon: false
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
    func transparentScrolling(showLineNumbers: Bool) -> some View {
        self.background(TransparentBackgroundView(showLineNumbers: showLineNumbers))
    }
}

struct TransparentBackgroundView: NSViewRepresentable {
    var showLineNumbers: Bool

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
