# Wiring and bench reference

Sequence/tools: [BUILD_PLAN](BUILD_PLAN.md). Status: [BUILD_STATE](BUILD_STATE.md). **Complete product proposal and official-source audit:** [PRODUCT_CIRCUIT](PRODUCT_CIRCUIT.md), existing parts, no added 104, physical qualification pending. Its limits/release gates govern portable integration. **Current bench wiring:** [BREADBOARD_LAYOUT](BREADBOARD_LAYOUT.md), separate USB/motor supplies. The battery wiring below is a later stage.

**Latest testing rule:** no re-testing published component specifications. Use [MOTOR_RESEARCH](MOTOR_RESEARCH.md) to identify actual unknowns. Earlier blanket requests to measure specified charger setpoints/termination are superseded; only unknown interactions or an actual anomaly justify those measurements.

## Connections

`SWITCHED_BAT+` is battery positive after the slide switch. `MOTOR−` is a switched collector node, not ground.

| From | To |
| --- | --- |
| Protected battery + | Verified slide-switch common |
| Selected switch throw | SWITCHED_BAT+: board BAT+ and motor + |
| Battery − | Board BAT− / common GND |
| Momentary button | D1 ↔ button ↔ GND; internal pull-up |
| D4 (prepared firmware; high HIGH drive) | 1 kΩ → transistor base B |
| Base B | 10 kΩ → GND |
| Emitter E | GND |
| Collector C | Motor − |
| 1N4148 banded cathode | Motor + |
| Diode unbanded anode | Motor − / collector |
| 100 nF ceramic, if needed after noise checks | Across motor terminals; short leads; omitted for current bench attempt |
| Optional 47–100 µF bulk capacitor | + to SWITCHED_BAT+, − to GND |

For exact **onsemi PN2222ABU**, flat face toward you, leads downward: **E–B–C left to right**. Place each lead on a separate breadboard net. Other “2N2222” packages can differ. [Datasheet](references/onsemi-pn2222a.pdf).

USB at top, components toward you: D1 is second left edge pad; **D4/SDA fifth left**; GND second right. Prepared firmware uses D4/P0.04 in `OUTPUT_S0H1` mode for the 1 kΩ base-resistor load; the previously uploaded disabled build still uses D2. Verify underside BAT pads from the [official pinout](https://wiki.seeedstudio.com/XIAO_BLE/), not a mirrored guess. [Local front image](images/xiao-nrf52840-official-pinout.png).

## Motor qualification

- Current stage after the 50 mA motor-only pass: [manual-jumper transistor test](TRANSISTOR_BENCH_TEST.md), without chip, battery or capacitor. Use its own hole map; do not mix with the later chip-connected layout.
- Confirmed bench supply: **Keysight U8031A**. Earlier E3631A/+6V-channel instructions do not apply. For the first isolated motor test, keep chip/USB/battery and transistor path disconnected. Ensure all outputs OFF; select **1** below the knob, use **Display Limit** and **Voltage/Current** to set **3.00 V / 0.10 A**, then leave output OFF while wiring. Use the leftmost pair labelled **OUTPUT 1 (+/−)**, not green earth or the fixed 5 V pair. Toggle only **Output 1 On/Off** for the brief test. [Manufacturer manual](references/keysight-u8030a-user-guide.pdf), printed pp. 27–28, 38–39.
- [FIT0774](https://www.dfrobot.com/product-2297.html): 1.5–4.2 V; 50 mA rating at 3 V does not establish startup current.
- Later chip-connected stage: battery detached; USB powers board; current-limited bench supply powers only motor branch; negatives share GND. Do not join that supply to board BAT+ while USB is attached.
- A current-limited bench supply provides adjustable voltage and a current ceiling; when reached, it reduces voltage. Use the model's manual to set the limit before connecting the motor. [How current limiting works](https://www.keysight.com/zz/en/use-cases/characterize-power-supply-current-limits.html).
- Begin motor characterization at 3.0 V with ~100 mA current limit; repeat at 3.7/4.2 V. Current limiting means unconstrained startup current remains unknown. Capture peaks with suitable equipment.
- Inspect driver before controlled D4 pulses using matching firmware. Motor must stay off at boot/reset. Record startup/running current, transistor collector–emitter drop (project target ≤0.3 V), and any supply dip/reset. The purchased 1 kΩ base resistor still needs validation; never bypass it. No-capacitor operation is an unverified bench attempt; observe transients before electrical sign-off and revisit suppression if measurements or stability fail.
- Only then enable motor feedback. Check phone records plus buzz patterns: Liked 150 ms; Want 90/90/90 ms on/off/on; undo 450 ms; error three 60 ms pulses. `l` is LED-only.
- Repeat total-current measurements on battery with USB absent. Project target <120 mA including startup, leaving margin to the cell's 150 mA maximum. Excess current/poor switching requires a revised driver/supply before integration.

## Battery and charging

- [ASR00003](https://tinycircuits.com/products/lithium-ion-polymer-battery-3-7v-150mah): protected 3.7 V/150 mAh; full charge 4.2 V; maximum charge and discharge 150 mA. Uses JST SH, not PH. Prefer a supported mating connector; verify polarity by voltage measurement.
- Unplug USB and physically disconnect the cell before soldering, rewiring, or continuity tests. Preserve the battery protection and connector; use a supported mating connector for assembly. Never cut both cell wires together or solder to pouch/tabs. Stop for damage, swelling, or abnormal heat.
- Measure voltage across; current in series. Never put a current-mode meter across the cell. Check shorts, switch common/throw, and connector polarity before inserting it.
- OFF disconnects battery positive. USB can still power the board and BAT_SW through its charger; OFF is not isolation for servicing. Charge with battery ON, motor inhibited and enclosure open for first verification. USB motor inhibition is a pending firmware requirement, including non-enumerating chargers.
- Firmware selects `PIN_CHARGING_CURRENT` as no-pull input for ~50 mA; battery-divider enable stays LOW. [Seeed guidance](https://wiki.seeedstudio.com/XIAO_BLE/#battery-charging-current). Accept specified charging behavior; inspect configuration rather than re-measuring its rated setpoint. Investigate only actual abnormalities or unknown load interactions. If diagnostic current measurement is needed, battery-branch current and USB input current are different quantities.
- Never power motor from GPIO or connect cell + to 3V3/5V. Battery-only startup does not prove cable-free captures while button is absent.
- The battery PCM overcurrent trip is 2.8–3.5 A, not the cell's 150 mA rating. Stock board charging has no pouch-temperature sensing; current prepared firmware has no calibrated low-battery cutoff. Resolve these product limits and charge-voltage/temperature requirements as described in [PRODUCT_CIRCUIT](PRODUCT_CIRCUIT.md) before portable sign-off.

## Case constraints

Measure battery seams/protection/leads, actual switch travel, driver, connector, and USB plug. The 34 × 32 mm concept is unverified. Use supported switch/board ledges, rigid battery separator, non-compressive tray, wire channels, restrained driver, thin motor bond to rigid wall, antenna clearance, and removable lid. Keep screws/keyring/button loads off the cell. Dry-fit unpowered; closure must require no force. Repeat action/reconnect/charging checks after closure.
