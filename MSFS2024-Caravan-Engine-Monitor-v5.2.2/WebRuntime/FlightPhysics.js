export class FlightPhysics {
  #ittTimer = null;
  #starterTimer = null;
  #propOverspeedTimer = null;
  #propTransientTimer = null;
  #cruiseCandidateTimer = null;
  #cruiseExitTimer = null;
  #cruiseActive = false;
  #oilBaselineTimer = null;
  #oilBaseline = null;
  #oilPeak = 0;

  /**
   * Resolves the dashboard flight phase.
   * References: Cessna Caravan POH, Section 4 — Normal Procedures; Section 5 —
   * Performance, Normal Cruise Power. Cruise requires five seconds inside
   * +/-100 FPM and exits after two seconds outside that band.
   */
  phaseFor(data, now = performance.now()) {
    if (data.starterActive || (data.ng > 0 && data.ng < 52 && data.fuelFlow > 0)) return 'STARTING';
    if (data.onGround) {
      this.#cruiseCandidateTimer = this.#cruiseExitTimer = null;
      this.#cruiseActive = false;
      return 'TAKEOFF';
    }
    // Five seconds keeps a little turbulence from declaring cruise too early.
    const stable = Math.abs(Number(data.verticalSpeed)) <= 100;
    if (stable) {
      this.#cruiseExitTimer = null;
      this.#cruiseCandidateTimer ??= now;
      if (now - this.#cruiseCandidateTimer >= 5000) this.#cruiseActive = true;
    } else {
      this.#cruiseCandidateTimer = null;
      if (this.#cruiseActive) {
        this.#cruiseExitTimer ??= now;
        if (now - this.#cruiseExitTimer >= 2000) {
          this.#cruiseActive = false;
          this.#cruiseExitTimer = null;
        }
      }
    }
    return this.#cruiseActive ? 'CRUISE' : 'CLIMB';
  }

  /**
   * Calculates the cold-weather Ng limit.
   * Reference: Cessna Caravan POH, Section 2 — Limitations, engine operating
   * limits chart. The simulator model applies a 2.2-point reduction per full
   * 10 C below -30 C.
   */
  ngLimit(oatCelsius) {
    return oatCelsius >= -30 ? 101.6 : 101.6 - Math.floor((-30 - oatCelsius) / 10) * 2.2;
  }

  /**
   * Linearly interpolates normal-cruise torque and fuel-flow references.
   * Reference: Cessna Caravan POH, Section 5 — Performance,
   * “Normal Cruise Power — Standard Day (ISA).” Values are guidance rather
   * than required operating points.
   */
  cruiseGuide(pressureAltitude, aircraftTitle = '') {
    const amphibian = aircraftTitle.toUpperCase().includes('AMPHIB');
    const points = amphibian
      ? [[4000,1600,365],[8000,1500,334],[12000,1400,308],[16000,1335,284],[20000,1185,265]]
      : [[4000,1600,365],[8000,1500,334],[12000,1400,308],[16000,1335,284],[22000,1175,256]];
    const altitude = Number(pressureAltitude);
    // Don't extrapolate beyond the published table. That gets optimistic fast.
    if (altitude <= points[0][0]) return this.#guide(points[0], true);
    const last = points.at(-1);
    if (altitude >= last[0]) return this.#guide(last, true);
    for (let index = 1; index < points.length; index += 1) {
      if (altitude > points[index][0]) continue;
      const low = points[index - 1], high = points[index];
      const ratio = (altitude - low[0]) / (high[0] - low[0]);
      return {
        torque: Math.round((low[1] + (high[1] - low[1]) * ratio) / 5) * 5,
        fuel: Math.round(low[2] + (high[2] - low[2]) * ratio),
        altitude: Math.round(altitude),
        clamped: false
      };
    }
    return this.#guide(last, true);
  }

  /**
   * Evaluates engine limits and time-dependent exceedances.
   * References: Cessna Caravan POH, Section 2 — Limitations; Section 4 —
   * Starting Engine; Black Square Caravan Professional manual,
   * “Turbine Engine Simulation.”
   */
  analyze(data, now = performance.now()) {
    const alerts = [];
    const add = (severity, title, detail) => alerts.push({severity, title, detail});
    const phase = this.phaseFor(data, now);
    let ittWarning = 740, ittCritical = 765, ittMaximum = 805, ittLabel = 'MAX 765 C';
    if (phase === 'STARTING') { ittWarning = 805; ittCritical = 1090; ittMaximum = 1120; ittLabel = 'MAX 1090 C / 2 SEC'; }
    else if (phase === 'TAKEOFF') { ittWarning = 765; ittCritical = 805; ittMaximum = 850; ittLabel = 'MAX 805 C'; }
    else if (phase === 'CRUISE') ittLabel = 'GUIDE <720 / LIMIT 740 C';

    let ittLevel = data.itt >= ittCritical ? 'critical' : data.itt >= ittWarning ? 'warning' : 'normal';
    if (phase === 'STARTING' && data.itt >= 1090) {
      this.#ittTimer ??= now;
      const seconds = (now - this.#ittTimer) / 1000;
      add(seconds >= 2 ? 'critical' : 'warning', 'START ITT', `${data.itt.toFixed(0)} C / ${seconds.toFixed(1)} SEC`);
    } else {
      this.#ittTimer = null;
      if (ittLevel === 'critical') add('critical', 'ITT LIMIT', `${data.itt.toFixed(0)} C / ${ittLabel}`);
      else if (ittLevel === 'warning') add('warning', 'HIGH ITT', `${data.itt.toFixed(0)} C / ${ittLabel}`);
    }
    if (data.onGround && !data.starterActive && data.ng < 5 && data.itt > 150)
      add('warning', 'HOT RESTART', `ITT ${data.itt.toFixed(0)} C / DRY MOTOR RECOMMENDED`);
    const condition = Math.round(Number(data.conditionLever));
    if (condition > 0 && Number(data.ng) > 0.5 && Number(data.ng) < 12)
      add('critical', 'HOT START', `${condition === 2 ? 'HIGH' : 'LOW'} IDLE / NG ${Number(data.ng).toFixed(1)}%`);

    const torqueLevel = data.torque > 1970 ? 'critical' : data.torque > 1865 ? 'warning' : 'normal';
    if (data.torque > 2400) add('critical', 'TORQUE TRANSIENT', `${data.torque.toFixed(0)} FT-LB`);
    else if (data.torque > 1970) add('critical', 'TORQUE LIMIT', `${data.torque.toFixed(0)} FT-LB`);
    else if (data.torque > 1865) add('warning', 'HIGH TORQUE', `${data.torque.toFixed(0)} FT-LB`);

    const ngLimit = this.ngLimit(data.oat);
    const ngLevel = data.ng > 102.6 ? 'critical' : data.ng > ngLimit ? 'warning' : 'normal';
    if (data.ng > 102.6) add('critical', 'NG TRANSIENT', `${data.ng.toFixed(1)}%`);
    else if (data.ng > ngLimit) add('warning', 'NG LIMIT', `${data.ng.toFixed(1)}% / LIMIT ${ngLimit.toFixed(1)}%`);

    let propellerLevel = 'normal';
    if (data.propRpm > 1900) {
      // The normal and transient limits run on separate clocks.
      this.#propOverspeedTimer ??= now;
      const seconds = (now - this.#propOverspeedTimer) / 1000;
      if (data.propRpm > 2090) this.#propTransientTimer ??= now;
      else this.#propTransientTimer = null;
      const transient = this.#propTransientTimer === null ? 0 : (now - this.#propTransientTimer) / 1000;
      if (transient > 2) { propellerLevel = 'critical'; add('critical', 'PROP TRANSIENT', `${data.propRpm.toFixed(0)} RPM / ${transient.toFixed(1)} SEC ABOVE 2090`); }
      else if (seconds > 15) { propellerLevel = 'critical'; add('critical', 'PROP OVERSPEED LIMIT', `${data.propRpm.toFixed(0)} RPM / ${seconds.toFixed(1)} SEC ABOVE 1900`); }
      else if (seconds > 2) { propellerLevel = 'warning'; add('warning', 'PROP OVERSPEED', `${data.propRpm.toFixed(0)} RPM / ${seconds.toFixed(1)} SEC ABOVE 1900`); }
    } else this.#propOverspeedTimer = this.#propTransientTimer = null;

    let oilLevel = 'normal', oilDetail = 'Baseline captures 5 sec after 52% Ng';
    const oilPressure = Number(data.oilPressure), ng = Number(data.ng);
    if (ng >= 52 && oilPressure > 0) {
      // Let pressure settle before calling today's healthy value the baseline.
      if (this.#oilBaselineTimer === null) { this.#oilBaselineTimer = now; this.#oilPeak = oilPressure; }
      this.#oilPeak = Math.max(this.#oilPeak, oilPressure);
      if (this.#oilBaseline === null && now - this.#oilBaselineTimer >= 5000) this.#oilBaseline = this.#oilPeak;
    }
    const shutdown = Boolean(data.onGround) && Math.round(Number(data.conditionLever)) === 0 && !data.starterActive;
    if (this.#oilBaseline !== null && this.#oilBaseline > 0) {
      const drop = (this.#oilBaseline - oilPressure) / this.#oilBaseline * 100;
      oilDetail = shutdown ? 'Shutdown / pressure decay expected' : `Post-start baseline ${this.#oilBaseline.toFixed(0)} PSI`;
      if (drop >= 40 && !shutdown) { oilLevel = 'critical'; add('critical', 'OIL PRESSURE DROP', `${oilPressure.toFixed(0)} PSI / ${drop.toFixed(0)}% BELOW BASELINE`); }
    }
    if (oilPressure > 105) { oilLevel = 'critical'; add('critical', 'HIGH OIL PRESSURE', `${oilPressure.toFixed(0)} PSI`); }
    const oilTemperatureLevel = data.oilTemperature >= 104 ? 'critical' : data.oilTemperature > 99 ? 'warning' : 'normal';
    if (data.oilTemperature >= 104) add('critical', 'OIL TEMPERATURE', `${data.oilTemperature.toFixed(0)} C`);
    else if (data.oilTemperature > 99) add('warning', 'HIGH OIL TEMP', `${data.oilTemperature.toFixed(0)} C`);

    if (data.starterActive) {
      this.#starterTimer ??= now;
      const seconds = (now - this.#starterTimer) / 1000;
      if (seconds >= 30) add('critical', 'STARTER LIMIT', `${seconds.toFixed(0)} SEC / ABORT START`);
      if (data.fuelFlow > 0 && data.ng < 52 && seconds >= 30) add('critical', 'POSSIBLE HUNG START', `NG ${data.ng.toFixed(1)}%`);
    } else this.#starterTimer = null;

    const poundsPerGallon = Number(data.fuelWeightPerGallon);
    if (poundsPerGallon > 0) {
      const left = Number(data.leftFuelQuantity) * poundsPerGallon;
      const right = Number(data.rightFuelQuantity) * poundsPerGallon;
      const difference = Math.abs(left - right);
      if (difference >= 200) {
        const lowerLeft = left < right, selector = Math.round(Number(data.fuelSelector));
        const lowerOpen = lowerLeft ? selector === 1 || selector === 2 : selector === 1 || selector === 3;
        const tank = lowerLeft ? 'LEFT' : 'RIGHT';
        add(difference >= 250 ? 'critical' : 'warning', 'FUEL IMBALANCE', `${difference.toFixed(0)} LB / ${lowerOpen ? `CLOSE ${tank} TANK` : `${tank} TANK CLOSED`}`);
      }
    }
    // Short aliases are retained for the existing card renderer while it is
    // being retired a piece at a time.
    return {
      alerts, phase, ittLevel, torqueLevel, ngLevel, propellerLevel, oilLevel, oilTemperatureLevel,
      ittLabel, ngLimit, oilDetail, ittWarning, ittCritical, ittMaximum,
      tqLevel: torqueLevel, propLevel: propellerLevel, op: oilLevel, ot: oilTemperatureLevel,
      il: ittLabel, nl: ngLimit, opd: oilDetail, iw: ittWarning, ic: ittCritical, imax: ittMaximum
    };
  }

  #guide(point, clamped) {
    return {torque: point[1], fuel: point[2], altitude: point[0], clamped};
  }
}
