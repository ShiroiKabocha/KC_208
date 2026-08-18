# KC-208

KC-208 is an external EICAS-style engine monitoring and startup-reference utility for Microsoft Flight Simulator 2024 and the Black Square Caravan Professional.

The Windows package connects through SimConnect and presents guided startup checks, live engine instrumentation, phase-aware limits, interpolated cruise references, advisories, and a session-based critical event log. A Parallel 42 Flow version is also included for Flow users.

## Download

Download the current Windows ZIP from the repository's Releases page. Extract the complete folder, load the Black Square Caravan Professional in MSFS 2024, and run `208 EICAS.exe`.

Keep `SimConnect.dll` beside the executable. This is an external application and does not belong in the Community folder.

## Repository layout

- `MSFS2024-Caravan-Engine-Monitor-v5.2.2/` — application source, atmospheric preview, assets, and packaging scripts
- `208-EICAS-Flow/` — self-contained Parallel 42 Flow widget source and working files
- `NOTEBOOK-CONTENT.md` inside the source project — editable pop-out notebook content

## Requirements

- Windows 10 or Windows 11, 64-bit
- Microsoft Flight Simulator 2024
- Black Square Caravan Professional

KC-208 is a read-only monitoring reference. It does not control the aircraft and does not replace aircraft manuals or official checklists.
