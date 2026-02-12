import AppKit
import CodeEditLanguages
import OrgKit
import SwiftTreeSitter
import SwiftUI

struct RichTextEditor: NSViewRepresentable {
  struct FontSizes {
    static let standard: CGFloat = 14
    static let h1: CGFloat = 26
    static let h2: CGFloat = 22
    static let h3: CGFloat = 18
    static let h4: CGFloat = 16
    static let h5: CGFloat = 14
    static let h6: CGFloat = 14
  }

  static let defaultFontSize: CGFloat = FontSizes.standard

  static func headingFontSize(level: Int) -> CGFloat {
    switch level {
    case 1: return FontSizes.h1
    case 2: return FontSizes.h2
    case 3: return FontSizes.h3
    case 4: return FontSizes.h4
    case 5: return FontSizes.h5
    case 6: return FontSizes.h6
    default: return FontSizes.standard
    }
  }

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

  /// Common intermediate representation for document elements across formats.
  enum DocumentElement {
    case heading(level: Int)
  }

  /// The Coordinator class acts as the delegate for both the NSTextView and NSTextContentStorage.
  /// It manages the lifecycle of the Tree-sitter parser and triggers syntax highlighting
  /// whenever the text content changes.
  class Coordinator: NSObject, NSTextViewDelegate, NSTextContentStorageDelegate {
    var parent: RichTextEditor
    var textLayoutManager: NSTextLayoutManager?
    var textContentStorage: NSTextContentStorage?
    // We need two parsers because Tree-sitter's Markdown grammar is split into two parts:
    // parser: Parses block-level elements like headings, lists, code blocks (tree-sitter-markdown)
    // inlineParser: Parses inline elements like bold, emphasis, links (tree-sitter-markdown-inline)
    var parser: Parser
    var inlineParser: Parser?

    init(_ parent: RichTextEditor) {
      self.parent = parent
      self.parser = Parser()
      self.inlineParser = Parser()
      super.init()
      setupParser()
    }

    func setupParser() {
      switch parent.format {
      case .org:
        if let orgLang = OrgLanguage.language {
          try? parser.setLanguage(orgLang)
        }
        // Org-mode does not use a separate inline parser
        inlineParser = nil
      case .markdown:
        if let markdownLang = CodeLanguage.allLanguages.first(where: {
          let id = "\($0.id)".lowercased()
          return id == "markdown"
        }), let tsLang = markdownLang.language {
          try? parser.setLanguage(tsLang)
        }

        if let markdownInlineLang = CodeLanguage.allLanguages.first(where: {
          let id = "\($0.id)".lowercased()
          return id == "markdowninline" || id == "markdown-inline"
        }), let tsInlineLang = markdownInlineLang.language {
          try? inlineParser?.setLanguage(tsInlineLang)
        }
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
        highlightNode(rootNode, in: textStorage, sourceString: string, parentTypes: [])
      }

      if parent.format == .markdown, let inlineParser,
        let inlineTree = inlineParser.parse(string),
        let inlineRootNode = inlineTree.rootNode
      {
        highlightInlineNode(
          inlineRootNode,
          in: textStorage,
          sourceString: string,
          parentTypes: []
        )
      }

      textStorage.endEditing()

      if let lm = textLayoutManager {
        lm.ensureLayout(for: lm.documentRange)
      }
    }

    private func highlightNode(
      _ node: Node,
      in textStorage: NSTextStorage,
      sourceString: String,
      parentTypes: [String]
    ) {
      if let type = node.nodeType,
        let element = classifyNode(type: type, node: node)
      {
        if let range = nodeRange(node, in: sourceString) {
          applyElementStyle(element, in: textStorage, range: range)
        }
      }

      for i in 0..<node.childCount {
        if let child = node.child(at: i) {
          var nextParentTypes = parentTypes
          if let type = node.nodeType {
            nextParentTypes.append(type)
          }
          highlightNode(
            child,
            in: textStorage,
            sourceString: sourceString,
            parentTypes: nextParentTypes
          )
        }
      }
    }

    /// Classifies a Tree-sitter node into a format-independent DocumentElement.
    private func classifyNode(type: String, node: Node) -> DocumentElement? {
      switch parent.format {
      case .markdown:
        return classifyMarkdownNode(type: type, node: node)
      case .org:
        return classifyOrgNode(type: type, node: node)
      }
    }

    private func classifyMarkdownNode(type: String, node: Node) -> DocumentElement? {
      if type == "atx_heading" || type == "setext_heading"
        || (type.contains("heading") && !type.contains("content"))
      {
        return .heading(level: getHeadingLevel(node))
      }
      return nil
    }

    private func classifyOrgNode(type: String, node: Node) -> DocumentElement? {
      if type == "headline" {
        return .heading(level: getOrgHeadingLevel(node))
      }
      return nil
    }

    /// Applies visual styling for a DocumentElement to the given range.
    private func applyElementStyle(
      _ element: DocumentElement,
      in textStorage: NSTextStorage,
      range: NSRange
    ) {
      switch element {
      case .heading(let level):
        let fontSize = RichTextEditor.headingFontSize(level: level)
        let font = NSFont.systemFont(ofSize: fontSize, weight: .bold)
        textStorage.addAttribute(.font, value: font, range: range)
      }
    }

    /// Determines org-mode heading level by counting "*" characters in the "stars" child node.
    private func getOrgHeadingLevel(_ node: Node) -> Int {
      for i in 0..<node.childCount {
        guard let child = node.child(at: i), let type = child.nodeType else { continue }
        if type == "stars", let range = child.byteRange as Range<UInt32>? {
          // Each star is one byte, and byte offsets are 2x UTF-16 units
          let starCount = Int(range.upperBound - range.lowerBound) / 2
          return min(max(starCount, 1), 6)
        }
      }
      return 1
    }

    private func getHeadingLevel(_ node: Node) -> Int {
      for i in 0..<node.childCount {
        guard let child = node.child(at: i), let type = child.nodeType else { continue }
        switch type {
        case "atx_h1_marker", "setext_h1_underline": return 1
        case "atx_h2_marker", "setext_h2_underline": return 2
        case "atx_h3_marker": return 3
        case "atx_h4_marker": return 4
        case "atx_h5_marker": return 5
        case "atx_h6_marker": return 6
        default: continue
        }
      }
      return 1
    }

    /// Converts a Tree-sitter Node's range into an NSRange for NSTextStorage.
    ///
    /// This function maps the byte range from a Tree-sitter Node to the corresponding
    /// NSRange in the source string, which is required for text styling.
    /// It handles the conversion from byte offsets to UTF-16 indices.
    private func nodeRange(_ node: Node, in sourceString: String) -> NSRange? {
      let byteRange = node.byteRange
      // Fix: Tree-sitter byte offsets are 2x UTF-16 unit offsets in this integration
      let start = Int(byteRange.lowerBound) / 2
      let end = Int(byteRange.upperBound) / 2

      guard
        let startIdx = sourceString.utf16.index(
          sourceString.utf16.startIndex, offsetBy: start, limitedBy: sourceString.utf16.endIndex),
        let endIdx = sourceString.utf16.index(
          sourceString.utf16.startIndex, offsetBy: end, limitedBy: sourceString.utf16.endIndex)
      else {
        return nil
      }

      return NSRange(startIdx..<endIdx, in: sourceString)
    }

    private func highlightInlineNode(
      _ node: Node,
      in textStorage: NSTextStorage,
      sourceString: String,
      parentTypes: [String]
    ) {
      if let type = node.nodeType {
        if type == "strong_emphasis" {
          if let range = nodeRange(node, in: sourceString) {
            let isCombined = parentTypes.contains("emphasis")
            applyFontTraits(
              in: textStorage,
              range: range,
              bold: true,
              italic: isCombined
            )
          }
        }

        if type == "emphasis" {
          if let range = nodeRange(node, in: sourceString) {
            let isCombined = parentTypes.contains("strong_emphasis")
            applyFontTraits(
              in: textStorage,
              range: range,
              bold: isCombined,
              italic: true
            )
          }
        }
      }

      for i in 0..<node.childCount {
        if let child = node.child(at: i) {
          var nextParentTypes = parentTypes
          if let type = node.nodeType {
            nextParentTypes.append(type)
          }
          highlightInlineNode(
            child,
            in: textStorage,
            sourceString: sourceString,
            parentTypes: nextParentTypes
          )
        }
      }
    }

    /// Applies bold and/or italic traits to the text in the specified range.
    ///
    /// This function retrieves the current font at the given range, modifies its symbolic traits
    /// to include bold or italic as requested, and applies the new font back to the text storage.
    /// It attempts to preserve the existing font size.
    private func applyFontTraits(
      in textStorage: NSTextStorage,
      range: NSRange,
      bold: Bool,
      italic: Bool
    ) {
      let baseFont =
        (textStorage.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont)
        ?? NSFont.monospacedSystemFont(ofSize: RichTextEditor.defaultFontSize, weight: .regular)
      var traits = baseFont.fontDescriptor.symbolicTraits
      if bold { traits.insert(.bold) }
      if italic { traits.insert(.italic) }
      let descriptor = baseFont.fontDescriptor.withSymbolicTraits(traits)
      if let styled = NSFont(descriptor: descriptor, size: baseFont.pointSize) {
        textStorage.addAttribute(.font, value: styled, range: range)
      } else {
        textStorage.addAttribute(.font, value: baseFont, range: range)
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
