export type FileFormat = 'markdown' | 'org';

/** Persisted window position and size. */
export interface WindowFrame {
  x: number;
  y: number;
  width: number;
  height: number;
}

/**
 * A sticky note's metadata. Persisted in electron-store.
 * The actual text content lives in the .md/.org file at `filePath`.
 */
export interface StickyNote {
  id: string;
  filePath: string;
  backgroundColor: string;
  fontColor: string;
  /** Window opacity, 0.1 to 1.0. */
  opacity: number;
  /** Persisted window position and size, restored on next launch. */
  frame: WindowFrame;
  isAlwaysOnTop: boolean;
  showLineNumbers: boolean;
}

/** Detect file format from extension. Non-.org files default to markdown. */
export function detectFileFormat(filePath: string): FileFormat {
  return filePath.endsWith('.org') ? 'org' : 'markdown';
}
