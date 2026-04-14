import { ipcMain, shell } from 'electron';
import * as IPC from '../shared/ipc-channels';
import {
  computeSetMouseThrough,
  shouldPauseMouseThrough,
  shouldResumeMouseThrough,
} from './mouse-through';
import { findManagedWindowByWebContentsId, openFile, updateManagedNote } from './window-manager';

const HEX_COLOR_REGEX = /^#[0-9A-Fa-f]{6}$/;

/**
 * Register all IPC handlers for main<->renderer communication.
 *
 * Handles:
 * - SAVE_CONTENT: persist editor content to disk via FileWatcher
 * - UPDATE_COLOR / UPDATE_FONT_COLOR / UPDATE_OPACITY: appearance settings
 * - TOGGLE_LINE_NUMBERS / TOGGLE_ALWAYS_ON_TOP: per-window toggles
 * - SET_MOUSE_THROUGH: click-through mode
 * - PAUSE_MOUSE_THROUGH / RESUME_MOUSE_THROUGH: hover-to-click support
 * - OPEN_FILE_DIALOG: show native file picker
 * - OPEN_URL: open URL in system browser
 * - GET_NOTE_SETTINGS: return current note settings (invoke/handle pattern)
 */
export function registerIpcHandlers(): void {
  ipcMain.on(IPC.SAVE_CONTENT, async (event: Electron.IpcMainEvent, content: string) => {
    const managed = findManagedWindowByWebContentsId(event.sender.id);
    if (!managed) {
      return;
    }
    if (typeof content !== 'string' || content.length > 10 * 1024 * 1024) {
      return;
    }
    try {
      await managed.watcher.saveContent(content);
    } catch (err) {
      console.error('Failed to save:', err);
    }
  });

  ipcMain.on(IPC.UPDATE_COLOR, (event, color: string) => {
    if (typeof color !== 'string' || !HEX_COLOR_REGEX.test(color)) {
      return;
    }
    const updated = updateManagedNote(event.sender.id, { backgroundColor: color });
    if (updated) {
      event.sender.send(IPC.NOTE_SETTINGS, updated);
    }
  });

  ipcMain.on(IPC.UPDATE_FONT_COLOR, (event, color: string) => {
    if (typeof color !== 'string' || !HEX_COLOR_REGEX.test(color)) {
      return;
    }
    const updated = updateManagedNote(event.sender.id, { fontColor: color });
    if (updated) {
      event.sender.send(IPC.NOTE_SETTINGS, updated);
    }
  });

  ipcMain.on(IPC.UPDATE_OPACITY, (event, opacity: number) => {
    const managed = findManagedWindowByWebContentsId(event.sender.id);
    if (!managed) {
      return;
    }
    if (typeof opacity !== 'number' || isNaN(opacity)) {
      return;
    }
    const clamped = Math.max(0.1, Math.min(1.0, opacity));
    const updated = updateManagedNote(event.sender.id, { opacity: clamped });
    if (updated) {
      managed.win.setOpacity(clamped);
    }
  });

  ipcMain.on(IPC.TOGGLE_LINE_NUMBERS, (event) => {
    const managed = findManagedWindowByWebContentsId(event.sender.id);
    if (!managed) {
      return;
    }
    const updated = updateManagedNote(event.sender.id, {
      showLineNumbers: !managed.note.showLineNumbers,
    });
    if (updated) {
      event.sender.send(IPC.NOTE_SETTINGS, updated);
    }
  });

  ipcMain.on(IPC.TOGGLE_ALWAYS_ON_TOP, (event) => {
    const managed = findManagedWindowByWebContentsId(event.sender.id);
    if (!managed) {
      return;
    }
    const onTop = !managed.note.isAlwaysOnTop;
    const updated = updateManagedNote(event.sender.id, { isAlwaysOnTop: onTop });
    if (updated) {
      managed.win.setAlwaysOnTop(onTop, onTop ? 'floating' : undefined);
      event.sender.send(IPC.NOTE_SETTINGS, updated);
    }
  });

  ipcMain.on(IPC.SET_MOUSE_THROUGH, (event, enabled: boolean) => {
    const managed = findManagedWindowByWebContentsId(event.sender.id);
    if (!managed) {
      return;
    }
    if (typeof enabled !== 'boolean') {
      return;
    }
    const result = computeSetMouseThrough(managed, enabled);
    if (result.shouldUpdate) {
      managed.win.setIgnoreMouseEvents(result.ignoreMouseEvents, { forward: result.forward });
    }
    event.sender.send(IPC.MOUSE_THROUGH_CHANGED, enabled);
  });

  // When mouse-through is active, the toolbar button needs to remain clickable.
  // The renderer pauses mouse-through on mouseenter (so the click event fires)
  // and resumes it on mouseleave.
  ipcMain.on(IPC.PAUSE_MOUSE_THROUGH, (event) => {
    const managed = findManagedWindowByWebContentsId(event.sender.id);
    if (!managed || !shouldPauseMouseThrough(managed)) {
      return;
    }
    managed.win.setIgnoreMouseEvents(false);
  });

  ipcMain.on(IPC.RESUME_MOUSE_THROUGH, (event) => {
    const managed = findManagedWindowByWebContentsId(event.sender.id);
    if (!managed || !shouldResumeMouseThrough(managed)) {
      return;
    }
    managed.win.setIgnoreMouseEvents(true, { forward: true });
  });

  ipcMain.on(IPC.OPEN_FILE_DIALOG, () => {
    openFile();
  });

  ipcMain.on(IPC.OPEN_URL, (_event, url: string) => {
    if (typeof url === 'string' && (url.startsWith('http://') || url.startsWith('https://'))) {
      shell.openExternal(url);
    }
  });

  ipcMain.handle(IPC.GET_NOTE_SETTINGS, (event) => {
    const managed = findManagedWindowByWebContentsId(event.sender.id);
    if (!managed) {
      return null;
    }
    return managed.note;
  });
}
