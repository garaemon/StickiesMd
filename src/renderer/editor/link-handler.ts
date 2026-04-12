/**
 * Link handling extension for CodeMirror 6.
 *
 * Provides two features:
 * 1. Bare URL decoration: detects http(s) URLs and marks them with .cm-link class
 * 2. Cmd/Ctrl+click: opens URLs in system browser via electronAPI
 *
 * Supports bare URLs, Markdown [text](url) links, and Org [[url][desc]] links.
 */
import {
  Decoration,
  type DecorationSet,
  EditorView,
  ViewPlugin,
  type ViewUpdate,
} from '@codemirror/view';
import { RangeSetBuilder } from '@codemirror/state';
import type { Extension } from '@codemirror/state';

interface LinkMatch {
  from: number;
  to: number;
  url: string;
}

const BARE_URL_REGEX = new RegExp('https?://[^\\s<>\\[\\]()"]*[^\\s<>\\[\\]()".,;:!?\'")}]', 'g');

/** Find bare http(s) URLs in text. */
function findBareUrls(text: string): LinkMatch[] {
  const matches: LinkMatch[] = [];
  // Reset lastIndex because this regex has the `g` flag and is reused across calls;
  // without this, subsequent calls would resume matching from the prior call's position.
  BARE_URL_REGEX.lastIndex = 0;
  let match;
  while ((match = BARE_URL_REGEX.exec(text)) !== null) {
    matches.push({
      from: match.index,
      to: match.index + match[0].length,
      url: match[0],
    });
  }
  return matches;
}

/** Find Markdown [text](url) links in text. */
function findMarkdownLinks(text: string): LinkMatch[] {
  const matches: LinkMatch[] = [];
  const regex = /\[([^\]]*)\]\(([^)]+)\)/g;
  let match;
  while ((match = regex.exec(text)) !== null) {
    matches.push({
      from: match.index,
      to: match.index + match[0].length,
      url: match[2],
    });
  }
  return matches;
}

/** Find Org [[url][desc]] and [[url]] links in text. */
function findOrgStructuredLinks(text: string): LinkMatch[] {
  const matches: LinkMatch[] = [];
  const regex = /\[\[([^\]]+?)(?:\]\[([^\]]*?))?\]\]/g;
  let match;
  while ((match = regex.exec(text)) !== null) {
    const url = match[1];
    // Only include links that look like URLs (not file: links)
    if (url.startsWith('http://') || url.startsWith('https://')) {
      matches.push({
        from: match.index,
        to: match.index + match[0].length,
        url,
      });
    }
  }
  return matches;
}

/** Find all clickable links (bare URLs + structured links) in the document. */
function findAllLinks(text: string): LinkMatch[] {
  return [...findBareUrls(text), ...findMarkdownLinks(text), ...findOrgStructuredLinks(text)];
}

const bareUrlDecorations = ViewPlugin.fromClass(
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

    // TODO: For large documents, consider limiting scanning to visible viewport lines
    // via view.visibleRanges instead of converting the full document to string.
    buildDecorations(view: EditorView): DecorationSet {
      const builder = new RangeSetBuilder<Decoration>();
      const text = view.state.doc.toString();

      for (const { from, to } of findBareUrls(text)) {
        builder.add(from, to, Decoration.mark({ class: 'cm-link' }));
      }

      return builder.finish();
    }
  },
  {
    // Accessor that tells CodeMirror where to read the DecorationSet from the plugin instance
    decorations: (plugin) => plugin.decorations,
  },
);

const linkClickHandler = EditorView.domEventHandlers({
  click(event: MouseEvent, view: EditorView) {
    if (!event.metaKey && !event.ctrlKey) {
      return false;
    }

    const target = event.target as HTMLElement;
    if (!target.classList.contains('cm-link') && !target.closest('.cm-link')) {
      return false;
    }

    const pos = view.posAtCoords({ x: event.clientX, y: event.clientY });
    if (pos === null) {
      return false;
    }

    const text = view.state.doc.toString();
    const links = findAllLinks(text);

    for (const { from, to, url } of links) {
      if (pos >= from && pos <= to) {
        window.electronAPI.openUrl(url);
        event.preventDefault();
        return true;
      }
    }

    return false;
  },
});

/**
 * CodeMirror extension that decorates bare URLs and handles Cmd/Ctrl+click
 * to open links (bare URLs, Markdown links, Org links) in system browser.
 */
export function linkHandlerExtension(): Extension[] {
  return [bareUrlDecorations, linkClickHandler];
}

// Export for testing
export { findBareUrls, findMarkdownLinks, findOrgStructuredLinks };
