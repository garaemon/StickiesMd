import Store from 'electron-store';
import { v4 as uuidv4 } from 'uuid';
import {
  DEFAULT_FONT_COLOR,
  DEFAULT_FRAME,
  DEFAULT_OPACITY,
  randomPaletteColor,
} from '../shared/constants';
import type { StickyNote } from '../shared/types';

interface StoreSchema {
  notes: StickyNote[];
}

const store = new Store<StoreSchema>({
  name: 'stickies-md',
  defaults: {
    notes: [],
  },
});

export function getAllNotes(): StickyNote[] {
  return store.get('notes');
}

export function getNote(id: string): StickyNote | undefined {
  return getAllNotes().find((n) => n.id === id);
}

export function createNote(filePath: string): StickyNote {
  const note: StickyNote = {
    id: uuidv4(),
    filePath,
    backgroundColor: randomPaletteColor(),
    fontColor: DEFAULT_FONT_COLOR,
    opacity: DEFAULT_OPACITY,
    frame: { ...DEFAULT_FRAME },
    isAlwaysOnTop: false,
    showLineNumbers: false,
  };
  const notes = getAllNotes();
  notes.push(note);
  store.set('notes', notes);
  return note;
}

export function updateNote(
  id: string,
  updates: Partial<Omit<StickyNote, 'id'>>,
): StickyNote | undefined {
  const notes = getAllNotes();
  const index = notes.findIndex((n) => n.id === id);
  if (index === -1) return undefined;
  notes[index] = { ...notes[index], ...updates };
  store.set('notes', notes);
  return notes[index];
}

export function removeNote(id: string): void {
  const notes = getAllNotes().filter((n) => n.id !== id);
  store.set('notes', notes);
}

export function findNoteByPath(filePath: string): StickyNote | undefined {
  return getAllNotes().find((n) => n.filePath === filePath);
}
