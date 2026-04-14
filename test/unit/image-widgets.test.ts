import { describe, it, expect } from 'vitest';
import {
  isImagePath,
  findMarkdownImages,
  findOrgImages,
  resolveImageUrl,
} from '../../src/renderer/editor/image-widgets';

describe('isImagePath', () => {
  it('returns true for common image extensions', () => {
    expect(isImagePath('photo.png')).toBe(true);
    expect(isImagePath('photo.jpg')).toBe(true);
    expect(isImagePath('photo.jpeg')).toBe(true);
    expect(isImagePath('photo.gif')).toBe(true);
    expect(isImagePath('photo.svg')).toBe(true);
    expect(isImagePath('photo.webp')).toBe(true);
    expect(isImagePath('photo.tiff')).toBe(true);
    expect(isImagePath('photo.bmp')).toBe(true);
  });

  it('returns true for uppercase extensions', () => {
    expect(isImagePath('photo.PNG')).toBe(true);
    expect(isImagePath('photo.JPG')).toBe(true);
  });

  it('returns false for non-image extensions', () => {
    expect(isImagePath('document.pdf')).toBe(false);
    expect(isImagePath('script.js')).toBe(false);
    expect(isImagePath('style.css')).toBe(false);
    expect(isImagePath('notes.md')).toBe(false);
  });

  it('returns false for paths without extension', () => {
    expect(isImagePath('noext')).toBe(false);
  });

  it('handles paths with directories', () => {
    expect(isImagePath('./images/photo.png')).toBe(true);
    expect(isImagePath('/home/user/photo.jpg')).toBe(true);
    expect(isImagePath('subdir/nested/image.gif')).toBe(true);
  });
});

describe('findMarkdownImages', () => {
  it('finds a simple image link', () => {
    const text = '![alt text](image.png)';
    const images = findMarkdownImages(text);
    expect(images).toHaveLength(1);
    expect(images[0].path).toBe('image.png');
  });

  it('finds image with relative path', () => {
    const text = '![photo](./images/photo.jpg)';
    const images = findMarkdownImages(text);
    expect(images).toHaveLength(1);
    expect(images[0].path).toBe('./images/photo.jpg');
  });

  it('finds image with absolute path', () => {
    const text = '![photo](/home/user/photo.png)';
    const images = findMarkdownImages(text);
    expect(images).toHaveLength(1);
    expect(images[0].path).toBe('/home/user/photo.png');
  });

  it('finds multiple images', () => {
    const text = '![a](a.png)\n![b](b.jpg)';
    const images = findMarkdownImages(text);
    expect(images).toHaveLength(2);
    expect(images[0].path).toBe('a.png');
    expect(images[1].path).toBe('b.jpg');
  });

  it('ignores non-image links', () => {
    const text = '![doc](document.pdf)';
    const images = findMarkdownImages(text);
    expect(images).toHaveLength(0);
  });

  it('ignores regular markdown links (not images)', () => {
    const text = '[click here](https://example.com)';
    const images = findMarkdownImages(text);
    expect(images).toHaveLength(0);
  });

  it('sets lineEnd to end of line containing the image', () => {
    const text = 'before\n![photo](image.png)\nafter';
    const images = findMarkdownImages(text);
    expect(images).toHaveLength(1);
    // lineEnd should point to the newline after the image line
    expect(images[0].lineEnd).toBe(text.indexOf('\nafter'));
  });

  it('sets lineEnd to text length for last line', () => {
    const text = '![photo](image.png)';
    const images = findMarkdownImages(text);
    expect(images).toHaveLength(1);
    expect(images[0].lineEnd).toBe(text.length);
  });

  it('finds image with empty alt text', () => {
    const text = '![](image.png)';
    const images = findMarkdownImages(text);
    expect(images).toHaveLength(1);
    expect(images[0].path).toBe('image.png');
  });
});

describe('resolveImageUrl', () => {
  it('prepends baseDir for relative paths', () => {
    const url = resolveImageUrl('image.png', '/Users/garaemon/notes');
    expect(url).toBe('local-image://localhost/Users/garaemon/notes/image.png');
  });

  it('prepends baseDir for dot-relative paths', () => {
    const url = resolveImageUrl('./images/photo.jpg', '/Users/garaemon/notes');
    expect(url).toBe('local-image://localhost/Users/garaemon/notes/./images/photo.jpg');
  });

  it('uses absolute path directly without baseDir', () => {
    const url = resolveImageUrl('/other/dir/image.png', '/Users/garaemon/notes');
    expect(url).toBe('local-image://localhost/other/dir/image.png');
  });

  it('passes through http URLs unchanged', () => {
    const url = resolveImageUrl('https://example.com/image.png', '/any/dir');
    expect(url).toBe('https://example.com/image.png');
  });

  it('passes through http URLs unchanged', () => {
    const url = resolveImageUrl('http://example.com/image.png', '/any/dir');
    expect(url).toBe('http://example.com/image.png');
  });

  it('encodes spaces in file paths', () => {
    const url = resolveImageUrl('my image.png', '/Users/garaemon/My Documents');
    expect(url).toBe('local-image://localhost/Users/garaemon/My%20Documents/my%20image.png');
  });

  it('encodes special characters in file paths', () => {
    const url = resolveImageUrl('photo (1).png', '/Users/garaemon/notes');
    expect(url).toBe('local-image://localhost/Users/garaemon/notes/photo%20(1).png');
  });

  it('preserves case in path components', () => {
    const url = resolveImageUrl('Image.PNG', '/Users/Garaemon/Notes');
    expect(url).toBe('local-image://localhost/Users/Garaemon/Notes/Image.PNG');
  });
});

describe('findOrgImages', () => {
  it('finds [[file:path]] syntax', () => {
    const text = '[[file:image.png]]';
    const images = findOrgImages(text);
    expect(images).toHaveLength(1);
    expect(images[0].path).toBe('image.png');
  });

  it('finds [[./path.ext]] syntax without file: prefix', () => {
    const text = '[[./images/photo.jpg]]';
    const images = findOrgImages(text);
    expect(images).toHaveLength(1);
    expect(images[0].path).toBe('./images/photo.jpg');
  });

  it('finds multiple org images', () => {
    const text = '[[file:a.png]]\n[[file:b.jpg]]';
    const images = findOrgImages(text);
    expect(images).toHaveLength(2);
    expect(images[0].path).toBe('a.png');
    expect(images[1].path).toBe('b.jpg');
  });

  it('ignores non-image file links', () => {
    const text = '[[file:document.pdf]]';
    const images = findOrgImages(text);
    expect(images).toHaveLength(0);
  });

  it('ignores URL links', () => {
    const text = '[[https://example.com]]';
    const images = findOrgImages(text);
    expect(images).toHaveLength(0);
  });

  it('sets lineEnd correctly', () => {
    const text = 'before\n[[file:image.png]]\nafter';
    const images = findOrgImages(text);
    expect(images).toHaveLength(1);
    expect(images[0].lineEnd).toBe(text.indexOf('\nafter'));
  });

  it('sets lineEnd to text length for last line', () => {
    const text = '[[file:image.png]]';
    const images = findOrgImages(text);
    expect(images).toHaveLength(1);
    expect(images[0].lineEnd).toBe(text.length);
  });
});
