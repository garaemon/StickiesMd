import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { writeFileSync, readFileSync, mkdtempSync, rmSync } from 'fs';
import { join } from 'path';
import { tmpdir } from 'os';
import { FileWatcher } from '../../src/main/file-watcher';

describe('FileWatcher', () => {
  let tempDir: string;
  let testFile: string;

  beforeEach(() => {
    tempDir = mkdtempSync(join(tmpdir(), 'stickies-test-'));
    testFile = join(tempDir, 'test.md');
    writeFileSync(testFile, 'initial content', 'utf-8');
  });

  afterEach(() => {
    rmSync(tempDir, { recursive: true, force: true });
  });

  it('reads initial content on start', async () => {
    const watcher = new FileWatcher(testFile, () => {});
    const content = await watcher.start();
    expect(content).toBe('initial content');
    await watcher.stop();
  });

  it('saves content atomically', async () => {
    const watcher = new FileWatcher(testFile, () => {});
    await watcher.start();
    await watcher.saveContent('new content');
    const saved = readFileSync(testFile, 'utf-8');
    expect(saved).toBe('new content');
    await watcher.stop();
  });

  it('does not save identical content', async () => {
    const watcher = new FileWatcher(testFile, () => {});
    await watcher.start();
    // Save same content as initial — should be a no-op
    await watcher.saveContent('initial content');
    await watcher.stop();
  });

  it('prevents reload loop by comparing against lastSavedContent', async () => {
    // This tests the core loop prevention logic:
    // After saveContent(), if we re-read the file, the callback should NOT fire
    // because lastSavedContent matches the file on disk.
    let changeCount = 0;
    const watcher = new FileWatcher(testFile, () => {
      changeCount++;
    });
    await watcher.start();

    // Save new content through the watcher (sets lastSavedContent)
    await watcher.saveContent('saved by us');

    // Verify file was actually written
    expect(readFileSync(testFile, 'utf-8')).toBe('saved by us');

    // Call checkForChanges() which re-reads the file — since content matches
    // lastSavedContent, callback should NOT fire (loop prevention)
    await watcher.checkForChanges();
    expect(changeCount).toBe(0);

    // Now simulate an external change — write different content directly
    writeFileSync(testFile, 'external edit', 'utf-8');

    // checkForChanges() should detect the difference and fire callback
    await watcher.checkForChanges();
    expect(changeCount).toBe(1);

    await watcher.stop();
  });

  it('stores file path', () => {
    const watcher = new FileWatcher(testFile, () => {});
    expect(watcher.filePath).toBe(testFile);
  });
});
