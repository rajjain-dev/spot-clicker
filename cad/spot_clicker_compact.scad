// Spot Clicker - compact keychain enclosure and internal layout, rev 4 (November 17, 2026)
// Rev 4: 22.86 mm (0.90 in) tall; 2.8 mm screw holes in the posts; only two printed parts, the shell and the lid
// (no separator plate, no battery stand-in block, no stop rib on the lid).
// Rev 3: the bottom lid is held by 4 screws that sit in round bulges at the corners. The USB end wall is part of
// the lid: with the lid off, the XIAO slides in from that end and its back corners go into two C clips that hold
// it up and down.
// Rev 2: USB first, battery later. Stage 1 runs from the USB cable with the battery bay empty; stage 2 adds the
// battery. The printed case is the same for both stages.
// Works in OpenSCAD 2021.01 and newer. Units: millimetres.
// Axes: X = length (button end at X = 0, USB-C end at +X), Y = width, Z = height (underside of the case = 0).
// Use: open this file, choose "part" in the Customizer (Window > Customizer), press F6, then File > Export > STL.
// Electrical parts are grey "ghost" models so you can see where everything goes; only the coloured shell parts are printed.

/* [What to show] */
part = "assembly"; // [assembly, exploded, section, inside_top, inside_bottom, top_shell, floor_lid, fit_test, print_set]
stage = "usb";     // [usb, battery] usb = stage 1 (no battery, no slide switch); battery = stage 2

/* [Measure these on your own parts before printing] */
battery_l = 20.0;      // along X, including the protection-board end (datasheet: 20.0 +/- 3.0)
battery_w = 20.0;      // along Y (datasheet: 20.0 +/- 2.0)
battery_t = 5.0;       // thickness (datasheet: 5.0 +/- 0.5; it swells when hot)
xiao_pcb_t = 1.6;      // XIAO board thickness (Seeed v1.2 KiCad stack-up)
usb_h = 3.3;           // USB-C metal shell height above the XIAO board (estimate)
q_lift = 2.0;          // gap between the perfboard and the bottom of Q1's body, after soldering
s1_l = 9.0;            // slide-switch body length (C&K JS102011SAQN, LCSC listing 9 mm)
s1_w = 3.5;            // slide-switch body width (LCSC listing 3.5 mm)
s1_h = 3.5;            // slide-switch body height, pin face to lever face (estimate; lies across the case)
s1_act_l = 2.0;        // slide-switch lever length (DigiKey listing 2.00 mm)
perf_t = 1.5;          // perfboard thickness (Raj: 1.5 mm)
keycap_side = 18.0;    // keycap width (Raj: 18 mm)
keycap_top = 15.0;     // keycap top height above the case top - picture only

/* [Screws (Raj: 0.22 in head, 0.11 in thread, 0.40 in long overall)] */
screw_d = 2.8;         // thread diameter (0.11 in)
screw_pilot = 2.8;     // hole in the posts; the screw cuts its own thread (2.5 printed too tight). 2.6 if a screw spins loose
screw_clear = 3.4;     // hole through the lid
head_d = 5.6;          // head diameter (0.22 in)
head_h = 2.4;          // head height; the lid is head_h + 1.2 thick so the heads sit flush with the bottom
screw_len = 10.4;      // overall length, head included (0.40 in)

/* [Case height] */
H_target = 22.86;      // overall height (0.90 in); the case is only made taller if the parts need it

/* [Fit and print settings] */
wall = 1.2;            // side wall thickness
plate = 1.5;           // top plate; keep 1.5 so the MX switch clips hold (plate standard 1.5 +/- 0.1)
xiao_fit = 0.25;       // clearance around the XIAO's corners in its two clips
mx_cut = 14.0;         // MX plate cutout, 14.0 x 14.0
corner_r = 3.0;        // rounded outer corners
in_r = 0.8;            // inner corner radius (small, so the square battery fits)
led_window = true;     // slot above the XIAO LEDs
$fn = 32;

// ---------- Published dimensions (do not change) ----------
xiao_l = 20.955; xiao_w = 17.78; xiao_r = 1.905;   // Seeed v1.2 KiCad board outline
usb_w = 9.0; usb_d = 7.35; usb_over = 1.51;        // USB-C body from the KiCad footprint; overhang past the board edge
mx_top = 15.6; mx_below = 5.0; mx_above = 10.2;    // Cherry MX: 15.6 housing; 5.0 below plate top; 18.5 total incl. 3.3 pins
mx_pin_l = 3.3; mx_post_d = 4.0; mx_post_l = 3.0;
motor_d = 10.0; motor_t = 2.7;                     // DFRobot FIT0774
q_w = 5.2; q_h = 5.33; q_d = 4.19;                 // onsemi TO-92 maximum body
res_l = 6.3; res_d = 2.6; dio_l = 4.56; dio_d = 1.91; // Stackpole CF14 and DO-35 maximum bodies
pitch = 2.54;

// ---------- Z stack ----------
lid_t = head_h + 1.2;             // floor lid: thick enough to sink the screw heads
z_floor = lid_t;                  // top surface of the floor lid
perf_foam = 1.0;                  // foam tape under the perfboard (covers its solder joints)
z_pf0 = z_floor + perf_foam;  z_pf1 = z_pf0 + perf_t;
q_top = z_pf1 + q_lift + q_h;     // top of the transistor, the tallest part on the perfboard
bat_foam = 1.0;                   // foam tape under the battery
bay_h = battery_t + bat_foam;     // battery bay height
xiao_gap_min = 1.0;               // least room under the XIAO for wires
H_switch = q_top + 0.3 + mx_below;                        // switch end: Q1 must clear the switch housing
H_xiao = z_floor + bay_h + xiao_gap_min + xiao_pcb_t + usb_h + 0.3 + plate; // USB end
H = max(H_target, H_switch, H_xiao);  // overall case height
if (H > H_target + 1e-6) echo(str("NOTE: the parts need ", H, " mm, so the case is taller than the ", H_target, " mm asked for"));
z_p0 = H - plate;                 // underside of the top plate
z_mx_bot = H - mx_below;          // bottom of the switch housing
z_x1 = z_p0 - 0.3 - usb_h;  z_x0 = z_x1 - xiao_pcb_t;    // the XIAO hangs just under the plate
z_sep0 = z_floor + bay_h;  z_sep1 = z_sep0;   // top of the battery bay
xiao_gap = z_x0 - z_sep0;         // room between the battery and the XIAO, for wires
z_bat1 = z_sep0;  z_bat0 = z_bat1 - battery_t;
assert(q_top <= z_mx_bot - 0.3 + 1e-6, "transistor would hit the switch housing");
assert(z_pf1 + res_d < z_mx_bot - mx_post_l - 0.3, "resistors would hit the switch centre post");

// ---------- X layout ----------
key_end = 0.6;                     // keycap edge to case end
Xs = key_end + keycap_side / 2;    // switch centre
perf_cols = 6;  perf_rows = 6;
perf_x0 = wall;  perf_x1 = perf_x0 + perf_cols * pitch;
q_x = perf_x0 + 1.27 + 5 * pitch;  // transistor leg line (column F)
bat_x0 = max(q_x + (q_d - q_w / 2) + 0.4, perf_x1 + 1.1);      // battery bay starts about 1 mm past the perfboard and clear of Q1
bat_x1 = bat_x0 + battery_l;
in_x1 = max(Xs + mx_cut / 2 + 0.4 + xiao_l + 0.15, bat_x1 + 0.2);
L = in_x1 + wall;
x_x1 = in_x1 - 0.15;  x_x0 = x_x1 - xiao_l;   // XIAO: USB end against the end wall
assert(q_x + (q_d - q_w / 2) < x_x0 - 0.1, "transistor would touch the XIAO");

// ---------- Y layout ----------
side_margin = max(s1_h + 0.2, motor_t + 0.7);
W_in = max(mx_cut + 2 * side_margin, battery_w + 0.8, xiao_w + 3.0);
W = W_in + 2 * wall;
Ys = W / 2;
x_y0 = Ys - xiao_w / 2;  x_y1 = Ys + xiao_w / 2;   // XIAO D-pin edge is x_y1 (+Y)
perf_y0 = wall + motor_t + 0.5;
function hole(c, r) = [perf_x0 + 1.27 + (c - 1) * pitch, perf_y0 + 1.27 + (r - 1) * pitch];

// XIAO features: board-local (kx from antenna end, ky from the D-pin edge) to case XY
function xk(kx, ky) = [x_x0 + kx, x_y1 - ky];

// MX switch pins, switch "north" toward +Y (the slide-switch wall)
mx_pins = [[Xs - 3.81, Ys + 2.54], [Xs + 2.54, Ys + 5.08]];

// ---------- screw posts ----------
// Button end: the posts stand in the case corners (room beside the perfboard). USB end: the battery fills the
// case wall to wall, so the posts sit at the outside corners. Each post has a round bulge on the outside; the
// lid has matching lobes with the screw heads sunk into them.
col_in = 1.45;                                   // button-end post centres, from the outside edges
col_r = screw_pilot / 2 + 1.15;                  // post radius inside the case
bulge_r = head_d / 2 + 0.7;                      // bulge radius outside the case (head plus a 0.5 mm wall)
function out_d(a, b, R) = (a * a + b * b >= R * R) ? 0 : (-(a + b) + sqrt((a + b) * (a + b) - 2 * (a * a + b * b - R * R))) / 2;
post_out = out_d(L - bat_x1, Ys - battery_w / 2, col_r + 0.15);   // moves the USB-end posts out if a bigger battery needs it
screw_xy = [[col_in, col_in], [col_in, W - col_in], [L + post_out, -post_out], [L + post_out, W + post_out]];
assert(norm([col_in, col_in] - [perf_x0, perf_y0]) >= col_r + 0.15, "button-end screw post would hit the perfboard");
assert(norm([col_in, W - col_in] - [perf_x0, perf_y0 + perf_rows * pitch]) >= col_r + 0.15, "button-end screw post would hit the perfboard");

// Motor on the -Y wall, slide switch on the +Y wall, both clear of the button-end screw posts
motor_c = [max(Xs - 1.0, col_in + col_r + 0.3 + motor_d / 2), wall + 0.2 + motor_t / 2, z_floor + 0.5 + motor_d / 2];
s1_cx = max(Xs - 2.0, col_in + col_r + 0.3 + 0.8 + s1_l / 2);
s1_x0 = s1_cx - s1_l / 2;  s1_y1 = W - wall - 0.1;  s1_z0 = z_pf1 + res_d + 0.9;
s1_act_z = s1_z0 + s1_w / 2;

// XIAO corner clips: square C shapes at the board's two back corners, a jaw above and a jaw below the board with a
// back wall behind it. They hold the board up and down and stop it sliding toward the key; kept out of the key switch's footprint.
clip_gap = 0.25;                   // room above and below the board inside each clip
clip_jaw = 1.0;                    // lower jaw thickness
clip_reach = 1.5;                  // how far the jaws reach over the board
hold_x0 = x_x0 - xiao_fit - 1.2;  hold_x1 = x_x0 + clip_reach;   // back wall 1.2 thick
hold_y0 = Ys - mx_cut / 2 - 0.1;  hold_y1 = Ys + mx_cut / 2 + 0.1;
hold_z0 = z_x0 - clip_gap - clip_jaw;

// USB end: the shell is open between the two USB-end screw posts, so the XIAO slides in from the end into its clips.
// The lid's end piece is the USB end wall. It has a notch for the USB-C, tabs on top that sit in grooves under the
// top plate, and side edges that sit behind the screw bulges, so it takes the pull when a cable is unplugged.
slot_y0 = Ys - usb_w / 2 - 0.35;  slot_y1 = Ys + usb_w / 2 + 0.35;   // USB-C notch
piece_z1 = z_x1 - 0.2;            // bottom of the USB-C notch, just under the USB-C
end_y0 = col_r - post_out + 0.15; // side edges of the end piece, just clear of the screw posts
piece_top = z_p0 - 0.15;          // top of the end piece, just under the plate
tab_ys = [[end_y0 + 0.3, end_y0 + 2.1], [W - end_y0 - 2.1, W - end_y0 - 0.3]];   // top tabs, near the two corners
assert(tab_ys[0][1] + 0.15 < xk(18.16, 14.6)[1] - 1.1 - 0.2, "end piece tab groove would run into the LED window");

echo(str("CASE  L x W x H = ", L, " x ", W, " x ", H, " mm (plus screw bulges, keyring lug and keycap)"));
echo(str("battery bay height ", bay_h, " (battery ", battery_t, " + foam ", bat_foam, ")  wire gap under XIAO ", xiao_gap, "  transistor top ", q_top, "  switch housing bottom ", z_mx_bot, "  lid ", lid_t, "  screw thread length in the post ", screw_len - z_floor));
echo(str("DIMS|", L, "|", W, "|", H, "|", Xs, "|", Ys, "|", x_x0, "|", x_y0, "|", x_y1, "|", z_floor, "|", z_bat0, "|", z_bat1, "|", z_sep1, "|", z_x0, "|", z_x1, "|", z_p0, "|", z_mx_bot, "|", z_pf0, "|", z_pf1, "|", perf_x0, "|", perf_y0, "|", bat_x0, "|", bat_x1, "|", s1_x0, "|", s1_y1, "|", s1_z0, "|", motor_c[0], "|", motor_c[1], "|", motor_c[2], "|", q_top, "|", in_x1, "|", bay_h, "|", xiao_gap, "|", z_sep0, "|", s1_cx, "|", hold_x0, "|", hold_y0, "|", hold_y1, "|", q_lift, "|", lid_t, "|", col_in, "|", col_r, "|", bulge_r, "|", post_out, "|", xiao_fit, "|", slot_y0, "|", slot_y1, "|", piece_z1, "|", hold_z0, "|", head_d, "|", screw_len, "|", end_y0, "|", hold_x1));

// ---------- helpers ----------
module rbox(size, r) { // rounded vertical edges
  translate([r, r, 0]) linear_extrude(size[2]) offset(r = r) square([size[0] - 2 * r, size[1] - 2 * r]);
}
module rrect2(sz, r) { translate([r, r]) offset(r = r) square([sz[0] - 2 * r, sz[1] - 2 * r]); }
module board2d(o = 0) { translate([x_x0, x_y0]) offset(r = o) rrect2([xiao_l, xiao_w], xiao_r); }
// case footprint with the four screw bulges; the inside corners where a bulge meets the case are rounded
module outline2d(lug = false) {
  offset(r = -1.0) offset(delta = 1.0) union() {
    rrect2([L, W], corner_r);
    for (p = screw_xy) translate(p) circle(r = bulge_r);
    if (lug) hull() { translate([-2.7, Ys]) circle(r = 3.5); translate([0, Ys - 3.5]) square([1.0, 7]); }
  }
}

// ---------- printed part 1: top shell (print upside down, top plate on the bed) ----------
module top_shell() {
  difference() {
    union() {
      difference() {
        // outer body; the top edge has a small 0.6 mm chamfer, built in 0.1 mm steps
        union() {
          translate([0, 0, z_floor]) linear_extrude(H - 0.6 - z_floor) outline2d();
          for (i = [1:6]) translate([0, 0, H - 0.6 + (i - 1) * 0.1]) linear_extrude(0.1 + 0.001) offset(r = -0.1 * i) outline2d();
        }
        // inside, minus the screw posts
        difference() {
          translate([wall, wall, z_floor - 1]) rbox([L - 2 * wall, W - 2 * wall, z_p0 - z_floor + 1], in_r);
          for (p = screw_xy) translate([p[0], p[1], z_floor - 2]) cylinder(r = col_r, h = H + 4);
        }
      }
      // XIAO hold-down posts (press on the bare board corners at the antenna end)
      for (p = [xk(0.9, 2.6), xk(0.9, 15.2)]) translate([p[0], p[1], z_x1 + 0.05]) cylinder(d = 1.6, h = z_p0 - z_x1);
      // C clips at the XIAO's two back corners: the board's corners slide into the slots, which hold it up and down,
      // and the back of each slot stops it sliding toward the key when a cable is pushed in.
      difference() {
        translate([0, 0, hold_z0]) linear_extrude(z_p0 - hold_z0 + 0.01) union() {
          translate([hold_x0, wall - 0.01]) square([hold_x1 - hold_x0, hold_y0 - wall + 0.01]);
          translate([hold_x0, hold_y1]) square([hold_x1 - hold_x0, W - wall - hold_y1 + 0.01]);
        }
        translate([0, 0, z_x0 - clip_gap]) linear_extrude(xiao_pcb_t + 2 * clip_gap) board2d(xiao_fit);
        // lead-in at the mouth of each clip
        for (z = [z_x0 - clip_gap, z_x1 + clip_gap]) translate([hold_x1, 0, z]) rotate([-90, 0, 0])
          translate([0, 0, wall]) linear_extrude(W - 2 * wall) polygon([[0.01, -0.5], [0.01, 0.5], [-0.5, 0]]);
      }
      // slide-switch guide ribs on the +Y wall, running up to the plate so they print cleanly
      for (dx = [-0.8, s1_l]) translate([s1_x0 + dx, W - wall - s1_h - 0.1, s1_z0 - 1.0]) cube([0.8, s1_h + 0.11, z_p0 - s1_z0 + 1.01]);
    }
    // MX switch cutout
    translate([Xs - mx_cut / 2, Ys - mx_cut / 2, z_p0 - 1]) cube([mx_cut, mx_cut, plate + 2]);
    // USB end: open between the two USB-end screw posts; the lid's end piece closes it
    translate([L - wall - 0.15, end_y0 - 0.15, z_floor - 1]) cube([wall + 0.3, W - 2 * end_y0 + 0.3, z_p0 - z_floor + 1]);
    // grooves under the top plate for the end piece's tabs
    for (t = tab_ys) translate([L - wall - 0.15, t[0] - 0.15, z_p0 - 0.01]) cube([0.9, t[1] - t[0] + 0.3, 0.75]);
    // slide-switch lever slot in the +Y wall (allows about 2 mm of travel)
    translate([s1_cx - 2.6, W - wall - 1, s1_act_z - 1.0]) cube([5.2, wall + 2, 2.0]);
    // LED window over the XIAO RGB and charge LEDs
    if (led_window) {
      p1 = xk(18.16, 14.6); p2 = xk(20.32, 14.6);
      hull() for (p = [p1, p2]) translate([p[0], p[1], z_p0 - 1]) cylinder(d = 2.2, h = plate + 2);
    }
    // screw holes: the screws cut their own thread in these; small lead-in at the bottom
    for (p = screw_xy) translate([p[0], p[1], z_floor - 0.01]) {
      cylinder(d = screw_pilot, h = screw_len + 1.5 - z_floor);
      cylinder(d1 = screw_pilot + 0.8, d2 = screw_pilot, h = 0.4);
    }
  }
}

// ---------- printed part 2: floor lid with the USB end piece (print flat, bottom down) ----------
module floor_lid() {
  difference() {
    union() {
      linear_extrude(lid_t) outline2d(lug = true);
      // end piece = the USB end wall: notch for the USB-C, and tabs on top that sit in grooves under the top plate
      difference() {
        translate([L - wall, end_y0, lid_t - 0.01]) cube([wall, W - 2 * end_y0, piece_top - lid_t + 0.01]);
        translate([L - wall - 1, slot_y0, piece_z1]) cube([wall + 2, slot_y1 - slot_y0, H]);
      }
      for (t = tab_ys) translate([L - wall, t[0], piece_top - 0.01]) cube([0.6, t[1] - t[0], 0.6]);
    }
    // screw holes, heads sunk flush with the bottom
    for (p = screw_xy) translate([p[0], p[1], -1]) {
      cylinder(d = screw_clear, h = lid_t + 2);
      cylinder(d = head_d + 0.4, h = 1 + head_h);
    }
    // keyring hole
    translate([-2.7, Ys, -1]) cylinder(d = 3.6, h = lid_t + 2);
  }
}

// ---------- ghost models of the electronics and screws ----------
module ghost(c = [0.55, 0.57, 0.62]) { color(c) children(); }
module keycap() {
  ghost([0.93, 0.93, 0.9]) translate([Xs - keycap_side / 2, Ys - keycap_side / 2, H + 1.0])
    hull() { rbox([keycap_side, keycap_side, 1], 1.5); translate([1.5, 1.5, keycap_top - 2]) rbox([keycap_side - 3, keycap_side - 3, 1], 1.5); }
}
module mx_switch() {
  ghost([0.2, 0.35, 0.8]) {
    translate([Xs - 7, Ys - 7, z_mx_bot]) cube([14, 14, mx_below]);
    translate([Xs - mx_top / 2, Ys - mx_top / 2, H]) cube([mx_top, mx_top, 6.6]);
    translate([Xs - 2, Ys - 2, H + 6.6]) cube([4, 4, mx_above - 6.6]);
    translate([Xs, Ys, z_mx_bot - mx_post_l]) cylinder(d = mx_post_d, h = mx_post_l);
  }
  ghost([0.85, 0.7, 0.3]) for (p = mx_pins) translate([p[0], p[1], z_mx_bot - 1.6]) cylinder(d = 1.5, h = 1.6); // pins trimmed after soldering
}
module xiao() {
  ghost([0.1, 0.4, 0.35]) translate([0, 0, z_x0]) linear_extrude(xiao_pcb_t) board2d();
  ghost([0.75, 0.75, 0.78]) {
    u = xk(15.113, 13.39); translate([u[0], u[1], z_x1]) cube([usb_d, usb_w, usb_h]);
    s = xk(4.0, 13.8); translate([s[0], s[1], z_x1]) cube([8.6, 9.4, 1.6]); // approximate shield can
  }
  ghost([1, 0.2, 0.2]) for (k = [[18.16, 14.6], [20.32, 14.6]]) { p = xk(k[0], k[1]); translate([p[0] - 0.5, p[1] - 0.5, z_x1]) cube([1, 1, 0.5]); }
  if (stage == "battery") // stage-2 solder joints on the underside BAT pads
    ghost([0.95, 0.8, 0.2]) for (k = [[10.795, 4.445], [12.70, 4.445]]) { p = xk(k[0], k[1]); translate([p[0] - 1.0, p[1] - 0.5, z_x0 - 0.6]) cube([2.0, 1.0, 0.6]); }
}
module battery() {
  ghost([0.95, 0.72, 0.1]) translate([bat_x0, Ys - battery_w / 2, z_bat0]) cube([battery_l * 0.28, battery_w, battery_t]);  // protection-board end
  ghost([0.75, 0.75, 0.75]) translate([bat_x0 + battery_l * 0.28, Ys - battery_w / 2, z_bat0]) cube([battery_l * 0.72, battery_w, battery_t]);
}
module motor() {
  ghost([0.7, 0.7, 0.72]) translate(motor_c) rotate([-90, 0, 0]) translate([0, 0, -motor_t / 2]) cylinder(d = motor_d, h = motor_t);
}
module slide_switch() {
  ghost([0.25, 0.25, 0.28]) translate([s1_x0, s1_y1 - s1_h, s1_z0]) cube([s1_l, s1_h, s1_w]);
  ghost([0.1, 0.1, 0.1]) translate([s1_cx - 0.75, s1_y1, s1_act_z - 0.6]) cube([1.5, s1_act_l, 1.2]);
}
module screws(check = false) { // check = true: thread drawn at the hole size, for the collision check
  ghost([0.8, 0.8, 0.82]) for (p = screw_xy) translate([p[0], p[1], 0]) {
    cylinder(d = head_d, h = head_h);
    cylinder(d = check ? screw_pilot - 0.1 : screw_d, h = screw_len);
  }
}
module axial(a, b, len, dia, col) {
  pa = hole(a[0], a[1]); pb = hole(b[0], b[1]); m = (pa + pb) / 2; d = pb - pa;
  ang = atan2(d[1], d[0]);
  color(col) translate([m[0], m[1], z_pf1 + dia / 2]) rotate([0, 0, ang]) rotate([0, 90, 0]) translate([0, 0, -len / 2]) cylinder(d = dia, h = len);
}
module perfboard() {
  color([0.82, 0.68, 0.42]) difference() {
    translate([perf_x0, perf_y0, z_pf0]) cube([perf_cols * pitch, perf_rows * pitch, perf_t]);
    for (c = [1:perf_cols]) for (r = [1:perf_rows]) { p = hole(c, r); translate([p[0], p[1], z_pf0 - 1]) cylinder(d = 1.0, h = perf_t + 2, $fn = 12); }
  }
  // transistor Q1: legs in column F, rows 2-4, flat face toward the battery (+X), body q_lift above the board
  q = hole(6, 3);
  color([0.15, 0.15, 0.15]) translate([q[0], q[1], z_pf1 + q_lift]) intersection() {
    cylinder(d = q_w, h = q_h);
    translate([-q_w, -q_w, 0]) cube([q_w + (q_d - q_w / 2), 2 * q_w, q_h]);
  }
  color([0.6, 0.6, 0.6]) for (dy = [-pitch, 0, pitch]) translate([q[0] - 0.2, q[1] + dy - 0.2, z_pf1]) cube([0.4, 0.4, q_lift]); // legs
  axial([1, 3], [5, 3], res_l, 2.3, [0.85, 0.62, 0.45]);   // R1 1 k
  axial([1, 2], [5, 2], res_l, 2.3, [0.45, 0.6, 0.85]);    // R2 10 k
  axial([2, 5], [5, 5], dio_l, dio_d, [0.85, 0.2, 0.2]);   // CR1 1N4148 (band at column B)
}

module mx_switch_check() { // housing shrunk 0.05 mm per side: the real one sits exactly in the cutout
  translate([Xs - 6.95, Ys - 6.95, z_mx_bot]) cube([13.9, 13.9, mx_below - 0.01]);
  translate([Xs - mx_top / 2, Ys - mx_top / 2, H + 0.01]) cube([mx_top, mx_top, 6.6]);
  translate([Xs, Ys, z_mx_bot - mx_post_l]) cylinder(d = mx_post_d, h = mx_post_l);
  for (p = mx_pins) translate([p[0], p[1], z_mx_bot - 1.6]) cylinder(d = 1.5, h = 1.6);
}
module bay_fill() { if (stage == "battery") battery(); }
module electronics() { mx_switch(); xiao(); bay_fill(); motor(); if (stage == "battery") slide_switch(); perfboard(); }

// ---------- views ----------
shell_col = [0.95, 0.55, 0.15, 0.55];
lid_col = [0.95, 0.8, 0.3];
fit_depth = H - hold_z0 + 0.5;   // fit test: the top of the case down to just below the XIAO clips
if (part == "none") { } // used by the collision-check harness
else if (part == "top_shell") translate([0, 0, H]) mirror([0, 0, 1]) top_shell();
else if (part == "floor_lid") floor_lid();
else if (part == "print_set") {
  translate([0, 0, H]) mirror([0, 0, 1]) top_shell();
  translate([0, W + 2 * bulge_r + 4, 0]) floor_lid();
}
else if (part == "exploded") {
  color(shell_col) translate([0, 0, 40]) top_shell();
  translate([0, 0, 54]) keycap();
  translate([0, 0, 46]) mx_switch();
  translate([0, 0, 20]) { xiao(); if (stage == "battery") slide_switch(); }
  bay_fill(); motor(); perfboard();
  color(lid_col) translate([0, 0, -12]) floor_lid();
  translate([0, 0, -26]) screws();
}
else if (part == "inside_top") { // case with the top plate cut away: top layer
  intersection() { color(shell_col) top_shell(); translate([-10, -10, -1]) cube([L + 20, W + 20, z_p0 + 1 - 0.01]); }
  color(lid_col) floor_lid(); electronics();
}
else if (part == "inside_bottom") { // walls cut below the XIAO: bottom layer
  intersection() { color(shell_col) top_shell(); translate([-10, -10, -1]) cube([L + 20, W + 20, z_sep0 + 1]); }
  intersection() { color(lid_col) floor_lid(); translate([-10, -10, -1]) cube([L + 20, W + 20, z_sep0 + 2]); }
  bay_fill(); motor(); perfboard();
}
else if (part == "fit_test") { // top of the shell: switch clips, keycap, LED window, XIAO clips and USB-C slot
  translate([0, 0, H]) mirror([0, 0, 1]) intersection() { top_shell(); translate([-10, -10, H - fit_depth]) cube([L + 20, W + 20, fit_depth + 1]); }
}
else if (part == "section") {
  intersection() {
    union() { color(shell_col) top_shell(); color(lid_col) floor_lid(); electronics(); keycap(); screws(); }
    translate([-10, -1, -1]) cube([L + 20, Ys + 1, 60]);
  }
}
else { // assembly
  color(shell_col) top_shell();
  color(lid_col) floor_lid();
  electronics();
  keycap();
  screws();
}
