import { BrowserWindow } from 'electron';
import { randomUUID } from 'crypto';
import { existsSync, mkdirSync, writeFileSync } from 'fs';
import { homedir } from 'os';
import { dirname, join } from 'path';
import * as IPC from '../shared/ipc-channels';
import type { StickyNote, WindowFrame } from '../shared/types';
import { FileWatcher } from './file-watcher';
import { allowImageDir } from './index';
import { showOpenDialog } from './menu';
import { createNote, findNoteByPath, getAllNotes, removeNote, updateNote } from './store';
import { createStickyWindow } from './sticky-window';

interface ManagedWindow {
  win: BrowserWindow;
  note: StickyNote;
  watcher: FileWatcher;
}

const windows = new Map<string, ManagedWindow>();

/** Create the storage directory if it doesn't exist, and return its path. */
function ensureStorageDir(): string {
  const dir = join(homedir(), '.stickies-md');
  mkdirSync(dir, { recursive: true });
  return dir;
}

/**
 * Create a BrowserWindow for a note and wire up all side effects:
 * - Start a FileWatcher for external change detection
 * - Send initial note settings and content when renderer is ready
 * - Track focus changes to toggle editor editability
 * - Persist window position/size on move/resize (debounced)
 * - Clean up watcher and tracking on window close
 */
export function createWindowForNote(note: StickyNote): void {
  const win = createStickyWindow(note);

  // Allow the note's directory for local-image:// protocol
  allowImageDir(dirname(note.filePath));

  const watcher = new FileWatcher(note.filePath, (content: string) => {
    if (!win.isDestroyed()) {
      win.webContents.send(IPC.FILE_CHANGED, content);
    }
  });

  const managed: ManagedWindow = { win, note, watcher };
  windows.set(note.id, managed);

  win.webContents.on('did-finish-load', async () => {
    win.webContents.send(IPC.NOTE_SETTINGS, note);
    try {
      const content = await watcher.start();
      win.webContents.send(IPC.FILE_CHANGED, content);
    } catch (err) {
      console.error(`Failed to start watcher for ${note.filePath}:`, err);
    }
  });

  win.on('focus', () => {
    win.webContents.send(IPC.FOCUS_CHANGED, true);
  });
  win.on('blur', () => {
    win.webContents.send(IPC.FOCUS_CHANGED, false);
  });

  // Debounced window frame persistence
  let framePersistDebounceTimer: ReturnType<typeof setTimeout> | null = null;
  const persistWindowFrame = () => {
    if (framePersistDebounceTimer) clearTimeout(framePersistDebounceTimer);
    framePersistDebounceTimer = setTimeout(() => {
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
  win.on('move', persistWindowFrame);
  win.on('resize', persistWindowFrame);

  win.on('closed', () => {
    if (framePersistDebounceTimer) clearTimeout(framePersistDebounceTimer);
    watcher.stop().catch((err) => {
      console.error(`Failed to stop watcher for ${note.filePath}:`, err);
    });
    windows.delete(note.id);
  });
}

/**
 * Restore all persisted notes on app launch.
 * Notes whose files no longer exist on disk are removed from the store.
 */
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

/** Create a new .org note file and open a window for it. */
export function createNewSticky(): void {
  const dir = ensureStorageDir();
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19);
  const filePath = join(dir, `note-${timestamp}-${randomUUID().slice(0, 8)}.org`);
  writeFileSync(filePath, `* New Note\n\nStart writing here...\n`, 'utf-8');
  const note = createNote(filePath);
  createWindowForNote(note);
}

export async function openFile(): Promise<void> {
  const filePath = await showOpenDialog();
  if (!filePath) return;

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

/**
 * Update a managed note's settings: persists to store and updates in-memory state.
 * Centralizes note mutation to prevent drift between in-memory and persisted state.
 */
export function updateManagedNote(
  webContentsId: number,
  updates: Partial<Omit<StickyNote, 'id'>>,
): StickyNote | undefined {
  const managed = findManagedWindowByWebContentsId(webContentsId);
  if (!managed) return undefined;
  const updated = updateNote(managed.note.id, updates);
  if (updated) managed.note = updated;
  return updated;
}

export function findManagedWindowByWebContentsId(webContentsId: number): ManagedWindow | undefined {
  for (const managed of windows.values()) {
    if (!managed.win.isDestroyed() && managed.win.webContents.id === webContentsId) {
      return managed;
    }
  }
  return undefined;
}
