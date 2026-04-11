import { describe, it, expect } from 'vitest';
import {
  findBareUrls,
  findMarkdownLinks,
  findOrgStructuredLinks,
} from '../../src/renderer/editor/link-handler';

describe('findBareUrls', () => {
  it('detects http URLs', () => {
    const urls = findBareUrls('Visit http://example.com for info');
    expect(urls).toHaveLength(1);
    expect(urls[0].url).toBe('http://example.com');
  });

  it('detects https URLs', () => {
    const urls = findBareUrls('Visit https://example.com/path for info');
    expect(urls).toHaveLength(1);
    expect(urls[0].url).toBe('https://example.com/path');
  });

  it('does not include trailing punctuation', () => {
    const urls = findBareUrls('See https://example.com.');
    expect(urls[0].url).toBe('https://example.com');
  });

  it('detects multiple URLs', () => {
    const urls = findBareUrls('http://a.com and https://b.com');
    expect(urls).toHaveLength(2);
  });

  it('returns correct positions', () => {
    const text = 'xx https://example.com yy';
    const urls = findBareUrls(text);
    expect(text.slice(urls[0].from, urls[0].to)).toBe('https://example.com');
  });

  it('returns empty for text without URLs', () => {
    expect(findBareUrls('no urls here')).toHaveLength(0);
  });
});

describe('findMarkdownLinks', () => {
  it('detects [text](url) links', () => {
    const links = findMarkdownLinks('Click [here](https://example.com) now');
    expect(links).toHaveLength(1);
    expect(links[0].url).toBe('https://example.com');
  });

  it('detects multiple markdown links', () => {
    const links = findMarkdownLinks('[a](http://a.com) [b](http://b.com)');
    expect(links).toHaveLength(2);
  });

  it('returns empty for plain text', () => {
    expect(findMarkdownLinks('no links')).toHaveLength(0);
  });
});

describe('findOrgStructuredLinks', () => {
  it('detects [[url]] links', () => {
    const links = findOrgStructuredLinks('See [[https://example.com]]');
    expect(links).toHaveLength(1);
    expect(links[0].url).toBe('https://example.com');
  });

  it('detects [[url][desc]] links', () => {
    const links = findOrgStructuredLinks('See [[https://example.com][Example]]');
    expect(links).toHaveLength(1);
    expect(links[0].url).toBe('https://example.com');
  });

  it('ignores non-http links (file: links)', () => {
    const links = findOrgStructuredLinks('See [[file:image.png]]');
    expect(links).toHaveLength(0);
  });

  it('detects multiple org links', () => {
    const links = findOrgStructuredLinks('[[https://a.com]] [[https://b.com]]');
    expect(links).toHaveLength(2);
  });
});
