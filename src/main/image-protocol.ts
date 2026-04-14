/**
 * Pure utility functions for the local-image:// protocol handler.
 *
 * Extracted from index.ts so they can be unit-tested without
 * pulling in Electron or electron-store dependencies.
 *
 * The local-image:// protocol works in three parts:
 *  1. The scheme is registered with `standard: true` so Chromium uses
 *     RFC 3986 URI parsing (see index.ts).
 *  2. The renderer builds URLs as `local-image://localhost/<absolute-path>`
 *     (see resolveImageUrl in image-widgets.ts). Using `localhost` as the
 *     host prevents Chromium from consuming the first path component
 *     (e.g. /Users) as a hostname and lowercasing it.
 *  3. The protocol handler in index.ts extracts the pathname via
 *     `new URL(request.url).pathname`, which strips the host and yields
 *     the original absolute file path.
 */
import { dirname, normalize, sep } from 'path';

/**
 * Check whether a file path is allowed to be served by the local-image:// protocol.
 * Returns true if the file's directory matches or is a subdirectory of an allowed dir.
 */
export function isPathAllowed(filePath: string, allowedDirs: Iterable<string>): boolean {
  if (filePath.includes('..')) {
    return false;
  }
  const fileDir = dirname(filePath);
  for (const dir of allowedDirs) {
    // Strip trailing separator so '/notes/' and '/notes' match identically
    const normalizedDir = normalize(dir).replace(new RegExp(`${sep === '\\' ? '\\\\' : sep}$`), '');
    if (fileDir === normalizedDir || fileDir.startsWith(normalizedDir + sep)) {
      return true;
    }
  }
  return false;
}

/**
 * Guess the MIME type for an image file based on its extension.
 * Hand-rolled instead of a library to avoid adding a dependency
 * for a fixed set of image formats that Chromium's <img> tag supports.
 */
export function guessImageMimeType(filePath: string): string {
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
