/**
 * CodeMirror 6 editor wrapper for sticky notes.
 *
 * Uses Compartments for dynamic reconfiguration of language mode,
 * line numbers, editability, and theme. Each renderer process has
 * one StickyEditor instance (one editor per Electron window).
 */
import { EditorState, type Extension, Compartment } from '@codemirror/state';
import { EditorView, lineNumbers, keymap } from '@codemirror/view';
import { defaultKeymap, history, historyKeymap } from '@codemirror/commands';
import { markdownExtensions } from './markdown-lang';
import { orgExtensions } from './org-lang';
import { linkHandlerExtension } from './link-handler';
import { imageWidgetExtension } from './image-widgets';
import { SAVE_DEBOUNCE_MS } from '../../shared/constants';
import type { FileFormat } from '../../shared/types';

export interface EditorConfig {
  container: HTMLElement;
  format: FileFormat;
  fontColor: string;
  showLineNumbers: boolean;
  baseDir: string;
  onContentChange: (content: string) => void;
}

const languageCompartment = new Compartment();
const lineNumbersCompartment = new Compartment();
const editableCompartment = new Compartment();
const themeCompartment = new Compartment();

/** Create a CodeMirror theme that applies the user's font color to text, cursor, and gutters. */
function createFontColorTheme(fontColor: string): Extension {
  return EditorView.theme({
    '&': {
      height: '100%',
      background: 'transparent',
      color: fontColor,
    },
    '.cm-content': {
      caretColor: fontColor,
    },
    '.cm-cursor': {
      borderLeftColor: fontColor,
    },
    '.cm-gutters': {
      background: 'transparent',
      borderRight: '1px solid rgba(0,0,0,0.1)',
      color: 'rgba(0,0,0,0.3)',
    },
    '.cm-scroller': {
      fontFamily: "'SF Mono', 'Menlo', 'Monaco', 'Consolas', monospace",
      fontSize: '14px',
      lineHeight: '1.5',
      padding: '4px 12px',
    },
    '&.cm-focused': {
      outline: 'none',
    },
    '.cm-activeLine': {
      background: 'rgba(0,0,0,0.03)',
    },
    '.cm-activeLineGutter': {
      background: 'rgba(0,0,0,0.05)',
    },
    // Emphasis styles for Org-mode ViewPlugin decorations
    '.cm-strong': {
      fontWeight: 'bold',
    },
    '.cm-emphasis': {
      fontStyle: 'italic',
    },
    '.cm-underline': {
      textDecoration: 'underline',
    },
  });
}

function languageExtensions(format: FileFormat, fontColor: string, baseDir: string): Extension[] {
  const exts: Extension[] = [];

  if (format === 'markdown') {
    exts.push(...markdownExtensions(fontColor));
  } else {
    exts.push(...orgExtensions(fontColor));
  }

  exts.push(imageWidgetExtension(baseDir, format));
  exts.push(...linkHandlerExtension());

  return exts;
}

export class StickyEditor {
  private view: EditorView;
  private saveDebounceTimer: ReturnType<typeof setTimeout> | null = null;
  private isExternalUpdate = false;
  private config: EditorConfig;

  constructor(config: EditorConfig) {
    this.config = config;

    const state = EditorState.create({
      doc: '',
      extensions: [
        history(),
        keymap.of([...defaultKeymap, ...historyKeymap]),
        languageCompartment.of(languageExtensions(config.format, config.fontColor, config.baseDir)),
        lineNumbersCompartment.of(config.showLineNumbers ? lineNumbers() : []),
        editableCompartment.of(EditorView.editable.of(true)),
        themeCompartment.of(createFontColorTheme(config.fontColor)),
        EditorView.updateListener.of((update) => {
          if (update.docChanged && !this.isExternalUpdate) {
            this.debouncedSave();
          }
        }),
      ],
    });

    this.view = new EditorView({
      state,
      parent: config.container,
    });
  }

  private debouncedSave(): void {
    if (this.saveDebounceTimer) clearTimeout(this.saveDebounceTimer);
    this.saveDebounceTimer = setTimeout(() => {
      this.config.onContentChange(this.view.state.doc.toString());
    }, SAVE_DEBOUNCE_MS);
  }

  setContent(content: string): void {
    // Flag suppresses the updateListener from treating this as a user edit.
    // Safe because CM6 dispatches update listeners synchronously within dispatch().
    this.isExternalUpdate = true;
    const currentContent = this.view.state.doc.toString();
    if (content !== currentContent) {
      this.view.dispatch({
        changes: { from: 0, to: this.view.state.doc.length, insert: content },
      });
    }
    this.isExternalUpdate = false;
  }

  getContent(): string {
    return this.view.state.doc.toString();
  }

  setEditable(editable: boolean): void {
    this.view.dispatch({
      effects: editableCompartment.reconfigure(EditorView.editable.of(editable)),
    });
  }

  setShowLineNumbers(show: boolean): void {
    this.view.dispatch({
      effects: lineNumbersCompartment.reconfigure(show ? lineNumbers() : []),
    });
  }

  setFontColor(fontColor: string): void {
    this.config.fontColor = fontColor;
    this.view.dispatch({
      effects: [
        themeCompartment.reconfigure(createFontColorTheme(fontColor)),
        languageCompartment.reconfigure(
          languageExtensions(this.config.format, fontColor, this.config.baseDir),
        ),
      ],
    });
  }

  forceSave(): void {
    if (this.saveDebounceTimer) clearTimeout(this.saveDebounceTimer);
    this.config.onContentChange(this.view.state.doc.toString());
  }

  destroy(): void {
    if (this.saveDebounceTimer) clearTimeout(this.saveDebounceTimer);
    this.view.destroy();
  }
}
