import { Decoration, type DecorationSet, EditorView, ViewPlugin, type ViewUpdate } from '@codemirror/view';
import { RangeSetBuilder } from '@codemirror/state';
import type { Extension } from '@codemirror/state';

declare global {
  interface Window {
    electronAPI: {
      openUrl: (url: string) => void;
    };
  }
}

// Bare URL detection regex (matches http:// and https:// URLs)
const BARE_URL_REGEX =
  /https?:\/\/[^\s<>\[\]()"]*[^\s<>\[\]()".,;:!?'")}]/g;

function findBareUrls(text: string): Array<{ from: number; to: number; url: string }> {
  const matches: Array<{ from: number; to: number; url: string }> = [];
  let match;
  BARE_URL_REGEX.lastIndex = 0;
  while ((match = BARE_URL_REGEX.exec(text)) !== null) {
    matches.push({
      from: match.index,
      to: match.index + match[0].length,
      url: match[0],
    });
  }
  return matches;
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
    decorations: (v) => v.decorations,
  },
);

// Click handler for links
const linkClickHandler = EditorView.domEventHandlers({
  click(event: MouseEvent, view: EditorView) {
    if (!event.metaKey && !event.ctrlKey) return false;

    const target = event.target as HTMLElement;
    if (!target.classList.contains('cm-link') && !target.closest('.cm-link')) return false;

    const pos = view.posAtCoords({ x: event.clientX, y: event.clientY });
    if (pos === null) return false;

    const text = view.state.doc.toString();
    const urls = findBareUrls(text);

    for (const { from, to, url } of urls) {
      if (pos >= from && pos <= to) {
        window.electronAPI.openUrl(url);
        event.preventDefault();
        return true;
      }
    }

    return false;
  },
});

export function linkHandlerExtension(): Extension[] {
  return [bareUrlDecorations, linkClickHandler];
}
