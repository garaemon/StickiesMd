export const PALETTE = [
  '#FFF9C4', // Yellow
  '#E1F5FE', // Blue
  '#F1F8E9', // Green
  '#FCE4EC', // Pink
  '#F3E5F5', // Purple
  '#F5F5F5', // Gray
] as const;

export const FONT_SIZES = {
  h1: 26,
  h2: 22,
  h3: 18,
  h4: 16,
  h5: 14,
  h6: 14,
  standard: 14,
} as const;

export const DEFAULT_FONT_COLOR = '#000000';
export const DEFAULT_OPACITY = 1.0;
export const DEFAULT_FRAME = { x: 100, y: 100, width: 300, height: 200 };
export const MIN_WINDOW_WIDTH = 200;
export const MIN_WINDOW_HEIGHT = 150;

export const SAVE_DEBOUNCE_MS = 300;
export const FILE_WATCH_DEBOUNCE_MS = 100;

export function randomPaletteColor(): string {
  return PALETTE[Math.floor(Math.random() * PALETTE.length)];
}
