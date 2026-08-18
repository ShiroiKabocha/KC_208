MSFS 2024 BLACK SQUARE CARAVAN ENGINE MONITOR — VERSION 5

WHAT THIS VERSION ADDS
----------------------
Live monitoring for:
- Interstage Turbine Temperature (ITT)
- Propeller torque
- Gas generator RPM (Ng)
- Propeller RPM
- Oil pressure
- Oil temperature
- Fuel pressure
- Fuel flow
- Outside air temperature
- Starter state
- On-ground/airborne state
- Height above ground
- Vertical speed

It retains the magnetic compass and HSI fields from version 3.

ALERTS INCLUDED
---------------
- Phase-aware ITT limits for start, takeoff, climb, and cruise
- Start ITT timer at or above 1090 C
- Hot-engine restart caution above approximately 150 C
- Torque cautions and exceedances
- Cold-weather Ng derating below -30 C
- Propeller overspeed
- Oil-pressure warnings based on Ng
- Oil-temperature exceedances
- Starter continuous-use timer
- Fuel introduced below 12% Ng
- Basic possible-hung-start detection

IMPORTANT LIMITATION
--------------------
This version does not yet monitor FOD intensity, inertial-separator vane position,
beta/reverse state, chip detector, or internal failure states. The manual does not
publish those variable names. They require inspection of the aircraft XML files.

INSTALL / RUN
-------------
1. Extract this folder.
2. Copy your working SimConnect.dll into this folder.
   This is the renamed copy of MSFS 2024's SimConnect_internal.dll that worked
   with the prior dashboard.
3. Close any older dashboard version.
4. Double-click BUILD.cmd.
5. Run CaravanDashboard.exe.
6. Keep the console window open.
7. Open http://localhost:8765/ if the browser does not open automatically.

The app is read-only. It does not write to the aircraft.

ALERT-LOGIC NOTES
-----------------
The operating phase is inferred from starter state, on-ground state, height above
ground, torque, and vertical speed. It is intended as a practical warning system,
not as a certified flight instrument.

The manual contains a conservative enroute-climb checklist target below 740 C,
while the limitations table permits up to 765 C for climb. The dashboard treats
740-765 C as caution and above 765 C as a limit exceedance during climb.

VERSION 4.1 FIX
---------------
Corrected native SimConnect variable names by removing invalid A: prefixes.

VERSION 4.2 FIX
---------------
- Oil temperature is now requested in Celsius rather than as an untyped number.
- Fuel pressure is now requested in PSI rather than as an untyped number.

VERSION 5 FIX
---------------
The documented fuel-flow L-var behaves like gallons per hour in live testing,
despite being labeled PPH in the manual. The dashboard now multiplies the raw
value by 6.7 lb/US gal to display approximate Jet-A pounds per hour.

VERSION 5 CHANGES
-----------------
- Removed the CDI, CDI flag, and glideslope displays.
- Added HSI heading bug from AUTOPILOT HEADING LOCK DIR.
- Added HSI selected course from NAV OBS:1.
- Rebuilt the interface to resemble rectangular digital retrofit instruments
  mounted in an analog cockpit panel.
- Retained the engine alert logic from version 4.3.

VERSION 5.1 CHANGE
------------------
- Increased the descriptive/limit text at the bottom of each instrument by 50%.

VERSION 5.2.2
-------------
- Clean rebuild from version 5.1.
- Added aircraft registration using ATC ID.
- Heading bug readout uses subdued orange.
- Selected course / OBS 1 readout uses subdued yellow.
- Retains the 50% larger descriptive text from version 5.1.
- Corrected C# verbatim-string escaping that caused version 5.2 to fail compilation.
