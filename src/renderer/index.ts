/**
 * Renderer entry point for each sticky note window.
 *
 * Listens for NOTE_SETTINGS (initial load + settings changes) to initialize
 * or update the editor, toolbar, and settings panel. Listens for FILE_CHANGED
 * to update editor content on external file modifications.
 */
import { StickyEditor } from './editor/editor';
import { Toolbar } from './ui/toolbar';
import { SettingsPanel } from './ui/settings-panel';
import { detectFileFormat } from '../shared/types';
import type { StickyNote } from '../shared/types';

/** Extract directory from a POSIX file path (renderer has no access to Node path module). */
function getDirname(filePath: string): string {
  const lastSlash = filePath.lastIndexOf('/');
  return lastSlash === -1 ? '.' : filePath.substring(0, lastSlash);
}

let editor: StickyEditor | null = null;
let toolbar: Toolbar | null = null;
let settingsPanel: SettingsPanel | null = null;

function applyBackgroundColor(color: string): void {
  document.body.style.backgroundColor = color;
}

function initEditor(note: StickyNote): void {
  const container = document.getElementById('editor-container')!;
  const format = detectFileFormat(note.filePath);
  const baseDir = getDirname(note.filePath);

  editor = new StickyEditor({
    container,
    format,
    fontColor: note.fontColor,
    showLineNumbers: note.showLineNumbers,
    baseDir,
    onContentChange: (content: string) => {
      window.electronAPI.saveContent(content);
    },
  });
}

function initToolbar(note: StickyNote): void {
  const container = document.getElementById('toolbar')!;
  toolbar = new Toolbar(container, {
    onSettingsToggle: () => settingsPanel?.toggle(),
    onSave: () => editor?.forceSave(),
  });
  toolbar.setFilePath(note.filePath);
  toolbar.setAlwaysOnTop(note.isAlwaysOnTop);
}

function initSettings(note: StickyNote): void {
  const container = document.getElementById('settings-panel')!;
  settingsPanel = new SettingsPanel(container);
  settingsPanel.updateSelectedColor(note.backgroundColor);
  settingsPanel.updateOpacity(note.opacity);
  settingsPanel.updateFontColor(note.fontColor);
  settingsPanel.updateLineNumbers(note.showLineNumbers);
}

window.electronAPI.onNoteSettings((note: StickyNote) => {
  if (!editor) {
    initEditor(note);
    initToolbar(note);
    initSettings(note);
  } else {
    editor.setShowLineNumbers(note.showLineNumbers);
    editor.setFontColor(note.fontColor);
    toolbar?.setAlwaysOnTop(note.isAlwaysOnTop);
    settingsPanel?.updateSelectedColor(note.backgroundColor);
    settingsPanel?.updateOpacity(note.opacity);
    settingsPanel?.updateFontColor(note.fontColor);
    settingsPanel?.updateLineNumbers(note.showLineNumbers);
  }

  applyBackgroundColor(note.backgroundColor);
});

window.electronAPI.onFileChanged((content: string) => {
  editor?.setContent(content);
});

window.electronAPI.onFocusChanged((focused: boolean) => {
  editor?.setEditable(focused);
});

window.electronAPI.onTriggerSave(() => {
  editor?.forceSave();
});

window.electronAPI.onMouseThroughReset(() => {
  toolbar?.setMouseThrough(false);
  settingsPanel?.updateMouseThrough(false);
});
