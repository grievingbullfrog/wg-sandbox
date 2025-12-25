/**
 * Phoenix LiveView Hooks for the wargame platform.
 *
 * Export all hooks here for use in app.js
 */

export { MapHook } from "./MapHook";
export { MapEditorHook } from "./MapEditorHook";

// Combine all hooks into a single object for easy import
import { MapHook } from "./MapHook";
import { MapEditorHook } from "./MapEditorHook";

export const Hooks = {
  MapHook,
  MapEditorHook,
};

export default Hooks;
