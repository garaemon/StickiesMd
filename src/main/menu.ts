import { app, BrowserWindow, dialog, Menu } from 'electron';
import * as IPC from '../shared/ipc-channels';

/**
 * Build and set the application menu.
 * Callbacks are injected to avoid circular imports with window-manager.
 */
export function buildAppMenu(callbacks: {
  onNewSticky: () => void;
  onOpenFile: () => void;
  onResetMouseThrough: () => void;
}): void {
  const template: Electron.MenuItemConstructorOptions[] = [
    {
      label: app.name,
      submenu: [
        { role: 'about' },
        { type: 'separator' },
        { role: 'hide' },
        { role: 'hideOthers' },
        { role: 'unhide' },
        { type: 'separator' },
        { role: 'quit' },
      ],
    },
    {
      label: 'File',
      submenu: [
        {
          label: 'New Sticky',
          accelerator: 'CmdOrCtrl+N',
          click: callbacks.onNewSticky,
        },
        {
          label: 'Open...',
          accelerator: 'CmdOrCtrl+O',
          click: callbacks.onOpenFile,
        },
        { type: 'separator' },
        {
          label: 'Save',
          accelerator: 'CmdOrCtrl+S',
          click: () => {
            const win = BrowserWindow.getFocusedWindow();
            if (win) {
              win.webContents.send(IPC.TRIGGER_SAVE);
            }
          },
        },
      ],
    },
    {
      label: 'Edit',
      submenu: [
        { role: 'undo' },
        { role: 'redo' },
        { type: 'separator' },
        { role: 'cut' },
        { role: 'copy' },
        { role: 'paste' },
        { role: 'selectAll' },
      ],
    },
    {
      label: 'Window',
      submenu: [
        { role: 'minimize' },
        { role: 'close' },
        { type: 'separator' },
        {
          label: 'Reset Mouse-Through',
          click: callbacks.onResetMouseThrough,
        },
      ],
    },
  ];

  const menu = Menu.buildFromTemplate(template);
  Menu.setApplicationMenu(menu);
}

export async function showOpenDialog(): Promise<string | undefined> {
  const result = await dialog.showOpenDialog({
    properties: ['openFile'],
    filters: [
      { name: 'Documents', extensions: ['md', 'org', 'txt'] },
      { name: 'Markdown', extensions: ['md'] },
      { name: 'Org-mode', extensions: ['org'] },
      { name: 'All Files', extensions: ['*'] },
    ],
  });

  if (result.canceled || result.filePaths.length === 0) {
    return undefined;
  }
  return result.filePaths[0];
}
