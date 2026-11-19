#!/usr/bin/env python3
"""Draw adapter or direct protected-battery-lead wiring."""
from pathlib import Path
from html import escape
import json
import argparse

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--direct', action='store_true', help='Show existing protected battery leads without an adapter')
DIRECT = parser.parse_args().direct
STEM = 'battery-direct-motor-breadboard' if DIRECT else 'battery-adapter-motor-breadboard'

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/images'
OUT.mkdir(parents=True, exist_ok=True)
P = []
RED, BLACK, PURPLE, BLUE = '#c84631', '#263a43', '#7253ac', '#087c9a'
COL = dict(zip('abcdefghij', [740,770,800,830,860,960,990,1020,1050,1080]))

def hole(s):
    return COL[s[0]], 560 + int(s[1:]) * 30

def rect(x,y,w,h,fill='white',stroke='#cbd5db',rx=0,sw=2):
    P.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>')

def text(x,y,s,size=18,color='#20323b',weight=400,anchor='start'):
    P.append(f'<text x="{x}" y="{y}" font-size="{size}" fill="{color}" font-weight="{weight}" text-anchor="{anchor}">{escape(s)}</text>')

def path(d,color=BLACK,sw=5,halo=False):
    if halo:
        P.append(f'<path d="{d}" fill="none" stroke="#f6f8f9" stroke-width="{sw+5}" stroke-linecap="round" stroke-linejoin="round"/>')
    P.append(f'<path d="{d}" fill="none" stroke="{color}" stroke-width="{sw}" stroke-linecap="round" stroke-linejoin="round"/>')

def circle(x,y,r=4,fill='#9aa9b0',stroke='none',sw=1):
    P.append(f'<circle cx="{x}" cy="{y}" r="{r}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>')

def plugged(s,color):
    x,y = hole(s)
    circle(x,y,7,'white',color,3)
    circle(x,y,3,color)

def jumper(a,b,color):
    x,y=hole(a); u,v=hole(b)
    path(f'M{x} {y} L{u} {v}',color,halo=True)
    plugged(a,color); plugged(b,color)

P.append('<svg xmlns="http://www.w3.org/2000/svg" width="1700" height="1700" viewBox="0 0 1700 1700">')
P.append('<title>Protected battery leads, switch, XIAO and motor breadboard wiring</title>' if DIRECT else '<title>Battery adapter, switch, XIAO and motor breadboard wiring</title>')
desc_start = 'Direct existing protected battery output leads, no detachable adapter. Positive to switch common; negative to h2 and XIAO BAT-. Pack modification is not manufacturer-approved. ' if DIRECT else 'Separate unplugged adapter cable only. Protected pack and original connector stay intact. Adapter positive to switch common; adapter negative to h2 and XIAO BAT-. '
P.append('<desc>'+desc_start+'ON throw to j18 and XIAO BAT+. XIAO D4 to i8. The front and underside drawings show the same board. PN2222ABU E b7 B b8 C b9; 1k d8-g8; 10k d14-g14; diode band g18 plain g22; motor positive h18 negative h22. Six jumpers as listed. Button D1 to GND. No added external capacitor. Proposed circuit, not physically qualified.</desc>')
P.append('<g font-family="Arial, Helvetica, sans-serif">')
rect(0,0,1700,1700,'#f6f8f9','none')
text(48,55,'Battery + motor · complete breadboard wiring',35,weight=700)
text(48,88,'Direct protected battery leads · soldered connections · no added 104' if DIRECT else 'Detachable adapter cable with soldered ends · existing driver · no added 104',20,'#526671')
rect(48,109,1604,62,'#fff0d9','none',8)
if DIRECT:
    text(65,135,'Battery leads stay live with S1 OFF. Remove USB. Never cut both leads together or let their exposed ends touch.',19,'#7b4b16',700)
    text(65,159,'Use existing protected output wires only; do not open the pack or solder to cell tabs. Pack modification is not manufacturer-approved.',18,'#7b4b16')
else:
    text(65,135,'Unplug the adapter from the battery and remove USB before cutting, stripping or soldering.',19,'#7b4b16',700)
    text(65,159,'Keep the protected battery, its wires and its original plug intact. Identify adapter polarity; wire colors alone are insufficient.',18,'#7b4b16')

# Both versions use the protected pack outputs, never the raw cell tabs.
rect(60,215,235,150,'#fff','#bdcbd2',12)
text(78,249,'ASR00003 battery',21,weight=700)
text(78,282,'Protected · 3.7 V / 150 mAh',17)
if DIRECT:
    text(78,315,'Keep pack protection intact',16,'#526671')
    text(78,343,'Existing two output leads',16,RED,700)
    path('M295 245 H620',RED,4)
    path('M295 315 H620',BLACK,4)
    text(335,228,'Protected + lead → S1 common',18,RED,700)
    text(335,344,'Protected − lead → GND',18,BLACK,700)
    text(60,198,'No adapter or detachable connector in this version',17,'#526671')
    text(60,388,'Insulated joints at the free wire ends; strain-relieve the leads.',17,'#526671')
    text(60,414,'Identify actual polarity; colors alone do not establish it.',17,'#526671')
else:
    text(78,315,'Original leads unchanged',16,'#526671')
    text(78,343,'Plug in LAST',18,RED,700)
    path('M295 245 H385',RED)
    path('M295 315 H385',BLACK)
    rect(330,225,55,110,'#ebe7db','#b7b2a5',6)
    text(60,198,'Pack plug → matching adapter socket',17,'#526671')
    rect(385,215,220,135,'#eaf0f3','#bdcbd2',8)
    text(403,270,'Separate adapter',20,weight=700)
    text(403,299,'cable / pigtail',18)
    path('M385 245 H620',RED,4)
    path('M385 315 H620',BLACK,4)
    text(611,233,'+',23,RED,700)
    text(611,343,'−',23,BLACK,700)
    text(60,388,'Cut/strip only the unplugged adapter’s free ends.',17,'#526671')
    text(60,414,'Solder + to S1 common; − to the GND junction.',17,'#526671')

# SPDT switch shown ON; the spare throw never connects to ground.
path('M620 245 H800',RED)
circle(800,245,6,'white',BLACK,2)
circle(900,245,6,'white',BLACK,2)
circle(900,210,6,'white',BLACK,2)
path('M806 245 H894',BLACK,4)
text(800,225,'C',17,weight=700,anchor='middle')
text(916,273,'ON',17,RED,700)
text(918,211,'Unused throw: insulate',16)
text(750,293,'S1 · JS102011SAQN',20,weight=700)
text(750,321,'Common → selected ON throw',17)
text(750,348,'Functional contacts shown; match package drawing.',16,'#526671')
text(982,282,'BAT_SW',19,RED,700)
text(982,307,'Switched battery voltage',16,RED)
text(670,474,'Common GND junction',18,BLACK,700)
circle(800,245,4,RED)
circle(650,315,6,'#d7b16a',BLACK,2)

rect(1240,194,412,270,'#fff','#d1dce2',12)
text(1260,228,'USB / charging',22,weight=700)
text(1260,263,'Battery operation: USB unplugged.',17)
text(1260,296,'To charge: S1 ON; motor inhibited.',17)
text(1260,329,'S1 OFF isolates battery + only.',17)
text(1260,356,'USB can still power the board',17)
text(1260,380,'and the BAT_SW charger node.',17)
text(1260,419,'Protective firmware is still pending.',17,RED,700)
text(1260,444,'See the accompanying wiring guide.',16,'#526671')

# Front of XIAO, beside the breadboard.
text(115,541,'XIAO · front view',21,weight=700)
rect(125,575,280,350,'#16646b','#0f454c',20)
rect(205,551,120,90,'#bcc7cc','#677c85',12)
rect(221,560,88,18,'#303c43','none',6)
rect(190,656,150,200,'#dbe3e7','#b6c2c9',5)
text(265,715,'Seeed Studio',22,'#314c56',700,'middle')
text(265,752,'XIAO',26,'#314c56',700,'middle')
text(265,780,'nRF52840',20,'#314c56',400,'middle')
text(265,813,'Battery powered',16,'#516873',400,'middle')
for i,(l,r) in enumerate(zip(['D0','D1','D2','D3','D4','D5','D6'],['5V','GND','3V3','D10','D9','D8','D7'])):
    y=630+i*40
    rect(111,y-9,26,18,'#dac581','#bba564',3)
    rect(393,y-9,26,18,'#dac581','#bba564',3)
    text(151,y+6,l,17,'white',700)
    text(380,y+6,r,17,'white',700,'end')
    if l in ('D4','D1'):
        circle(117,y,7,'white',PURPLE if l=='D4' else '#2b8964',3)
text(435,637,'5V unused',16,'#7c8991')
text(435,717,'3V3 unused',16,'#7c8991')
text(115,956,'Front and back below are the SAME XIAO.',18,'#526671',700)

# Underside pad arrangement taken from Seeed's official back pinout, USB at top.
text(115,995,'Same XIAO · underside facing you',20,weight=700)
rect(125,1035,280,280,'#205f62','#0f454c',20)
rect(205,1009,120,45,'#bcc7cc','#677c85',8)
for i in range(7):
    for x in (111,393):
        rect(x,1058+i*35,26,15,'#dac581','#bba564',3)
rect(337,1118,26,24,'#dac581','#e7e0bb',3)
rect(337,1153,26,24,'#dac581','#e7e0bb',3)
text(325,1136,'BAT−',18,'white',700,'end')
text(325,1171,'BAT+',18,'white',700,'end')
text(265,1237,'USB at top',17,'white',400,'middle')
text(265,1264,'Solder to the two BAT pads',16,'white',400,'middle')
text(530,1483,'BAT_SW → underside BAT+ and j18',18,RED,700)

# Breadboard layout is unchanged from the USB diagram.
rect(690,522,440,810,'#e5e9ec','#bcc8ce',14)
rect(706,568,173,739,'#fff','#d2dbe0',6,1)
rect(941,568,173,739,'#fff','#d2dbe0',6,1)
text(909,537,'BREADBOARD',19,weight=700,anchor='middle')
for c,x in COL.items():
    text(x,559,c,18,'#566d79',700,'middle')
for row in range(1,25):
    y=560+row*30
    text(722,y+5,str(row),14,'#6e828c',anchor='end')
    text(1120,y+5,str(row),14,'#6e828c')
    for x in COL.values():
        circle(x,y,4,'#b4c0c7')
text(910,1356,'Side power rails unused.',17,'#526671',anchor='middle')

P.append('<path d="M665 765 L665 835 C605 835 605 765 665 765 Z" fill="#27343b" stroke="#15232a" stroke-width="2"/>')
for label,d,h in [('E','M665 780 C705 780 735 780 770 770','b7'),('B','M665 800 C705 810 735 810 770 800','b8'),('C','M665 820 C705 840 735 840 770 830','b9')]:
    path(d,'#788a94',3)
    plugged(h,BLACK)
    text(679,hole(h)[1]+5,label,16,weight=700)
text(623,726,'Q1',20,weight=700)
text(595,887,'Flat face →',17,weight=700)
fixed=[('a7','a2',BLACK),('e2','f2',BLACK),('j2','j14',BLACK),('a8','a14',PURPLE),('c9','c22',BLUE),('e22','f22',BLUE)]
for a,b,c in fixed:
    jumper(a,b,c)
for a,b,name,bands in [('d8','g8','R1 · 1 kΩ',['#814528','#252525','#c44632','#b19449']),('d14','g14','R2 · 10 kΩ',['#814528','#252525','#df802b','#b19449'])]:
    x,y=hole(a); u,_=hole(b)
    path(f'M{x} {y} H{u}','#7b8c96',3)
    rect(873,y-12,84,24,'#dfc59b','#a58c63',8,1.5)
    for xx,cc in zip([887,905,923,944],bands):
        rect(xx,y-11,6,22,cc,'none')
    plugged(a,PURPLE); plugged(b,PURPLE)
    text(912,y-23,name,17,weight=700,anchor='middle')
path('M990 1100 V1220','#7b8c96',3)
rect(982,1135,16,50,'#cb8562','#7c5546',6,1.5)
rect(982,1140,16,7,'#252a2d','none')
plugged('g18',RED); plugged('g22',BLUE)
text(965,1178,'CR1',16,weight=700,anchor='end')
path('M117 790 H35 V1525 H1210 V800 H1050',PURPLE,5,True)
plugged('i8',PURPLE)
text(65,1512,'D4 → i8 → 1 kΩ → base',18,PURPLE,700)
path('M620 315 H650 V480 H1160 V620 H1020',BLACK,5,True)
path('M650 480 H575 V1118 H350 V1130',BLACK,5,True)
path('M906 245 H1180 V1100 H1080',RED,5,True)
path('M350 1165 V1188 H510 V1495 H1180 V1100',RED,5,True)
circle(650,480,6,BLACK)
circle(350,1130,5,BLACK)
circle(350,1165,5,RED)
circle(1180,1100,6,RED)
plugged('h2',BLACK); plugged('j18',RED)
text(815,510,'Battery − → h2; motor return' if DIRECT else 'Adapter − → h2; motor return',17,BLACK,700)

circle(1400,1163,63,'#c7d3d8','#7e939d',3)
circle(1400,1163,52,'#e6edef','#9baeb6',1.5)
text(1400,1166,'FIT0774',19,'#425d68',700,'middle')
text(1400,1190,'motor',17,'#425d68',anchor='middle')
path('M1380 1103 V1078 H1020 V1100',RED,5,True)
path('M1420 1103 H1490 V1260 H1020 V1220',BLUE,5,True)
circle(1380,1103,6,RED); circle(1420,1103,6,BLUE)
plugged('h18',RED); plugged('h22',BLUE)
text(1340,1057,'+',24,RED,700)
text(1435,1101,'−',24,BLUE,700)
text(1270,1302,'Motor + → h18',19,RED,700)
text(1270,1331,'Motor − → h22',19,BLUE,700)

rect(1240,522,412,455,'#fff','#d1dce2',12)
text(1260,557,'Component hole map',22,weight=700)
for y,a,b in [(599,'Q1 PN2222ABU','E b7 · B b8 · C b9'),(656,'R1 1 kΩ','d8 ↔ g8'),(713,'R2 10 kΩ','d14 ↔ g14'),(770,'CR1 1N4148 diode','BAND end g18 · plain end g22'),(827,'Motor','+ h18 · − h22')]:
    text(1260,y,a,18,weight=700)
    text(1260,y+24,b,17,'#536c78')
text(1260,888,'Each a–e row is connected.',17)
text(1260,914,'Each f–j row is connected.',17)
text(1260,940,'The centre gap separates them.',17)

rect(60,1350,415,130,'#fff','#d1dce2',12)
text(80,1379,'S2 · normally-open button',20,weight=700)
path('M113 1420 H250 M305 1420 H445','#2b8964',4)
circle(250,1420,5,'white','#2b8964',2)
circle(305,1420,5,'white','#2b8964',2)
path('M254 1416 L297 1395','#2b8964',3)
text(113,1407,'D1',17,'#2b8964',700)
text(445,1407,'GND (i2)',17,'#2b8964',700,'end')
text(80,1460,'Internal pull-up; usable button still needed.',16,'#526671')

rect(48,1550,1604,93,'#eaf0f3','none',8)
text(65,1578,'Six fixed jumpers',19,weight=700)
text(265,1578,'a7–a2  ·  e2–f2  ·  j2–j14  ·  a8–a14  ·  c9–c22  ·  e22–f22',19)
text(65,1606,'Remove i8–i18 and all bench-supply leads. Remove the USB version’s 3V3 → j18 wire.',18,'#526671')
text(65,1632,'Only wire ends plug into holes. Insulated crossings do not join. Support and insulate every solder joint.',17,'#526671')
text(48,1674,'Proposed wiring. Startup/total battery load and driver behavior remain unknown; low-battery and USB motor-inhibit firmware pending.',17,'#526671')
P.append('</g></svg>')
(OUT/(STEM+'.svg')).write_text('\n'.join(P))
mapping={
    'assumption':'Separate detachable adapter cable, unplugged during cutting/soldering; protected pack and original leads unchanged',
    'power':{'adapter_positive':'S1 common','S1_selected_ON_throw':['j18','XIAO underside BAT+'],'S1_other_throw':'unconnected, insulated','adapter_negative':['h2','XIAO underside BAT-']},
    'board':{'BAT+':'BAT_SW','BAT-':'GND','D4':'i8','3V3':'unconnected','5V':'unconnected'},
    'components':{'Q1':{'E':'b7','B':'b8','C':'b9'},'R1_1k':['d8','g8'],'R2_10k':['d14','g14'],'diode':{'cathode_band':'g18','anode':'g22'},'motor':{'positive':'h18','negative':'h22'}},
    'fixed_jumpers':[[a,b] for a,b,_ in fixed],
    'button':['XIAO D1','normally-open S2','i2 (GND)'],
    'remove':['3V3-to-j18 wire from USB-only version','temporary i8-i18 jumper','bench supply'],
    'status':'Proposal; unknown load/driver behavior and protective firmware remain unresolved'
}
if DIRECT:
    mapping['assumption'] = 'Existing two insulated leads from the protected battery pack; no adapter or detachable connection; no direct cell-tab soldering or protection bypass'
    mapping['power']['battery_protected_positive'] = mapping['power'].pop('adapter_positive')
    mapping['power']['battery_protected_negative'] = mapping['power'].pop('adapter_negative')
    mapping['handling'] = 'Leads remain live even with S1 OFF; pack modification is outside manufacturer handling instructions'
schedule = 'battery-direct-motor.connections.json' if DIRECT else 'battery-adapter-motor.connections.json'
(ROOT/'docs'/schedule).write_text(json.dumps(mapping,indent=2)+'\n')
print('Wrote '+STEM+' SVG and connection schedule.')
