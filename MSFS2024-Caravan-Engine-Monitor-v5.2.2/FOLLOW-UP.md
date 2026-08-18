# Kabocha CAS XL505 — Follow-up items

Items to address after the current packaged-build test cycle.

## Phase-aware operating references - implemented for v1.0.1 test r3

- Treat on-ground operation as takeoff and show hard limits only.
- Treat airborne operation as climb until vertical speed remains within
  +/-100 FPM for five continuous seconds.
- Hold cruise mode through brief vertical-speed excursions and return to climb
  after two continuous seconds outside the cruise band.
- In cruise, show the user's ITT, Ng, and propeller targets together with the
  applicable hard limits.
- Interpolate torque and fuel-flow guidance from the manual's Normal Cruise
  pressure-altitude tables, with a separate amphibian schedule.
- Keep all target values informational; only hard limits affect alerting.

## Session shutdown guidance

- Make it explicit that closing the browser does not stop the dashboard executable or release port 8765.
- Tell users to right-click the Kabocha CAS XL505 notification-area icon and select **Exit** to disconnect SimConnect, clear the session log, and release the port.
- Consider a concise first-run notice in addition to clearer README wording.
- Retain double-clicking the tray icon as the way to reopen a closed browser dashboard.
- Add an avionics-style power pushbutton in the dashboard's upper-right corner.
- Confirm the intended face label (`PWR` versus the supplied `PWRa`) before styling it.
- Make the button shut down the background executable—not merely close the browser—so it disconnects SimConnect and releases port 8765.
- Include an accidental-click safeguard appropriate to the design, such as a short hold or confirmation action.

## Propeller overspeed alert timing — implemented for v1.0.1 test

- Above 1,900 RPM for more than 2 continuous seconds: live `PROP OVERSPEED` advisory.
- Above 1,900 RPM for more than 15 continuous seconds: critical logged `PROP OVERSPEED LIMIT`.
- Above 2,090 RPM for more than 2 continuous seconds: critical logged `PROP TRANSIENT`.
- The general 1,900 RPM timer continues while RPM is also above 2,090; the transient timer resets independently at or below 2,090.
- Both timers reset when propeller speed returns to 1,900 RPM or below.

## Distribution resilience

- Add visible startup/error handling suitable for the console-free build.
- Detect port 8765 already being used and explain how to close an older dashboard instance.
- Prevent or clearly handle launching a second dashboard instance.
- Show a useful error when the bundled SimConnect DLL is missing or cannot be loaded.
- Detect and report an unsupported Windows/.NET runtime condition where practical.
- Distinguish between SimConnect being unavailable, SimConnect being connected without the correct aircraft loaded, and expected Black Square variables not producing valid data.
- Review behavior when SmartScreen, antivirus, corporate policy, or local HTTP-listener restrictions interfere with startup.
- Keep the README clear that the package must be extracted and that the executable and SimConnect DLL must remain together.

## Black Square Caravan variant compatibility

- Audit the additional Caravan models identified in the manual, including the amphibian and cargo-pod variants.
- Compare every custom variable used by the dashboard across the variants, not only the primary engine variables.
- Current custom-variable surface comprises 13 L-vars: ITT, magnetic-compass heading, torque, Ng, fuel pressure, fuel flow, oil temperature, fuel-cutoff handle, firewall-cutoff handle, fuel-pump switch, condition lever, engine covers, and inertial separator.
- Confirm whether their names, units, value ranges, and switch-state mappings are identical in each variant.
- Pay particular attention to variant-only equipment or geometry that could affect engine covers, fuel-system state, inertial-separator state, or pre-start logic.
- If all variables are shared, document explicit compatibility with each tested variant in the package README.
- If differences exist, identify the loaded variant and map its variables without changing the dashboard layout.

## Application and tray icon

- Create a simple `208` application identity that Caravan users will recognize immediately.
- Keep the artwork bold and uncluttered enough to remain readable at 16x16 and 20x20 notification-area sizes.
- Produce a multi-resolution Windows `.ico` containing at least 16, 20, 24, 32, 48, 64, 128, and 256 px versions.
- Use the icon as the embedded executable/file icon and for the live notification-area icon instead of the generic Windows application symbol.
- Use the same `208` identity as the dashboard favicon for browser tabs, bookmarks, and saved browser shortcuts; serve it locally from the dashboard executable with no external asset dependency.
- Test it against both light and dark Windows taskbar themes and at common display-scaling settings.
- Consider a restrained avionics treatment—off-white or illuminated `208` lettering on a near-black instrument face—without adding details that disappear at tray size.
