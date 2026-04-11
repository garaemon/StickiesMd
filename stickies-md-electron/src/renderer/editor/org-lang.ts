/**
 * Org-mode language support for CodeMirror 6.
 *
 * Block-level elements (headings, code blocks, property drawers) are handled
 * by a StreamLanguage line tokenizer. Inline emphasis (*bold*, /italic/, etc.)
 * is handled by a ViewPlugin that creates Decoration.mark ranges.
 *
 * The PRE/POST character validation rules for emphasis markers are ported from
 * the Org-mode specification (Section 16.1 "Emphasis and Monospace").
 */
import {
  StreamLanguage,
  HighlightStyle,
  syntaxHighlighting,
  type StringStream,
} from '@codemirror/language';
import { tags } from '@lezer/highlight';
import {
  Decoration,
  type DecorationSet,
  EditorView,
  ViewPlugin,
  type ViewUpdate,
} from '@codemirror/view';
import { RangeSetBuilder } from '@codemirror/state';
import type { Extension } from '@codemirror/state';
import { FONT_SIZES } from '../../shared/constants';

// Org-mode emphasis PRE/POST character sets.
// Per the Org-mode spec, an emphasis marker is valid only if:
//   - The character before the opening marker is a PRE char (or start of text)
//   - The character after the closing marker is a POST char (or end of text)
// See: https://orgmode.org/worg/dev/org-syntax.html#Emphasis_Markers
const PRE_CHARS = new Set([' ', '\t', '\n', '-', '(', "'", '"', '{', '\u200B']);
const POST_CHARS = new Set([
  ' ',
  '\t',
  '\n',
  '-',
  '.',
  ',',
  ';',
  ':',
  '!',
  '?',
  "'",
  '"',
  ')',
  '}',
  ']',
  '\u200B',
]);

function isOrgEmphasisPre(ch: string | undefined): boolean {
  return ch === undefined || PRE_CHARS.has(ch);
}

function isOrgEmphasisPost(ch: string | undefined): boolean {
  return ch === undefined || POST_CHARS.has(ch);
}

// Block-level state for StreamLanguage
interface OrgState {
  inCodeBlock: boolean;
  inPropertyDrawer: boolean;
}

const orgStreamParser = {
  name: 'org',

  startState(): OrgState {
    return { inCodeBlock: false, inPropertyDrawer: false };
  },

  token(stream: StringStream, state: OrgState): string | null {
    // Code block boundaries
    if (stream.match(/^#\+BEGIN_SRC\b.*/i)) {
      state.inCodeBlock = true;
      return 'processingInstruction';
    }
    if (stream.match(/^#\+END_SRC\b.*/i)) {
      state.inCodeBlock = false;
      return 'processingInstruction';
    }
    if (state.inCodeBlock) {
      stream.skipToEnd();
      return 'monospace';
    }

    // Property drawer boundaries
    if (stream.match(/^:PROPERTIES:\s*$/)) {
      state.inPropertyDrawer = true;
      return 'meta';
    }
    if (stream.match(/^:END:\s*$/)) {
      state.inPropertyDrawer = false;
      return 'meta';
    }
    if (state.inPropertyDrawer) {
      stream.skipToEnd();
      return 'meta';
    }

    // Headings: lines starting with one or more * followed by space
    if (stream.sol() && stream.match(/^(\*{1,6})\s/)) {
      const match = stream.current();
      const level = match.trim().length;
      stream.skipToEnd();
      return `heading heading${level}`;
    }

    // Unordered lists
    if (stream.sol() && stream.match(/^\s*[-+]\s/)) {
      return 'list';
    }

    // Ordered lists
    if (stream.sol() && stream.match(/^\s*\d+[.)]\s/)) {
      return 'list';
    }

    // Keywords: #+TITLE, #+AUTHOR, etc.
    if (stream.sol() && stream.match(/^#\+\w+:/)) {
      stream.skipToEnd();
      return 'keyword';
    }

    // Comment lines
    if (stream.sol() && stream.match(/^#\s/)) {
      stream.skipToEnd();
      return 'comment';
    }

    // Default: consume a character
    stream.next();
    return null;
  },

  copyState(state: OrgState): OrgState {
    return { ...state };
  },
};

// Inline emphasis decorations via ViewPlugin
// Matches: *bold*, /italic/, _underline_, +strikethrough+, ~code~, =verbatim=
const EMPHASIS_MARKERS: Array<{
  open: string;
  close: string;
  class: string;
}> = [
  { open: '*', close: '*', class: 'cm-strong' },
  { open: '/', close: '/', class: 'cm-emphasis' },
  { open: '_', close: '_', class: 'cm-underline' },
  { open: '+', close: '+', class: 'cm-strikethrough' },
  { open: '~', close: '~', class: 'cm-inline-code' },
  { open: '=', close: '=', class: 'cm-inline-code' },
];

interface EmphasisRange {
  from: number;
  to: number;
  class: string;
}

/**
 * Scan text for Org-mode inline emphasis ranges.
 *
 * Algorithm: for each marker type, scan for an opening marker character
 * that passes PRE validation, then find the matching closing marker that
 * passes POST validation. Content must not start/end with whitespace
 * and must not cross line boundaries.
 */
function findOrgEmphasisRanges(text: string): EmphasisRange[] {
  const ranges: EmphasisRange[] = [];

  for (const marker of EMPHASIS_MARKERS) {
    const { open, close } = marker;
    let i = 0;
    while (i < text.length) {
      // Find opening marker
      if (text[i] === open) {
        const pre = i > 0 ? text[i - 1] : undefined;
        if (isOrgEmphasisPre(pre)) {
          // Find closing marker
          const start = i;
          let j = i + 1;
          // Content must not start with space
          if (j < text.length && text[j] !== ' ' && text[j] !== '\t') {
            while (j < text.length) {
              if (text[j] === close && j > start + 1) {
                // Content must not end with space before closing marker
                if (text[j - 1] !== ' ' && text[j - 1] !== '\t') {
                  const post = j + 1 < text.length ? text[j + 1] : undefined;
                  if (isOrgEmphasisPost(post)) {
                    ranges.push({ from: start, to: j + 1, class: marker.class });
                    i = j + 1;
                    break;
                  }
                }
              }
              // Don't cross line boundaries for emphasis
              if (text[j] === '\n') break;
              j++;
            }
            if (j >= text.length || text[j] === '\n') {
              i++;
            }
          } else {
            i++;
          }
        } else {
          i++;
        }
      } else {
        i++;
      }
    }
  }

  // Sort by position
  ranges.sort((a, b) => a.from - b.from);
  return ranges;
}

// Org link detection: [[url][desc]] or [[url]]
interface OrgLink {
  from: number;
  to: number;
}

function findOrgLinks(text: string): OrgLink[] {
  const links: OrgLink[] = [];
  const regex = /\[\[([^\]]+?)(?:\]\[([^\]]*?))?\]\]/g;
  let match;
  while ((match = regex.exec(text)) !== null) {
    links.push({ from: match.index, to: match.index + match[0].length });
  }
  return links;
}

const orgInlineDecorations = ViewPlugin.fromClass(
  class {
    decorations: DecorationSet;

    constructor(view: EditorView) {
      this.decorations = this.buildDecorations(view);
    }

    update(update: ViewUpdate) {
      if (update.docChanged || update.viewportChanged) {
        this.decorations = this.buildDecorations(update.view);
      }
    }

    buildDecorations(view: EditorView): DecorationSet {
      const builder = new RangeSetBuilder<Decoration>();
      const doc = view.state.doc;
      const text = doc.toString();

      // Collect all decoration ranges
      const allRanges: Array<{ from: number; to: number; deco: Decoration }> = [];

      // Emphasis ranges
      for (const range of findOrgEmphasisRanges(text)) {
        allRanges.push({
          from: range.from,
          to: range.to,
          deco: Decoration.mark({ class: range.class }),
        });
      }

      // Link ranges
      for (const link of findOrgLinks(text)) {
        allRanges.push({
          from: link.from,
          to: link.to,
          deco: Decoration.mark({ class: 'cm-link' }),
        });
      }

      // Sort by start position, required by RangeSetBuilder
      allRanges.sort((a, b) => a.from - b.from || a.to - b.to);

      for (const { from, to, deco } of allRanges) {
        builder.add(from, to, deco);
      }

      return builder.finish();
    }
  },
  {
    decorations: (v) => v.decorations,
  },
);

function createOrgHighlightStyle(fontColor: string): HighlightStyle {
  return HighlightStyle.define([
    { tag: tags.heading1, fontSize: `${FONT_SIZES.h1}px`, fontWeight: 'bold', color: fontColor },
    { tag: tags.heading2, fontSize: `${FONT_SIZES.h2}px`, fontWeight: 'bold', color: fontColor },
    { tag: tags.heading3, fontSize: `${FONT_SIZES.h3}px`, fontWeight: 'bold', color: fontColor },
    { tag: tags.heading4, fontSize: `${FONT_SIZES.h4}px`, fontWeight: 'bold', color: fontColor },
    { tag: tags.heading5, fontSize: `${FONT_SIZES.h5}px`, fontWeight: 'bold', color: fontColor },
    { tag: tags.heading6, fontSize: `${FONT_SIZES.h6}px`, fontWeight: 'bold', color: fontColor },
    { tag: tags.monospace, class: 'cm-inline-code' },
    { tag: tags.meta, class: 'cm-property-drawer' },
    { tag: tags.processingInstruction, class: 'cm-code-block' },
    { tag: tags.keyword, color: '#666', fontStyle: 'italic' },
    { tag: tags.comment, color: '#999' },
    { tag: tags.list, color: fontColor },
    { tag: tags.content, color: fontColor },
  ]);
}

export function orgExtensions(fontColor: string): Extension[] {
  return [
    StreamLanguage.define(orgStreamParser),
    syntaxHighlighting(createOrgHighlightStyle(fontColor)),
    orgInlineDecorations,
  ];
}

// Export for testing
export {
  findOrgEmphasisRanges,
  findOrgLinks,
  isOrgEmphasisPre,
  isOrgEmphasisPost,
  type EmphasisRange,
};
