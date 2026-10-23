import Foundation

/// Runs in an isolated WebKit world; page scripts cannot invoke the native field editor directly.
enum CarBrowserInputScript {
    static let source = #"""
    (() => {
      const handler = window.webkit.messageHandlers.roadivoCarInput;
      const documentID = String(Date.now()) + ':' + Math.random().toString(36).slice(2);
      let selected = null;
      let requestID = 0;
      function eligible(element) {
        if (!(element instanceof HTMLInputElement || element instanceof HTMLTextAreaElement)) return false;
        if (element.disabled || element.readOnly || !element.isConnected) return false;
        const autocomplete = (element.autocomplete || '').toLowerCase();
        if (/password|one-time-code|cc-/.test(autocomplete)) return false;
        return element instanceof HTMLTextAreaElement ||
          ['text', 'search', 'url', 'email', 'tel'].includes(element.type);
      }
      function searchField(element) {
        if (element instanceof HTMLTextAreaElement) return false;
        return element.type === 'search' || element.enterKeyHint === 'search' ||
          ['q', 'query', 'search', 'search_query'].includes(element.name) ||
          (element.form && element.form.getAttribute('role') === 'search' &&
            Array.from(element.form.elements).filter(eligible).length === 1);
      }
      document.addEventListener('pointerup', event => {
        if (event.isTrusted) handler.postMessage({kind: 'pointer'});
      }, true);
      document.addEventListener('pointerdown', event => {
        if (event.isTrusted && event.composedPath().some(eligible)) event.preventDefault();
      }, true);
      document.addEventListener('click', event => {
        if (!event.isTrusted) return;
        const element = event.composedPath().find(eligible);
        if (!element) return;
        event.preventDefault();
        selected = element;
        requestID += 1;
        const label = element.getAttribute('aria-label') || element.placeholder || element.name || '';
        handler.postMessage({kind: 'edit', documentID, requestID: String(requestID),
          label: label.slice(0, 120), search: Boolean(searchField(element))});
      }, true);
      globalThis.roadivoCarInput = {
        apply(documentToken, fieldToken, value, submit) {
          if (documentToken !== documentID || fieldToken !== String(requestID) || !eligible(selected)) return false;
          if (typeof value !== 'string' || value.length > 4096) return false;
          const element = selected;
          selected = null;
          const prototype = element instanceof HTMLTextAreaElement
            ? HTMLTextAreaElement.prototype : HTMLInputElement.prototype;
          Object.getOwnPropertyDescriptor(prototype, 'value').set.call(element, value);
          element.dispatchEvent(new InputEvent('input', {bubbles: true, inputType: 'insertText', data: value}));
          element.dispatchEvent(new Event('change', {bubbles: true}));
          if (submit && searchField(element)) {
            if (!element.form || typeof element.form.requestSubmit !== 'function') return false;
            element.form.requestSubmit();
          }
          return true;
        }
      };
      handler.postMessage({kind: 'ready'});
    })();
    """#

    static let apply = """
    return globalThis.roadivoCarInput?.apply(documentToken, fieldToken, value, submit) === true;
    """
}
