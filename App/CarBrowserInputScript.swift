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
      // A dropdown, whose options Roadivo lists on the car screen, which shows no picker of its own.
      function choosable(element) {
        return element instanceof HTMLSelectElement && !element.disabled && element.isConnected;
      }
      function searchField(element) {
        if (element instanceof HTMLTextAreaElement) return false;
        return element.type === 'search' || element.enterKeyHint === 'search' ||
          ['q', 'query', 'search', 'search_query'].includes(element.name) ||
          (element.form && element.form.getAttribute('role') === 'search' &&
            Array.from(element.form.elements).filter(eligible).length === 1);
      }
      function request(kind, element) {
        selected = element;
        requestID += 1;
        const label = element.getAttribute('aria-label') || element.placeholder || element.name || '';
        return {kind, documentID, requestID: String(requestID), label: label.slice(0, 120)};
      }
      function handled(event) {
        return event.composedPath().some(node => eligible(node) || choosable(node));
      }
      document.addEventListener('pointerup', event => {
        if (event.isTrusted) handler.postMessage({kind: 'pointer'});
      }, true);
      // Neither the system keyboard nor a system picker opens; Roadivo's own pages answer the click below.
      for (const type of ['pointerdown', 'mousedown']) {
        document.addEventListener(type, event => {
          if (event.isTrusted && handled(event)) event.preventDefault();
        }, true);
      }
      document.addEventListener('click', event => {
        if (!event.isTrusted) return;
        const path = event.composedPath();
        const field = path.find(eligible);
        if (field) {
          event.preventDefault();
          handler.postMessage(Object.assign(request('edit', field), {search: Boolean(searchField(field))}));
          return;
        }
        const dropdown = path.find(choosable);
        if (!dropdown) return;
        event.preventDefault();
        const options = Array.from(dropdown.options).slice(0, 100).map(option => ({
          title: (option.label || option.text || '').trim().slice(0, 120),
          selected: option.selected, disabled: option.disabled
        }));
        handler.postMessage(Object.assign(request('choose', dropdown), {options}));
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
        },
        choose(documentToken, fieldToken, index) {
          const element = selected;
          if (documentToken !== documentID || fieldToken !== String(requestID) || !choosable(element)) return false;
          const option = element.options[index];
          if (!option || option.disabled) return false;
          selected = null;
          element.selectedIndex = index;
          element.dispatchEvent(new Event('input', {bubbles: true}));
          element.dispatchEvent(new Event('change', {bubbles: true}));
          return true;
        }
      };
      handler.postMessage({kind: 'ready'});
    })();
    """#

    static let apply = """
    return globalThis.roadivoCarInput?.apply(documentToken, fieldToken, value, submit) === true;
    """

    static let choose = """
    return globalThis.roadivoCarInput?.choose(documentToken, fieldToken, index) === true;
    """
}
