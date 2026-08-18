(function attachNotebookController(global) {
  class NotebookController {
    #trigger;
    #overlay;
    #closeButton;
    #tabs;
    #pages;
    #previousBodyOverflow = '';

    constructor(trigger, overlay) {
      if (!trigger || !overlay) {
        throw new Error('NotebookController requires a trigger and overlay.');
      }

      this.#trigger = trigger;
      this.#overlay = overlay;
      this.#closeButton = overlay.querySelector('.manual-close');
      this.#tabs = [...overlay.querySelectorAll('.manual-tab')];
      this.#pages = [...overlay.querySelectorAll('.manual-page')];

      this.#overlay.setAttribute('aria-hidden', 'true');
      this.#bindEvents();
    }

    open() {
      this.#previousBodyOverflow = document.body.style.overflow;
      document.body.style.overflow = 'hidden';
      this.#overlay.classList.add('open');
      this.#overlay.setAttribute('aria-hidden', 'false');
      this.#closeButton?.focus();
    }

    close() {
      this.#overlay.classList.remove('open');
      this.#overlay.setAttribute('aria-hidden', 'true');
      document.body.style.overflow = this.#previousBodyOverflow;
      this.#trigger.focus();
    }

    showPage(pageName) {
      this.#tabs.forEach((tab) => {
        const selected = tab.dataset.page === pageName;
        tab.classList.toggle('active', selected);
        tab.setAttribute('aria-selected', String(selected));
      });

      this.#pages.forEach((page) => {
        page.classList.toggle('active', page.dataset.page === pageName);
      });
    }

    #bindEvents() {
      this.#trigger.addEventListener('click', () => this.open());
      this.#closeButton?.addEventListener('click', () => this.close());

      this.#overlay.addEventListener('click', (event) => {
        if (event.target === this.#overlay) this.close();
      });

      document.addEventListener('keydown', (event) => {
        if (event.key === 'Escape' && this.#overlay.classList.contains('open')) {
          this.close();
        }
      });

      this.#tabs.forEach((tab) => {
        tab.addEventListener('click', () => this.showPage(tab.dataset.page));
      });
    }
  }

  global.KabochaNotebookController = NotebookController;
})(window);
