import AppKit
import CodeEditLanguages
import SwiftTreeSitter

/// Token categories for syntax highlighting within code blocks.
/// Each case maps to a foreground color used for coloring code tokens.
enum SyntaxTokenType: Equatable {
  case keyword
  case string
  case comment
  case number
  case type
  case function
  case variable
  case property
  case `operator`
  case constant
  case punctuation

  /// Maps a tree-sitter capture name to a SyntaxTokenType.
  ///
  /// Capture names follow dotted notation (e.g., "keyword.function"),
  /// so we use the first component for classification.
  static func fromCaptureName(_ name: String) -> SyntaxTokenType? {
    let primary = name.split(separator: ".").first.map(String.init) ?? name
    switch primary {
    case "keyword": return .keyword
    case "string": return .string
    case "comment": return .comment
    case "number", "float": return .number
    case "type": return .type
    case "function", "method": return .function
    case "variable": return .variable
    case "property", "field": return .property
    case "operator": return .operator
    case "constant", "boolean": return .constant
    case "punctuation": return .punctuation
    default: return nil
    }
  }

  /// Foreground color for this token type in code blocks.
  var color: NSColor {
    switch self {
    case .keyword: return NSColor.systemPurple
    case .string: return NSColor.systemGreen
    case .comment: return NSColor.systemGray
    case .number: return NSColor.systemOrange
    case .type: return NSColor.systemTeal
    case .function: return NSColor.systemBlue
    case .variable: return NSColor.labelColor
    case .property: return NSColor.systemCyan
    case .operator: return NSColor.systemPink
    case .constant: return NSColor.systemOrange
    case .punctuation: return NSColor.secondaryLabelColor
    }
  }
}

/// Provides syntax highlighting for code content inside fenced code blocks.
///
/// Uses CodeEditLanguages tree-sitter grammars and highlight queries
/// to parse code in isolation and apply language-specific coloring.
enum CodeBlockHighlighter {

  // Cache parsers per language to avoid re-creating on every keystroke
  private static var parserCache: [TreeSitterLanguage: Parser] = [:]

  /// Hardcoded aliases for common language shorthand names.
  private static let languageAliases: [String: String] = [
    "py": "python",
    "js": "javascript",
    "ts": "typescript",
    "rb": "ruby",
    "rs": "rust",
    "c++": "cpp",
    "c#": "csharp",
    "cs": "csharp",
    "sh": "bash",
    "shell": "bash",
    "zsh": "bash",
    "yml": "yaml",
    "md": "markdown",
    "objc": "objc",
    "objective-c": "objc",
    "kt": "kotlin",
    "dockerfile": "dockerfile",
    "hs": "haskell",
    "ex": "elixir",
    "exs": "elixir",
  ]

  /// Finds a CodeLanguage matching the info_string from a fenced code block.
  ///
  /// Uses a 3-tier lookup:
  /// 1. Match by tsName (exact tree-sitter name)
  /// 2. Match by file extension
  /// 3. Match by hardcoded alias
  static func findLanguage(infoString: String) -> CodeLanguage? {
    let name = infoString.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if name.isEmpty { return nil }

    // Tier 1: Match by tsName
    if let lang = CodeLanguage.allLanguages.first(where: {
      $0.tsName.lowercased() == name
    }) {
      return lang
    }

    // Tier 2: Match by file extension
    if let lang = CodeLanguage.allLanguages.first(where: {
      $0.extensions.contains(name)
    }) {
      return lang
    }

    // Tier 3: Match by alias
    if let resolved = languageAliases[name] {
      return CodeLanguage.allLanguages.first(where: {
        $0.tsName.lowercased() == resolved
      })
    }

    return nil
  }

  /// Applies syntax highlighting to code content using the given language grammar.
  ///
  /// Parses `codeContent` in isolation with the language's tree-sitter grammar,
  /// runs the highlight query, and applies foreground colors at the correct
  /// document offsets in textStorage.
  static func applyHighlighting(
    codeContent: String,
    language: CodeLanguage,
    documentOffset: Int,
    textStorage: NSTextStorage
  ) {
    guard let tsLanguage = language.language else { return }

    let parser = cachedParser(for: language.id, tsLanguage: tsLanguage)

    guard let tree = parser.parse(codeContent) else { return }
    guard let query = TreeSitterModel.shared.query(for: language.id) else { return }
    guard let rootNode = tree.rootNode else { return }

    let cursor = query.execute(node: rootNode, in: tree)

    for match in cursor {
      for capture in match.captures {
        guard let captureName = capture.name else { continue }
        guard let tokenType = SyntaxTokenType.fromCaptureName(captureName) else { continue }

        let captureRange = capture.range
        guard captureRange.length > 0 else { continue }

        // Convert capture range (relative to code content) to document range
        let codeUTF16 = codeContent.utf16
        let captureStart = captureRange.location
        let captureEnd = captureStart + captureRange.length

        guard captureStart >= 0, captureEnd <= codeUTF16.count else { continue }

        let documentRange = NSRange(
          location: documentOffset + captureStart,
          length: captureRange.length
        )

        guard documentRange.location >= 0,
          documentRange.location + documentRange.length <= textStorage.length
        else { continue }

        textStorage.addAttribute(
          .foregroundColor, value: tokenType.color, range: documentRange)
      }
    }
  }

  private static func cachedParser(
    for languageId: TreeSitterLanguage,
    tsLanguage: Language
  ) -> Parser {
    if let existing = parserCache[languageId] {
      return existing
    }
    let parser = Parser()
    try? parser.setLanguage(tsLanguage)
    parserCache[languageId] = parser
    return parser
  }
}
