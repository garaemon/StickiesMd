import SwiftUI
import AppKit
import OrgKit
import SwiftTreeSitter
import CodeEditLanguages

struct RichTextEditor: NSViewRepresentable {
    let textStorage: NSTextStorage
    var format: FileFormat
    var isEditable: Bool
    var fontColor: String
    var showLineNumbers: Bool
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        
        scrollView.contentView.drawsBackground = false
        scrollView.contentView.backgroundColor = .clear
        
        let textView = NSTextView(usingTextLayoutManager: true)
        textView.autoresizingMask = [.width]
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        
        textView.isEditable = isEditable
        textView.isRichText = false
        textView.importsGraphics = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        let color = NSColor(hex: fontColor) ?? .textColor
        textView.textColor = color
        textView.insertionPointColor = color
        
        if let textLayoutManager = textView.textLayoutManager {
            if let textContentStorage = textLayoutManager.textContentManager as? NSTextContentStorage {
                textContentStorage.textStorage = textStorage
                textContentStorage.delegate = context.coordinator
                context.coordinator.textLayoutManager = textLayoutManager
                context.coordinator.textContentStorage = textContentStorage
                if let textContainer = textLayoutManager.textContainer {
                    textContainer.widthTracksTextView = true
                }
                textLayoutManager.ensureLayout(for: textLayoutManager.documentRange)
            }
        }
        
        textView.delegate = context.coordinator
        scrollView.documentView = textView
        
        context.coordinator.applyHighlighting()
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        
        if textView.isEditable != isEditable {
            textView.isEditable = isEditable
        }
        
        if let color = NSColor(hex: fontColor) {
            if textView.textColor != color {
                textView.textColor = color
                textView.insertionPointColor = color
            }
        }
        
        if showLineNumbers {
            nsView.rulersVisible = true
            if !(nsView.verticalRulerView is LineNumberRulerView) {
                nsView.verticalRulerView = LineNumberRulerView(textView: textView)
            }
        } else {
            nsView.rulersVisible = false
        }
        
        context.coordinator.applyHighlighting()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate, NSTextContentStorageDelegate {
        var parent: RichTextEditor
        var textLayoutManager: NSTextLayoutManager?
        var textContentStorage: NSTextContentStorage?
        var parser: Parser
        
        init(_ parent: RichTextEditor) {
            self.parent = parent
            self.parser = Parser()
            super.init()
            setupParser()
        }
        
        func setupParser() {
            if let codeLang = CodeLanguage.allLanguages.first(where: { 
                let id = "\($0.id)".lowercased()
                return id == "markdown" || id.contains("markdown")
            }), let tsLang = codeLang.language {
                try? parser.setLanguage(tsLang)
            }
        }
        
        func textDidChange(_ notification: Notification) {
            applyHighlighting()
        }
        
        func applyHighlighting() {
            guard let textContentStorage = textContentStorage,
                  let textStorage = textContentStorage.textStorage else { return }
            
            let string = textStorage.string
            if string.isEmpty { return }
            
            guard let tree = parser.parse(string) else { return }
            
            textStorage.beginEditing()
            let fullRange = NSRange(location: 0, length: textStorage.length)
            let defaultFont = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
            let defaultColor = NSColor(hex: parent.fontColor) ?? .textColor
            textStorage.setAttributes([.font: defaultFont, .foregroundColor: defaultColor], range: fullRange)
            
            if let rootNode = tree.rootNode {
                highlightNode(rootNode, in: textStorage)
            }
            textStorage.endEditing()
            
            if let lm = textLayoutManager {
                lm.ensureLayout(for: lm.documentRange)
            }
        }
        
        private func highlightNode(_ node: Node, in textStorage: NSTextStorage) {
            if let type = node.nodeType {
                // Highlighting headings
                if type == "atx_heading" || type == "setext_heading" || (type.contains("heading") && !type.contains("content")) {
                    let byteRange = node.byteRange
                    // Fix: Tree-sitter byte offsets are 2x UTF-16 unit offsets in this integration
                    let start = Int(byteRange.lowerBound) / 2
                    let end = Int(byteRange.upperBound) / 2
                    
                    if end > start && end <= textStorage.length {
                        let range = NSRange(location: start, length: end - start)
                        let font = NSFont.systemFont(ofSize: 18, weight: .bold)
                        textStorage.addAttribute(.font, value: font, range: range)
                    }
                }
            }
            
            for i in 0..<node.childCount {
                if let child = node.child(at: i) {
                    highlightNode(child, in: textStorage)
                }
            }
        }
    }
}

class LineNumberRulerView: NSRulerView {
    init(textView: NSTextView) {
        super.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)
        self.clientView = textView
        self.ruleThickness = 30
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func drawHashMarksAndLabels(in rect: NSRect) {
        NSColor.clear.set()
        rect.fill()
    }
}
