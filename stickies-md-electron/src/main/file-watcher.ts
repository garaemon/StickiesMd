import { watch, type FSWatcher } from 'chokidar';
import { readFile, writeFile, rename, unlink } from 'fs/promises';
import { dirname, join } from 'path';
import { FILE_WATCH_DEBOUNCE_MS } from '../shared/constants';

/**
 * Watches a file for external changes and provides atomic save.
 *
 * Uses `lastSavedContent` to implement save-reload loop prevention:
 * when we save content ourselves, the watcher will fire a change event,
 * but we skip the reload because the content matches what we just wrote.
 * This is the same pattern used in the original Swift NSFilePresenter implementation.
 */
export class FileWatcher {
  private watcher: FSWatcher | null = null;
  private lastSavedContent: string = '';
  private debounceTimer: ReturnType<typeof setTimeout> | null = null;
  private onExternalChange: (content: string) => void;

  constructor(
    public readonly filePath: string,
    onExternalChange: (content: string) => void,
  ) {
    this.onExternalChange = onExternalChange;
  }

  /** Start watching the file. Returns the initial file content. */
  async start(): Promise<string> {
    const content = await readFile(this.filePath, 'utf-8');
    this.lastSavedContent = content;

    this.watcher = watch(this.filePath, {
      persistent: true,
    });

    // Debounce change events to avoid rapid-fire reloads during multi-step writes
    this.watcher.on('change', () => {
      if (this.debounceTimer) clearTimeout(this.debounceTimer);
      this.debounceTimer = setTimeout(() => this.checkForChanges(), FILE_WATCH_DEBOUNCE_MS);
    });

    return content;
  }

  /**
   * Re-read the file and fire the callback if content differs from lastSavedContent.
   * Called by the chokidar watcher on 'change' events, and can be called directly
   * in tests to verify the loop prevention logic without relying on inotify.
   */
  async checkForChanges(): Promise<void> {
    try {
      const content = await readFile(this.filePath, 'utf-8');
      if (content !== this.lastSavedContent) {
        this.lastSavedContent = content;
        this.onExternalChange(content);
      }
    } catch {
      // File might be temporarily unavailable during write
    }
  }

  /**
   * Save content to the file atomically (write temp file, then rename).
   * Sets lastSavedContent before writing to prevent the watcher from
   * treating our own save as an external change.
   */
  async saveContent(content: string): Promise<void> {
    if (content === this.lastSavedContent) return;
    this.lastSavedContent = content;

    const tempPath = join(dirname(this.filePath), `.${Date.now()}.tmp`);
    try {
      await writeFile(tempPath, content, 'utf-8');
      await rename(tempPath, this.filePath);
    } catch (err) {
      // Clean up orphaned temp file on rename failure
      try {
        await unlink(tempPath);
      } catch {
        // Temp file may not exist if writeFile failed
      }
      throw err;
    }
  }

  async stop(): Promise<void> {
    if (this.debounceTimer) clearTimeout(this.debounceTimer);
    if (this.watcher) {
      await this.watcher.close();
      this.watcher = null;
    }
  }
}
