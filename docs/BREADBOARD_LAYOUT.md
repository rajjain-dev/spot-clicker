# Breadboard setup — XIAO and motor, no added capacitor

Prepared November 10, 2026. **Proposed, physically untested.** Target: USB command → phone save/undo → motor feedback, using the existing parts. The motor-only test passed at 3.00 V / 50 mA; transistor and chip-connected tests remain pending. Battery, slide switch and missing replacement button stay outside this bench test.

Latest rule: accept specified component ratings/values; test only true unknowns. See [MOTOR_RESEARCH](MOTOR_RESEARCH.md) for exact product and comparable manufacturer data. The external capacitor is not established as mandatory; there is no confirmed noise-caused failure in this build.

USB powers the XIAO. **U8031A Output 1 powers only the motor branch: 3.00 V / 0.10 A limit.** Negatives share ground. No motor-supply positive connection to XIAO BAT+, 3V3, 5V or GPIO. Use OUTPUT 1's actual +/− posts, not green earth or the fixed 5 V output. Existing green/grey lead colours are assigned below, not a polarity standard.

Omit the external **104 = 100 nF = 0.1 µF** capacitor for this controlled attempt. Keep the required flyback diode and both resistors. Short, gently twisted motor wires and separation from the antenna/control wire help reduce noise; separate supplies do not eliminate it. A capacitor or circuit change may still be needed if measurements/stability fail. The diode handles winding-current turn-off. **FIT0774 brush construction is unconfirmed:** its [manufacturer page](https://www.dfrobot.com/product-2297.html) lists voltage/current/speed but does not specify brushes or internal commutation. Small coin motors exist in both brushed and brushless forms ([manufacturer comparison](https://www.precisionmicrodrives.com/ab-028)); brush noise is therefore a possible mechanism, not a verified property or measured problem of this FIT0774. [General motor-noise guidance](https://www.pololu.com/docs/0j15/9).

## One hole map for both stages

Standard a–e / f–j breadboard with at least 22 rows: each five-hole half-row connects internally; the centre gap separates the halves. **Side rails unused.** This preserves the [manual transistor test](TRANSISTOR_BENCH_TEST.md) map. Verify actual breadboard connectivity first.

**Before assembling or changing wiring:** USB unplugged, supply output OFF, supply leads disconnected, battery detached. Support board/motor; use secure pin-ended tails for thin motor wires. Do not force bare strands into holes or balance jumper pins against bare XIAO pads.

| Part | Holes |
| --- | --- |
| Exact onsemi PN2222ABU | E → b7; B → b8; C → b9 |
| 1 kΩ | d8 ↔ g8 |
| 10 kΩ | d14 ↔ g14 |
| 1N4148 | Verified band/cathode → g18; anode → g22 |
| Motor | Positive/red → h18; negative/other → h22 |
| OUTPUT 1 +, assigned green lead | Pin-ended tail → j18 |
| OUTPUT 1 −, assigned grey lead | Pin-ended tail → i2 |

For this exact [PN2222ABU](references/onsemi-pn2222a.pdf), flat face toward you, leads down = E–B–C. In the top-view hole map its flat face points right, with E/B/C in rows 7/8/9. Verify actual marking; other transistor packages can differ. Gently spread leads; do not force the body flush.

Fixed insulated jumpers:

| Purpose | Holes |
| --- | --- |
| Base to pull-down | a8 ↔ a14 |
| Collector extension | c9 ↔ c22 |
| Collector across gap | e22 ↔ f22 |
| Emitter ground | a7 ↔ a2 |
| Ground across gap | e2 ↔ f2 |
| Pull-down ground | j2 ↔ j14 |

## 1. Driver check, chip disconnected

1. Match identified parts to their published pinouts/values; no resistor-value re-test. If the actual diode's polarity is genuinely unidentified, identify it out of circuit using the marking or meter diode mode. Inspect assembled wiring for shorts/misconnections; this is an assembly check, not re-verification of component ratings.
2. With **no temporary i8–i18 jumper**, connect supply at the stated limits and enable briefly. Motor must remain OFF. Switch output OFF and disconnect before changes.
3. Add **i8 ↔ i18** unpowered. Enable for 1–2 seconds: motor should start promptly. Record supply current and collector–emitter voltage (meter in voltage mode: red c9, black c7). Target: running near the previous 50 mA result and VCE ≤0.3 V. Persistent CC, no start, heating or high VCE → OFF and diagnose; do not raise limits or bypass 1 kΩ.
4. Output OFF, disconnect leads and **remove i8–i18**. This ON jumper must never coexist with a chip control connection. Startup current remains unqualified by this current-limited check.

## 2. Add XIAO after the driver passes

Keep the map above. With all power disconnected, add:

| From XIAO | Breadboard |
| --- | --- |
| **D4 / SDA**, fifth left pad down with USB at top | i8, 1 kΩ input |
| GND, second right pad down | h2, common ground |

Board may stay supported beside breadboard. Motor current returns directly through the transistor to supply negative; the XIAO ground wire is a reference connection. [Official pinout](https://wiki.seeedstudio.com/XIAO_BLE/).

**Firmware must match D4.** Previously uploaded firmware uses D2 with motor disabled. Prepared source uses D4/P0.04 and `OUTPUT_S0H1`, with `MOTOR_ENABLED = false` until the driver passes. The 1 kΩ base resistor draws about 2–3 mA; high drive supports this load and D4 avoids D2/P0.28's standard-drive recommendation. [Nordic GPIO specification](https://docs.nordicsemi.com/r/bundle/ps_nrf52840/page/gpio.html), [pin recommendations](https://docs.nordicsemi.com/r/bundle/ps_nrf52840/page/pin.html).

1. After driver approval from actual measurements, with motor supply disconnected, set `MOTOR_ENABLED = true`; compile/upload the prepared firmware for `Seeeduino:nrf52:xiaonRF52840`. Verify `Device programmed` in the upload log. Do not use an old D2 motor-enabled binary.
2. Power XIAO by USB first, OUT1 OFF. Pair in the phone app; enable Clicker save feedback; wait for Ready to save. Close Arduino Serial Monitor. Run `python3 scripts/clicker-usb.py s`: confirm motor enabled, control D4 and phone subscribed.
3. Reconnect supply with output OFF; recheck polarity and removal of i8–i18. Enable OUT1: motor must stay OFF at idle and during a board reset. Unsolicited buzz → OFF.
4. Run `python3 scripts/clicker-usb.py 1 --wait 16`. Confirm new Liked record, feedback code 1, then 150 ms buzz. Inspect the phone before retrying an uncertain action; helper exit code alone does not mean a save.
5. Use the same helper for `2` (Want: two 90 ms buzzes) and `3` (undo: one 450 ms buzz). Deliberately disconnect phone, send one action: no save/queue; three short error buzzes. Reconnect. `l` stays LED-only.
6. Repeat 10 Liked→undo pairs and 10 Want→undo pairs, waiting for each result. Record phone records, starts, current, resets/BLE drops and any heating. Any anomaly → OFF and diagnose. Turn motor supply OFF before unplugging USB; disconnect both sources before touching wiring.

## Before the final portable prototype

A stable bench run does not prove absence of voltage spikes; observe switching transients with a scope before electrical sign-off. This guide proves only the USB-operated bench loop. Replacement button, battery/charging/current, cable-free actions and pocket behavior remain pending in [BUILD_PLAN](BUILD_PLAN.md). A current-limited 3 V pass cannot qualify a 4.2 V cell. Do not increase voltage as part of this guide. Record actual results in [VALIDATION](VALIDATION.md); preparation/compilation is not a physical pass.
