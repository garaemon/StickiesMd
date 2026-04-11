import { watch, type FSWatcher } from 'chokidar';
import { readFile, writeFile, rename } from 'fs/promises';
import { dirname, join } from 'path';
import { FILE_WATCH_DEBOUNCE_MS } from '../shared/constants';

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

  async start(): Promise<string> {
    const content = await readFile(this.filePath, 'utf-8');
    this.lastSavedContent = content;

    this.watcher = watch(this.filePath, {
      persistent: true,
      awaitWriteFinish: {
        stabilityThreshold: FILE_WATCH_DEBOUNCE_MS,
      },
    });

    this.watcher.on('change', () => {
      if (this.debounceTimer) clearTimeout(this.debounceTimer);
      this.debounceTimer = setTimeout(() => this.handleChange(), FILE_WATCH_DEBOUNCE_MS);
    });

    return content;
  }

  private async handleChange(): Promise<void> {
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

  async saveContent(content: string): Promise<void> {
    if (content === this.lastSavedContent) return;
    this.lastSavedContent = content;

    // Atomic write: write to temp file, then rename
    const tempPath = join(dirname(this.filePath), `.${Date.now()}.tmp`);
    await writeFile(tempPath, content, 'utf-8');
    await rename(tempPath, this.filePath);
  }

  async stop(): Promise<void> {
    if (this.debounceTimer) clearTimeout(this.debounceTimer);
    if (this.watcher) {
      await this.watcher.close();
      this.watcher = null;
    }
  }
}
