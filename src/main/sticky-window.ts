import { BrowserWindow } from 'electron';
import { existsSync } from 'fs';
import { join } from 'path';
import { MIN_WINDOW_HEIGHT, MIN_WINDOW_WIDTH } from '../shared/constants';
import type { StickyNote } from '../shared/types';

// App icon lives in resources/ at the project root. On macOS the dock/app
// icon comes from the packaged bundle (icon.icns), but on Linux/Windows and in
// development the window icon must be set explicitly.
const ICON_PATH = join(__dirname, '../../resources/icon.png');

export function createStickyWindow(note: StickyNote): BrowserWindow {
  const win = new BrowserWindow({
    x: note.frame.x,
    y: note.frame.y,
    width: note.frame.width,
    height: note.frame.height,
    minWidth: MIN_WINDOW_WIDTH,
    minHeight: MIN_WINDOW_HEIGHT,
    ...(existsSync(ICON_PATH) ? { icon: ICON_PATH } : {}),
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
