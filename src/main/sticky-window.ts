import { BrowserWindow } from 'electron';
import { join } from 'path';
import { MIN_WINDOW_HEIGHT, MIN_WINDOW_WIDTH } from '../shared/constants';
import type { StickyNote } from '../shared/types';

export function createStickyWindow(note: StickyNote): BrowserWindow {
  const win = new BrowserWindow({
    x: note.frame.x,
    y: note.frame.y,
    width: note.frame.width,
    height: note.frame.height,
    minWidth: MIN_WINDOW_WIDTH,
    minHeight: MIN_WINDOW_HEIGHT,
    frame: false,
    titleBarStyle: 'hidden',
    trafficLightPosition: { x: 10, y: 15 },
    transparent: true,
    hasShadow: true,
    alwaysOnTop: note.isAlwaysOnTop,
    backgroundColor: '#00000000',
    resizable: true,
    movable: true,
    webPreferences: {
      preload: join(__dirname, '../preload/preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });

  win.setOpacity(note.opacity);

  if (note.isAlwaysOnTop) {
    win.setAlwaysOnTop(true, 'floating');
  }

  // Load the renderer HTML
  if (process.env.ELECTRON_RENDERER_URL) {
    win.loadURL(process.env.ELECTRON_RENDERER_URL);
  } else {
    win.loadFile(join(__dirname, '../renderer/index.html'));
  }

  return win;
}
