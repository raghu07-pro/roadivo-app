import Foundation

/// Runs in an isolated WebKit world; page scripts cannot invoke the native field editor directly.
enum CarBrowserInputScript {
    static let source = #"""
    (() => {
      const handler = window.webkit.messageHandlers.playcartvCarInput;
      const documentID = String(Date.now()) + ':' + Math.random().toString(36).slice(2);
      let selected = null;
      let requestID = 0;
      // Every box that takes typing: text, search, address, email, phone, password and number fields, text areas,
      // and rich editors (contenteditable), so PlayCarTV's keyboard opens on any site (owner, 2026-10-26).
      function textual(element) {
        if (element instanceof HTMLTextAreaElement) return true;
        return element instanceof HTMLInputElement &&
          ['text', 'search', 'url', 'email', 'tel', 'password', 'number'].includes(element.type);
      }
      function editable(element) {
        return element instanceof HTMLElement && element.isContentEditable &&
          element !== document.body && element !== document.documentElement;
      }
      function eligible(element) {
        if (!(element instanceof Element) || !element.isConnected) return false;
        if (textual(element)) return !element.disabled && !element.readOnly;
        return editable(element);
      }
      // The rich editor itself rather than the paragraph tapped inside it.
      function editingHost(element) {
        let host = element;
        while (host.parentElement && editable(host.parentElement)) host = host.parentElement;
        return host;
      }
      // The tapped box, or the box a tapped label belongs to, as for a floating "Password" label over its field.
      function fieldIn(path) {
        for (const node of path) {
          if (eligible(node)) return textual(node) ? node : editingHost(node);
          if (node instanceof HTMLLabelElement && node.control && eligible(node.control)) return node.control;
        }
        return null;
      }
      function secure(element) {
        return element instanceof HTMLInputElement && element.type === 'password';
      }
      function numeric(element) {
        return (element instanceof HTMLInputElement && ['number', 'tel'].includes(element.type)) ||
          ['numeric', 'decimal', 'tel'].includes(element.inputMode);
      }
      // What's already typed, to edit; never a password, which stays on the page.
      function currentValue(element) {
        if (secure(element)) return '';
        return (textual(element) ? element.value : element.innerText || '').slice(0, 4096);
      }
      // A dropdown, whose options PlayCarTV lists on the car screen, which shows no picker of its own.
      function choosable(element) {
        return element instanceof HTMLSelectElement && !element.disabled && element.isConnected;
      }
      function searchField(element) {
        if (!textual(element)) return element.getAttribute('role') === 'searchbox';
        return element.type === 'search' || element.enterKeyHint === 'search' ||
          ['q', 'query', 'search', 'search_query'].includes(element.name) ||
          (element.form && element.form.getAttribute('role') === 'search' &&
            Array.from(element.form.elements).filter(eligible).length === 1);
      }
      function request(kind, element) {
        selected = element;
        requestID += 1;
        const label = element.getAttribute('aria-label') || element.placeholder || element.name ||
          element.getAttribute('data-placeholder') || '';
        return {kind, documentID, requestID: String(requestID), label: label.slice(0, 120)};
      }
      function handled(event) {
        const path = event.composedPath();
        return Boolean(fieldIn(path)) || path.some(choosable);
      }
      document.addEventListener('pointerup', event => {
        if (event.isTrusted) handler.postMessage({kind: 'pointer'});
      }, true);
      // Neither the system keyboard nor a system picker opens; PlayCarTV's own pages answer the click below.
      for (const type of ['pointerdown', 'mousedown']) {
        document.addEventListener(type, event => {
          if (event.isTrusted && handled(event)) event.preventDefault();
        }, true);
      }
      document.addEventListener('click', event => {
        if (!event.isTrusted) return;
        const path = event.composedPath();
        const field = fieldIn(path);
        if (field) {
          event.preventDefault();
          handler.postMessage(Object.assign(request('edit', field), {
            search: Boolean(searchField(field)), secure: secure(field), numeric: numeric(field),
            value: currentValue(field)
          }));
          // YouTube focuses its own box on click; PlayCarTV's keyboard types instead, so nothing zooms in to it.
          setTimeout(() => field.blur(), 0);
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
      globalThis.playcartvCarInput = {
        apply(documentToken, fieldToken, value, submit) {
          if (documentToken !== documentID || fieldToken !== String(requestID) || !eligible(selected)) return false;
          if (typeof value !== 'string' || value.length > 4096) return false;
          const element = selected;
          selected = null;
          if (textual(element)) {
            const prototype = element instanceof HTMLTextAreaElement
              ? HTMLTextAreaElement.prototype : HTMLInputElement.prototype;
            Object.getOwnPropertyDescriptor(prototype, 'value').set.call(element, value);
            element.dispatchEvent(new InputEvent('input', {bubbles: true, inputType: 'insertText', data: value}));
            element.dispatchEvent(new Event('change', {bubbles: true}));
          } else {
            // A rich editor takes the text as typing, replacing what was there, so its own script sees it.
            element.focus({preventScroll: true});
            const range = document.createRange();
            range.selectNodeContents(element);
            const selection = window.getSelection();
            selection.removeAllRanges();
            selection.addRange(range);
            if (!document.execCommand('insertText', false, value)) {
              element.textContent = value;
              element.dispatchEvent(new InputEvent('input', {bubbles: true, inputType: 'insertText', data: value}));
            }
          }
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
    return globalThis.playcartvCarInput?.apply(documentToken, fieldToken, value, submit) === true;
    """

    static let choose = """
    return globalThis.playcartvCarInput?.choose(documentToken, fieldToken, index) === true;
    """
}
