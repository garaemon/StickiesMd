import { ipcMain, shell } from 'electron';
import * as IPC from '../shared/ipc-channels';
import { updateNote } from './store';
import { findManagedWindowByWebContents, openFile } from './window-manager';

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
    updateNote(managed.note.id, { backgroundColor: color });
    managed.note.backgroundColor = color;
    // Color is applied via CSS in the renderer, so just send updated settings
    managed.win.webContents.send(IPC.NOTE_SETTINGS, managed.note);
  });

  ipcMain.on(IPC.UPDATE_FONT_COLOR, (event, color: string) => {
    const managed = findManagedWindowByWebContents(event.sender.id);
    if (!managed) return;
    updateNote(managed.note.id, { fontColor: color });
    managed.note.fontColor = color;
    managed.win.webContents.send(IPC.NOTE_SETTINGS, managed.note);
  });

  ipcMain.on(IPC.UPDATE_OPACITY, (event, opacity: number) => {
    const managed = findManagedWindowByWebContents(event.sender.id);
    if (!managed) return;
    const clamped = Math.max(0.1, Math.min(1.0, opacity));
    updateNote(managed.note.id, { opacity: clamped });
    managed.note.opacity = clamped;
    managed.win.setOpacity(clamped);
  });

  ipcMain.on(IPC.TOGGLE_LINE_NUMBERS, (event) => {
    const managed = findManagedWindowByWebContents(event.sender.id);
    if (!managed) return;
    const show = !managed.note.showLineNumbers;
    updateNote(managed.note.id, { showLineNumbers: show });
    managed.note.showLineNumbers = show;
    managed.win.webContents.send(IPC.NOTE_SETTINGS, managed.note);
  });

  ipcMain.on(IPC.TOGGLE_ALWAYS_ON_TOP, (event) => {
    const managed = findManagedWindowByWebContents(event.sender.id);
    if (!managed) return;
    const onTop = !managed.note.isAlwaysOnTop;
    updateNote(managed.note.id, { isAlwaysOnTop: onTop });
    managed.note.isAlwaysOnTop = onTop;
    managed.win.setAlwaysOnTop(onTop, onTop ? 'floating' : undefined);
    managed.win.webContents.send(IPC.NOTE_SETTINGS, managed.note);
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

  ipcMain.handle(IPC.GET_FILE_CONTENT, async (event) => {
    const managed = findManagedWindowByWebContents(event.sender.id);
    if (!managed) return null;
    // Content is sent via FILE_CHANGED on load, this is a fallback
    return null;
  });
}
