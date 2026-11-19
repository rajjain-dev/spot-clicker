# Parts and missing supplies

Core parts received per Raj; verify markings before use. Quantity one each unless stated.

| Part | Selected model |
| --- | --- |
| Controller | Plain Seeed XIAO nRF52840, 102010448 |
| Battery | TinyCircuits ASR00003, protected 3.7 V/150 mAh |
| Motor | DFRobot FIT0774 |
| Battery switch | C&K JS102011SAQN |
| Driver | onsemi PN2222ABU + 1N4148 |
| Resistors | 1 kΩ CF14JT1K00; 10 kΩ CF14JT10K0 |
| Input/appearance | Existing keycap/keyring; replacement momentary switch needed |
| Test fixture | Breadboard available |

Raj's latest selection is **use existing parts and list unresolved limits**. The [complete product proposal](PRODUCT_CIRCUIT.md) and [USB/motor bench setup](BREADBOARD_LAYOUT.md) omit an added external 104. No additional driver/regulator/current-limiter IC or battery replacement is adopted. The missing button, supported connector and assembly supplies below still prevent a finished physical product:

- Normally-open momentary switch with accessible contacts and compatible keycap.
- Supported battery connection: matching JST SH 1 mm connector/carrier; pack mates with SM02B-SRSS-TB(LF)(SN). Bare SMD header needs mounting; PH 2 mm does not fit. Check what was delivered.
- Short 28–30 AWG insulated wire, solder/flux, heat-shrink/Kapton, strain relief, thin motor-mount tape, small driver/switch carriers.
- If noise measurements/stability require it: 100 nF ceramic ≥10 V; optional 47–100 µF bulk capacitor ≥6.3 V. Neither is added to the current bench attempt.
- Case fasteners after CAD; print material/access.

Borrow tools listed in [BUILD_PLAN](BUILD_PLAN.md). No additional controller, GPS, programmer, or separate charger is planned. Prices/delivery estimates removed because purchasing is complete; replacements require fresh checks.
