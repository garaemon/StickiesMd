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

  static let supportedImageExtensions: Set<String> = [
    "png", "jpg", "jpeg", "gif", "svg", "webp", "tiff", "bmp",
  ]

  let textStorage: NSTextStorage
  var format: FileFormat
  var isEditable: Bool
  var fontColor: String
  var showLineNumbers: Bool
  // Incremented on external file reload to trigger updateNSView and re-highlight
  var version: Int
  // This is optional because it might be a newly created, unsaved document.
  // It is also used as the base URL to resolve relative image paths.
  var fileURL: URL?
  var showImages: Bool

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
    context.coordinator.textView = textView
    scrollView.documentView = textView

    context.coordinator.applyHighlighting()

    return scrollView
  }

  // NSViewRepresentable requires updateNSView method
  func updateNSView(_ nsView: NSScrollView, context: Context) {
    guard let textView = nsView.documentView as? NSTextView else { return }

    // Keep coordinator state in sync with current SwiftUI view values
    let previousFormat = context.coordinator.parent.format
    context.coordinator.textView = textView
    context.coordinator.parent = self

    if previousFormat != format {
      context.coordinator.setupParser()
    }

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
    case bold
    case italic
    case underline
    case strikethrough
    // code is for inline codes
    case code
    // codeBlock is for code blocks
    case codeBlock
    case image(path: String)
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
    weak var textView: NSTextView?
    // imageOverlays holds NSImageView instances used to display inline images below their link text.
    // They are updated and repositioned whenever the text changes.
    var imageOverlays: [NSImageView] = []

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

        if inlineParser == nil {
          inlineParser = Parser()
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

      var collectedImages: [(path: String, range: NSRange)] = []

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

      // tree-sitter-org does not parse inline markup, so we use regex
      // following Org-mode's official PRE/POST emphasis rules.
      if parent.format == .org {
        highlightOrgInlineMarkup(in: textStorage, sourceString: string)
        collectedImages.append(
          contentsOf: findOrgImageLinks(sourceString: string, textStorage: textStorage))
      }

      if parent.format == .markdown, let inlineParser,
        let inlineTree = inlineParser.parse(string),
        let inlineRootNode = inlineTree.rootNode
      {
        highlightInlineNode(
          inlineRootNode,
          in: textStorage,
          sourceString: string
        )
        collectedImages.append(
          contentsOf: findMarkdownImageLinks(
            inlineRootNode, sourceString: string, textStorage: textStorage))
      }

      textStorage.endEditing()

      if let lm = textLayoutManager {
        lm.ensureLayout(for: lm.documentRange)
      }

      if parent.showImages {
        updateImageOverlays(images: collectedImages)
      } else {
        // Remove existing overlays when images are toggled off
        for overlay in imageOverlays {
          overlay.removeFromSuperview()
        }
        imageOverlays.removeAll()
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
      // fenced_code_block: Code blocks surrounded by backticks (```) or tildes (~~~)
      // indented_code_block: Code blocks indented by 4 spaces or a tab
      if type == "fenced_code_block" || type == "indented_code_block" {
        return .codeBlock
      }
      return nil
    }

    private func classifyOrgNode(type: String, node: Node) -> DocumentElement? {
      if type == "headline" {
        return .heading(level: getOrgHeadingLevel(node))
      }
      if type == "block" {
        return .codeBlock
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
      case .bold:
        applyFontTraits(in: textStorage, range: range, bold: true, italic: false)
      case .italic:
        applyFontTraits(in: textStorage, range: range, bold: false, italic: true)
      case .underline:
        textStorage.addAttribute(
          .underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
      case .strikethrough:
        textStorage.addAttribute(
          .strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range)
      case .code:
        let monoFont = NSFont.monospacedSystemFont(
          ofSize: RichTextEditor.defaultFontSize, weight: .regular)
        textStorage.addAttribute(.font, value: monoFont, range: range)
        textStorage.addAttribute(
          .backgroundColor, value: NSColor.gray.withAlphaComponent(0.15), range: range)
      case .codeBlock:
        let monoFont = NSFont.monospacedSystemFont(
          ofSize: RichTextEditor.defaultFontSize, weight: .regular)
        textStorage.addAttribute(.font, value: monoFont, range: range)
        textStorage.addAttribute(
          .backgroundColor, value: NSColor.black.withAlphaComponent(0.06), range: range)
      case .image:
        textStorage.addAttribute(
          .foregroundColor, value: NSColor.systemBlue, range: range)
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

    /// Classifies a Markdown inline Tree-sitter node into a DocumentElement.
    private func classifyInlineNode(type: String) -> DocumentElement? {
      switch type {
      case "strong_emphasis": return .bold
      case "emphasis": return .italic
      case "strikethrough": return .strikethrough
      case "code_span": return .code
      default: return nil
      }
    }

    /// Walks inline Tree-sitter nodes and applies styling via DocumentElement.
    ///
    /// parentTypes tracking is unnecessary because applyFontTraits is additive:
    /// nested emphasis (e.g. ***bold italic***) automatically combines traits
    /// as the parent node's style is already applied before recursing into children.
    private func highlightInlineNode(
      _ node: Node,
      in textStorage: NSTextStorage,
      sourceString: String
    ) {
      if let type = node.nodeType,
        let element = classifyInlineNode(type: type)
      {
        if let range = nodeRange(node, in: sourceString) {
          applyElementStyle(element, in: textStorage, range: range)
        }
      }

      for i in 0..<node.childCount {
        if let child = node.child(at: i) {
          highlightInlineNode(child, in: textStorage, sourceString: sourceString)
        }
      }
    }

    /// Finds Markdown image links from inline tree-sitter nodes.
    ///
    /// This function acts as a public entry point that initializes an empty array
    /// and then delegates the actual recursive search to `findMarkdownImageLinksRecursive`.
    /// This separation hides the `inout` array parameter from the caller, providing
    /// a cleaner API that simply returns the collected results.
    private func findMarkdownImageLinks(
      _ node: Node,
      sourceString: String,
      textStorage: NSTextStorage
    ) -> [(path: String, range: NSRange)] {
      var results: [(path: String, range: NSRange)] = []
      findMarkdownImageLinksRecursive(
        node, sourceString: sourceString, textStorage: textStorage, into: &results)
      return results
    }

    /// Recursively walks the inline AST looking for "image" nodes and extracts
    /// the link destination child to get the image path. Matches are appended
    /// to the `results` array passed by reference (`inout`).
    private func findMarkdownImageLinksRecursive(
      _ node: Node,
      sourceString: String,
      textStorage: NSTextStorage,
      into results: inout [(path: String, range: NSRange)]
    ) {
      if let type = node.nodeType, type == "image" {
        if let range = nodeRange(node, in: sourceString) {
          let imagePath = extractMarkdownImagePath(node, sourceString: sourceString)
          if let path = imagePath {
            // Always style image links with blue color
            applyElementStyle(.image(path: path), in: textStorage, range: range)
            // Only collect for overlay if it looks like a local image file
            if isImagePath(path) {
              results.append((path: path, range: range))
            }
          }
        }
      }
      for i in 0..<node.childCount {
        if let child = node.child(at: i) {
          findMarkdownImageLinksRecursive(
            child, sourceString: sourceString, textStorage: textStorage, into: &results)
        }
      }
    }

    /// Extracts the image path from a Markdown "image" inline node.
    private func extractMarkdownImagePath(_ node: Node, sourceString: String) -> String? {
      for i in 0..<node.childCount {
        guard let child = node.child(at: i), let type = child.nodeType else { continue }
        if type == "link_destination" {
          if let range = nodeRange(child, in: sourceString) {
            return (sourceString as NSString).substring(with: range)
          }
        }
      }
      return nil
    }

    /// Checks if a path points to a supported image file.
    private func isImagePath(_ path: String) -> Bool {
      let ext = (path as NSString).pathExtension.lowercased()
      return RichTextEditor.supportedImageExtensions.contains(ext)
    }

    /// Finds Org-mode image links using regex.
    ///
    /// Detects `[[file:path]]` and `[[./path]]` patterns.
    private func findOrgImageLinks(
      sourceString: String,
      textStorage: NSTextStorage
    ) -> [(path: String, range: NSRange)] {
      // Match [[file:path.ext]] or [[./path.ext]] or [[/path.ext]]
      let pattern = "\\[\\[(?:file:)?([^]]+?\\.[a-zA-Z]+)\\]\\]"
      guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

      let nsString = sourceString as NSString
      let fullRange = NSRange(location: 0, length: nsString.length)
      var results: [(path: String, range: NSRange)] = []

      for match in regex.matches(in: sourceString, range: fullRange) {
        let matchRange = match.range
        let pathRange = match.range(at: 1)
        guard pathRange.location != NSNotFound else { continue }
        let path = nsString.substring(with: pathRange)
        if isImagePath(path) {
          applyElementStyle(.image(path: path), in: textStorage, range: matchRange)
          results.append((path: path, range: matchRange))
        }
      }

      return results
    }

    /// Entry point for Org-mode inline emphasis highlighting.
    ///
    /// tree-sitter-org only handles block-level structure, so inline markup
    /// (bold, italic) is detected via regex with Org-mode PRE/POST rules.
    /// Parsing and styling are separated: parseOrgInlineElements produces
    /// format-independent DocumentElements, then applyElementStyle renders them.
    private func highlightOrgInlineMarkup(
      in textStorage: NSTextStorage,
      sourceString: String
    ) {
      for (element, range) in parseOrgInlineElements(sourceString: sourceString) {
        applyElementStyle(element, in: textStorage, range: range)
      }
    }

    /// Parses all Org-mode inline emphasis spans into DocumentElements.
    ///
    /// Returns an array of (DocumentElement, NSRange) pairs without
    /// applying any styling, keeping parsing separate from rendering.
    private func parseOrgInlineElements(
      sourceString: String
    ) -> [(DocumentElement, NSRange)] {
      var elements: [(DocumentElement, NSRange)] = []
      elements.append(
        contentsOf: findOrgEmphasisRanges(
          marker: "*", element: .bold, sourceString: sourceString))
      elements.append(
        contentsOf: findOrgEmphasisRanges(
          marker: "/", element: .italic, sourceString: sourceString))
      elements.append(
        contentsOf: findOrgEmphasisRanges(
          marker: "_", element: .underline, sourceString: sourceString))
      elements.append(
        contentsOf: findOrgEmphasisRanges(
          marker: "+", element: .strikethrough, sourceString: sourceString))
      elements.append(
        contentsOf: findOrgEmphasisRanges(
          marker: "~", element: .code, sourceString: sourceString))
      elements.append(
        contentsOf: findOrgEmphasisRanges(
          marker: "=", element: .code, sourceString: sourceString))
      return elements
    }

    /// Finds ranges matching a specific Org-mode emphasis marker.
    ///
    /// Uses regex to find `MARKER content MARKER` spans where content
    /// doesn't start/end with whitespace, then validates surrounding
    /// characters against Org-mode's PRE/POST rules.
    private func findOrgEmphasisRanges(
      marker: String,
      element: DocumentElement,
      sourceString: String
    ) -> [(DocumentElement, NSRange)] {
      let escaped = NSRegularExpression.escapedPattern(for: marker)
      let pattern = "\(escaped)(?:\\S|\\S[^\(escaped)\\n]*?\\S)\(escaped)"
      guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

      let nsString = sourceString as NSString
      let fullRange = NSRange(location: 0, length: nsString.length)
      var results: [(DocumentElement, NSRange)] = []

      for result in regex.matches(in: sourceString, range: fullRange) {
        let matchRange = result.range
        let startPos = matchRange.location
        let endPos = startPos + matchRange.length - 1

        // Validate PRE: char before opening marker must be BOL, whitespace, or PRE char
        if startPos > 0 {
          let preChar = nsString.character(at: startPos - 1)
          if !isOrgEmphasisPre(preChar) { continue }
        }

        // Validate POST: char after closing marker must be EOL, whitespace, or POST char
        if endPos + 1 < nsString.length {
          let postChar = nsString.character(at: endPos + 1)
          if !isOrgEmphasisPost(postChar) { continue }
        }

        results.append((element, matchRange))
      }

      return results
    }

    private func isOrgEmphasisPre(_ charCode: unichar) -> Bool {
      guard let scalar = Unicode.Scalar(charCode) else { return false }
      let char = Character(scalar)
      if char.isWhitespace || char.isNewline { return true }
      return "-('\"{ ".contains(char)
    }

    private func isOrgEmphasisPost(_ charCode: unichar) -> Bool {
      guard let scalar = Unicode.Scalar(charCode) else { return false }
      let char = Character(scalar)
      if char.isWhitespace || char.isNewline { return true }
      return "-.,;:!?'\")}]".contains(char)
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

    /// Resolves a possibly-relative image path against the document directory.
    private func resolveImageURL(_ path: String) -> URL? {
      if path.hasPrefix("/") {
        return URL(fileURLWithPath: path)
      }
      guard let fileURL = parent.fileURL else { return nil }
      let directoryURL = fileURL.deletingLastPathComponent()
      return directoryURL.appendingPathComponent(path).standardized
    }

    /// Updates image overlay views positioned below each image link.
    ///
    /// Removes all previous overlays and creates new NSImageViews
    /// placed below the corresponding image link text.
    private func updateImageOverlays(images: [(path: String, range: NSRange)]) {
      for overlay in imageOverlays {
        overlay.removeFromSuperview()
      }
      imageOverlays.removeAll()

      guard let textView = textView,
        let textLayoutManager = textLayoutManager,
        let textContentStorage = textContentStorage
      else { return }

      guard let textStorage = textContentStorage.textStorage else { return }

      let maxImageWidth = textView.bounds.width - 20
      let maxImageHeight: CGFloat = 200

      // Pre-calculate image sizes and add paragraph spacing
      var imageEntries:
        [(url: URL, image: NSImage, range: NSRange, width: CGFloat, height: CGFloat)] = []

      for imageInfo in images {
        guard let imageURL = resolveImageURL(imageInfo.path),
          FileManager.default.fileExists(atPath: imageURL.path),
          let nsImage = NSImage(contentsOf: imageURL)
        else { continue }

        let originalSize = nsImage.size
        var displayWidth = min(maxImageWidth, originalSize.width)
        var scale = displayWidth / originalSize.width
        var displayHeight = originalSize.height * scale

        if displayHeight > maxImageHeight {
          displayHeight = maxImageHeight
          scale = displayHeight / originalSize.height
          displayWidth = originalSize.width * scale
        }

        imageEntries.append(
          (
            url: imageURL, image: nsImage, range: imageInfo.range, width: displayWidth,
            height: displayHeight
          ))
      }

      // Add paragraph spacing so text below images doesn't overlap
      if !imageEntries.isEmpty {
        textStorage.beginEditing()
        for entry in imageEntries {
          addParagraphSpacing(
            after: entry.range, spacing: entry.height + 4, in: textStorage)
        }
        textStorage.endEditing()

        textLayoutManager.ensureLayout(for: textLayoutManager.documentRange)
      }

      // Place image overlays at calculated positions
      for entry in imageEntries {
        let linkRect = computeRectForRange(
          entry.range,
          textLayoutManager: textLayoutManager,
          textContentStorage: textContentStorage
        )
        guard let rect = linkRect else { continue }

        let imageView = NSImageView(
          frame: NSRect(
            x: rect.origin.x,
            y: rect.origin.y + rect.height + 2,
            width: entry.width,
            height: entry.height
          ))
        imageView.image = entry.image
        imageView.imageScaling = .scaleProportionallyUpOrDown

        textView.addSubview(imageView)
        imageOverlays.append(imageView)
      }
    }

    /// Adds paragraph spacing after the line containing the given range.
    ///
    /// This creates room for image overlays so they don't overlap
    /// with the following text.
    private func addParagraphSpacing(
      after range: NSRange, spacing: CGFloat, in textStorage: NSTextStorage
    ) {
      let string = textStorage.string as NSString
      let lineRange = string.lineRange(for: range)
      let style = NSMutableParagraphStyle()
      style.paragraphSpacing = spacing
      textStorage.addAttribute(.paragraphStyle, value: style, range: lineRange)
    }

    /// Computes the bounding rectangle for a character range in the text view.
    private func computeRectForRange(
      _ nsRange: NSRange,
      textLayoutManager: NSTextLayoutManager,
      textContentStorage: NSTextContentStorage
    ) -> NSRect? {
      guard
        let contentManager = textLayoutManager.textContentManager,
        let start = contentManager.location(
          contentManager.documentRange.location,
          offsetBy: nsRange.location),
        let end = contentManager.location(start, offsetBy: nsRange.length)
      else { return nil }

      guard let textRange = NSTextRange(location: start, end: end) else { return nil }
      var resultRect: NSRect?

      textLayoutManager.enumerateTextSegments(
        in: textRange,
        type: .standard,
        options: []
      ) { _, rect, _, _ in
        if let existing = resultRect {
          resultRect = existing.union(rect)
        } else {
          resultRect = rect
        }
        return true
      }

      return resultRect
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
