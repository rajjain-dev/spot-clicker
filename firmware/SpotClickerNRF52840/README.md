# Active firmware

**USB-motor-test v8** runs on the plain XIAO nRF52840 (`Seeeduino:nrf52:xiaonRF52840`, Seeed nRF52 Boards **1.1.13 non-mbed**, Bluefruit). It drives the motor through **D4 / P0.04** in high drive mode (`OUTPUT_S0H1`). The XIAO **3V3** rail feeds the motor driver in the USB-only build. [USB wiring](../../docs/USB_MOTOR_MVP.md) · [Upload and test record](../../docs/BUILD_STATE.md)

The onboard LED flashes blue for 180 ms on each debounced physical press, including both taps of a double press and the start of a hold. Quick taps get a 75 ms dark gap between flashes. The flash works with the phone disconnected. Green indicates a confirmed action, and red indicates an error or uncertain result.

Automatic vibration is on at startup. A single press requests Liked, a double press requests Want to go, and an 800 ms hold requests undo. The clicker plays the success pattern when the iPhone confirms the result.

| Result | Vibration |
| --- | --- |
| Liked | One 300 ms buzz |
| Want to go | Two 250 ms buzzes with a 180 ms gap |
| Undone | One 750 ms buzz |
| Error or uncertain result | Three 180 ms buzzes with 140 ms gaps |

## USB

Close Arduino Serial Monitor before the helper; one port owner at a time. Serial: 115200 baud, one command per line (Serial Monitor: any line ending works).

| Command | What it does |
| --- | --- |
| `1`, `2`, `3`/`h` | Liked, Want to go, undo (sent to the phone) |
| `s`, `?`, `l` | status, help, blue LED test only |
| `on` | motor on until `off`; stops by itself after 60 s |
| `on 2000` | on for 2000 ms (up to 600000) |
| `off` or `x` | motor off now |
| `pulse 200` / `pulse 200 3 150` | one 200 ms buzz / three 200 ms buzzes with 150 ms gaps (gap defaults to the buzz time) |
| `pattern 100 50 100 400 x3` | ON OFF ON OFF … in ms, up to 32 steps, optional repeat `x2`…`x1000` |
| `power 60` | strength 10–100 %; below 100 the motor is driven by about 31 kHz PWM; `power` alone reports it |
| `play liked` / `want` / `error` / `undone` | the phone-feedback patterns, on the motor |
| `auto on` / `auto off` | turn automatic vibration on or off for the current boot |
| `m` | 10-second buzz, as in v4 |

Each motor command replaces the one running, and a whole command is limited to 10 minutes. Motor commands send no click and save no spot.

```sh
python3 scripts/clicker-usb.py console          # live control: type commands, quit to leave (motor turns off)
python3 scripts/clicker-usb.py pulse 200 3 150  # one command; waits until it finishes
python3 scripts/clicker-usb.py s
python3 scripts/clicker-usb.py 1 --wait 16
```

Add `--port /dev/cu.usbmodem101` if needed; recheck the actual port. Pair in Clicker → Set up a clicker; wait for Ready to save; enable Clicker save feedback. One outstanding action; no disconnected queue/retry. A 15-second timeout is uncertain: inspect the phone before retrying. One-byte feedback cannot perfectly correlate very late replies.

The helper waits as long as a timed motor command takes, then exits. Ctrl-C during that wait sends `off`. Plain `on` returns right away and leaves the motor running until `off` or the 60-second stop. Unlike v4, closing the USB serial session does not stop a running buzz; every buzz has its own end time.

Status reports the motor state, the time left, the power and whether automatic vibration is on. These are firmware states, not motor voltage or current measurements. History: v2 used a 150 ms pulse (Raj reported very light vibration), v3 500 ms (no vibration), v4 one 10-second pulse per boot. In the [v5 hardware check](../../docs/VALIDATION.md#november-12-usb-only-motor-test-v5), the board accepted `power 60` and reported completion of a pattern at that setting. Physical vibration strength at 60%, loaded driver behavior, and startup/shared-rail demand remain unverified.

## Contract

Name `SpotClicker`; UUIDs:

- Service: `7A1C0001-5B3E-4D2A-9F10-3C5D8E2B6A01`.
- Click: `7A1C0002-5B3E-4D2A-9F10-3C5D8E2B6A01`; read/notify, `[type, uint8 sequence]`; types 1/2/3 = Liked/Want/undo.
- Feedback: `7A1C0003-5B3E-4D2A-9F10-3C5D8E2B6A01`; write/write-without-response; 1/2/3/4 = Liked/Want/error/undone.

The D1–GND button shares the USB dispatcher. It uses a 25 ms debounce, a 350 ms double-press gap, and an 800 ms hold threshold. D4 starts LOW. A running manual motor command takes priority over automatic vibration. D4's high drive supplies the roughly 2–3 mA base-resistor load. Low charging mode and battery-divider LOW are explicit. This USB-only test build uses no battery.

## Build notes

Use Arduino IDE's selected target above. This Mac's installed package has a `platform.local.txt` UF2-wrapper override using `/Library/Frameworks/Python.framework/Versions/3.11/bin/python3`; package updates can remove it. Verify upload logs say `Device programmed`; outer exit code alone was unreliable. Double-reset for bootloader recovery.

Host gesture checks from project root:

```sh
mkdir -p build
DEVELOPER_DIR="$HOME/Downloads/Xcode.app/Contents/Developer" xcrun clang++ -std=c++11 -Wall -Wextra -pedantic firmware/tests/ButtonGesturesTest.cpp -o build/button-gesture-tests
build/button-gesture-tests
```

Motor command checks (parser and timing), from project root:

```sh
DEVELOPER_DIR="$HOME/Downloads/Xcode.app/Contents/Developer" xcrun clang++ -std=c++11 -Wall -Wextra -pedantic firmware/tests/MotorControlTest.cpp -o build/motor-control-tests
build/motor-control-tests
```
