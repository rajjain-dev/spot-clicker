# Validation

Tests recorded October 31–November 14, 2026. Raj reconfirmed chip/app communication and return response November 8.

## Passed

- November 10 | User reports USB-only motor breadboard assembled, USB connected, “nothing happens” | Mac detected /dev/cu.usbmodem101; issued `python3 scripts/clicker-usb.py s --port /dev/cu.usbmodem101 --wait 2` | firmware responded; BLE initialized yes, phone connected yes, notifications subscribed yes, awaiting feedback no, motor output enabled no | USB/firmware/phone communication observed; no motor actuation, load measurement, physical wiring inspection or driver pass implied

- November 9: Raj confirmed motor vibration and **0.05 A (50 mA) running current** after clip-contact troubleshooting, with 3.00 V / 0.10 A test settings. Startup peak and transistor operation remain unverified.
- Swift core tests: storage/edit/move/delete, undo, location validation, write failure/corruption, CSV, BLE duplicate/wrap/reconnect. Simulator build and two UI tests passed.
- iPhone 14/iOS 26.2 installation renewed in place November 14. Verified that `spots.json` remained present with the same size and modification timestamp. The first launch was denied by iOS security; a retry launched successfully. The new profile expires November 21 at 5:19 p.m. New York time.
- Plain nRF52840 blink/upload/USB restart; Seeed nRF52 Boards 1.1.13.
- Initial clicker firmware compiled/uploaded: 120,936 B flash, 13,984 B RAM. Eleven host gesture scenarios passed.
- November 10 preparation only: revised source selects D4/P0.04 with `OUTPUT_S0H1`, motor still disabled. Compiled for `Seeeduino:nrf52:xiaonRF52840`, Seeed 1.1.13: 121,024 B flash, 13,984 B RAM. Not uploaded; no new physical pass. Bench guide attempts operation without an added 104 capacitor after the manual driver check.
- USB status/LED command/disconnected-action rejection passed.
- Chip → app delivery and app → chip response passed: paired/subscribed USB Liked event, type 1/sequence 0 → phone feedback 1; Raj confirmed the new spot. This integration stage is complete.
- November 10 | XIAO alone on USB, after a solder blob touched the RF shield can | visual check; continuity pad↔shield, neighbouring pads, 3V3↔GND, 5V↔GND; 3V3 DC voltage; USB status; phone Liked save | Raj reported all passed (no shorts, about 3.3 V, status reply, save) | board OK; resume the driver bench test

## Pending

Follow [BUILD_PLAN](BUILD_PLAN.md): motor/current/charging; physical gestures; battery-only operation; enclosure; locked-phone/reconnection; walk/runtime. Check remaining double/undo behavior alongside motor feedback.

Also record Bluetooth off/on, force quit/reopen, phone restart, denied-location recovery, notification/Focus effects, and offline saving. Do not infer these from the first foreground save.

## November 12 USB-only motor test v5

- Built for `Seeeduino:nrf52:xiaonRF52840` with Seeed nRF52 Boards 1.1.13. Used 128,852 B flash and 14,500 B RAM. All 11 host gesture scenarios and 52 motor control checks passed. Uploaded over `/dev/cu.usbmodem101`; the uploader reported `Device programmed` and the board reported v5.
- In one console session, `pulse 200 3 150` replaced `on 2000`, then ran again without a reconnect. The board reported completion for the 60% custom pattern and `play want` at 100%. It acknowledged `auto on` and `auto off`, and `quit` stopped a running timed buzz. The final status showed increasing uptime, the phone connected/subscribed, motor off, power at 100%, and automatic feedback vibration off.
- The USB replies confirm command handling. Physical vibration strength at 60% and the motor response to a live phone event await verification.
- Raj reported no felt vibration on v4 and during the v5 reruns at 100%, including the 10-second command. The latest command reported `MOTOR done; D4 LOW`, and v5 uptime advanced from 28.6 s before the command to 78.7 s afterward. Voltage at the motor leads during a pulse is pending.
- Live physical button test: a single press sent `BUTTON type=1` and returned phone feedback `1` (Liked). A double press sent `BUTTON type=2` and returned phone feedback `2` (Want to go). A subsequent 10-second motor command at 100% reported `MOTOR done; D4 LOW`. Physical vibration on this rerun has yet to be reported.
- Raj measured 0 V across the motor during a 100% pulse, 3.3 V from motor positive to XIAO GND at idle, and 3.3 V from D4 to GND during a pulse. On the first base-measurement run, USB dropped after the start acknowledgment. The board reappeared with about 6 s of uptime and the motor off. On completed 10-second reruns, Raj measured 0.6–0.9 V at the base and 3.3 V continuously at the collector, both relative to XIAO GND. Raj confirmed continuity from emitter to XIAO GND and collector to motor negative with power disconnected. The restart cause remains unknown.
- November 14: v5 completed another 10-second command at 100%. Raj felt no vibration. No new voltage readings or transistor replacement were confirmed for this run.
- November 14 follow-up: Raj measured 3.29 V from D4 to the transistor base during a 20-second pulse and 13.2 MΩ across that path with power disconnected, where about 1 kΩ is expected. In the next 10-second USB test at 100%, Raj confirmed motor vibration and the board reported `MOTOR done; D4 LOW`. The exact repair and post-repair resistance were not reported.

## November 10 USB-only motor tests — live hardware commands

Configuration reported assembled by Raj: XIAO on USB; 3V3 → existing PN2222ABU/1N4148 driver and FIT0774; D4 through 1 kΩ, 10 kΩ pulldown, no added 104, battery and bench supply excluded. Commands below do not send click/save events.

| Build / action | Direct evidence | User observation / conclusion |
| --- | --- | --- |
| v2, 150 ms `m` | Compiled 121,680 B flash / 13,984 B RAM; upload logged `Device programmed`; command printed start/completion; post-status uptime 40.7 s, pulse used yes, phone connected/subscribed | “it was very very light more power” |
| v3, 500 ms `m` | Compiled 121,792 B flash / 13,984 B RAM; upload logged `Device programmed`; command completed; later status uptime 175.4 s, pulse used yes, phone connected/subscribed | “No vibration”; no cause or damage established |
| v4, requested 10-second `m --wait 12` | Compiled 122,104 B flash / 13,984 B RAM; upload logged `Device programmed`; GPIO digital readback HIGH; `TEST MOTOR complete after 10000 ms; D4 commanded LOW`; subsequent status uptime 42.9 s, pulse used yes, phone connected/subscribed | “it worked perfectly” — **USB-powered motor functional test passed** |
| v4, user-requested rerun of the same 10-second test | Same firmware, no upload; before test uptime 9.2 s and pulse unused; command GPIO readback HIGH and completion after 10,000 ms; subsequent status uptime 45.8 s, pulse used yes, phone connected/subscribed | Software execution and automatic return LOW confirmed; no new physical observation reported yet |
| v4, second user-requested rerun | Same firmware, no upload; before test uptime 30.3 s and pulse unused; GPIO readback HIGH; completion after 10,000 ms, D4 LOW; subsequent status uptime 66.5 s, pulse used yes, phone connected/subscribed | Software execution and automatic return LOW confirmed; no new physical observation reported yet |

The last test's consumed-pulse flag and continuing uptime show no observed restart between that command and the subsequent status query. Post-test phone connection was observed; uninterrupted Bluetooth connectivity was not separately instrumented. GPIO readback is a digital pin observation, not a motor-voltage reading. No motor current, rail waveform, loaded VCE, temperature or electrical limit was measured. Automatic phone-feedback vibration remains disabled; portable battery policy remains pending. Only the pulse duration changed between these tests; no stronger supply voltage was selected.

## November 10 product-circuit review — documentation only

[PRODUCT_CIRCUIT](PRODUCT_CIRCUIT.md), schematic and machine-readable netlist prepared for existing parts without an added 104. Netlist checks covered battery/switch routing, D4/1 kΩ/base path, 10 kΩ pull-down, E/C connections, flyback polarity and D1 button path. Manufacturer sources and unverified identities/specifications are listed in the proposal. No circuit was physically built, scoped, charged or newly qualified during this review. Low-voltage cutoff, USB charging inhibit and charging-temperature limits remain unresolved product requirements.

## Record only new evidence

November 10 testing rule: do not re-test published component ratings/values or already passed motor-only running current. [MOTOR_RESEARCH](MOTOR_RESEARCH.md) records manufacturer comparator measurements and numerical limits. No FIT0774-caused noise/reset/damage is established. Only true unknowns, system behavior and observed anomalies warrant new experiments.

For each checkpoint add: `date | configuration | action/measurement | result | issue/change/next step`.

Keep electrical values with voltage, USB/battery state, and measurement method: motor startup/running current; transistor drop; total battery idle/peak; charging current/voltage/temperature; runtime. Keep dimensions with the print revision. Log user tests as tester/task/confusion or quote/design change/retest. Blank or absent results mean unverified.
