import { ipcMain, shell } from 'electron';
import * as IPC from '../shared/ipc-channels';
import { updateNote } from './store';
import { findManagedWindowByWebContents, openFile } from './window-manager';

/**
 * Register all IPC handlers for main<->renderer communication.
 *
 * Handles:
 * - SAVE_CONTENT: persist editor content to disk via FileWatcher
 * - UPDATE_COLOR / UPDATE_FONT_COLOR / UPDATE_OPACITY: appearance settings
 * - TOGGLE_LINE_NUMBERS / TOGGLE_ALWAYS_ON_TOP: per-window toggles
 * - SET_MOUSE_THROUGH: click-through mode
 * - OPEN_FILE_DIALOG: show native file picker
 * - OPEN_URL: open URL in system browser
 * - GET_NOTE_SETTINGS: return current note settings (invoke/handle pattern)
 */
export function registerIpcHandlers(): void {
  ipcMain.on(IPC.SAVE_CONTENT, async (event, content: string) => {
    const managed = findManagedWindowByWebContents(event.sender.id);
    if (!managed) return;
    try {
      await managed.watcher.saveContent(content);
    } catch (err) {
      console.error('Failed to save:', err);
    }
  });

  ipcMain.on(IPC.UPDATE_COLOR, (event, color: string) => {
    const managed = findManagedWindowByWebContents(event.sender.id);
    if (!managed) return;
    const updated = updateNote(managed.note.id, { backgroundColor: color });
    if (updated) {
      managed.note = updated;
      managed.win.webContents.send(IPC.NOTE_SETTINGS, updated);
    }
  });

  ipcMain.on(IPC.UPDATE_FONT_COLOR, (event, color: string) => {
    const managed = findManagedWindowByWebContents(event.sender.id);
    if (!managed) return;
    const updated = updateNote(managed.note.id, { fontColor: color });
    if (updated) {
      managed.note = updated;
      managed.win.webContents.send(IPC.NOTE_SETTINGS, updated);
    }
  });

  ipcMain.on(IPC.UPDATE_OPACITY, (event, opacity: number) => {
    const managed = findManagedWindowByWebContents(event.sender.id);
    if (!managed) return;
    const clamped = Math.max(0.1, Math.min(1.0, opacity));
    const updated = updateNote(managed.note.id, { opacity: clamped });
    if (updated) {
      managed.note = updated;
      managed.win.setOpacity(clamped);
    }
  });

  ipcMain.on(IPC.TOGGLE_LINE_NUMBERS, (event) => {
    const managed = findManagedWindowByWebContents(event.sender.id);
    if (!managed) return;
    const updated = updateNote(managed.note.id, { showLineNumbers: !managed.note.showLineNumbers });
    if (updated) {
      managed.note = updated;
      managed.win.webContents.send(IPC.NOTE_SETTINGS, updated);
    }
  });

  ipcMain.on(IPC.TOGGLE_ALWAYS_ON_TOP, (event) => {
    const managed = findManagedWindowByWebContents(event.sender.id);
    if (!managed) return;
    const onTop = !managed.note.isAlwaysOnTop;
    const updated = updateNote(managed.note.id, { isAlwaysOnTop: onTop });
    if (updated) {
      managed.note = updated;
      managed.win.setAlwaysOnTop(onTop, onTop ? 'floating' : undefined);
      managed.win.webContents.send(IPC.NOTE_SETTINGS, updated);
    }
  });

  ipcMain.on(IPC.SET_MOUSE_THROUGH, (event, enabled: boolean) => {
    const managed = findManagedWindowByWebContents(event.sender.id);
    if (!managed) return;
    managed.win.setIgnoreMouseEvents(enabled);
    if (enabled) {
      managed.win.setOpacity(0.5);
    } else {
      managed.win.setOpacity(managed.note.opacity);
    }
  });

  ipcMain.on(IPC.OPEN_FILE_DIALOG, () => {
    openFile();
  });

  ipcMain.on(IPC.OPEN_URL, (_event, url: string) => {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      shell.openExternal(url);
    }
  });

  ipcMain.handle(IPC.GET_NOTE_SETTINGS, (event) => {
    const managed = findManagedWindowByWebContents(event.sender.id);
    if (!managed) return null;
    return managed.note;
  });
}
