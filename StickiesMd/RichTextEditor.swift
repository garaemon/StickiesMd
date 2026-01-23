import SwiftUI
import AppKit
import OrgKit

struct RichTextEditor: NSViewRepresentable {
    @Binding var text: String
    var format: FileFormat
    var isEditable: Bool = true
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        
        guard let textView = scrollView.documentView as? NSTextView else { return scrollView }
        
        textView.delegate = context.coordinator
        textView.isRichText = false 
        textView.importsGraphics = false
        textView.allowsImageEditing = false
        textView.drawsBackground = false
        textView.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isEditable = isEditable
        textView.isSelectable = true
        
        // Ensure full width and word wrap
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        
        if textView.isEditable != isEditable {
            textView.isEditable = isEditable
        }
        
        if textView.string != text {
            // Keep selection if possible? 
            // Replacing string resets selection.
            // Since this update usually comes from external changes (reloading file), 
            // resetting selection is acceptable or unavoidable.
            textView.string = text
            context.coordinator.highlight(textView: textView)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: RichTextEditor
        
        init(_ parent: RichTextEditor) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            highlight(textView: textView)
        }
        
        func highlight(textView: NSTextView) {
            let text = textView.string
            let parser = OrgParser()
            let document = parser.parse(text, format: parent.format)
            
            let storage = textView.textStorage
            
            // We need to beginEditing/endEditing for batch updates
            storage?.beginEditing()
            
            // Clear attributes but preserve selection logic (handled by view)
            let fullRange = NSRange(location: 0, length: storage?.length ?? 0)
            storage?.setAttributes([
                .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular),
                .foregroundColor: NSColor.textColor
            ], range: fullRange)
            
            // Visit nodes
            let highlighter = HighlightingVisitor(storage: storage)
            highlighter.visit(document)
            
            storage?.endEditing()
            
            // Force layout update and redraw to fix rendering issues when deleting text at the end
            if let layoutManager = textView.layoutManager, let textContainer = textView.textContainer {
                layoutManager.ensureLayout(for: textContainer)
            }
            textView.needsDisplay = true
        }
    }
}

class HighlightingVisitor: OrgVisitor {
    weak var storage: NSTextStorage?
    
    init(storage: NSTextStorage?) {
        self.storage = storage
    }
    
    func visit(_ node: OrgNode) { node.accept(self) }
    func visitDocument(_ node: OrgDocument) { node.children.forEach { visit($0) } }
    
    func visitHeading(_ node: Heading) {
        let size: CGFloat = 22 - CGFloat(min(node.level, 6) * 2)
        storage?.addAttributes([
            .font: NSFont.monospacedSystemFont(ofSize: max(14, size), weight: .bold),
            .foregroundColor: NSColor.labelColor
        ], range: node.range)
    }
    
    func visitParagraph(_ node: Paragraph) { node.children.forEach { visit($0) } }
    
    func visitList(_ node: ListNode) {
        // Just bold the marker? 
        // We parsed the whole list as strings in current AST implementation. 
        // We don't have ranges for markers. 
        // Assuming range covers the whole list.
        // Let's just indent or something?
        // Attributes on plain text view don't support paragraph style easily for partial text without affecting lines.
        // We can apply color.
        // But better to leave as is if we can't do precision.
        // Actually, we can just color the whole list range slightly different?
        // storage?.addAttributes([.foregroundColor: NSColor.secondaryLabelColor], range: node.range)
        // No, user wants readable text.
    }
    
    func visitCodeBlock(_ node: CodeBlock) {
        storage?.addAttributes([
            .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
            .foregroundColor: NSColor.secondaryLabelColor
        ], range: node.range)
    }
    
    func visitHorizontalRule(_ node: HorizontalRule) {
        storage?.addAttributes([
            .strikethroughStyle: NSUnderlineStyle.thick.rawValue,
            .foregroundColor: NSColor.tertiaryLabelColor
        ], range: node.range)
    }
    
    func visitText(_ node: TextNode) {
        // No-op, default styles
    }
    
    func visitStrong(_ node: StrongNode) {
        // applyFontTraits not directly available on NSTextStorage easily, use FontManager
        // Or just add .bold trait
        if let font = storage?.attribute(.font, at: node.range.location, effectiveRange: nil) as? NSFont {
            let boldFont = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
            storage?.addAttribute(.font, value: boldFont, range: node.range)
        }
    }
    
    func visitEmphasis(_ node: EmphasisNode) {
        if let font = storage?.attribute(.font, at: node.range.location, effectiveRange: nil) as? NSFont {
            let italicFont = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
            storage?.addAttribute(.font, value: italicFont, range: node.range)
        }
    }
    
    func visitLink(_ node: LinkNode) {
        storage?.addAttributes([
            .foregroundColor: NSColor.linkColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ], range: node.range)
    }
    
    func visitImage(_ node: ImageNode) {
        storage?.addAttributes([
            .foregroundColor: NSColor.systemPurple
        ], range: node.range)
    }
}