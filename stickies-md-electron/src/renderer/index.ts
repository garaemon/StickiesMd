import { StickyEditor } from './editor/editor';
import { Toolbar } from './ui/toolbar';
import { SettingsPanel } from './ui/settings-panel';
import { detectFileFormat } from '../shared/types';
import type { ElectronAPI } from './preload';
import type { StickyNote } from '../shared/types';
import { dirname } from 'path';

declare global {
  interface Window {
    electronAPI: ElectronAPI;
  }
}

let editor: StickyEditor | null = null;
let toolbar: Toolbar | null = null;
let settingsPanel: SettingsPanel | null = null;
let currentNote: StickyNote | null = null;

function applyBackgroundColor(color: string): void {
  document.body.style.backgroundColor = color;
}

function initEditor(note: StickyNote): void {
  const container = document.getElementById('editor-container')!;
  const format = detectFileFormat(note.filePath);
  const baseDir = dirname(note.filePath);

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

// Listen for note settings (sent on load and when settings change)
window.electronAPI.onNoteSettings((note: StickyNote) => {
  currentNote = note;

  if (!editor) {
    // First time: initialize everything
    initEditor(note);
    initToolbar(note);
    initSettings(note);
  } else {
    // Update settings
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

// Listen for file content changes (initial load + external editor changes)
window.electronAPI.onFileChanged((content: string) => {
  editor?.setContent(content);
});

// Listen for focus changes
window.electronAPI.onFocusChanged((focused: boolean) => {
  editor?.setEditable(focused);
});

// Listen for save trigger (from menu Cmd+S)
window.electronAPI.onTriggerSave(() => {
  editor?.forceSave();
});
