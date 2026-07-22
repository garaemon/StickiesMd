import { describe, it, expect } from 'vitest';
import { MOUSE_THROUGH_ICON_SVG } from '../../src/renderer/ui/toolbar-icons';

// The Apple color emoji for U+1F5B1 (three button mouse) is nearly
// white, so it is invisible on light sticky backgrounds. The toolbar
// renders an inline SVG instead, colored via currentColor so it
// follows the per-note font color like the gear glyph does.
describe('MOUSE_THROUGH_ICON_SVG', () => {
  it('should_be_inline_svg_markup', () => {
    expect(MOUSE_THROUGH_ICON_SVG.startsWith('<svg')).toBe(true);
  });

  it('should_follow_font_color_via_current_color', () => {
    expect(MOUSE_THROUGH_ICON_SVG).toContain('currentColor');
  });
});
