/**
 * Mouse-through state management logic.
 *
 * Mouse-through allows clicks to pass through the window to applications below.
 * When enabled, Electron's setIgnoreMouseEvents(true, { forward: true }) is used
 * so that mousemove events are still forwarded to the renderer -- this lets the
 * toolbar button detect mouseenter/mouseleave to temporarily pause mouse-through
 * (so the user can click the button to disable it).
 *
 * Extracted as pure functions to enable unit testing without Electron mocks.
 */

export interface MouseThroughState {
  isMouseThrough: boolean;
}

export interface SetMouseThroughResult {
  ignoreMouseEvents: boolean;
  forward: boolean;
}

/** Update the mouse-through state and return the Electron side effects to apply. */
export function applySetMouseThrough(
  state: MouseThroughState,
  enabled: boolean,
): SetMouseThroughResult {
  state.isMouseThrough = enabled;
  if (enabled) {
    return { ignoreMouseEvents: true, forward: true };
  }
  return { ignoreMouseEvents: false, forward: false };
}

/**
 * Determine whether a pause request should be honored.
 * Only pauses when mouse-through is currently active.
 */
export function shouldPauseMouseThrough(state: MouseThroughState): boolean {
  return state.isMouseThrough;
}

/**
 * Determine whether a resume request should be honored.
 * Only resumes when mouse-through is currently active.
 */
export function shouldResumeMouseThrough(state: MouseThroughState): boolean {
  return state.isMouseThrough;
}
