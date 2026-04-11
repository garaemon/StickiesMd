import { markdown, markdownLanguage } from '@codemirror/lang-markdown';
import { HighlightStyle, syntaxHighlighting } from '@codemirror/language';
import { tags } from '@lezer/highlight';
import type { Extension } from '@codemirror/state';
import { FONT_SIZES } from '../../shared/constants';

function createMarkdownHighlightStyle(fontColor: string): HighlightStyle {
  return HighlightStyle.define([
    { tag: tags.heading1, fontSize: `${FONT_SIZES.h1}px`, fontWeight: 'bold', color: fontColor },
    { tag: tags.heading2, fontSize: `${FONT_SIZES.h2}px`, fontWeight: 'bold', color: fontColor },
    { tag: tags.heading3, fontSize: `${FONT_SIZES.h3}px`, fontWeight: 'bold', color: fontColor },
    { tag: tags.heading4, fontSize: `${FONT_SIZES.h4}px`, fontWeight: 'bold', color: fontColor },
    { tag: tags.heading5, fontSize: `${FONT_SIZES.h5}px`, fontWeight: 'bold', color: fontColor },
    { tag: tags.heading6, fontSize: `${FONT_SIZES.h6}px`, fontWeight: 'bold', color: fontColor },
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
