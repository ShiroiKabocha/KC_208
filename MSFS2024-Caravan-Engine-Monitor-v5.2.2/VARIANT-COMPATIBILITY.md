# Black Square Caravan variant compatibility
## Manual audit result

The Black Square Caravan Professional manual describes the standard aircraft, cargo-pod/Cargomaster configurations, and amphibian within one product and one shared hardware-variable appendix.

The 13 custom variables consumed by Kabocha CAS XL505 are listed as common Caravan aircraft, engine, exterior, or primary-control variables. The manual does not publish alternate names, units, ranges, or state mappings for these variables by variant:

- `L:BKSQ_CARAVAN_ITT`
- `L:BKSQ_MagneticCompassHeading`
- `L:BKSQ_CARAVAN_TQ`
- `L:BKSQ_CARAVAN_NG`
- `L:BKSQ_CARAVAN_FUELPRESSURE`
- `L:BKSQ_CARAVAN_FuelFlow`
- `L:BKSQ_CARAVAN_OILTEMPERATURE`
- `L:var_FuelCutoffHandle`
- `L:var_FirewallCutoffHandle`
- `L:var_FuelPumpSwitch`
- `L:BKSQ_ConditionLever`
- `L:bksq_EngineCovers`
- `L:XMLVAR_InterSep`

The manual does identify genuinely variant-specific variables, such as cargo-pod doors, water-rudder controls, and amphibious landing-gear controls. The dashboard does not currently consume any of those variables.

## Compatibility conclusion

The manual provides no indication that the dashboard's existing engine/start variables change between the standard, cargo-pod/Cargomaster, and amphibian models. All three are therefore expected to work with the same data definition and dashboard logic.

This is a documentation-level conclusion. Before public compatibility claims are finalized, run one live validation in each model and confirm:

1. The application recognizes the loaded aircraft title.
2. All eight engine-monitor values update.
3. Engine covers, fuel cutoff, firewall cutoff, boost pump, condition lever, and inertial separator report the same states.
4. Starter switch and starter-motor-active indications behave normally.
5. Fuel-tank selector and quantity readings remain correct.
