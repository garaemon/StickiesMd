/**
 * Custom toolbar rendered inside each sticky note window.
 * Displays filename, save/pin/settings buttons.
 * Drag-enabled via CSS `-webkit-app-region: drag` on the container.
 *
 * Technical decision: UI components (this file and settings-panel.ts) use vanilla
 * TypeScript DOM manipulation instead of React/Vue/Svelte because:
 *   1. The UI surface is small (toolbar ~86 lines, settings panel ~147 lines)
 *   2. CodeMirror 6 manages its own DOM, so a framework adds boundary management
 *      burden with no benefit for the editor layer
 *   3. Avoids ~40KB gzip bundle overhead (React + ReactDOM) for a lightweight desktop app
 * If the UI grows significantly more complex (e.g., note list panel, search UI),
 * this decision should be revisited.
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
  private mouseThroughBtn: HTMLButtonElement;
  private isAlwaysOnTop = false;
  private isMouseThrough = false;
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

    // Mouse Through button
    this.mouseThroughBtn = document.createElement('button');
    this.mouseThroughBtn.className = 'toolbar-btn';
    this.mouseThroughBtn.textContent = '\u{1F5B1}'; // mouse
    this.mouseThroughBtn.title = 'Mouse Through';
    this.mouseThroughBtn.addEventListener('click', () => {
      window.electronAPI.setMouseThrough(!this.isMouseThrough);
    });
    this.mouseThroughBtn.addEventListener('mouseenter', () => {
      if (this.isMouseThrough) {
        window.electronAPI.pauseMouseThrough();
      }
    });
    this.mouseThroughBtn.addEventListener('mouseleave', () => {
      if (this.isMouseThrough) {
        window.electronAPI.resumeMouseThrough();
      }
    });
    buttonsDiv.appendChild(this.mouseThroughBtn);

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

  setMouseThrough(enabled: boolean): void {
    this.isMouseThrough = enabled;
    this.mouseThroughBtn.classList.toggle('active', enabled);
  }

  private updateTitle(): void {
    const prefix = this.isDirty ? '** ' : '';
    this.filenameEl.textContent = `${prefix}${this.filename}`;
  }
}
