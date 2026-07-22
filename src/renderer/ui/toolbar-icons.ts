/**
 * Icons used by the toolbar buttons.
 */

/** Emoji glyphs for toolbar buttons that render reliably as color emoji. */
export const TOOLBAR_ICONS = {
  save: '\u{1F4BE}',
  pin: '\u{1F4CC}',
  settings: '\u{2699}',
} as const;

/**
 * Inline SVG for the mouse-through button.
 *
 * The mouse emoji (U+1F5B1) is not usable here:
 * - Chromium in Electron >= 43 renders it invisible without VS16
 *   because the codepoint defaults to text presentation.
 * - With VS16, the Apple color emoji is nearly white, so it vanishes
 *   on light sticky backgrounds.
 * An inline SVG stroked with currentColor follows the per-note font
 * color, matching the monochrome gear glyph.
 */
export const MOUSE_THROUGH_ICON_SVG = `<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><rect x="6" y="3" width="12" height="18" rx="6"/><line x1="12" y1="7" x2="12" y2="11"/></svg>`;
