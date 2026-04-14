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
  private pinButton: HTMLButtonElement;
  private mouseThroughButton: HTMLButtonElement;
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
    const saveButton = document.createElement('button');
    saveButton.className = 'toolbar-btn';
    saveButton.textContent = '\u{1F4BE}'; // floppy disk
    saveButton.title = 'Save (Cmd+S)';
    saveButton.addEventListener('click', callbacks.onSave);
    buttonsDiv.appendChild(saveButton);

    // Pin button (always-on-top)
    this.pinButton = document.createElement('button');
    this.pinButton.className = 'toolbar-btn';
    this.pinButton.textContent = '\u{1F4CC}'; // pushpin
    this.pinButton.title = 'Always on Top';
    this.pinButton.addEventListener('click', () => {
      window.electronAPI.toggleAlwaysOnTop();
    });
    buttonsDiv.appendChild(this.pinButton);

    // Mouse Through button
    this.mouseThroughButton = document.createElement('button');
    this.mouseThroughButton.className = 'toolbar-btn';
    this.mouseThroughButton.textContent = '\u{1F5B1}'; // mouse
    this.mouseThroughButton.title = 'Mouse Through';
    this.mouseThroughButton.addEventListener('click', () => {
      window.electronAPI.setMouseThrough(!this.isMouseThrough);
    });
    this.mouseThroughButton.addEventListener('mouseenter', () => {
      if (this.isMouseThrough) {
        window.electronAPI.pauseMouseThrough();
      }
    });
    // Main process guard prevents re-enabling mouse-through if the user
    // clicked the button to disable it while hovering (state already false).
    this.mouseThroughButton.addEventListener('mouseleave', () => {
      if (this.isMouseThrough) {
        window.electronAPI.resumeMouseThrough();
      }
    });
    buttonsDiv.appendChild(this.mouseThroughButton);

    // Settings button
    const settingsButton = document.createElement('button');
    settingsButton.className = 'toolbar-btn';
    settingsButton.dataset.testid = 'settings-button';
    settingsButton.textContent = '\u2699'; // gear
    settingsButton.title = 'Settings';
    settingsButton.addEventListener('click', callbacks.onSettingsToggle);
    buttonsDiv.appendChild(settingsButton);

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
    this.pinButton.classList.toggle('active', onTop);
  }

  setMouseThrough(enabled: boolean): void {
    this.isMouseThrough = enabled;
    this.mouseThroughButton.classList.toggle('active', enabled);
  }

  private updateTitle(): void {
    const prefix = this.isDirty ? '** ' : '';
    this.filenameEl.textContent = `${prefix}${this.filename}`;
  }
}
