/**
 * Phoenix LiveView Hooks for the wargame platform.
 *
 * Export all hooks here for use in app.js
 */

export { MapHook } from "./MapHook";
export { MapEditorHook } from "./MapEditorHook";
export { GameHook } from "./GameHook";

// Combine all hooks into a single object for easy import
import { MapHook } from "./MapHook";
import { MapEditorHook } from "./MapEditorHook";
import { GameHook } from "./GameHook";

export const Hooks = {
  MapHook,
  MapEditorHook,
  GameHook,
};

export default Hooks;
