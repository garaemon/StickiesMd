import { test, expect } from '@playwright/test';
import { _electron as electron } from 'playwright';
import { resolve } from 'path';

const appPath = resolve(__dirname, '../../');

test.describe('Settings Panel', () => {
  test('should toggle settings panel on gear button click', async () => {
    const app = await electron.launch({
      args: [resolve(appPath, 'dist/main/index.js')],
      cwd: appPath,
    });

    const window = await app.firstWindow();
    await window.waitForSelector('#editor-container', { timeout: 10000 });

    // Settings panel should be hidden initially
    const hiddenPanel = await window.$('#settings-panel.hidden');
    expect(hiddenPanel).toBeTruthy();

    // Click the settings (gear) button - it's the last toolbar button
    const gearButton = await window.$('#toolbar .toolbar-btn:last-child');
    if (gearButton) {
      await gearButton.click();

      // Settings panel should now be visible
      const visiblePanel = await window.$('#settings-panel:not(.hidden)');
      expect(visiblePanel).toBeTruthy();
    }

    await app.close();
  });

  test('settings panel should have color palette with 6 colors', async () => {
    const app = await electron.launch({
      args: [resolve(appPath, 'dist/main/index.js')],
      cwd: appPath,
    });

    const window = await app.firstWindow();
    await window.waitForSelector('#editor-container', { timeout: 10000 });

    // Open settings
    const gearButton = await window.$('#toolbar .toolbar-btn:last-child');
    if (gearButton) {
      await gearButton.click();
      await window.waitForSelector('#settings-panel:not(.hidden)');

      // Should have 6 color swatches
      const swatches = await window.$$('.color-swatch');
      expect(swatches.length).toBe(6);
    }

    await app.close();
  });
});
