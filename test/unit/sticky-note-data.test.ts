import { describe, it, expect } from 'vitest';
import type { StickyNote } from '../../src/shared/types';
import {
  PALETTE,
  DEFAULT_FONT_COLOR,
  DEFAULT_OPACITY,
  DEFAULT_FRAME,
} from '../../src/shared/constants';

// Test the StickyNote data shape and defaults (without electron-store which needs Electron)
describe('StickyNote data model', () => {
  function createTestNote(filePath: string): StickyNote {
    return {
      id: 'test-uuid',
      filePath,
      backgroundColor: PALETTE[0],
      fontColor: DEFAULT_FONT_COLOR,
      opacity: DEFAULT_OPACITY,
      frame: { ...DEFAULT_FRAME },
      isAlwaysOnTop: false,
      showLineNumbers: false,
    };
  }

  it('creates note with correct defaults', () => {
    const note = createTestNote('/tmp/test.org');
    expect(note.filePath).toBe('/tmp/test.org');
    expect(note.fontColor).toBe('#000000');
    expect(note.opacity).toBe(1.0);
    expect(note.isAlwaysOnTop).toBe(false);
    expect(note.showLineNumbers).toBe(false);
    expect(note.frame.width).toBe(300);
    expect(note.frame.height).toBe(200);
  });

  it('serializes to JSON correctly', () => {
    const note = createTestNote('/tmp/test.md');
    const json = JSON.stringify(note);
    const parsed = JSON.parse(json) as StickyNote;
    expect(parsed.id).toBe(note.id);
    expect(parsed.filePath).toBe(note.filePath);
    expect(parsed.backgroundColor).toBe(note.backgroundColor);
    expect(parsed.fontColor).toBe(note.fontColor);
    expect(parsed.opacity).toBe(note.opacity);
    expect(parsed.frame).toEqual(note.frame);
    expect(parsed.isAlwaysOnTop).toBe(note.isAlwaysOnTop);
    expect(parsed.showLineNumbers).toBe(note.showLineNumbers);
  });

  it('handles all palette colors', () => {
    for (const color of PALETTE) {
      const note = createTestNote('/tmp/test.org');
      note.backgroundColor = color;
      expect(note.backgroundColor).toBe(color);
    }
  });

  it('frame has no bookmarkData (unlike Swift version)', () => {
    const note = createTestNote('/tmp/test.org');
    expect((note as Record<string, unknown>).bookmarkData).toBeUndefined();
  });
});
