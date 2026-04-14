import { app, BrowserWindow, protocol } from 'electron';
import { readFile } from 'fs/promises';
import { dirname, normalize, resolve } from 'path';
import { registerIpcHandlers } from './ipc-handlers';
import { buildAppMenu } from './menu';
import { createNewSticky, openFile, resetAllMouseThrough, restoreWindows } from './window-manager';

if (process.platform === 'win32') {
  app.setAppUserModelId('com.stickiesmd.app');
}

// Must be called before app.whenReady(). Without this registration,
// Chromium will not load <img> resources from the custom protocol.
// `standard: true` is required so that Chromium uses RFC 3986 URI parsing;
// without it, the first path component after // is treated as a hostname
// and lowercased, silently corrupting file paths (e.g. /Users → /users).
protocol.registerSchemesAsPrivileged([
  {
    scheme: 'local-image',
    privileges: {
      standard: true,
      secure: true,
      supportFetchAPI: true,
      stream: true,
    },
  },
]);

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
  protocol.handle('local-image', async (request: Request) => {
    // Use URL API for robust parsing. With standard: true the pathname
    // is correctly extracted regardless of slash count or encoding.
    const parsed = new URL(request.url);
    const filePath = normalize(resolve(decodeURIComponent(parsed.pathname)));

    // Defense-in-depth: reject paths with '..' segments even after normalization,
    // guards against future changes that might introduce double-decoding
    if (filePath.includes('..')) {
      return new Response('Forbidden', { status: 403 });
    }

    const fileDir = dirname(filePath);

    // Validate the file is within an allowed directory (enforce boundary with trailing /)
    // Both paths are normalized to prevent unicode NFC/NFD bypass on macOS
    let allowed = false;
    for (const dir of allowedImageDirs) {
      const normalizedDir = normalize(dir);
      if (fileDir === normalizedDir || fileDir.startsWith(normalizedDir + '/')) {
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

// Hand-rolled instead of a library (e.g., mime-types) to avoid adding a dependency
// for a fixed set of image formats that Chromium's <img> tag supports.
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
