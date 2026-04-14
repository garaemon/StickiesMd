/**
 * Code block decorations for CodeMirror 6.
 *
 * Provides:
 * 1. Line decorations that create a GitHub-style box around code blocks
 *    (works for both Markdown and Org-mode)
 * 2. Syntax highlighting for code inside Org-mode #+BEGIN_SRC blocks
 *    (Markdown handles this natively via codeLanguages)
 */
import {
  Decoration,
  type DecorationSet,
  EditorView,
  ViewPlugin,
  type ViewUpdate,
} from '@codemirror/view';
import { RangeSetBuilder, type Text, type Extension, type EditorState } from '@codemirror/state';
import { LanguageDescription, syntaxTree } from '@codemirror/language';
import { languages } from '@codemirror/language-data';
import { highlightTree } from '@lezer/highlight';
import { codeTokenHighlightStyle } from './code-highlight-theme';
import type { FileFormat } from '../../shared/types';

// ---------------------------------------------------------------------------
// Code block detection
// ---------------------------------------------------------------------------

export interface CodeBlockInfo {
  /** 1-based line number of the opening fence / #+BEGIN_SRC */
  startLineNum: number;
  /** 1-based line number of the closing fence / #+END_SRC */
  endLineNum: number;
  /** Language specifier (empty string if none) */
  language: string;
}

/**
 * Find Markdown fenced code blocks by walking the Lezer syntax tree.
 *
 * Uses the `FencedCode` nodes produced by @codemirror/lang-markdown's
 * incremental parser instead of regex, so indented fences, mixed fence
 * characters, and other edge cases are handled correctly by the parser.
 */
export function findMarkdownCodeBlocks(state: EditorState): CodeBlockInfo[] {
  const blocks: CodeBlockInfo[] = [];
  const doc = state.doc;
  const tree = syntaxTree(state);
  let currentBlock: CodeBlockInfo | null = null;

  tree.iterate({
    enter(node) {
      if (node.name === 'FencedCode') {
        currentBlock = {
          startLineNum: doc.lineAt(node.from).number,
          endLineNum: doc.lineAt(node.to).number,
          language: '',
        };
      } else if (node.name === 'CodeInfo' && currentBlock) {
        currentBlock.language = doc.sliceString(node.from, node.to).trim().split(/\s/)[0] || '';
      }
    },
    leave(node) {
      if (node.name === 'FencedCode' && currentBlock) {
        blocks.push(currentBlock);
        currentBlock = null;
      }
    },
  });

  return blocks;
}

/** Find Org-mode code blocks (#+BEGIN_SRC ... #+END_SRC). */
export function findOrgCodeBlocks(doc: Text): CodeBlockInfo[] {
  const blocks: CodeBlockInfo[] = [];
  let inBlock = false;
  let startLineNum = 0;
  let language = '';

  for (let i = 1; i <= doc.lines; i++) {
    const lineText = doc.line(i).text;

    if (!inBlock) {
      const match = lineText.match(/^#\+BEGIN_SRC\s*(\S*)/i);
      if (match) {
        inBlock = true;
        startLineNum = i;
        language = match[1] || '';
      }
    } else {
      if (/^#\+END_SRC\b/i.test(lineText)) {
        blocks.push({ startLineNum, endLineNum: i, language });
        inBlock = false;
      }
    }
  }

  return blocks;
}

// ---------------------------------------------------------------------------
// Line decorations for the code block box
// ---------------------------------------------------------------------------

const codeblockLine = Decoration.line({ class: 'cm-codeblock-line' });
const codeblockFirst = Decoration.line({ class: 'cm-codeblock-line cm-codeblock-first' });
const codeblockLast = Decoration.line({ class: 'cm-codeblock-line cm-codeblock-last' });
const codeblockSingle = Decoration.line({
  class: 'cm-codeblock-line cm-codeblock-first cm-codeblock-last',
});

/** ViewPlugin that adds line decorations to code block lines for box styling. */
function codeBlockBoxPlugin(format: FileFormat) {
  return ViewPlugin.fromClass(
    class {
      decorations: DecorationSet;

      constructor(view: EditorView) {
        this.decorations = this.buildDecorations(view);
      }

      update(update: ViewUpdate) {
        if (
          update.docChanged ||
          (format === 'markdown' && syntaxTree(update.state) !== syntaxTree(update.startState))
        ) {
          this.decorations = this.buildDecorations(update.view);
        }
      }

      buildDecorations(view: EditorView): DecorationSet {
        const builder = new RangeSetBuilder<Decoration>();
        const doc = view.state.doc;
        const blocks =
          format === 'markdown' ? findMarkdownCodeBlocks(view.state) : findOrgCodeBlocks(doc);

        for (const block of blocks) {
          for (let lineNum = block.startLineNum; lineNum <= block.endLineNum; lineNum++) {
            const line = doc.line(lineNum);
            let deco: Decoration;
            if (block.startLineNum === block.endLineNum) {
              deco = codeblockSingle;
            } else if (lineNum === block.startLineNum) {
              deco = codeblockFirst;
            } else if (lineNum === block.endLineNum) {
              deco = codeblockLast;
            } else {
              deco = codeblockLine;
            }
            builder.add(line.from, line.from, deco);
          }
        }

        return builder.finish();
      }
    },
    { decorations: (v) => v.decorations },
  );
}

// ---------------------------------------------------------------------------
// Org-mode code block syntax highlighting
// ---------------------------------------------------------------------------

/** ViewPlugin that applies syntax highlighting to Org-mode code block contents. */
function orgCodeHighlightPlugin() {
  return ViewPlugin.fromClass(
    class {
      decorations: DecorationSet;
      private loadingLanguages = new Set<string>();
      private view: EditorView;
      private destroyed = false;

      constructor(view: EditorView) {
        this.view = view;
        this.decorations = this.buildDecorations();
      }

      update(update: ViewUpdate) {
        if (update.docChanged || update.viewportChanged) {
          this.decorations = this.buildDecorations();
        }
      }

      destroy() {
        this.destroyed = true;
      }

      buildDecorations(): DecorationSet {
        const builder = new RangeSetBuilder<Decoration>();
        const doc = this.view.state.doc;
        const blocks = findOrgCodeBlocks(doc);

        for (const block of blocks) {
          if (!block.language) {
            continue;
          }

          const langDesc = LanguageDescription.matchLanguageName(languages, block.language);
          if (!langDesc) {
            continue;
          }

          if (langDesc.support) {
            // Language loaded — parse and highlight the content
            const contentStartLine = block.startLineNum + 1;
            const contentEndLine = block.endLineNum - 1;
            if (contentStartLine > contentEndLine) {
              continue;
            }

            const contentFrom = doc.line(contentStartLine).from;
            const contentTo = doc.line(contentEndLine).to;
            const code = doc.sliceString(contentFrom, contentTo);

            const tree = langDesc.support.language.parser.parse(code);
            highlightTree(tree, codeTokenHighlightStyle, (from, to, classes) => {
              builder.add(
                contentFrom + from,
                contentFrom + to,
                Decoration.mark({ class: classes }),
              );
            });
          } else if (!this.loadingLanguages.has(block.language)) {
            // Start loading the language; re-render when ready
            this.loadingLanguages.add(block.language);
            langDesc.load().then(() => {
              this.loadingLanguages.delete(block.language);
              if (!this.destroyed) {
                this.view.dispatch({});
              }
            });
          }
        }

        return builder.finish();
      }
    },
    { decorations: (v) => v.decorations },
  );
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/** Create code block extensions (box decorations + syntax highlighting) for the given format. */
export function codeBlockExtensions(format: FileFormat): Extension[] {
  const exts: Extension[] = [codeBlockBoxPlugin(format)];
  if (format === 'org') {
    exts.push(orgCodeHighlightPlugin());
  }
  return exts;
}
