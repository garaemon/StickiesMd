import Foundation
import SwiftTreeSitter
import TreeSitterOrg

/// Provides the Tree-sitter language instance for Org-mode parsing.
public enum OrgLanguage {
  /// The Tree-sitter Language for Org-mode, created from the C grammar.
  public static var language: Language? {
    guard let tsLanguagePointer = tree_sitter_org() else {
      return nil
    }
    return Language(tsLanguagePointer)
  }
}
