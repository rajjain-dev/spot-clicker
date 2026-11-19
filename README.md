# Spot Clicker

A Bluetooth clicker that saves your current iPhone location as a map pin. A single press saves **Liked**, a double press saves **Want to go**, and a hold undoes the latest capture within 10 minutes. The iPhone stores spots locally and sends confirmation back to the clicker for LED and vibration feedback.

## Submission contents

This repository contains the firmware, iPhone application source, and supporting hardware design files for the Spot Clicker prototype.

| Deliverable | Location |
| --- | --- |
| iPhone app source (Swift / SwiftUI) | [ios/SpotClicker](ios/SpotClicker/) |
| Ready-to-open Xcode project | [ios/SpotClicker.xcodeproj](ios/SpotClicker.xcodeproj/) |
| Active XIAO nRF52840 firmware (Arduino C++) | [firmware/SpotClickerNRF52840](firmware/SpotClickerNRF52840/) |
| App and firmware tests | [ios/Tests](ios/Tests/), [ios/UITests](ios/UITests/), [firmware/tests](firmware/tests/) |
| USB control and design-generation tools | [scripts](scripts/) |
| Enclosure CAD source and STL files | [cad](cad/) |
| Wiring, circuit diagrams, assembly and validation records | [docs](docs/) |

To download everything as a ZIP, use **Code → Download ZIP** on GitHub.

## Run the iPhone app

Requires macOS, Xcode with an iOS 18 or newer SDK, and an iOS 18 or newer simulator or iPhone. No backend, API keys, or third-party app packages are required.

1. Open `ios/SpotClicker.xcodeproj` in Xcode.
2. Select the **SpotClicker** scheme and an iPhone simulator, then Run.
3. For a physical iPhone, select your own development team under **Signing & Capabilities**. If needed, choose a unique bundle identifier. Keep the existing identity when renewing an existing installation, and export saved captures before uninstalling.
4. For simulator GPS, select `ios/Demo/WestVillage.gpx` as the simulated location. Example pins are also available in the Clicker screen. Bluetooth hardware pairing requires a physical iPhone.

The app includes map, list and detail screens, editing, CSV export, local storage, and clicker setup. Use **Clicker → Set up a clicker** to pair the device, wait for **Ready to save**, and enable **Clicker save feedback**.

The generated Xcode project is included. XcodeGen is needed only to regenerate it after changing `ios/project.yml`.

## Build the firmware

The active sketch is `firmware/SpotClickerNRF52840/SpotClickerNRF52840.ino`, with `ButtonGestures.h` and `MotorControl.h` in the same folder.

- Board: standard **Seeed Studio XIAO nRF52840**.
- Arduino board package: **Seeed nRF52 Boards 1.1.13**, non-mbed / Bluefruit.
- Target identifier: `Seeeduino:nrf52:xiaonRF52840`.
- Button: **D1 to GND**. Motor-driver control: **D4**.
- Current prototype: **USB-only**, with the motor driver supplied from the XIAO **3V3** rail. Follow the [USB wiring guide](docs/USB_MOTOR_MVP.md).

Open the active sketch in Arduino IDE, select the board above and its USB port, then compile and upload. See the [firmware README](firmware/SpotClickerNRF52840/README.md) for dependencies, USB commands, Bluetooth UUIDs, gesture timing, and build notes.

## Checks

From the repository root on a Mac with Xcode installed:

```sh
bash scripts/check.sh
```

This runs the Swift core tests and builds the app for the simulator without code signing. Run the UI tests from Xcode with **Product → Test**. Host firmware checks require a C++11 compiler:

```sh
mkdir -p build
c++ -std=c++11 -Wall -Wextra -pedantic firmware/tests/ButtonGesturesTest.cpp -o build/button-gesture-tests
build/button-gesture-tests
c++ -std=c++11 -Wall -Wextra -pedantic firmware/tests/MotorControlTest.cpp -o build/motor-control-tests
build/motor-control-tests
```

## Prototype status and design records

The current firmware is **USB-motor-test v8**. Bluetooth delivery and app confirmation have been demonstrated; motor vibration has been observed in the USB prototype. Physical confirmation of the latest automatic feedback patterns, final enclosure fit, battery/charging integration, and field/runtime testing remain pending. See [current state](docs/BUILD_STATE.md), [validation](docs/VALIDATION.md), and the [build plan](docs/BUILD_PLAN.md) for measured results and outstanding work.

The [product circuit proposal](docs/PRODUCT_CIRCUIT.md) describes the proposed portable circuit and unresolved limits. The [enclosure guide](docs/COMPACT_ENCLOSURE.md) documents the CAD and fit assumptions; the included files do not establish a physically validated final assembly.

`firmware/BoardBlink/` and `firmware/SwitchInputTest/` are diagnostic sketches. `firmware/SpotClicker/` is the earlier ESP32 sketch, `firmware/archive/` contains historical firmware, and `phase2/` contains deferred backend/reference code. These are separate from the active nRF52840 firmware and local-only iPhone app.
