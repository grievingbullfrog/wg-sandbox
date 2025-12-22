/**
 * Type definitions for Phoenix LiveView hooks
 */

declare interface ViewHookInterface {
  /**
   * The DOM element the hook is mounted on
   */
  el: HTMLElement;

  /**
   * Push an event to the LiveView server
   */
  pushEvent(event: string, payload?: Record<string, unknown>, callback?: (reply: unknown, ref: number) => void): void;

  /**
   * Push an event to a specific component
   */
  pushEventTo(selectorOrTarget: string | HTMLElement, event: string, payload?: Record<string, unknown>, callback?: (reply: unknown, ref: number) => void): void;

  /**
   * Handle events pushed from the server
   */
  handleEvent(event: string, callback: (payload: unknown) => void): void;

  /**
   * Upload files
   */
  upload(name: string, files: FileList | File[]): void;

  /**
   * Upload files to a specific component
   */
  uploadTo(selectorOrTarget: string | HTMLElement, name: string, files: FileList | File[]): void;
}

/**
 * Hook definition object with lifecycle callbacks
 */
declare interface ViewHook extends ViewHookInterface {
  /**
   * Called when the element has been added to the DOM and the server LiveView has finished mounting
   */
  mounted?(): void;

  /**
   * Called before the element is about to be updated in the DOM
   */
  beforeUpdate?(): void;

  /**
   * Called after the element has been updated in the DOM
   */
  updated?(): void;

  /**
   * Called when the element is about to be removed from the DOM
   */
  destroyed?(): void;

  /**
   * Called when the element has been disconnected from the server
   */
  disconnected?(): void;

  /**
   * Called when the element has been reconnected to the server
   */
  reconnected?(): void;
}
