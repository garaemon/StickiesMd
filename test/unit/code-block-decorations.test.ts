import { describe, it, expect } from 'vitest';
import { Text } from '@codemirror/state';
import {
  findMarkdownCodeBlocks,
  findOrgCodeBlocks,
} from '../../src/renderer/editor/code-block-decorations';

describe('findMarkdownCodeBlocks', () => {
  it('detects a basic fenced code block with language', () => {
    const doc = Text.of(['some text', '```javascript', 'const x = 1;', '```', 'more text']);
    const blocks = findMarkdownCodeBlocks(doc);
    expect(blocks).toHaveLength(1);
    expect(blocks[0]).toEqual({ startLineNum: 2, endLineNum: 4, language: 'javascript' });
  });

  it('detects a fenced code block without language', () => {
    const doc = Text.of(['```', 'plain code', '```']);
    const blocks = findMarkdownCodeBlocks(doc);
    expect(blocks).toHaveLength(1);
    expect(blocks[0]).toEqual({ startLineNum: 1, endLineNum: 3, language: '' });
  });

  it('detects tilde-fenced code blocks', () => {
    const doc = Text.of(['~~~python', 'print("hi")', '~~~']);
    const blocks = findMarkdownCodeBlocks(doc);
    expect(blocks).toHaveLength(1);
    expect(blocks[0]).toEqual({ startLineNum: 1, endLineNum: 3, language: 'python' });
  });

  it('detects multiple code blocks', () => {
    const doc = Text.of([
      '```js',
      'let a = 1;',
      '```',
      '',
      '```python',
      'x = 2',
      '```',
    ]);
    const blocks = findMarkdownCodeBlocks(doc);
    expect(blocks).toHaveLength(2);
    expect(blocks[0].language).toBe('js');
    expect(blocks[1].language).toBe('python');
  });

  it('handles indented opening fence', () => {
    const doc = Text.of(['  ```sh', '  echo hi', '  ```']);
    const blocks = findMarkdownCodeBlocks(doc);
    expect(blocks).toHaveLength(1);
    expect(blocks[0].language).toBe('sh');
  });

  it('requires closing fence to use same character', () => {
    const doc = Text.of(['```js', 'code', '~~~']);
    const blocks = findMarkdownCodeBlocks(doc);
    expect(blocks).toHaveLength(0);
  });

  it('requires closing fence to have at least as many characters', () => {
    const doc = Text.of(['````js', 'code', '```']);
    const blocks = findMarkdownCodeBlocks(doc);
    expect(blocks).toHaveLength(0);
  });

  it('accepts closing fence with more characters', () => {
    const doc = Text.of(['```js', 'code', '`````']);
    const blocks = findMarkdownCodeBlocks(doc);
    expect(blocks).toHaveLength(1);
  });

  it('ignores unclosed code blocks', () => {
    const doc = Text.of(['```js', 'no closing fence']);
    const blocks = findMarkdownCodeBlocks(doc);
    expect(blocks).toHaveLength(0);
  });

  it('extracts only first word as language', () => {
    const doc = Text.of(['```js highlight', 'code', '```']);
    const blocks = findMarkdownCodeBlocks(doc);
    expect(blocks).toHaveLength(1);
    expect(blocks[0].language).toBe('js');
  });
});

describe('findOrgCodeBlocks', () => {
  it('detects a basic code block with language', () => {
    const doc = Text.of(['text', '#+BEGIN_SRC python', 'print("hi")', '#+END_SRC', 'more']);
    const blocks = findOrgCodeBlocks(doc);
    expect(blocks).toHaveLength(1);
    expect(blocks[0]).toEqual({ startLineNum: 2, endLineNum: 4, language: 'python' });
  });

  it('detects a code block without language', () => {
    const doc = Text.of(['#+BEGIN_SRC', 'code', '#+END_SRC']);
    const blocks = findOrgCodeBlocks(doc);
    expect(blocks).toHaveLength(1);
    expect(blocks[0]).toEqual({ startLineNum: 1, endLineNum: 3, language: '' });
  });

  it('is case-insensitive for markers', () => {
    const doc = Text.of(['#+begin_src shell', 'echo hi', '#+end_src']);
    const blocks = findOrgCodeBlocks(doc);
    expect(blocks).toHaveLength(1);
    expect(blocks[0].language).toBe('shell');
  });

  it('detects multiple code blocks', () => {
    const doc = Text.of([
      '#+BEGIN_SRC js',
      'let a = 1;',
      '#+END_SRC',
      '',
      '#+BEGIN_SRC ruby',
      'x = 2',
      '#+END_SRC',
    ]);
    const blocks = findOrgCodeBlocks(doc);
    expect(blocks).toHaveLength(2);
    expect(blocks[0].language).toBe('js');
    expect(blocks[1].language).toBe('ruby');
  });

  it('ignores unclosed code blocks', () => {
    const doc = Text.of(['#+BEGIN_SRC python', 'no end']);
    const blocks = findOrgCodeBlocks(doc);
    expect(blocks).toHaveLength(0);
  });

  it('handles #+END_SRC with trailing text', () => {
    const doc = Text.of(['#+BEGIN_SRC sh', 'echo', '#+END_SRC extra']);
    const blocks = findOrgCodeBlocks(doc);
    expect(blocks).toHaveLength(1);
  });
});
