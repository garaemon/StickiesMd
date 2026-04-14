/**
 * Mouse-through state management logic.
 *
 * Extracted as pure functions to enable unit testing without Electron mocks.
 * Each function returns a description of the side effects to apply,
 * rather than performing them directly.
 */

export interface MouseThroughState {
  isMouseThrough: boolean;
}

export interface SetMouseThroughResult {
  shouldUpdate: boolean;
  ignoreMouseEvents: boolean;
  forward: boolean;
}

/**
 * Determine the side effects for enabling/disabling mouse-through.
 * Returns null if the request should be ignored.
 */
export function computeSetMouseThrough(
  state: MouseThroughState,
  enabled: boolean,
): SetMouseThroughResult {
  state.isMouseThrough = enabled;
  if (enabled) {
    return { shouldUpdate: true, ignoreMouseEvents: true, forward: true };
  }
  return { shouldUpdate: true, ignoreMouseEvents: false, forward: false };
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
