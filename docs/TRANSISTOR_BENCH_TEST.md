# Current test: transistor driver, no chip

Replaces the motor-only wiring. U8031A OUT1: **3.00 V / 0.10 A**. Chip, USB, battery and capacitor remain disconnected. Side rails unused. Assemble/change wires only with output OFF and supply leads disconnected; clip jaws grip bare jumper metal.

| Part | Holes |
| --- | --- |
| PN2222ABU | E b7; B b8; C b9 |
| 1 kΩ | d8–g8 |
| 10 kΩ | d14–g14 |
| 1N4148 | Verified cathode/band g18; anode g22 |
| Motor | Positive/red h18; negative/other h22 |
| Green lead from OUTPUT 1 + | j18 via jumper tail |
| Grey lead from OUTPUT 1 − | i2 via jumper tail |

Fixed insulated jumpers: **a8–a14; c9–c22; e22–f22; a7–a2; e2–f2; j2–j14**. The resistors remain parallel across the centre gap. Verify E/B/C from the exact transistor marking/datasheet, and verify diode polarity before power.

OFF check: no temporary control jumper. Reconnect supply and enable OUT1 briefly; motor should stay off. Switch OUT1 OFF.

ON check: with power disconnected, add **i8–i18**. Reconnect and enable OUT1 for 1–2 seconds; motor should run. Switch OFF before removing the jumper. This applies the 3 V supply through the existing 1 kΩ base resistor; never bypass that resistor. This jumper must be removed before a future chip connection.

Record current and collector–emitter voltage while ON (project target ≤0.3 V), plus off-state behavior. Weak/no buzz, persistent CC, heating or excessive transistor drop → OFF and diagnose; do not raise limits. A buzz alone does not qualify startup-current margin or the eventual battery circuit. Initial motor-only current already passed at 50 mA; do not repeat that stage.

Topology reference: [ROHM low-side NPN switching](https://techweb.rohm.com/product/transistors-diodes/transistors/27354/). This is a proposed bench layout, not yet physically verified. After this driver passes, follow the [November 10 chip-connected bench guide](BREADBOARD_LAYOUT.md), which preserves this hole map and attempts separate USB/motor supplies without an added 104 capacitor. Remove the temporary i8–i18 ON jumper before connecting XIAO D4.
