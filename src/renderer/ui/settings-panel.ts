/**
 * Settings panel popover for per-note appearance controls.
 * Changes propagate via electronAPI -> IPC -> main process -> store,
 * then back to the renderer via NOTE_SETTINGS callback.
 */
import { PALETTE } from '../../shared/constants';

export class SettingsPanel {
  private element: HTMLElement;
  private colorSwatches: HTMLElement[] = [];
  private opacitySlider: HTMLInputElement | null = null;
  private fontColorInput: HTMLInputElement | null = null;
  private lineNumbersCheckbox: HTMLInputElement | null = null;
  private mouseThroughCheckbox: HTMLInputElement | null = null;

  constructor(container: HTMLElement) {
    this.element = container;
    this.render();
  }

  private render(): void {
    this.element.innerHTML = '';

    // Background Color section
    const colorSection = this.createSection('Background Color');
    const palette = document.createElement('div');
    palette.className = 'color-palette';
    for (const color of PALETTE) {
      const swatch = document.createElement('div');
      swatch.className = 'color-swatch';
      swatch.style.backgroundColor = color;
      swatch.dataset.color = color;
      swatch.addEventListener('click', () => {
        window.electronAPI.updateColor(color);
      });
      palette.appendChild(swatch);
      this.colorSwatches.push(swatch);
    }
    colorSection.appendChild(palette);
    this.element.appendChild(colorSection);

    // Opacity section
    const opacitySection = this.createSection('Opacity');
    this.opacitySlider = document.createElement('input');
    this.opacitySlider.type = 'range';
    this.opacitySlider.className = 'opacity-slider';
    this.opacitySlider.min = '10';
    this.opacitySlider.max = '100';
    this.opacitySlider.value = '100';
    this.opacitySlider.addEventListener('input', () => {
      const value = parseInt(this.opacitySlider!.value, 10) / 100;
      window.electronAPI.updateOpacity(value);
    });
    opacitySection.appendChild(this.opacitySlider);
    this.element.appendChild(opacitySection);

    // Font Color section
    const fontColorSection = this.createSection('Font Color');
    this.fontColorInput = document.createElement('input');
    this.fontColorInput.type = 'color';
    this.fontColorInput.value = '#000000';
    this.fontColorInput.style.width = '100%';
    this.fontColorInput.style.height = '28px';
    this.fontColorInput.style.border = 'none';
    this.fontColorInput.style.cursor = 'pointer';
    this.fontColorInput.addEventListener('input', () => {
      window.electronAPI.updateFontColor(this.fontColorInput!.value);
    });
    fontColorSection.appendChild(this.fontColorInput);
    this.element.appendChild(fontColorSection);

    // Line Numbers toggle
    const { section: lineNumberSection, checkbox: lineNumberCheckbox } = this.createToggleRow(
      'Line Numbers',
      () => window.electronAPI.toggleLineNumbers(),
    );
    this.lineNumbersCheckbox = lineNumberCheckbox;
    this.element.appendChild(lineNumberSection);

    // Mouse Through toggle
    const { section: mouseThroughSection, checkbox: mouseThroughCheckbox } = this.createToggleRow(
      'Mouse Through',
      (checked) => window.electronAPI.setMouseThrough(checked),
    );
    this.mouseThroughCheckbox = mouseThroughCheckbox;
    this.element.appendChild(mouseThroughSection);

    // Open Another File button
    const openButton = document.createElement('button');
    openButton.className = 'settings-open-btn';
    openButton.textContent = 'Open Another File...';
    openButton.addEventListener('click', () => {
      window.electronAPI.openFileDialog();
    });
    this.element.appendChild(openButton);
  }

  private createToggleRow(
    labelText: string,
    onChange: (checked: boolean) => void,
  ): { section: HTMLElement; checkbox: HTMLInputElement } {
    const section = this.createSection('');
    const row = document.createElement('div');
    row.className = 'toggle-row';
    const label = document.createElement('span');
    label.textContent = labelText;
    row.appendChild(label);
    const toggleSwitch = document.createElement('label');
    toggleSwitch.className = 'toggle-switch';
    const checkbox = document.createElement('input');
    checkbox.type = 'checkbox';
    checkbox.addEventListener('change', () => onChange(checkbox.checked));
    const slider = document.createElement('span');
    slider.className = 'toggle-slider';
    toggleSwitch.appendChild(checkbox);
    toggleSwitch.appendChild(slider);
    row.appendChild(toggleSwitch);
    section.appendChild(row);
    return { section, checkbox };
  }

  private createSection(title: string): HTMLElement {
    const section = document.createElement('div');
    section.className = 'settings-section';
    if (title) {
      const label = document.createElement('div');
      label.className = 'settings-label';
      label.textContent = title;
      section.appendChild(label);
    }
    return section;
  }

  updateSelectedColor(color: string): void {
    for (const swatch of this.colorSwatches) {
      swatch.classList.toggle('selected', swatch.dataset.color === color);
    }
  }

  updateOpacity(opacity: number): void {
    if (this.opacitySlider) {
      this.opacitySlider.value = String(Math.round(opacity * 100));
    }
  }

  updateFontColor(color: string): void {
    if (this.fontColorInput) {
      this.fontColorInput.value = color;
    }
  }

  updateLineNumbers(show: boolean): void {
    if (this.lineNumbersCheckbox) {
      this.lineNumbersCheckbox.checked = show;
    }
  }

  updateMouseThrough(enabled: boolean): void {
    if (this.mouseThroughCheckbox) {
      this.mouseThroughCheckbox.checked = enabled;
    }
    if (enabled) {
      this.hide();
    }
  }

  toggle(): void {
    this.element.classList.toggle('hidden');
  }

  hide(): void {
    this.element.classList.add('hidden');
  }
}
