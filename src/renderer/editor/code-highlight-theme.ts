/**
 * Shared syntax highlighting theme for programming language tokens inside
 * code blocks. Colors are based on GitHub's light theme to ensure good
 * contrast on all sticky note background colors.
 */
import { HighlightStyle, syntaxHighlighting } from '@codemirror/language';
import { tags } from '@lezer/highlight';
import type { Extension } from '@codemirror/state';

export const codeTokenHighlightStyle = HighlightStyle.define([
  // Keywords & control flow
  { tag: tags.keyword, color: '#d73a49' },
  { tag: tags.operatorKeyword, color: '#d73a49' },

  // Definitions & functions
  { tag: tags.definition(tags.variableName), color: '#6f42c1' },
  { tag: tags.function(tags.variableName), color: '#6f42c1' },

  // Types & classes
  { tag: tags.typeName, color: '#6f42c1' },
  { tag: tags.className, color: '#6f42c1' },
  { tag: tags.namespace, color: '#6f42c1' },
  { tag: tags.macroName, color: '#6f42c1' },

  // Properties
  { tag: tags.propertyName, color: '#005cc5' },
  { tag: tags.definition(tags.propertyName), color: '#005cc5' },

  // Variables
  { tag: tags.variableName, color: '#e36209' },
  { tag: tags.special(tags.variableName), color: '#e36209' },

  // Literals
  { tag: tags.string, color: '#032f62' },
  { tag: tags.special(tags.string), color: '#032f62' },
  { tag: tags.number, color: '#005cc5' },
  { tag: tags.bool, color: '#005cc5' },
  { tag: tags.null, color: '#005cc5' },
  { tag: tags.atom, color: '#005cc5' },
  { tag: tags.self, color: '#005cc5' },
  { tag: tags.regexp, color: '#032f62' },
  { tag: tags.escape, color: '#22863a' },

  // Comments
  { tag: tags.comment, color: '#6a737d', fontStyle: 'italic' },
  { tag: tags.lineComment, color: '#6a737d', fontStyle: 'italic' },
  { tag: tags.blockComment, color: '#6a737d', fontStyle: 'italic' },

  // Operators
  { tag: tags.operator, color: '#d73a49' },

  // HTML/XML/JSX
  { tag: tags.tagName, color: '#22863a' },
  { tag: tags.attributeName, color: '#6f42c1' },
  { tag: tags.attributeValue, color: '#032f62' },

  // Misc
  { tag: tags.meta, color: '#6a737d' },
]);

/** Extension that applies syntax highlighting colors for programming language tokens. */
export function codeTokenHighlightExtension(): Extension {
  return syntaxHighlighting(codeTokenHighlightStyle);
}
