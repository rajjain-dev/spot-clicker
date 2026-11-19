# Current test: motor + diode only

Use a clear a–e section, rows 5–10. Disconnect/remove the old transistor wiring from these rows; chip, USB and battery stay disconnected. Side rails are unused. No chip soldering is needed.

With U8031A outputs OFF, select adjustable Output 1 and set 3.00 V / 0.10 A. Use the leftmost OUTPUT 1 red (+)/black (−) binding posts, not green earth or the fixed 5 V pair. [Manual](references/keysight-u8030a-user-guide.pdf).

| Connection | Hole |
| --- | --- |
| Green lead, assigned to supply OUTPUT 1 + | Jumper pin → a5 |
| Grey lead, assigned to supply OUTPUT 1 − | Jumper pin → a10 |
| Motor positive/red | e5 |
| Motor negative/other lead | e10 |
| Diode cathode (verified banded end) | c5 |
| Diode anode | c10 |

Alligator jaws do not enter breadboard holes: clip onto the exposed metal at the free end of a pin-ended jumper; its other pin enters the listed hole. At the supply, use proper banana adapters or clip securely to the exposed metal binding-post shaft with its cap loosened, keeping adjacent jaws apart. Never clip to plastic or force jaws into sockets.

Wire colour does not determine polarity. Check the actual +/− terminal labels. Each a–e half-row is connected internally; row 5 and row 10 must remain separate. Motor leads need secure pin-ended adapters/tails if too thin for reliable breadboard contact. Support motor/wires without pulling on their joints.

Verify diode polarity before powering. For a brief 1–2 second test, enable only Output 1, then switch it OFF before touching wiring. Persistent CC/no start/heating → OFF; do not raise limits. 100 nF unavailable; test has no chip attached.

November 9 result: Raj confirmed vibration and **0.05 A (50 mA) running current** at the 3.00 V / 0.10 A test settings. Startup peak remains unmeasured. No repeat of the motor-only test is needed.
