/**
 * Phoenix LiveView Hooks for the wargame platform.
 *
 * Export all hooks here for use in app.js
 */

export { MapHook } from "./MapHook";

// Combine all hooks into a single object for easy import
import { MapHook } from "./MapHook";

export const Hooks = {
  MapHook,
};

export default Hooks;
