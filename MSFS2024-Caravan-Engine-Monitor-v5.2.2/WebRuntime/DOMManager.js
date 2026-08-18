export class DOMManager {
  #root;
  #idCache = new Map();

  constructor(root = document) {
    this.#root = root;
  }

  byId(id) {
    const cached = this.#idCache.get(id);
    if (cached?.isConnected) return cached;

    const element = this.#root.getElementById(id);
    // Missing cockpit hardware is a build error, not an optional state.
    if (!element) throw new Error(`Dashboard element #${id} was not found.`);
    this.#idCache.set(id, element);
    return element;
  }

  optional(id) {
    const cached = this.#idCache.get(id);
    if (cached?.isConnected) return cached;

    const element = this.#root.getElementById(id);
    if (element) this.#idCache.set(id, element);
    return element;
  }

  all(selector) {
    return [...this.#root.querySelectorAll(selector)];
  }

  text(id, value) {
    this.byId(id).textContent = value;
  }

  toggle(id, className, enabled) {
    this.byId(id).classList.toggle(className, Boolean(enabled));
  }
}
