208 EICAS v1.0


Thank you for downloading the Kabocha 208 EICAS system, manufactured by Kabocha Industries-your leader in anachronistic simulator add-ons.

With Kabocha avionics, we'll get you home...most of the time.

Please review the following safety information:

REQUIREMENTS
------------
- Windows 10 or Windows 11, 64-bit
- Microsoft Flight Simulator 2024
- Black Square Caravan Professional


INSTALLATION
------------
1. Extract the entire 208-EICAS-v1.0 folder somewhere convenient.
2. Do not place it in the MSFS Community folder. This is an external application.
3. Keep 208 EICAS.exe and SimConnect.dll together in the same folder.
4. Start MSFS and load the Black Square Caravan Professional.
5. Run 208 EICAS.exe.
6. The dashboard runs in the Windows notification area without a console window.
   Closing the browser does not stop it. Double-click its `208` tray icon to
   reopen the dashboard, or right-click the icon and choose Exit to disconnect
   SimConnect and release port 8765.

The dashboard also has a PWR button in its upper-right corner. Hold it to stop the background application and release port 8765.

The dashboard normally opens http://localhost:8765/ automatically. If it does
not, open that address manually in your browser.

WHAT IT MONITORS
----------------
- Guided pre-start checks, start setup, and active start sequence
- ITT, torque, Ng, propeller RPM, oil pressure, oil temperature
- Fuel pressure and fuel flow
- Wing-tank fuel imbalance by actual simulator fuel weight
- Starter timing and start-limit protection during hung starts.
- Aircraft heading, heading bug, selected course, and outside temperature
- Session-based critical limit-exceedance log
- Phase-aware engine-card references: takeoff and climb limits, plus cruise
  targets derived from the manual's Normal Cruise table using pressure altitude

CRUISE GUIDANCE
---------------
Note:  Cruise guidance numbers are factored on the base Caravan 208. Use your best judgement when flying the cargo pod and amphibian variants.

After the aircraft remains within -100 to +100 feet per minute for five
seconds, the dashboard shows cruise guidance on the primary engine monitors.
Torque and fuel-flow targets are interpolated from the aircraft manual's
Normal Cruise table using simulator pressure altitude. Amphibian table values
are selected automatically when that variant is detected.

These values are convenient planning references, not required settings and not
alert thresholds. The published table is based on ISA conditions and maximum
gross weight; actual conditions may require different power. Hard operating
limits remain separately identified and are the only values used for limit
alerting.

IMPORTANT
---------
This utility is a read-only monitoring reference. It does not control the
aircraft and does not replace the full pre-flight checklists. Always follow the aircraft
manual and in-simulator checklists.

The limit-event log exists only for the current application session. Closing or refreshing the browser window clears it.
You can also press the 'CLR Last' button to remove the last event log captured.

TROUBLESHOOTING
---------------
INOP tape or blank values:
- Confirm MSFS is running and the Black Square Caravan is fully loaded.
- Confirm SimConnect.dll remains beside 208 EICAS.exe.
- Close older copies of the dashboard; only one can use port 8765.
- Restart the dashboard after the aircraft finishes loading.

Browser does not open:
- Visit http://localhost:8765/ manually.

Windows SmartScreen warning:
- This executable is not digitally signed. Confirm that it came from your
  trusted download source before choosing to run it.

Port 8765 already in use:
- Close another dashboard instance or any application using localhost:8765.
- If an older dashboard is still running, find its `208` notification-area icon,
  right-click it, and choose Exit.

Wrong aircraft / INOP while SimConnect is connected:
- Load a Black Square Caravan Professional variant. The status-lamp tooltip
  reports the aircraft title currently seen by the dashboard.

UNINSTALLATION
--------------
Right-click the notification-area icon and choose Exit, then delete its
extracted folder. It does not install files
into MSFS and does not add registry entries.
