import { app, protocol } from 'electron';
import { registerIpcHandlers } from './ipc-handlers';
import { buildAppMenu } from './menu';
import { createNewSticky, openFile, resetAllMouseThrough, restoreWindows } from './window-manager';

// Handle creating/removing shortcuts on Windows when installing/uninstalling.
if (process.platform === 'win32') {
  app.setAppUserModelId('com.stickiesmd.app');
}

app.whenReady().then(() => {
  // Register custom protocol for serving local images to renderer
  protocol.handle('local-image', (request) => {
    const filePath = decodeURIComponent(request.url.replace('local-image://', ''));
    return new Response(require('fs').readFileSync(filePath), {
      headers: { 'Content-Type': guessImageMimeType(filePath) },
    });
  });

  registerIpcHandlers();

  buildAppMenu({
    onNewSticky: createNewSticky,
    onOpenFile: openFile,
    onResetMouseThrough: resetAllMouseThrough,
  });

  restoreWindows();
});

app.on('activate', () => {
  const { BrowserWindow } = require('electron');
  if (BrowserWindow.getAllWindows().length === 0) {
    createNewSticky();
  }
});

app.on('window-all-closed', () => {
  // On macOS, keep app running even when all windows are closed
  if (process.platform !== 'darwin') {
    app.quit();
  }
});

function guessImageMimeType(filePath: string): string {
  const ext = filePath.split('.').pop()?.toLowerCase();
  const mimeTypes: Record<string, string> = {
    png: 'image/png',
    jpg: 'image/jpeg',
    jpeg: 'image/jpeg',
    gif: 'image/gif',
    svg: 'image/svg+xml',
    webp: 'image/webp',
    tiff: 'image/tiff',
    bmp: 'image/bmp',
  };
  return mimeTypes[ext ?? ''] ?? 'application/octet-stream';
}
