import { BrowserWindow, shell } from 'electron';
import { existsSync, mkdirSync, writeFileSync } from 'fs';
import { homedir } from 'os';
import { join } from 'path';
import * as IPC from '../shared/ipc-channels';
import type { StickyNote, WindowFrame } from '../shared/types';
import { FileWatcher } from './file-watcher';
import { showOpenDialog } from './menu';
import { createNote, findNoteByPath, getAllNotes, removeNote, updateNote } from './store';
import { createStickyWindow } from './sticky-window';

interface ManagedWindow {
  win: BrowserWindow;
  note: StickyNote;
  watcher: FileWatcher;
}

const windows = new Map<string, ManagedWindow>();

function getStorageDir(): string {
  const dir = join(homedir(), '.stickies-md');
  if (!existsSync(dir)) {
    mkdirSync(dir, { recursive: true });
  }
  return dir;
}

export function createWindowForNote(note: StickyNote): void {
  const win = createStickyWindow(note);

  const watcher = new FileWatcher(note.filePath, (content: string) => {
    if (!win.isDestroyed()) {
      win.webContents.send(IPC.FILE_CHANGED, content);
    }
  });

  const managed: ManagedWindow = { win, note, watcher };
  windows.set(note.id, managed);

  // Send note settings when renderer is ready
  win.webContents.on('did-finish-load', async () => {
    win.webContents.send(IPC.NOTE_SETTINGS, note);
    try {
      const content = await watcher.start();
      win.webContents.send(IPC.FILE_CHANGED, content);
    } catch (err) {
      console.error(`Failed to start watcher for ${note.filePath}:`, err);
    }
  });

  // Focus tracking
  win.on('focus', () => {
    win.webContents.send(IPC.FOCUS_CHANGED, true);
  });
  win.on('blur', () => {
    win.webContents.send(IPC.FOCUS_CHANGED, false);
  });

  // Window position/size persistence (debounced)
  let frameTimer: ReturnType<typeof setTimeout> | null = null;
  const saveFrame = () => {
    if (frameTimer) clearTimeout(frameTimer);
    frameTimer = setTimeout(() => {
      if (win.isDestroyed()) return;
      const bounds = win.getBounds();
      const frame: WindowFrame = {
        x: bounds.x,
        y: bounds.y,
        width: bounds.width,
        height: bounds.height,
      };
      updateNote(note.id, { frame });
    }, 500);
  };
  win.on('move', saveFrame);
  win.on('resize', saveFrame);

  // Handle close
  win.on('closed', async () => {
    await watcher.stop();
    windows.delete(note.id);
  });
}

export function restoreWindows(): void {
  const notes = getAllNotes();
  if (notes.length === 0) {
    createNewSticky();
    return;
  }
  for (const note of notes) {
    if (existsSync(note.filePath)) {
      createWindowForNote(note);
    } else {
      removeNote(note.id);
    }
  }
}

export function createNewSticky(): void {
  const dir = getStorageDir();
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19);
  const filePath = join(dir, `note-${timestamp}.org`);
  writeFileSync(
    filePath,
    `* New Note\n\nStart writing here...\n`,
    'utf-8',
  );
  const note = createNote(filePath);
  createWindowForNote(note);
}

export async function openFile(): Promise<void> {
  const filePath = await showOpenDialog();
  if (!filePath) return;

  // Check if already open
  const existing = findNoteByPath(filePath);
  if (existing) {
    const managed = windows.get(existing.id);
    if (managed && !managed.win.isDestroyed()) {
      managed.win.focus();
      return;
    }
  }

  const note = createNote(filePath);
  createWindowForNote(note);
}

export function resetAllMouseThrough(): void {
  for (const { win, note } of windows.values()) {
    if (!win.isDestroyed()) {
      win.setIgnoreMouseEvents(false);
      win.setOpacity(note.opacity);
    }
  }
}

export function getManagedWindow(noteId: string): ManagedWindow | undefined {
  return windows.get(noteId);
}

export function findManagedWindowByWebContents(
  webContentsId: number,
): ManagedWindow | undefined {
  for (const managed of windows.values()) {
    if (!managed.win.isDestroyed() && managed.win.webContents.id === webContentsId) {
      return managed;
    }
  }
  return undefined;
}

export function getAllWindows(): BrowserWindow[] {
  return Array.from(windows.values())
    .filter((m) => !m.win.isDestroyed())
    .map((m) => m.win);
}
