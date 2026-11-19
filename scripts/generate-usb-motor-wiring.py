#!/usr/bin/env python3
"""Draw the USB-only breadboard wiring from the documented hole schedule."""
from pathlib import Path
from html import escape
import json

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/images"
OUT.mkdir(parents=True, exist_ok=True)
W, H = 1700, 1240
P = []
RED, BLACK, PURPLE, BLUE = "#c84631", "#263a43", "#7253ac", "#087c9a"
COL = dict(zip("abcdefghij", [740, 770, 800, 830, 860, 960, 990, 1020, 1050, 1080]))

def hole(s):
    return COL[s[0]], 230 + int(s[1:]) * 30

def rect(x, y, w, h, fill="white", stroke="#cbd5db", rx=0, sw=2):
    P.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>')

def text(x, y, s, size=18, color="#20323b", weight=400, anchor="start"):
    P.append(f'<text x="{x}" y="{y}" font-size="{size}" fill="{color}" font-weight="{weight}" text-anchor="{anchor}">{escape(s)}</text>')

def path(d, color=BLACK, sw=5, halo=False):
    if halo:
        P.append(f'<path d="{d}" fill="none" stroke="#f6f8f9" stroke-width="{sw+5}" stroke-linecap="round" stroke-linejoin="round"/>')
    P.append(f'<path d="{d}" fill="none" stroke="{color}" stroke-width="{sw}" stroke-linecap="round" stroke-linejoin="round"/>')

def circle(x, y, r=4, fill="#9aa9b0", stroke="none", sw=1):
    P.append(f'<circle cx="{x}" cy="{y}" r="{r}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>')

def plugged(s, color):
    x, y = hole(s)
    circle(x, y, 7, "white", color, 3)
    circle(x, y, 3, color)

def jumper(a, b, color):
    x1, y1 = hole(a); x2, y2 = hole(b)
    path(f"M{x1} {y1} L{x2} {y2}", color, halo=True)
    plugged(a, color); plugged(b, color)

P.append(f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">')
P.append('<title>USB-only XIAO and FIT0774 breadboard wiring</title>')
P.append('<desc>USB powers XIAO. XIAO 3V3 goes to j18, GND to h2, D4 to i8. PN2222ABU E b7, B b8, C b9. 1k d8 to g8; 10k d14 to g14. Diode cathode g18 and anode g22. Motor positive h18, negative h22. Fixed jumpers a8-a14, c9-c22, e22-f22, a7-a2, e2-f2, j2-j14. Optional button D1 to GND at i2. No battery, bench supply or external capacitor.</desc>')
P.append('<g font-family="Arial, Helvetica, sans-serif">')
rect(0, 0, W, H, "#f6f8f9", "none")
text(48, 55, "USB + motor · breadboard wiring", 35, weight=700)
text(48, 88, "Plain XIAO nRF52840 + FIT0774 + PN2222ABU · no battery · no added 104", 20, "#526671")
rect(48, 109, 1604, 46, "#fff0d9", "none", 8)
text(65, 139, "Unplug USB before wiring. Use 3V3, not 5V. Remove the old i8–i18 ON jumper and all bench-supply leads.", 19, "#7b4b16", 700)

# The assembled board is supported beside the breadboard, not plugged into it.
text(115, 211, "XIAO", 21, weight=700)
rect(125, 245, 280, 350, "#16646b", "#0f454c", 20)
rect(205, 221, 120, 90, "#bcc7cc", "#677c85", 12)
rect(221, 230, 88, 18, "#303c43", "none", 6)
path("M265 170 V220", BLACK, 11)
text(288, 192, "USB to Mac", 18)
rect(190, 326, 150, 200, "#dbe3e7", "#b6c2c9", 5)
text(265, 385, "Seeed Studio", 22, "#314c56", 700, "middle")
text(265, 422, "XIAO", 26, "#314c56", 700, "middle")
text(265, 450, "nRF52840", 20, "#314c56", 400, "middle")
text(265, 483, "USB powered", 16, "#516873", 400, "middle")
left = ["D0", "D1", "D2", "D3", "D4", "D5", "D6"]
right = ["5V", "GND", "3V3", "D10", "D9", "D8", "D7"]
for i, (l, r) in enumerate(zip(left, right)):
    y = 300 + i * 40
    lc = PURPLE if l == "D4" else ("#2b8964" if l == "D1" else "#a4b6bf")
    rc = RED if r == "3V3" else (BLACK if r == "GND" else "#a4b6bf")
    rect(111, y-9, 26, 18, "#dac581", "#bba564", 3)
    rect(393, y-9, 26, 18, "#dac581", "#bba564", 3)
    text(151, y+6, l, 17, "white", 700)
    text(380, y+6, r, 17, "white", 700, "end")
    if l in ("D4", "D1"):
        circle(117, y, 7, "white", lc, 3)
    if r in ("GND", "3V3"):
        circle(413, y, 7, "white", rc, 3)
text(435, 305, "5V unused", 16, "#7c8991")
text(115, 626, "Front view · USB at top.", 18, "#526671")
text(115, 654, "Board beside breadboard; BAT unused.", 18, "#526671")

# Breadboard halves: each five-hole row connects; the centre gap separates halves.
rect(690, 192, 440, 810, "#e5e9ec", "#bcc8ce", 14)
rect(706, 238, 173, 739, "#fff", "#d2dbe0", 6, 1)
rect(941, 238, 173, 739, "#fff", "#d2dbe0", 6, 1)
text(909, 207, "BREADBOARD", 19, weight=700, anchor="middle")
for c, x in COL.items():
    text(x, 229, c, 18, "#566d79", 700, "middle")
for row in range(1, 25):
    y = 230 + row * 30
    text(722, y+5, str(row), 14, "#6e828c", anchor="end")
    text(1120, y+5, str(row), 14, "#6e828c")
    for x in COL.values():
        circle(x, y, 4, "#b4c0c7")
text(910, 1026, "Side power rails are not used.", 17, "#526671", anchor="middle")

# Transistor body and leads; flat face points right, E/B/C occupy distinct rows.
P.append('<path d="M665 435 L665 505 C605 505 605 435 665 435 Z" fill="#27343b" stroke="#15232a" stroke-width="2"/>')
for label, d, h in [
    ("E", "M665 450 C705 450 735 450 770 440", "b7"),
    ("B", "M665 470 C705 480 735 480 770 470", "b8"),
    ("C", "M665 490 C705 510 735 510 770 500", "b9")]:
    path(d, "#788a94", 3)
    plugged(h, BLACK)
    y = hole(h)[1]
    text(679, y+5, label, 16, weight=700)
text(623, 396, "Q1", 20, weight=700)
text(595, 557, "Flat face →", 17, weight=700)

fixed = [("a7", "a2", BLACK), ("e2", "f2", BLACK), ("j2", "j14", BLACK),
         ("a8", "a14", PURPLE), ("c9", "c22", BLUE), ("e22", "f22", BLUE)]
for a,b,c in fixed:
    jumper(a,b,c)

# Both resistors bridge the centre gap, as in the existing layout.
for a,b,name,bands in [
    ("d8","g8","R1 · 1 kΩ",["#814528", "#252525", "#c44632", "#b19449"]),
    ("d14","g14","R2 · 10 kΩ",["#814528", "#252525", "#df802b", "#b19449"])]:
    x1,y = hole(a); x2,_ = hole(b)
    path(f"M{x1} {y} H{x2}", "#7b8c96", 3)
    rect(873, y-12, 84, 24, "#dfc59b", "#a58c63", 8, 1.5)
    for xx,cc in zip([887,905,923,944],bands):
        rect(xx, y-11, 6, 22, cc, "none")
    plugged(a,PURPLE); plugged(b,PURPLE)
    text(912, y-23, name, 17, weight=700, anchor="middle")

# Glass diode: cathode identification band is at the top, g18.
x,yt = hole("g18"); _,yb = hole("g22")
path(f"M{x} {yt} V{yb}", "#7b8c96", 3)
rect(982, 805, 16, 50, "#cb8562", "#7c5546", 6, 1.5)
rect(982, 810, 16, 7, "#252a2d", "none")
plugged("g18",RED); plugged("g22",BLUE)
text(965, 848, "D1", 16, weight=700, anchor="end")

# Three external board wires. White halos make crossings visibly unjoined.
path("M413 340 H550 V180 H1160 V290 H1020", BLACK, 5, True)
plugged("h2",BLACK)
text(561, 319, "GND → h2", 18, BLACK, 700)
path("M117 460 H35 V1095 H1210 V470 H1050", PURPLE, 5, True)
plugged("i8",PURPLE)
text(65, 1082, "D4 → i8 (through R1 to base)", 18, PURPLE, 700)
path("M413 380 H575 V1060 H1180 V770 H1080", RED, 5, True)
plugged("j18",RED)
text(535, 1089, "3V3 → j18 · this is motor power", 18, RED, 700)

# Motor outside the breadboard. Red/+ and blue/− identify the wire functions.
circle(1400, 833, 63, "#c7d3d8", "#7e939d", 3)
circle(1400, 833, 52, "#e6edef", "#9baeb6", 1.5)
text(1400, 836, "FIT0774", 19, "#425d68", 700, "middle")
text(1400, 860, "motor", 17, "#425d68", anchor="middle")
path("M1380 773 V748 H1020 V770", RED, 5, True)
path("M1420 773 H1490 V930 H1020 V890", BLUE, 5, True)
circle(1380, 773, 6, RED)
circle(1420, 773, 6, BLUE)
plugged("h18",RED); plugged("h22",BLUE)
text(1340, 727, "+", 24, RED, 700)
text(1435, 771, "−", 24, BLUE, 700)
text(1270, 972, "Motor + → h18", 19, RED, 700)
text(1270, 1001, "Motor − → h22", 19, BLUE, 700)

# Clear placement key at upper right; all physical coordinates are explicit.
rect(1240, 192, 412, 455, "#fff", "#d1dce2", 12)
text(1260, 227, "Component hole map", 22, weight=700)
for y,a,b in [
    (269,"Q1 PN2222ABU", "E b7 · B b8 · C b9"),
    (326,"R1 1 kΩ", "d8 ↔ g8"),
    (383,"R2 10 kΩ", "d14 ↔ g14"),
    (440,"D1 1N4148 diode", "BAND end g18 · plain end g22"),
    (497,"Motor", "+ h18 · − h22")]:
    text(1260,y,a,18,weight=700)
    text(1260,y+24,b,17,"#536c78")
text(1260, 558, "Each a–e row is connected.", 17)
text(1260, 584, "Each f–j row is connected.", 17)
text(1260, 610, "The centre gap separates them.", 17)

# Optional switch is expressed by named endpoints so no assumed 4-leg pinout is invented.
rect(60, 802, 475, 210, "#fff", "#d1dce2", 12)
text(80, 837, "Optional physical button", 21, weight=700)
text(80, 866, "Normally open · no external pull-up", 17, "#536c78")
path("M113 918 H260 M315 918 H464", "#2b8964", 4)
circle(260,918,5,"white","#2b8964",2)
circle(315,918,5,"white","#2b8964",2)
path("M264 914 L307 891 M283 880 V892", "#2b8964", 3)
text(113, 903, "D1", 18, "#2b8964", 700)
text(464, 903, "GND (i2)", 18, "#2b8964", 700, "end")
text(80, 964, "Connect board D1 and hole i2 as shown.", 17)
text(80, 990, "Or use the existing USB commands: 1 / 2 / 3.", 17)

rect(48, 1120, 1604, 86, "#eaf0f3", "none", 8)
text(65, 1149, "Six fixed jumpers", 19, weight=700)
text(265, 1149, "a7–a2  ·  e2–f2  ·  j2–j14  ·  a8–a14  ·  c9–c22  ·  e22–f22", 19)
text(65, 1177, "Only wire ends plug into holes. Insulated wire crossings do not join. Drawing paths are not required wire lengths.", 18, "#526671")
text(48, 1226, "Proposed shared-3V3 wiring. Actual combined startup load / driver behavior remain unknown. Motor firmware must use D4.", 16, "#526671")
P.append("</g></svg>")
(OUT / "usb-motor-breadboard.svg").write_text("\n".join(P))

mapping = {
    "board": {"3V3":"j18", "GND":"h2", "D4":"i8"},
    "components": {"Q1":{"E":"b7","B":"b8","C":"b9"},
                   "R1_1k":["d8","g8"],"R2_10k":["d14","g14"],
                   "diode":{"cathode_band":"g18","anode":"g22"},
                   "motor":{"positive":"h18","negative":"h22"}},
    "fixed_jumpers": [[a,b] for a,b,_ in fixed],
    "optional_button": ["XIAO D1", "button", "i2 (GND)"],
    "disconnected": ["battery", "bench supply", "temporary i8-i18 jumper"],
    "status": "proposed wiring; physical unknowns not resolved by this drawing"
}
(ROOT / "docs/usb-motor-breadboard.connections.json").write_text(json.dumps(mapping,indent=2)+"\n")
print("Wrote USB motor breadboard SVG and connection schedule.")
