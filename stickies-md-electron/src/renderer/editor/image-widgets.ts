/**
 * Inline image preview extension for CodeMirror 6.
 *
 * Renders <img> elements below lines containing image links.
 * Supports Markdown ![alt](path) and Org [[file:path]] syntax.
 * Local images are served via the custom local-image:// protocol.
 */
import {
  Decoration,
  type DecorationSet,
  EditorView,
  ViewPlugin,
  type ViewUpdate,
  WidgetType,
} from '@codemirror/view';
import { RangeSetBuilder } from '@codemirror/state';
import type { Extension } from '@codemirror/state';

const IMAGE_EXTENSIONS = new Set(['png', 'jpg', 'jpeg', 'gif', 'svg', 'webp', 'tiff', 'bmp']);

function isImagePath(path: string): boolean {
  const ext = path.split('.').pop()?.toLowerCase() ?? '';
  return IMAGE_EXTENSIONS.has(ext);
}

class ImageWidget extends WidgetType {
  constructor(
    private readonly imagePath: string,
    private readonly baseDir: string,
  ) {
    super();
  }

  toDOM(): HTMLElement {
    const wrapper = document.createElement('div');
    wrapper.style.padding = '4px 0';

    const img = document.createElement('img');
    img.className = 'cm-image-widget';

    // Resolve path - if relative, prepend baseDir
    let src = this.imagePath;
    if (!src.startsWith('/') && !src.startsWith('http')) {
      src = `local-image://${this.baseDir}/${src}`;
    } else if (src.startsWith('/')) {
      src = `local-image://${src}`;
    }

    img.src = src;
    img.alt = this.imagePath;
    img.style.maxHeight = '200px';
    img.style.maxWidth = 'calc(100% - 20px)';
    img.style.borderRadius = '4px';
    img.style.display = 'block';

    img.onerror = () => {
      wrapper.style.display = 'none';
    };

    wrapper.appendChild(img);
    return wrapper;
  }

  eq(other: ImageWidget): boolean {
    return this.imagePath === other.imagePath && this.baseDir === other.baseDir;
  }

  ignoreEvent(): boolean {
    return false;
  }
}

interface ImageMatch {
  lineEnd: number;
  path: string;
}

// Find Markdown images: ![alt](path)
function findMarkdownImages(text: string): ImageMatch[] {
  const matches: ImageMatch[] = [];
  const regex = /!\[([^\]]*)\]\(([^)]+)\)/g;
  let match;
  while ((match = regex.exec(text)) !== null) {
    const path = match[2];
    if (isImagePath(path)) {
      // Find end of line
      const lineEnd = text.indexOf('\n', match.index);
      matches.push({
        lineEnd: lineEnd === -1 ? text.length : lineEnd,
        path,
      });
    }
  }
  return matches;
}

// Find Org images: [[file:path]] or [[./path.ext]]
function findOrgImages(text: string): ImageMatch[] {
  const matches: ImageMatch[] = [];
  const regex = /\[\[(?:file:)?([^\]]+?)\]\]/g;
  let match;
  while ((match = regex.exec(text)) !== null) {
    const path = match[1];
    if (isImagePath(path)) {
      const lineEnd = text.indexOf('\n', match.index);
      matches.push({
        lineEnd: lineEnd === -1 ? text.length : lineEnd,
        path,
      });
    }
  }
  return matches;
}

export function imageWidgetExtension(baseDir: string, format: 'markdown' | 'org'): Extension {
  return ViewPlugin.fromClass(
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

        const images = format === 'markdown' ? findMarkdownImages(text) : findOrgImages(text);

        // Deduplicate by lineEnd and sort
        const seen = new Set<number>();
        const unique = images.filter((img) => {
          if (seen.has(img.lineEnd)) return false;
          seen.add(img.lineEnd);
          return true;
        });
        unique.sort((a, b) => a.lineEnd - b.lineEnd);

        for (const img of unique) {
          builder.add(
            img.lineEnd,
            img.lineEnd,
            Decoration.widget({
              widget: new ImageWidget(img.path, baseDir),
              side: 1,
            }),
          );
        }

        return builder.finish();
      }
    },
    {
      decorations: (v) => v.decorations,
    },
  );
}
