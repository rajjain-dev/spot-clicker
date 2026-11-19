# FIT0774: manufacturer evidence and true unknowns

November 10, 2026. Raj's current rule: **accept published component specifications; do not schedule tests to re-verify them. Test only unpublished quantities, unknown interactions or an observed malfunction.** Configuration/wiring inspection is distinct from re-measuring a manufacturer's rating. Earlier blanket requests to measure resistor values, charger setpoints or other established ratings are superseded by this rule.

## Exact product and available documentation

**DFRobot Mini Vibration Motor (10*2.7mm), SKU FIT0774.** [Official product/specification page](https://www.dfrobot.com/product-2297.html).

Established: 10 × 2.7 mm, 3 V rated, 50 mA rated, 1.5–4.2 V operating range, 11,000 ±2,500 rpm, stated continuous service life 72 hours at 3.7 V. The existing 50 mA / 3 V running observation already agrees; do not repeat it to establish the same rating.

No motor-specific public official manual, engineering datasheet, driver schematic or capacitor instruction was found in the product page, its links, DFRobot wiki or exact-model searches. The [official dimensional drawing](https://dfimg.dfrobot.com/enshop/image/data/FIT0774/Dimension_0x0.jpg.webp) carries LUXS MOTOR branding, but no traceable OEM model was identified. Neither branding nor matching dimensions establishes a particular internal motor design.

The page's low-noise description supplies no electrical-noise amplitude, spectrum, dB measurement or test method. FIT0774 brushes, capacitor necessity, startup/stall current and electrical-noise waveform remain undocumented. No reset, Bluetooth failure, overheating or chip damage attributable to FIT0774 has been observed in this project.

## Comparable manufacturers: documented capacitor guidance

[Precision Microdrives' discrete-driver application note](https://www.precisionmicrodrives.com/discrete-driver-circuits-for-vibration-motors) explicitly treats an EMI suppression capacitor as **optional**, describing small-vibrator EMI as generally low. Its guidance is 10–100 pF with PWM; if electrical noise is an issue without PWM, consider 100 nF. The current SpotClicker patterns use individual DC on/off buzzes, not a high-frequency PWM carrier. This is evidence against treating an external 104 as a universal prerequisite; it is not a FIT0774 guarantee.

[PMD AB-005](https://www.precisionmicrodrives.com/ab-005) provides actual scope captures for a same-size 310-103 motor, comparing no capacitor, 100 pF and 100 nF. The vertical scale is 2 V/div. [Original manufacturer figure](https://www.precisionmicrodrives.com/wp-content/uploads/2021/06/310-103-capacitor-effect-on-motor-electrical-noise.original.png).

| Published trace | Approximate visual reading |
| --- | --- |
| Without capacitor | About 15–16 V peak-to-peak; some excursions approach display limits |
| 100 pF | About 10–11 V peak-to-peak |
| 100 nF / 104 | About 1 V peak-to-peak |

These are **rough readings from a manufacturer plot**, not tabulated specifications or measurements of FIT0774. The figure does not fully describe probe location, circuit, bandwidth or loading. These numbers therefore cannot be transferred to the XIAO rail/GPIO, used as expected FIT0774 amplitudes, or treated as a product acceptance threshold. The confirmed result is that suppression changed electrical noise in that particular same-size-motor example. No chip failure is demonstrated there.

## Comparable motor numerical specifications

| Manufacturer/model | Dimensions | Published running current at 3 V | Published startup current at 3 V |
| --- | --- | --- | --- |
| DFRobot FIT0774 | 10 × 2.7 mm | 50 mA rated | Not published |
| Precision Microdrives 310-103 | 10 × 2.7 mm | 58 mA typical; 90 mA maximum | 106 mA typical; 150 mA maximum |
| Vybronics VC1027B001D | 10 × 2.7 mm | 90 mA maximum in datasheet | 120 mA maximum |

[PMD official engineering datasheet](https://precisionmicrodrives.com/cdn/catalog_product/89437681-576e-46e1-97cf-5ae185adeb1c/310-103-datasheet.pdf), pp.3–4; [Vybronics official datasheet](https://www.vybronics.com/wp-content/uploads/datasheet-files/Vybronics-VC1027B001D-datasheet.pdf), pp.3–4. Both comparison motors are documented brushed designs; this does not establish FIT0774 construction.

The comparison establishes that startup on this size of motor is not necessarily its rated running current. It supplies useful planning numbers, **not a guaranteed FIT0774 range**. Do not add the other models' maximum startup current to this circuit's budget as though it were our motor's measured value. Nor can an exact FIT0774 startup current be calculated from its 50 mA operating rating alone.

The two comparison datasheets also give mechanical/acoustic noise around 50 dB(A); Vybronics specifies a 100 mm measurement distance. Audible noise is a separate quantity from electrical interference or a chip-damage threshold.

## Actual system limits and defensible estimates

- **Chip limits, not noise measurements:** Nordic specifies nRF52840 VDD operation at 1.7–3.6 V. Normal System-ON brownout reset is 1.57–1.63 V (1.60 V typical). Small ripple is not automatically a brownout. [Nordic operating conditions](https://docs.nordicsemi.com/r/bundle/ps_nrf52840/page/recommended_op_conditions.html), [POWER electrical specification](https://docs.nordicsemi.com/r/bundle/ps_nrf52840/page/power.html).
- **GPIO boundaries:** at VDD=3.3 V, guaranteed logic LOW is ≤0.99 V and HIGH ≥2.31 V. Absolute GPIO limits are −0.3 V to VDD+0.3 V, hence −0.3 to 3.6 V at 3.3 V VDD. Absolute limits are not an allowed noise budget. [Nordic GPIO](https://docs.nordicsemi.com/r/bundle/ps_nrf52840/page/gpio.html), [absolute maxima](https://docs.nordicsemi.com/r/bundle/ps_nrf52840/page/abs_max_ratings.html).
- **Current compatibility:** Seeed's selected nominal 50 mA charging mode is below the cell's 150 mA charge rating. This published-current comparison needs no experiment. Motor 1.5–4.2 V and the pack's nominal operating span overlap; no nominal-voltage incompatibility has been established. [Seeed charging](https://wiki.seeedstudio.com/XIAO_BLE/#battery-charging-current), [TinyCircuits product specifications](https://tinycircuits.com/products/lithium-ion-polymer-battery-3-7v-150mah).
- **Pack voltage-drop estimate:** using the pack datasheet's initial resistance figure 0.31 Ω and separately stated protection-path resistance 0.07 Ω gives a conservative simple model of 0.38 Ω. An additional 50 mA produces `0.05 × 0.38 ≈ 0.019 V`, about **19 mV** of resistive drop. This can double-count resistance if the first figure includes the protection path, and does not model fast transients, wiring, aging or state of charge. It is not a guaranteed waveform. Normal 50 mA load is not evidence of a large supply collapse. [TinyCircuits datasheet pp.2,5](https://files.tinycircuits.com/Datasheets/ASR00003_150mAh.pdf).
- **Driver estimate:** at assumed 0.8 V base voltage, the existing 1 kΩ/10 kΩ network supplies approximately 2.42 mA base current. At an assumed 0.3 V collector–emitter drop and established 50 mA running current, collector-path power is 15 mW. Actual loaded VCE is unknown. Neither calculation establishes an overheating or switching failure. The onsemi 0.3 V saturation guarantee uses a different test condition, so it also does not prove success at this operating point. [PN2222ABU datasheet](https://www.onsemi.com/download/data-sheet/pdf/pn2222a-d.pdf).

There is **no universal motor electrical-noise threshold** in these documents. The waveform at each affected node, its duration/frequency and the receiver's specifications matter. No confirmed FIT0774-induced electrical problem has been found here.

## Only true unknowns eligible for further testing

1. FIT0774 startup current at the voltage actually selected for the product; stall current only if needed for a defined fault analysis. No direct battery stall experiment is proposed.
2. Loaded PN2222ABU VCE/startup behavior with this exact base network, if the motor is retained.
3. Actual coupled disturbances at the board and whether the complete assembly shows an observable malfunction without an external capacitor. The capacitor remains conditional, not a presupposed requirement.
4. Whole-device current/runtime and phone/button behavior under actual use, which are not component datasheet specifications.

Construction identity and unavailable FIT0774 noise specifications are manufacturer-information gaps. They cannot be filled by re-testing unrelated rated values or treating comparator specifications as our own.

The proposed motorless MVP is still an option, not a committed hardware change. This research does not restore motor use, remove the existing flyback diode from a motor circuit, authorize new components or imply a physical test pass.
