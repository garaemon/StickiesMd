export type FileFormat = 'markdown' | 'org';

export interface WindowFrame {
  x: number;
  y: number;
  width: number;
  height: number;
}

export interface StickyNote {
  id: string;
  filePath: string;
  backgroundColor: string;
  fontColor: string;
  opacity: number;
  frame: WindowFrame;
  isAlwaysOnTop: boolean;
  showLineNumbers: boolean;
}

export function detectFileFormat(filePath: string): FileFormat {
  return filePath.endsWith('.org') ? 'org' : 'markdown';
}
