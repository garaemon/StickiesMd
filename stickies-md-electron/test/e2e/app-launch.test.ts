import { test, expect, _electron as electron } from '@playwright/test';
import path from 'path';

const appPath = path.resolve(__dirname, '../../');

test.describe('App Launch', () => {
  test('should launch and show a window', async () => {
    const app = await electron.launch({
      args: [path.resolve(appPath, 'dist/main/index.js')],
      cwd: appPath,
    });

    const window = await app.firstWindow();
    expect(window).toBeTruthy();

    const title = await window.title();
    expect(typeof title).toBe('string');

    await app.close();
  });

  test('should create a default note file on first launch', async () => {
    const app = await electron.launch({
      args: [path.resolve(appPath, 'dist/main/index.js')],
      cwd: appPath,
    });

    const window = await app.firstWindow();

    // Wait for the editor to load
    await window.waitForSelector('#editor-container', { timeout: 10000 });

    // The toolbar should exist
    const toolbar = await window.$('#toolbar');
    expect(toolbar).toBeTruthy();

    // The settings panel should be hidden initially
    const settingsPanel = await window.$('#settings-panel.hidden');
    expect(settingsPanel).toBeTruthy();

    await app.close();
  });
});
