import { describe, it, expect } from 'vitest';
import {
  applySetMouseThrough,
  shouldPauseMouseThrough,
  shouldResumeMouseThrough,
} from '../../src/main/mouse-through';
import type { MouseThroughState } from '../../src/main/mouse-through';

function createState(isMouseThrough = false): MouseThroughState {
  return { isMouseThrough };
}

describe('mouse-through state management', () => {
  describe('applySetMouseThrough', () => {
    it('should enable mouse-through with forward flag', () => {
      const state = createState(false);
      const result = applySetMouseThrough(state, true);
      expect(result.ignoreMouseEvents).toBe(true);
      expect(result.forward).toBe(true);
      expect(state.isMouseThrough).toBe(true);
    });

    it('should disable mouse-through without forward flag', () => {
      const state = createState(true);
      const result = applySetMouseThrough(state, false);
      expect(result.ignoreMouseEvents).toBe(false);
      expect(result.forward).toBe(false);
      expect(state.isMouseThrough).toBe(false);
    });

    it('should update state through full cycle: enable -> disable', () => {
      const state = createState(false);
      applySetMouseThrough(state, true);
      expect(state.isMouseThrough).toBe(true);
      applySetMouseThrough(state, false);
      expect(state.isMouseThrough).toBe(false);
    });

    it('should handle enabling when already enabled', () => {
      const state = createState(true);
      const result = applySetMouseThrough(state, true);
      expect(result.ignoreMouseEvents).toBe(true);
      expect(result.forward).toBe(true);
      expect(state.isMouseThrough).toBe(true);
    });

    it('should handle disabling when already disabled', () => {
      const state = createState(false);
      const result = applySetMouseThrough(state, false);
      expect(result.ignoreMouseEvents).toBe(false);
      expect(result.forward).toBe(false);
      expect(state.isMouseThrough).toBe(false);
    });
  });

  describe('shouldPauseMouseThrough', () => {
    it('should allow pause when mouse-through is active', () => {
      const state = createState(true);
      expect(shouldPauseMouseThrough(state)).toBe(true);
    });

    it('should reject pause when mouse-through is inactive', () => {
      const state = createState(false);
      expect(shouldPauseMouseThrough(state)).toBe(false);
    });
  });

  describe('shouldResumeMouseThrough', () => {
    it('should allow resume when mouse-through is active', () => {
      const state = createState(true);
      expect(shouldResumeMouseThrough(state)).toBe(true);
    });

    it('should reject resume when mouse-through is inactive', () => {
      const state = createState(false);
      expect(shouldResumeMouseThrough(state)).toBe(false);
    });
  });

  describe('state transitions', () => {
    it('should handle enable -> pause -> resume -> disable cycle', () => {
      const state = createState(false);

      applySetMouseThrough(state, true);
      expect(state.isMouseThrough).toBe(true);

      expect(shouldPauseMouseThrough(state)).toBe(true);
      expect(shouldResumeMouseThrough(state)).toBe(true);

      applySetMouseThrough(state, false);
      expect(state.isMouseThrough).toBe(false);
      expect(shouldPauseMouseThrough(state)).toBe(false);
      expect(shouldResumeMouseThrough(state)).toBe(false);
    });

    it('should prevent resume after disable during hover', () => {
      const state = createState(false);

      applySetMouseThrough(state, true);
      expect(shouldPauseMouseThrough(state)).toBe(true);

      // User clicks button to disable while hovering
      applySetMouseThrough(state, false);

      // mouseleave fires -- resume should be rejected
      expect(shouldResumeMouseThrough(state)).toBe(false);
    });
  });
});
