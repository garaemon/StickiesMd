import { describe, it, expect } from 'vitest';
import { guessImageMimeType, isPathAllowed } from '../../src/main/image-protocol';

describe('guessImageMimeType', () => {
  it('returns correct MIME type for png', () => {
    expect(guessImageMimeType('/path/to/image.png')).toBe('image/png');
  });

  it('returns correct MIME type for jpg', () => {
    expect(guessImageMimeType('/path/to/photo.jpg')).toBe('image/jpeg');
  });

  it('returns correct MIME type for jpeg', () => {
    expect(guessImageMimeType('/path/to/photo.jpeg')).toBe('image/jpeg');
  });

  it('returns correct MIME type for gif', () => {
    expect(guessImageMimeType('/path/to/anim.gif')).toBe('image/gif');
  });

  it('returns correct MIME type for svg', () => {
    expect(guessImageMimeType('/path/to/icon.svg')).toBe('image/svg+xml');
  });

  it('returns correct MIME type for webp', () => {
    expect(guessImageMimeType('/path/to/photo.webp')).toBe('image/webp');
  });

  it('returns octet-stream for unknown extensions', () => {
    expect(guessImageMimeType('/path/to/file.xyz')).toBe('application/octet-stream');
  });

  it('handles uppercase extensions', () => {
    expect(guessImageMimeType('/path/to/image.PNG')).toBe('image/png');
  });

  it('handles files without extension', () => {
    expect(guessImageMimeType('/path/to/noext')).toBe('application/octet-stream');
  });
});

describe('isPathAllowed', () => {
  it('allows files in an allowed directory', () => {
    const allowed = ['/Users/garaemon/notes'];
    expect(isPathAllowed('/Users/garaemon/notes/image.png', allowed)).toBe(true);
  });

  it('allows files in a subdirectory of an allowed directory', () => {
    const allowed = ['/Users/garaemon/notes'];
    expect(isPathAllowed('/Users/garaemon/notes/images/photo.png', allowed)).toBe(true);
  });

  it('rejects files outside allowed directories', () => {
    const allowed = ['/Users/garaemon/notes'];
    expect(isPathAllowed('/etc/passwd', allowed)).toBe(false);
  });

  it('rejects files in a sibling directory', () => {
    const allowed = ['/Users/garaemon/notes'];
    expect(isPathAllowed('/Users/garaemon/secrets/key.png', allowed)).toBe(false);
  });

  it('rejects paths containing .. segments', () => {
    const allowed = ['/Users/garaemon/notes'];
    expect(isPathAllowed('/Users/garaemon/notes/../secrets/key.png', allowed)).toBe(false);
  });

  it('supports multiple allowed directories', () => {
    const allowed = ['/Users/garaemon/notes', '/Users/garaemon/photos'];
    expect(isPathAllowed('/Users/garaemon/notes/a.png', allowed)).toBe(true);
    expect(isPathAllowed('/Users/garaemon/photos/b.png', allowed)).toBe(true);
    expect(isPathAllowed('/Users/garaemon/secrets/c.png', allowed)).toBe(false);
  });

  it('rejects when no directories are allowed', () => {
    expect(isPathAllowed('/Users/garaemon/notes/image.png', [])).toBe(false);
  });

  it('prevents prefix-matching bypass (notes-evil vs notes)', () => {
    const allowed = ['/Users/garaemon/notes'];
    expect(isPathAllowed('/Users/garaemon/notes-evil/image.png', allowed)).toBe(false);
  });

  it('handles allowed directory with trailing slash', () => {
    const allowed = ['/Users/garaemon/notes/'];
    expect(isPathAllowed('/Users/garaemon/notes/image.png', allowed)).toBe(true);
  });

  it('allows paths containing spaces', () => {
    const allowed = ['/Users/garaemon/My Documents'];
    expect(isPathAllowed('/Users/garaemon/My Documents/image.png', allowed)).toBe(true);
  });
});
