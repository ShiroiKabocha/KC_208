import {DOMManager} from './DOMManager.js';
import {FlightPhysics} from './FlightPhysics.js';

export class DashboardController {
  #dom;
  #physics;
  #pollTimer = null;
  #renderTelemetry;
  #onOffline;

  constructor({root = document, renderTelemetry, onOffline}) {
    this.#dom = new DOMManager(root);
    this.#physics = new FlightPhysics();
    this.#renderTelemetry = renderTelemetry;
    this.#onOffline = onOffline;
  }

  start(intervalMs = 100) {
    this.refresh();
    this.#pollTimer = window.setInterval(() => {
      // This polling path is older than refresh(), so it still speaks promises.
      fetch('/api/data', {cache: 'no-store'})
        .then(response => {
          if (!response.ok) throw new Error(`Telemetry HTTP ${response.status}`);
          return response.json();
        })
        .then(data => this.#consume(data))
        .catch(error => this.#offline(error));
    }, intervalMs);
  }

  stop() {
    if (this.#pollTimer !== null) window.clearInterval(this.#pollTimer);
    this.#pollTimer = null;
  }

  async refresh() {
    try {
      const response = await fetch('/api/data', {cache: 'no-store'});
      if (!response.ok) throw new Error(`Telemetry HTTP ${response.status}`);
      this.#consume(await response.json());
    } catch (error) {
      this.#offline(error);
    }
  }

  async shutdown() {
    // The header is intentional; a random webpage shouldn't stop the tray app.
    await fetch('/api/shutdown', {method: 'POST', headers: {'X-Kabocha-Shutdown': '208'}});
    this.stop();
  }

  #consume(data) {
    const operational = Boolean(data.connected && data.aircraftCompatible);
    this.#dom.toggle('app', 'offline', !operational);
    if (!operational) return this.#offline(new Error(data.message || 'Simulator unavailable'));
    const analysis = this.#physics.analyze(data);
    this.#renderTelemetry({data, analysis, physics: this.#physics, dom: this.#dom});
  }

  #offline(error) {
    this.#dom.toggle('app', 'offline', true);
    this.#onOffline?.(error, this.#dom);
  }
}
