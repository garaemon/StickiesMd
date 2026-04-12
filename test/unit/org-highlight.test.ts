import { describe, it, expect } from 'vitest';
import {
  findOrgEmphasisRanges,
  findOrgLinks,
  isOrgEmphasisPre,
  isOrgEmphasisPost,
} from '../../src/renderer/editor/org-lang';

describe('Org-mode inline emphasis', () => {
  describe('isOrgEmphasisPre', () => {
    it('returns true for undefined (start of text)', () => {
      expect(isOrgEmphasisPre(undefined)).toBe(true);
    });

    it('returns true for space', () => {
      expect(isOrgEmphasisPre(' ')).toBe(true);
    });

    it('returns true for dash', () => {
      expect(isOrgEmphasisPre('-')).toBe(true);
    });

    it('returns true for open paren', () => {
      expect(isOrgEmphasisPre('(')).toBe(true);
    });

    it('returns false for alphanumeric', () => {
      expect(isOrgEmphasisPre('a')).toBe(false);
    });
  });

  describe('isOrgEmphasisPost', () => {
    it('returns true for undefined (end of text)', () => {
      expect(isOrgEmphasisPost(undefined)).toBe(true);
    });

    it('returns true for period', () => {
      expect(isOrgEmphasisPost('.')).toBe(true);
    });

    it('returns true for comma', () => {
      expect(isOrgEmphasisPost(',')).toBe(true);
    });

    it('returns false for alphanumeric', () => {
      expect(isOrgEmphasisPost('a')).toBe(false);
    });
  });

  describe('findOrgEmphasisRanges', () => {
    it('detects bold *text*', () => {
      const text = 'This is *bold text* end';
      const ranges = findOrgEmphasisRanges(text);
      const bold = ranges.find((r) => r.class === 'cm-strong');
      expect(bold).toBeDefined();
      expect(text.slice(bold!.from, bold!.to)).toBe('*bold text*');
    });

    it('detects italic /text/', () => {
      const text = 'This is /italic text/ end';
      const ranges = findOrgEmphasisRanges(text);
      const italic = ranges.find((r) => r.class === 'cm-emphasis');
      expect(italic).toBeDefined();
      expect(text.slice(italic!.from, italic!.to)).toBe('/italic text/');
    });

    it('detects underline _text_', () => {
      const text = 'This is _underlined text_ end';
      const ranges = findOrgEmphasisRanges(text);
      const underline = ranges.find((r) => r.class === 'cm-underline');
      expect(underline).toBeDefined();
      expect(text.slice(underline!.from, underline!.to)).toBe('_underlined text_');
    });

    it('detects strikethrough +text+', () => {
      const text = 'This is +deleted text+ end';
      const ranges = findOrgEmphasisRanges(text);
      const strike = ranges.find((r) => r.class === 'cm-strikethrough');
      expect(strike).toBeDefined();
      expect(text.slice(strike!.from, strike!.to)).toBe('+deleted text+');
    });

    it('detects code ~text~', () => {
      const text = 'This is ~inline code~ end';
      const ranges = findOrgEmphasisRanges(text);
      const code = ranges.find((r) => r.class === 'cm-inline-code');
      expect(code).toBeDefined();
      expect(text.slice(code!.from, code!.to)).toBe('~inline code~');
    });

    it('detects verbatim =text=', () => {
      const text = 'This is =verbatim text= end';
      const ranges = findOrgEmphasisRanges(text);
      const code = ranges.find((r) => r.class === 'cm-inline-code');
      expect(code).toBeDefined();
      expect(text.slice(code!.from, code!.to)).toBe('=verbatim text=');
    });

    it('does not match emphasis without proper PRE char', () => {
      const text = 'word*not bold*end';
      const ranges = findOrgEmphasisRanges(text);
      const bold = ranges.find((r) => r.class === 'cm-strong');
      expect(bold).toBeUndefined();
    });

    it('does not match emphasis without proper POST char', () => {
      const text = '*not bold*word';
      const ranges = findOrgEmphasisRanges(text);
      const bold = ranges.find((r) => r.class === 'cm-strong');
      expect(bold).toBeUndefined();
    });

    it('does not match emphasis starting with space', () => {
      const text = 'This is * not bold* end';
      const ranges = findOrgEmphasisRanges(text);
      const bold = ranges.find((r) => r.class === 'cm-strong');
      expect(bold).toBeUndefined();
    });

    it('does not match emphasis ending with space before marker', () => {
      const text = 'This is *not bold * end';
      const ranges = findOrgEmphasisRanges(text);
      const bold = ranges.find((r) => r.class === 'cm-strong');
      expect(bold).toBeUndefined();
    });

    it('detects emphasis at start of text', () => {
      const text = '*bold* at start';
      const ranges = findOrgEmphasisRanges(text);
      const bold = ranges.find((r) => r.class === 'cm-strong');
      expect(bold).toBeDefined();
      expect(text.slice(bold!.from, bold!.to)).toBe('*bold*');
    });

    it('detects emphasis at end of text', () => {
      const text = 'end with *bold*';
      const ranges = findOrgEmphasisRanges(text);
      const bold = ranges.find((r) => r.class === 'cm-strong');
      expect(bold).toBeDefined();
      expect(text.slice(bold!.from, bold!.to)).toBe('*bold*');
    });

    it('detects multiple emphasis in same text', () => {
      const text = 'This has *bold* and /italic/ text';
      const ranges = findOrgEmphasisRanges(text);
      expect(ranges.length).toBeGreaterThanOrEqual(2);
      const bold = ranges.find((r) => r.class === 'cm-strong');
      const italic = ranges.find((r) => r.class === 'cm-emphasis');
      expect(bold).toBeDefined();
      expect(italic).toBeDefined();
    });

    it('handles emphasis after dash (PRE char)', () => {
      const text = 'list -*bold* item';
      const ranges = findOrgEmphasisRanges(text);
      const bold = ranges.find((r) => r.class === 'cm-strong');
      expect(bold).toBeDefined();
    });

    it('handles emphasis followed by period (POST char)', () => {
      const text = 'This is *bold*.';
      const ranges = findOrgEmphasisRanges(text);
      const bold = ranges.find((r) => r.class === 'cm-strong');
      expect(bold).toBeDefined();
    });
  });

  describe('findOrgLinks', () => {
    it('detects [[url]] links', () => {
      const text = 'Visit [[https://example.com]] for info';
      const links = findOrgLinks(text);
      expect(links).toHaveLength(1);
      expect(text.slice(links[0].from, links[0].to)).toBe('[[https://example.com]]');
    });

    it('detects [[url][desc]] links', () => {
      const text = 'Visit [[https://example.com][Example]] for info';
      const links = findOrgLinks(text);
      expect(links).toHaveLength(1);
      expect(text.slice(links[0].from, links[0].to)).toBe(
        '[[https://example.com][Example]]',
      );
    });

    it('detects file links', () => {
      const text = 'See [[file:image.png]]';
      const links = findOrgLinks(text);
      expect(links).toHaveLength(1);
    });

    it('detects multiple links', () => {
      const text = '[[link1]] and [[link2]]';
      const links = findOrgLinks(text);
      expect(links).toHaveLength(2);
    });
  });
});
