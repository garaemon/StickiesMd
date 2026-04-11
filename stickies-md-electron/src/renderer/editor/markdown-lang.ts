import { markdown, markdownLanguage } from '@codemirror/lang-markdown';
import { HighlightStyle, syntaxHighlighting } from '@codemirror/language';
import { tags } from '@lezer/highlight';
import type { Extension } from '@codemirror/state';

function createMarkdownHighlightStyle(fontColor: string): HighlightStyle {
  return HighlightStyle.define([
    { tag: tags.heading1, fontSize: '26px', fontWeight: 'bold', color: fontColor },
    { tag: tags.heading2, fontSize: '22px', fontWeight: 'bold', color: fontColor },
    { tag: tags.heading3, fontSize: '18px', fontWeight: 'bold', color: fontColor },
    { tag: tags.heading4, fontSize: '16px', fontWeight: 'bold', color: fontColor },
    { tag: tags.heading5, fontSize: '14px', fontWeight: 'bold', color: fontColor },
    { tag: tags.heading6, fontSize: '14px', fontWeight: 'bold', color: fontColor },
    { tag: tags.strong, fontWeight: 'bold' },
    { tag: tags.emphasis, fontStyle: 'italic' },
    { tag: tags.strikethrough, textDecoration: 'line-through' },
    { tag: tags.monospace, class: 'cm-inline-code' },
    { tag: tags.url, class: 'cm-link' },
    { tag: tags.link, class: 'cm-link' },
    {
      tag: tags.processingInstruction,
      fontFamily: "'SF Mono', 'Menlo', 'Monaco', monospace",
      class: 'cm-code-block',
    },
    { tag: tags.content, color: fontColor },
  ]);
}

export function markdownExtensions(fontColor: string): Extension[] {
  return [
    markdown({ base: markdownLanguage }),
    syntaxHighlighting(createMarkdownHighlightStyle(fontColor)),
  ];
}
