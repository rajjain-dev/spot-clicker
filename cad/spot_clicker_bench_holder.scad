// Spot Clicker - bench holder (November 16, 2026)
// Holds the XIAO, the driver perfboard and the motor on one base while you develop,
// so plugging and unplugging USB can't jerk the XIAO around on its wires.
// The XIAO sits parts-up between two end frames: the back frame stops it sliding when
// you push a cable in, and the front frame (under the USB-C) stops it when you pull.
// A small zip tie or rubber band through the two slots holds it down.
// Print flat, no supports. Units: mm. X = length (USB-C end at +X), Y = width, Z = up.

/* [Fit] */
fit = 0.2;          // clearance around the XIAO and the perfboard
base_t = 2.0;       // base plate thickness
ped_h = 1.0;        // pedestal under the XIAO, keeps its edge solder joints off the base
frame_w = 1.6;      // end-frame wall thickness
tie_x = 5.4;        // zip-tie position along the XIAO: over the unused D5/D8 pads and the metal shield, on the pedestal
$fn = 48;

// ---------- published sizes ----------
xiao_l = 20.955; xiao_w = 17.78; xiao_r = 1.905; xiao_t = 1.6;  // Seeed v1.2 KiCad outline
usb_over = 1.51;                                                 // USB-C shell past the board edge
perf = 15.24;                                                    // 6 x 6 holes
motor_d = 10.0;

// ---------- layout ----------
W = 28;                                        // base width
Yc = W / 2;
margin = 2.5;
motor_c = [margin + motor_d / 2 + 0.3, Yc];
perf_x0 = motor_c[0] + motor_d / 2 + 0.3 + 3.0;
perf_x1 = perf_x0 + perf + 2 * fit;
x0 = perf_x1 + 1.2 + 6.0;                      // XIAO antenna end
x1 = x0 + xiao_l;                              // XIAO USB end (board edge)
front_x = x1 + usb_over - 0.15;                // front frame stays just behind the USB-C opening
L = front_x + 0.1;
y0 = Yc - xiao_w / 2;
z_ped = base_t + ped_h;                        // XIAO underside
z_top = z_ped + xiao_t;                        // XIAO top surface
echo(str("HOLDER L x W = ", L, " x ", W, " mm"));

module board2d(o = 0) { translate([x0, y0]) offset(r = o) translate([xiao_r, xiao_r]) offset(r = xiao_r) square([xiao_l - 2 * xiao_r, xiao_w - 2 * xiao_r]); }
module rbox(size, r) { translate([r, r, 0]) linear_extrude(size[2]) offset(r = r) square([size[0] - 2 * r, size[1] - 2 * r]); }

module holder() {
  difference() {
    union() {
      rbox([L, W, base_t], 2.0);
      // pedestal under the middle of the XIAO, clear of the edge pads
      translate([x0 + 0.6, y0 + 1.8, base_t - 0.01]) cube([xiao_l - 1.2, xiao_w - 3.6, ped_h + 0.01]);
      // end frames around the board outline; the long edges stay open for the soldered wires
      intersection() {
        translate([0, 0, base_t - 0.01]) linear_extrude(z_top - base_t + 0.01) difference() { board2d(fit + frame_w); board2d(fit); }
        union() {
          translate([x0 - 5, -1, 0]) cube([1.9 + 5, W + 2, 20]);               // back frame (antenna end)
          translate([x1 - 1.85, -1, 0]) cube([front_x - (x1 - 1.85), W + 2, 20]); // front frame (USB end)
        }
      }
      // perfboard pocket: low walls locate it; stick it down on 1 mm foam tape
      translate([perf_x0 - 1.2, Yc - perf / 2 - fit - 1.2, base_t - 0.01]) difference() {
        cube([perf + 2 * fit + 2.4, perf + 2 * fit + 2.4, 1.5]);
        translate([1.2, 1.2, -1]) cube([perf + 2 * fit, perf + 2 * fit, 4]);
      }
    }
    // groove across the pedestal under the XIAO's BAT pads, for the later battery wires
    translate([x0 + 9.0, y0 - 1, base_t]) cube([6.5, xiao_w + 2, ped_h + 1]);
    // zip-tie slots either side of the XIAO
    for (y = [y0 - fit - 2.6, y0 + xiao_w + fit + 0.8]) translate([x0 + tie_x - 1.6, y, -1]) cube([3.2, 1.8, 10]);
    // motor recess (the motor's own sticky pad holds it) with a notch for its leads
    translate([motor_c[0], motor_c[1], base_t - 1.0]) cylinder(d = motor_d + 0.6, h = 5);
    translate([motor_c[0], motor_c[1] - 1.5, base_t - 1.0]) cube([motor_d / 2 + 1.5, 3, 5]);
    // tie points for thread or twist ties, beside the wire gap between the perfboard and the XIAO
    for (y = [1.6, W - 1.6]) for (dx = [-1.5, 1.5]) translate([perf_x1 + 4.2 + dx, y, -1]) cylinder(d = 1.6, h = 10);
  }
}

module xiao_ghost() {
  color([0.1, 0.4, 0.35]) translate([0, 0, z_ped]) linear_extrude(xiao_t) board2d();
  color([0.75, 0.75, 0.78]) translate([x0 + 15.113, y0 + xiao_w - 13.39, z_top]) cube([7.35, 9.0, 3.3]);
}

part = "holder"; // [holder, preview]
if (part == "preview") {
  color([0.95, 0.55, 0.15]) holder();
  xiao_ghost();
  color([0.82, 0.68, 0.42]) translate([perf_x0 + fit, Yc - perf / 2, base_t + 1.0]) cube([perf, perf, 1.5]);
  color([0.7, 0.7, 0.72]) translate([motor_c[0], motor_c[1], base_t - 1.0]) cylinder(d = motor_d, h = 2.7);
} else holder();
