import { describe, it, expect } from 'vitest';
import { EditorState, Text } from '@codemirror/state';
import { markdown, markdownLanguage } from '@codemirror/lang-markdown';
import { ensureSyntaxTree } from '@codemirror/language';
import {
  findMarkdownCodeBlocks,
  findOrgCodeBlocks,
} from '../../src/renderer/editor/code-block-decorations';

/** Create an EditorState with the markdown parser and ensure the tree is fully parsed. */
function mkMarkdownState(lines: string[]): EditorState {
  const state = EditorState.create({
    doc: lines.join('\n'),
    extensions: [markdown({ base: markdownLanguage })],
  });
  // Force a synchronous full parse so the tree is available.
  ensureSyntaxTree(state, state.doc.length, 5000);
  return state;
}

describe('findMarkdownCodeBlocks (syntax tree)', () => {
  it('detects a basic fenced code block with language', () => {
    const state = mkMarkdownState(['some text', '```javascript', 'const x = 1;', '```', 'more text']);
    const blocks = findMarkdownCodeBlocks(state);
    expect(blocks).toHaveLength(1);
    expect(blocks[0]).toEqual({ startLineNum: 2, endLineNum: 4, language: 'javascript' });
  });

  it('detects a fenced code block without language', () => {
    const state = mkMarkdownState(['```', 'plain code', '```']);
    const blocks = findMarkdownCodeBlocks(state);
    expect(blocks).toHaveLength(1);
    expect(blocks[0].startLineNum).toBe(1);
    expect(blocks[0].endLineNum).toBe(3);
    expect(blocks[0].language).toBe('');
  });

  it('detects tilde-fenced code blocks', () => {
    const state = mkMarkdownState(['~~~python', 'print("hi")', '~~~']);
    const blocks = findMarkdownCodeBlocks(state);
    expect(blocks).toHaveLength(1);
    expect(blocks[0]).toEqual({ startLineNum: 1, endLineNum: 3, language: 'python' });
  });

  it('detects multiple code blocks', () => {
    const state = mkMarkdownState([
      '```js',
      'let a = 1;',
      '```',
      '',
      '```python',
      'x = 2',
      '```',
    ]);
    const blocks = findMarkdownCodeBlocks(state);
    expect(blocks).toHaveLength(2);
    expect(blocks[0].language).toBe('js');
    expect(blocks[1].language).toBe('python');
  });

  it('requires closing fence to use same character', () => {
    const state = mkMarkdownState(['```js', 'code', '~~~']);
    const blocks = findMarkdownCodeBlocks(state);
    // The parser treats ~~~ inside a ``` block as content, not a closing fence.
    // The block will be unclosed and extend to the end of the document.
    expect(blocks).toHaveLength(1);
    expect(blocks[0].endLineNum).toBe(3); // extends to last line
  });

  it('extracts only first word as language', () => {
    const state = mkMarkdownState(['```js highlight', 'code', '```']);
    const blocks = findMarkdownCodeBlocks(state);
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
