#!/usr/bin/env python3
"""Draw the compact USB MVP perfboard assembly sheet."""
from html import escape
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/images/usb-perfboard-mvp.svg'
W, H = 1640, 1330
PITCH = 58
INK, MUTED = '#192c39', '#526a78'
POWER, GROUND, BASE, RETURN, KEY, FUTURE = '#b24b28', '#30485a', '#7555a8', '#087c96', '#25765c', '#8a6524'
BG, LINE = '#eef3f5', '#c6d4dc'
parts = []


def rect(x, y, width, height, fill, stroke='none', radius=0, sw=1.5):
    parts.append(f'<rect x="{x}" y="{y}" width="{width}" height="{height}" rx="{radius}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>')


def text(x, y, label, size=19, color=INK, weight=400, anchor='start'):
    parts.append(f'<text x="{x}" y="{y}" font-size="{size}" fill="{color}" font-weight="{weight}" text-anchor="{anchor}">{escape(label)}</text>')


def path(points, color, width=4, halo=False, dashed=False):
    points_string = ' '.join(f'{x},{y}' for x, y in points)
    if halo:
        parts.append(f'<polyline points="{points_string}" fill="none" stroke="#f8fbfa" stroke-width="{width+5}" stroke-linecap="round" stroke-linejoin="round"/>')
    dash = ' stroke-dasharray="7 6"' if dashed else ''
    parts.append(f'<polyline points="{points_string}" fill="none" stroke="{color}" stroke-width="{width}" stroke-linecap="round" stroke-linejoin="round"{dash}/>')


def circle(x, y, r, fill, stroke='none', sw=1.5):
    parts.append(f'<circle cx="{x}" cy="{y}" r="{r}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>')


def card(x, y, width, height, title, caption):
    rect(x, y, width, height, '#ffffff', LINE, 16)
    text(x+22, y+35, title, 24, weight=700)
    text(x+22, y+64, caption, 17, MUTED)


def position(pad, solder=False):
    col = ord(pad[0]) - ord('A')
    return (590 if solder else 112) + (4-col if solder else col)*PITCH, 265 + (int(pad[1])-1)*PITCH


NETS = {
    POWER: 'A1 B1 C1 A5 B5',
    GROUND: 'B4 A6 B6 C6 D6',
    BASE: 'A2 A3 E2 C4 E6',
    RETURN: 'D4 D5 E5',
    FUTURE: 'D1 E1',
}
PAD_COLORS = {p: color for color, group in NETS.items() for p in group.split()}
LINKS = [
    ('A1', 'B1', POWER), ('B1', 'C1', POWER), ('D1', 'E1', FUTURE),
    ('A2', 'A3', BASE), ('A5', 'B5', POWER),
    ('D4', 'D5', RETURN), ('D5', 'E5', RETURN),
    ('A6', 'B6', GROUND), ('B6', 'C6', GROUND), ('C6', 'D6', GROUND),
]
# Coordinates between the named end pads, relative to the mirrored board origin.
INSULATED = [
    ('C1', 'B5', POWER, [(139, 22), (139, 217), (174, 217)]),
    ('E2', 'C4', BASE, [(32, 75), (32, 142), (92, 142)]),
    ('E6', 'C4', BASE, [(24, 264), (24, 251), (90, 251), (90, 200)]),
    ('B4', 'B6', GROUND, [(200, 194), (200, 265)]),
]


def board(solder=False):
    x0 = 590 if solder else 112
    rect(x0-29, 236, 290, 348, '#f6faf8', '#9fb4ac', 11)
    corner, _ = position('A1', solder)
    rect(corner-14, 241, 28, 6, '#698c80', radius=2)
    for n, letter in enumerate('EDCBA' if solder else 'ABCDE'):
        text(x0+n*PITCH, 227, letter, 18, MUTED, 700, 'middle')
    for row in range(1, 7):
        text(x0-41, 271+(row-1)*PITCH, str(row), 17, MUTED, 700, 'middle')
    if solder:
        for a, b, color in LINKS:
            path([position(a, True), position(b, True)], color, 7 if (a, b) == ('B1','C1') else 4)
        for a, b, color, turns in INSULATED:
            path([position(a, True), *((x0+x, 265+y) for x,y in turns), position(b, True)], color, 5, halo=True)
    for letter in 'ABCDE':
        for row in range(1, 7):
            pad = f'{letter}{row}'
            x, y = position(pad, solder)
            color = PAD_COLORS.get(pad, '#bdcdca')
            circle(x, y, 10, '#ffffff', color, 3 if pad in PAD_COLORS else 1.5)
            circle(x, y, 4, color)


def resistor(a, b, label, stripe):
    x1, y = position(a)
    x2, _ = position(b)
    path([(x1, y), (x2, y)], '#728894', 3)
    mid = (x1+x2)/2
    rect(mid-59, y-11, 118, 22, '#e7ce9d', '#a78c5e', 8)
    for i, color in enumerate(['#845034', '#222a2e', stripe, '#a7893d']):
        rect(mid-41+i*24, y-10, 7, 20, color)
    text(mid, y-19, label, 17, INK, 700, 'middle')


def top_parts():
    resistor('A2', 'E2', 'R1   1 kΩ', '#c74c37')
    resistor('A6', 'E6', 'R2   10 kΩ', '#db8339')
    ax, dy = position('A5')
    dx, _ = position('D5')
    path([(ax, dy), (dx, dy)], '#728894', 3)
    rect(ax+34, dy-10, 104, 20, '#d9916b', '#a26149', 8)
    rect(ax+44, dy-9, 10, 18, '#242a30')
    text(ax+86, dy-17, '1N4148', 16, INK, 700, 'middle')
    for pin, symbol, offset in [('B4','E',-34),('C4','B',0),('D4','C',34)]:
        x,y = position(pin)
        center,_ = position('C4')
        path([(center+offset, y-35), (x, y)], '#728894', 3)
        text(x, y+24, symbol, 15, INK, 700, 'middle')
    x,y = position('C4')
    parts.append(f'<path d="M{x-51} {y-35} Q{x-48} {y-95} {x} {y-95} Q{x+48} {y-95} {x+51} {y-35} Z" fill="#253945"/>')
    text(x,y-55,'Q1',18,'#ffffff',700,'middle')


def plan():
    ox, oy, scale = 1040, 250, 11.7
    def box(x,y,w,h,fill,stroke,r=0):
        rect(ox+x*scale,oy+y*scale,w*scale,h*scale,fill,stroke,r)
    box(0,0,40,24,'#f4f8fa','#b1c5cf',13)
    box(0.8,0.8,17.8,21,'#e2f1ef','#3b807c',10)
    box(5.55,-0.55,8.3,3.7,'#b7c7cf','#647f8c',5)
    text(ox+9.7*scale,oy-13,'USB-C',16,INK,700,'middle')
    box(2.5,5.7,14.4,9.9,'#f9ffff','#a5bdbb',6)
    text(ox+9.7*scale,oy+10*scale,'XIAO',22,INK,700,'middle')
    text(ox+9.7*scale,oy+12.5*scale,'17.8 × 21 mm',16,MUTED,400,'middle')
    box(1.65,18.1,16.1,2.9,'#f4e2af','#b9934b',5)
    text(ox+9.7*scale,oy+20.0*scale,'ANTENNA END',14,'#6d5426',700,'middle')
    box(19.5,1.4,19,19,'#f1edf9','#8771ae',12)
    box(21.2,3.1,15.6,15.6,'#ffffff','#bbaacf',8)
    bx,by=ox+22.5*scale,oy+4.0*scale
    parts.append(f'<rect x="{bx}" y="{by}" width="{12.7*scale}" height="{15.24*scale}" rx="6" fill="#e1f0e8" fill-opacity=".83" stroke="#4b8e72" stroke-width="2" stroke-dasharray="7 5"/>')
    text(ox+28.85*scale,oy+9.2*scale,'CHERRY KEY',20,INK,700,'middle')
    text(ox+28.85*scale,oy+12.0*scale,'Perfboard',16,KEY,700,'middle')
    text(ox+28.85*scale,oy+14.1*scale,'below',16,KEY,700,'middle')
    box(37.1,5.6,2.7,10,'#ffd8c5','#b24b28',5)
    text(ox+29.3*scale,oy+22.3*scale,'Motor on side wall',16,POWER,700,'middle')
    text(ox+20*scale,oy+26.4*scale,'≈ 40 × 24 mm internal plan',18,INK,700,'middle')


parts.append(f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">')
parts.append('<title>SpotClicker USB perfboard MVP wiring and compact layout</title>')
parts.append('<desc>Top and mirrored solder-side views of a five-column by six-row perfboard. The USB 3V3 supply connects through a removable link to the motor positive and diode cathode. The CHERRY keyboard switch connects XIAO D1 to ground. Spare battery pads permit a later upgrade.</desc>')
parts.append('<g font-family="Arial, Helvetica, sans-serif">')
rect(0,0,W,H,BG)
text(38,56,'SpotClicker USB perfboard MVP',37,weight=700)
text(38,90,'CHERRY keyboard switch · XIAO nRF52840 · FIT0774 motor · battery pads reserved',21,MUTED)
card(38,124,440,540,'Component side','5 columns × 6 rows · 2.54 mm pitch')
card(516,124,440,540,'Solder side','Flip left-to-right. Keep row 1 at top.')
card(994,124,608,540,'Compact placement','Side-by-side modules with the perfboard below the key')
board()
top_parts()
board(True)
text(78,615,'Q1 flat face points toward row 5.',17,MUTED)
text(78,641,'Diode stripe is at A5.',17,POWER,700)
text(554,615,'B1–C1 is the removable USB motor link.',17,POWER,700)
text(554,641,'Raised routes are insulated jumpers.',17,MUTED)
plan()
text(1016,607,'USB plug and enclosure walls need their own clearance.',17,MUTED)
text(1016,634,'Leave the XIAO underside and source link accessible.',17,MUTED)

card(38,696,760,372,'External wires','PB coordinates refer to the perfboard shown above.')
connections = [
    ('XIAO 3V3', 'PB A1', POWER), ('XIAO GND', 'PB B6', GROUND),
    ('XIAO D4', 'PB A3  ·  R1 to Q1 base', BASE),
    ('CHERRY switch contact 1', 'XIAO D1 directly', KEY),
    ('CHERRY switch contact 2', 'PB C6  ·  GND', KEY),
    ('Motor +', 'PB B5  ·  VM', POWER), ('Motor −', 'PB E5  ·  Q1 collector', RETURN),
]
for i,(origin,dest,color) in enumerate(connections):
    y=795+36*i
    if i%2==0:
        rect(56,y-21,724,33,'#f2f6f8',radius=5)
    text(68,y,origin,18,color,700)
    text(341,y,'→',17,MUTED)
    text(382,y,dest,18)

card(836,696,766,372,'Links on the solder side','Every listed pair needs a wire. Perfboard pads are isolated.')
for y,heading,lines in [
    (798,'Short links', ['A1–B1, A2–A3, A5–B5, D4–D5, D5–E5', 'A6–B6, B6–C6, C6–D6, D1–E1']),
    (895,'Insulated jumpers', ['C1–B5, E2–C4, E6–C4, B4–B6']),
    (972,'Removable USB source link', ['B1–C1 connects 3V3 to the motor supply.']),
]:
    text(858,y,heading,18,INK,700)
    for i,line in enumerate(lines):
        text(858,y+28+25*i,line,18,MUTED)

card(38,1098,1564,188,'Battery later','Use the reserved pads for the protected pack and slide switch.')
text(62,1200,'Keep B1–C1 for the first battery trial. Add switched pack + to PB D1, XIAO BAT+ to PB E1, and pack − to PB D6.',19,INK)
text(62,1230,'If portable measurements call for direct motor power, move the link to C1–D1 after implementing the battery firmware.',18,MUTED)
text(62,1258,'USB build uses the 3V3 link only. Keep the battery pads empty during this build.',18,FUTURE,700)
parts.append('</g></svg>')
OUT.write_text('\n'.join(parts)+'\n', encoding='utf-8')
print(OUT)
