import { contextBridge, ipcRenderer } from 'electron';
import type { StickyNote } from '../shared/types';
import * as IPC from '../shared/ipc-channels';

const api = {
  // Main -> Renderer listeners
  onFileChanged: (callback: (content: string) => void) => {
    const handler = (_event: Electron.IpcRendererEvent, content: string) => callback(content);
    ipcRenderer.on(IPC.FILE_CHANGED, handler);
    return () => ipcRenderer.removeListener(IPC.FILE_CHANGED, handler);
  },
  onFocusChanged: (callback: (focused: boolean) => void) => {
    const handler = (_event: Electron.IpcRendererEvent, focused: boolean) => callback(focused);
    ipcRenderer.on(IPC.FOCUS_CHANGED, handler);
    return () => ipcRenderer.removeListener(IPC.FOCUS_CHANGED, handler);
  },
  onNoteSettings: (callback: (note: StickyNote) => void) => {
    const handler = (_event: Electron.IpcRendererEvent, note: StickyNote) => callback(note);
    ipcRenderer.on(IPC.NOTE_SETTINGS, handler);
    return () => ipcRenderer.removeListener(IPC.NOTE_SETTINGS, handler);
  },
  onTriggerSave: (callback: () => void) => {
    const handler = () => callback();
    ipcRenderer.on(IPC.TRIGGER_SAVE, handler);
    return () => ipcRenderer.removeListener(IPC.TRIGGER_SAVE, handler);
  },

  // Renderer -> Main actions
  saveContent: (content: string) => ipcRenderer.send(IPC.SAVE_CONTENT, content),
  updateColor: (color: string) => ipcRenderer.send(IPC.UPDATE_COLOR, color),
  updateFontColor: (color: string) => ipcRenderer.send(IPC.UPDATE_FONT_COLOR, color),
  updateOpacity: (opacity: number) => ipcRenderer.send(IPC.UPDATE_OPACITY, opacity),
  toggleLineNumbers: () => ipcRenderer.send(IPC.TOGGLE_LINE_NUMBERS),
  toggleAlwaysOnTop: () => ipcRenderer.send(IPC.TOGGLE_ALWAYS_ON_TOP),
  setMouseThrough: (enabled: boolean) => ipcRenderer.send(IPC.SET_MOUSE_THROUGH, enabled),
  openFileDialog: () => ipcRenderer.send(IPC.OPEN_FILE_DIALOG),
  openUrl: (url: string) => ipcRenderer.send(IPC.OPEN_URL, url),
  dropImage: (path: string) => ipcRenderer.send(IPC.DROP_IMAGE, path),

  // Renderer -> Main invoke (request-response)
  getNoteSettings: (): Promise<StickyNote | null> => ipcRenderer.invoke(IPC.GET_NOTE_SETTINGS),
};

export type ElectronAPI = typeof api;

contextBridge.exposeInMainWorld('electronAPI', api);
