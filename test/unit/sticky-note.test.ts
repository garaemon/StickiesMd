import { describe, it, expect } from 'vitest';
import { detectFileFormat } from '../../src/shared/types';
import { PALETTE, DEFAULT_FONT_COLOR, DEFAULT_OPACITY, DEFAULT_FRAME, randomPaletteColor } from '../../src/shared/constants';

describe('StickyNote types', () => {
  describe('detectFileFormat', () => {
    it('detects org files', () => {
      expect(detectFileFormat('/path/to/file.org')).toBe('org');
    });

    it('detects markdown files', () => {
      expect(detectFileFormat('/path/to/file.md')).toBe('markdown');
    });

    it('defaults to markdown for unknown extensions', () => {
      expect(detectFileFormat('/path/to/file.txt')).toBe('markdown');
    });
  });

  describe('constants', () => {
    it('has 6 palette colors', () => {
      expect(PALETTE).toHaveLength(6);
    });

    it('palette colors are valid hex', () => {
      for (const color of PALETTE) {
        expect(color).toMatch(/^#[0-9A-Fa-f]{6}$/);
      }
    });

    it('has correct palette colors matching Swift', () => {
      expect(PALETTE[0]).toBe('#FFF9C4'); // Yellow
      expect(PALETTE[1]).toBe('#E1F5FE'); // Blue
      expect(PALETTE[2]).toBe('#F1F8E9'); // Green
      expect(PALETTE[3]).toBe('#FCE4EC'); // Pink
      expect(PALETTE[4]).toBe('#F3E5F5'); // Purple
      expect(PALETTE[5]).toBe('#F5F5F5'); // Gray
    });

    it('default font color is black', () => {
      expect(DEFAULT_FONT_COLOR).toBe('#000000');
    });

    it('default opacity is 1.0', () => {
      expect(DEFAULT_OPACITY).toBe(1.0);
    });

    it('default frame has reasonable dimensions', () => {
      expect(DEFAULT_FRAME.width).toBe(300);
      expect(DEFAULT_FRAME.height).toBe(200);
    });

    it('randomPaletteColor returns a palette color', () => {
      const color = randomPaletteColor();
      expect(PALETTE).toContain(color);
    });
  });
});
