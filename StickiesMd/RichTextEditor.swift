import AppKit
import CodeEditLanguages
import OrgKit
import SwiftTreeSitter
import SwiftUI

struct RichTextEditor: NSViewRepresentable {
  static let defaultFontSize: CGFloat = 14
  // TODO: Change the font size based on the level of headings
  static let headingFontSize: CGFloat = 18

  let textStorage: NSTextStorage
  var format: FileFormat
  var isEditable: Bool
  var fontColor: String
  var showLineNumbers: Bool

  // NSViewRepresentable protocol requires makeNSView
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
    textView.font = NSFont.monospacedSystemFont(ofSize: Self.defaultFontSize, weight: .regular)
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

  // NSViewRepresentable requires updateNSView method
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
      nsView.verticalRulerView?.needsDisplay = true
    } else {
      nsView.rulersVisible = false
    }

    context.coordinator.applyHighlighting()
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }

  /// The Coordinator class acts as the delegate for both the NSTextView and NSTextContentStorage.
  /// It manages the lifecycle of the Tree-sitter parser and triggers syntax highlighting
  /// whenever the text content changes.
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
      if let scrollView = (notification.object as? NSTextView)?.enclosingScrollView {
        scrollView.verticalRulerView?.needsDisplay = true
      }
    }

    func applyHighlighting() {
      guard let textContentStorage = textContentStorage,
        let textStorage = textContentStorage.textStorage
      else { return }

      let string = textStorage.string
      if string.isEmpty { return }

      guard let tree = parser.parse(string) else { return }

      textStorage.beginEditing()
      let fullRange = NSRange(location: 0, length: textStorage.length)
      let defaultFont = NSFont.monospacedSystemFont(
        ofSize: RichTextEditor.defaultFontSize, weight: .regular)
      let defaultColor = NSColor(hex: parent.fontColor) ?? .textColor
      textStorage.setAttributes(
        [.font: defaultFont, .foregroundColor: defaultColor], range: fullRange)

      if let rootNode = tree.rootNode {
        highlightNode(rootNode, in: textStorage, sourceString: string)
      }
      textStorage.endEditing()

      if let lm = textLayoutManager {
        lm.ensureLayout(for: lm.documentRange)
      }
    }

    private func highlightNode(_ node: Node, in textStorage: NSTextStorage, sourceString: String) {
      if let type = node.nodeType {
        // Highlighting headings
        if type == "atx_heading" || type == "setext_heading"
          || (type.contains("heading") && !type.contains("content"))
        {
          let byteRange = node.byteRange
          // Fix: Tree-sitter byte offsets are 2x UTF-16 unit offsets in this integration
          let start = Int(byteRange.lowerBound) / 2
          let end = Int(byteRange.upperBound) / 2

          if let startIdx = sourceString.utf16.index(
            sourceString.utf16.startIndex, offsetBy: start, limitedBy: sourceString.utf16.endIndex),
            let endIdx = sourceString.utf16.index(
              sourceString.utf16.startIndex, offsetBy: end, limitedBy: sourceString.utf16.endIndex)
          {
            let range = NSRange(startIdx..<endIdx, in: sourceString)
            let font = NSFont.systemFont(ofSize: RichTextEditor.headingFontSize, weight: .bold)
            textStorage.addAttribute(.font, value: font, range: range)
          }
        }
      }

      for i in 0..<node.childCount {
        if let child = node.child(at: i) {
          highlightNode(child, in: textStorage, sourceString: sourceString)
        }
      }
    }
  }
}

/// LineNumberRulerView is a custom NSRulerView that displays line numbers for the NSTextView.
/// It uses TextKit 2 (NSTextLayoutManager) to efficiently calculate and draw line numbers
/// for the visible fragments of the text.
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
    guard let textView = clientView as? NSTextView,
      let textLayoutManager = textView.textLayoutManager
    else {
      return
    }

    let visibleRect = textView.visibleRect
    let nsFont = textView.font ?? NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
    let attributes: [NSAttributedString.Key: Any] = [
      .font: nsFont,
      .foregroundColor: NSColor.secondaryLabelColor,
    ]

    var currentLineNumber = 1

    // We need to know the line number of the first visible fragment.
    // For simplicity and correctness in small documents, we enumerate from the beginning.
    textLayoutManager.enumerateTextLayoutFragments(
      from: textLayoutManager.documentRange.location, options: [.ensuresLayout]
    ) { fragment in
      let frame = fragment.layoutFragmentFrame

      if frame.origin.y + frame.height < visibleRect.origin.y {
        // Fragment is above the visible area, just increment line count
        currentLineNumber += 1
        return true
      }

      if frame.origin.y > visibleRect.origin.y + visibleRect.height {
        // Fragment is below the visible area, we can stop
        return false
      }

      // Fragment is visible, draw the line number
      let lineString = "\(currentLineNumber)"
      let stringSize = lineString.size(withAttributes: attributes)

      // Center the line number in the ruler
      let yOffset = frame.origin.y - visibleRect.origin.y + (frame.height - stringSize.height) / 2
      let xOffset = ruleThickness - stringSize.width - 5

      lineString.draw(at: NSPoint(x: xOffset, y: yOffset), withAttributes: attributes)

      currentLineNumber += 1
      return true
    }
  }
}
