/** IPC channels for communication between main and renderer processes. */

// Main -> Renderer
export const FILE_CHANGED = 'stickies:file-changed';
export const FOCUS_CHANGED = 'stickies:focus-changed';
export const NOTE_SETTINGS = 'stickies:note-settings';
export const TRIGGER_SAVE = 'stickies:trigger-save';
export const MOUSE_THROUGH_RESET = 'stickies:mouse-through-reset';

// Renderer -> Main
export const SAVE_CONTENT = 'stickies:save-content';
export const UPDATE_COLOR = 'stickies:update-color';
export const UPDATE_FONT_COLOR = 'stickies:update-font-color';
export const UPDATE_OPACITY = 'stickies:update-opacity';
export const TOGGLE_LINE_NUMBERS = 'stickies:toggle-line-numbers';
export const TOGGLE_ALWAYS_ON_TOP = 'stickies:toggle-always-on-top';
export const SET_MOUSE_THROUGH = 'stickies:set-mouse-through';
export const OPEN_FILE_DIALOG = 'stickies:open-file-dialog';
export const OPEN_URL = 'stickies:open-url';
export const GET_NOTE_SETTINGS = 'stickies:get-note-settings';
