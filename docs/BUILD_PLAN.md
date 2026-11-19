# Build plan

Latest rule: **no tests to re-verify specified component ratings or values**. Test only unpublished parameters, unknown assembly interactions or observed faults. [MOTOR_RESEARCH](MOTOR_RESEARCH.md) supersedes earlier blanket verification requests and provides same-size motor-maker measurements. No motor-noise problem has been observed in this build. Motorless MVP remains an option, not a committed change.

Finish one portable clicker: button → phone save → felt confirmation, inside a serviceable case. **Chip/app communication and the return response are already tested and complete. Next: motor circuit.** The manufacturer-checked [PRODUCT_CIRCUIT](PRODUCT_CIRCUIT.md) recreates the complete proposed circuit using existing parts; its unresolved limits and release gates must pass before final assembly. Details: [BUILD_STATE](BUILD_STATE.md).

## Before the next visit

- Pack Mac/charger, iPhone with working app, USB-C data cable, all [parts](HARDWARE_SHOPPING_LIST.md), breadboard, and keycap/keyring. Obtain a normally-open momentary replacement switch with exposed solder contacts; confirm keycap compatibility.
- Confirm access to soldering station, multimeter, adjustable bench supply with current limiting, and a scope/current logger for startup peaks. Work independently; use the equipment model's manual for setup. Bring this folder offline.
- Resolve the battery's mating SH connector/carrier, hookup wire, insulation, and small driver/switch supports before portable integration.
- Raj requested an existing-parts breadboard setup, avoiding an added 104 capacitor. Follow [BREADBOARD_LAYOUT](BREADBOARD_LAYOUT.md): manual driver first, then separate USB/3 V motor supplies. Prepared source uses D4 with high HIGH drive and motor disabled; upload/enable only after driver checks pass. Capacitor-free stability/transients remain unverified; revisit suppression if checks fail.
- Confirm printer training/access and queue before the fabrication visit. Printing waits for actual measurements and a working circuit.

## Order of work

Times are bench estimates; allow separate electronics and fabrication visits, charge observation, and a reprint.

| Step | Task | Tools / parts | Finish when |
| --- | --- | --- | --- |
| 1 · 15–20 min | Inventory, label E/B/C and diode band; map slide-switch contacts; measure parts. Start with transistor in separate breadboard rows. | Meter, calipers, breadboard, magnification; exact parts | Contacts identified; dimensions and missing supplies recorded. |
| 2 · 45–90 min | Motor-only 3 V/50 mA test passed. Build the [manual-jumper transistor test](TRANSISTOR_BENCH_TEST.md), with parallel resistors and no chip/capacitor. Check OFF/ON and transistor drop. Startup peaks at 3.0/3.7/4.2 V still need qualification before battery integration; do not increase voltage in the initial breadboard test. | Supply, meter, peak-current instrument; existing driver/motor | Driver inspected; proper OFF/ON behavior, startup current and transistor drop measured. |
| 3 · 30–45 min | After driver checks, follow the [D4 breadboard guide](BREADBOARD_LAYOUT.md), upload/enable matching firmware and attempt operation without the 104 capacitor. Use the proven app response for Liked, Want to go, undo and controlled error buzz patterns via USB. | Mac/Arduino, iPhone, qualified driver, separate 3 V supply; scope for transients | Distinct buzz follows app result; no reset/BLE drop; electrical noise checked. Cover remaining double/undo behavior. |
| 4 · 45–90 min | Add supported battery connector and slide switch. Inspect polarity/OFF routing; integrate qualified motor; implement/test low-voltage cutoff and USB motor inhibition; measure unknown whole-device idle current. Accept specified charger ratings/behavior; no routine charging-current or voltage re-test. | Soldering station, meter/series breakout, battery/switch | Battery-only boot/reconnect and protective firmware recorded; charging diagnostics only for an actual anomaly or unknown load interaction. Cable-free actions wait for step 5. |
| 5 · 30–60 min | Wire replacement momentary switch D1–GND. Check single/double/hold and startup held; repeat on battery with USB removed, including motor starts. | Switch/keycap, meter, soldering station, phone, peak-current instrument | 10 singles, 10 doubles, 5 holds correct; one action each, no hold-release save. Total battery peaks qualified under real actions. |
| 6 · 30–45 min | Prove pocket use before committing to a case. Enable pocket saving/Precise Location; test foreground, locked at 1/5/15 min, power-cycle and out-of-range recovery. | Phone, battery-powered assembly, test log | Captures saved once to correct lists; failures distinguished from missing feedback. |
| 7 · 1–2 hr + print queue | Measure final wired assembly; CAD and print a fit tray, then shell. | Calipers, CAD/slicer, printer, actual cable/fasteners | Button returns freely; USB/switch accessible; gentle lid closure; no pressure on battery. |
| 8 · 1–2 hr | Transfer proven wiring to compact supported carriers; insulate, mount, and close. | Fine-tip iron/extraction, flux, cutters/strippers, tweezers, holder, heat-shrink/Kapton, thin motor tape, screwdriver | No exposed joints/pinched wires/rattles; shell carries button/keyring forces; closed-case actions and charging still pass. |
| 9 · 30 min walk + runtime | Walk: 5 singles + 5 doubles with phone pocketed; inspect records, reopen app/export CSV; measure runtime. Test with users and record design changes. | Complete clicker/phone; meter/logger for runtime | Initial field target: ≥8/10 saved once, correct list, within a declared useful tolerance (start with 30 m); all misses/extras logged. Runtime measured. |

## Session boundaries

Next visit: aim for steps 1–3; begin step 4 only with time for proper checks. If the replacement is absent, finish motor/power work and record cable-free action tests as pending. A missing peak-current instrument blocks electrical qualification; use the time for measurements/layout.

Fabrication visit: steps 7–8, after electronics and pocket checks. Field/demo: step 9. Allow one case revision.

At each stop, save one wiring photo, measurements/result, blocker, and exact next action in [VALIDATION](VALIDATION.md) and [BUILD_STATE](BUILD_STATE.md). Battery/charge/current requirements are in [ASSEMBLY_GUIDE](ASSEMBLY_GUIDE.md).
