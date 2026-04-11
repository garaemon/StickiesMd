import { app, BrowserWindow, protocol } from 'electron';
import { readFile } from 'fs/promises';
import { dirname, resolve } from 'path';
import { registerIpcHandlers } from './ipc-handlers';
import { buildAppMenu } from './menu';
import { createNewSticky, openFile, resetAllMouseThrough, restoreWindows } from './window-manager';

if (process.platform === 'win32') {
  app.setAppUserModelId('com.stickiesmd.app');
}

/**
 * Allowed base directories for the local-image:// protocol.
 * Updated when windows are created. Prevents path traversal attacks
 * by ensuring only files within note directories can be served.
 */
const allowedImageDirs = new Set<string>();

/** Register a directory as allowed for local-image:// serving. */
export function allowImageDir(dir: string): void {
  allowedImageDirs.add(dir);
}

app.whenReady().then(() => {
  // Custom protocol for serving local images to the renderer.
  // The renderer cannot access file:// URLs due to Chromium security restrictions,
  // so we serve images through this protocol with path validation.
  protocol.handle('local-image', async (request) => {
    const filePath = resolve(decodeURIComponent(request.url.replace('local-image://', '')));
    const fileDir = dirname(filePath);

    // Validate the file is within an allowed directory
    let allowed = false;
    for (const dir of allowedImageDirs) {
      if (fileDir.startsWith(dir)) {
        allowed = true;
        break;
      }
    }
    if (!allowed) {
      return new Response('Forbidden', { status: 403 });
    }

    try {
      const data = await readFile(filePath);
      return new Response(data, {
        headers: { 'Content-Type': guessImageMimeType(filePath) },
      });
    } catch {
      return new Response('Not Found', { status: 404 });
    }
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
  if (BrowserWindow.getAllWindows().length === 0) {
    createNewSticky();
  }
});

app.on('window-all-closed', () => {
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
