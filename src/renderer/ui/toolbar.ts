/**
 * Custom toolbar rendered inside each sticky note window.
 * Displays filename, save/pin/settings buttons.
 * Drag-enabled via CSS `-webkit-app-region: drag` on the container.
 */

/** Extract filename from a POSIX path (renderer has no Node path module). */
function getBasename(filePath: string): string {
  const lastSlash = filePath.lastIndexOf('/');
  return lastSlash === -1 ? filePath : filePath.substring(lastSlash + 1);
}

export interface ToolbarCallbacks {
  onSettingsToggle: () => void;
  onSave: () => void;
}

/**
 * Custom toolbar UI component for a sticky note window.
 * Displays the filename (with `** ` dirty indicator), save/pin/settings buttons.
 * The toolbar area is draggable to allow window repositioning.
 */
export class Toolbar {
  private element: HTMLElement;
  private filenameEl: HTMLElement;
  private pinBtn: HTMLButtonElement;
  private isAlwaysOnTop = false;
  private isDirty = false;
  private filename = '';

  constructor(container: HTMLElement, callbacks: ToolbarCallbacks) {
    this.element = container;
    this.element.innerHTML = '';

    this.filenameEl = document.createElement('span');
    this.filenameEl.className = 'toolbar-filename';
    this.element.appendChild(this.filenameEl);

    const buttonsDiv = document.createElement('div');
    buttonsDiv.className = 'toolbar-buttons';

    // Save button
    const saveBtn = document.createElement('button');
    saveBtn.className = 'toolbar-btn';
    saveBtn.textContent = '\u{1F4BE}'; // floppy disk
    saveBtn.title = 'Save (Cmd+S)';
    saveBtn.addEventListener('click', callbacks.onSave);
    buttonsDiv.appendChild(saveBtn);

    // Pin button (always-on-top)
    this.pinBtn = document.createElement('button');
    this.pinBtn.className = 'toolbar-btn';
    this.pinBtn.textContent = '\u{1F4CC}'; // pushpin
    this.pinBtn.title = 'Always on Top';
    this.pinBtn.addEventListener('click', () => {
      window.electronAPI.toggleAlwaysOnTop();
    });
    buttonsDiv.appendChild(this.pinBtn);

    // Settings button
    const settingsBtn = document.createElement('button');
    settingsBtn.className = 'toolbar-btn';
    settingsBtn.dataset.testid = 'settings-button';
    settingsBtn.textContent = '\u2699'; // gear
    settingsBtn.title = 'Settings';
    settingsBtn.addEventListener('click', callbacks.onSettingsToggle);
    buttonsDiv.appendChild(settingsBtn);

    this.element.appendChild(buttonsDiv);
  }

  setFilePath(filePath: string): void {
    this.filename = getBasename(filePath);
    this.updateTitle();
  }

  setDirty(dirty: boolean): void {
    this.isDirty = dirty;
    this.updateTitle();
  }

  setAlwaysOnTop(onTop: boolean): void {
    this.isAlwaysOnTop = onTop;
    this.pinBtn.classList.toggle('active', onTop);
  }

  private updateTitle(): void {
    const prefix = this.isDirty ? '** ' : '';
    this.filenameEl.textContent = `${prefix}${this.filename}`;
  }
}
