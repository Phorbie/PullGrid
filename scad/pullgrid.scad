// PullGrid — parametric vertical pull-out for deep cabinets
// https://github.com/Phorbie/PullGrid
//
// All dimensions in mm. -1 means "auto" (derived from the Basic inputs).
// See docs/parameters.md for what each input means and how to measure it.

/* [Basic] */
// Width of the cabinet opening (inside the face frame / between the side panels)
opening_w = 280;
// Height of the cabinet opening
opening_h = 600;
// Interior depth, from the front plane to the back wall
interior_depth = 560;
// Face frame cabinets have rails/stiles that overhang the interior
frame_type = "face_frame"; // [face_frame, frameless]
// Which side the door hinges are on
hinge_side = "left"; // [left, right, none]

/* [Advanced: opening offsets] */
// How far the face frame overhangs the interior on each side (-1 = auto)
offset_left = -1;
offset_right = -1;
// Height of the bottom rail above the interior floor (-1 = auto)
offset_bottom = -1;
offset_top = -1;

/* [Advanced: non-square cabinets] */
// Interior width at the back wall (-1 = same as front)
rear_w = -1;
// Interior height at the back wall (-1 = same as front)
rear_h = -1;

/* [Advanced: hinges] */
// Override auto hinges: list of [center height, intrusion, hinge height, hinge depth]. Empty = auto.
hinges = [];
// Extra intrusion along the hinge side if the door can't swing past 90 degrees
door_intrusion = 0;

/* [Expert: keep-outs] */
// Extra obstacles: list of [x, y, z, width, depth, height] in interior coordinates
keepouts = [];

/* [Door] */
// mount = your door comes off its hinges and becomes the pull-out's front; keep = door stays hinged
door_mode = "mount"; // [mount, keep]
// Door thickness
door_thickness = 19;
// How far the door overlaps the opening on each side (preview only)
door_overlay = 12.7;
// Face frame depth, front to back (-1 = auto: 19 for face frame, 0 for frameless)
face_frame_thickness = -1;

/* [Frame] */
// openGrid panels per pull-out, running front to back
panel_count = 1;
// 6.8 = openGrid Full (double-sided), 4.0 = openGrid Lite
panel_thickness = 6.8; // [6.8, 4.0]
// Pull-outs side by side (-1 = as few as fit your print bed)
pullouts = -1;
// Print bed size; parts are split to fit
bed_size = 256;

/* [Hardware] */
// Where you buy hardware: sets slide lengths, stock sizes and shopping-list names
region = "inch"; // [inch, metric]
// angle = aluminum angle floor rails (stronger, less printing); printed = no metalwork
rail_type = "angle"; // [angle, printed]
// Aluminum angle wall thickness (-1 = auto: 3.2 inch / 3.0 metric)
angle_thickness = -1;
// Side-mount slide clearance per side. Spec is 1/2" (12.7) plus up to 1/32", so aim mid-range
slide_t = 13.0;
// Slide body height (standard ball-bearing slides are 45)
slide_h = 45;

/* [Clearances] */
clear_side = 3;
clear_top = 5;
// Room behind the rear plate for tie-rod nuts (keep 10 or more)
clear_rear = 10;
// Gap in front of the front plate (-1 = auto: room for tie-rod nuts and door brackets)
clear_front = -1;

/* [Render] */
show_cabinet = true;
part = "assembly"; // [assembly, carriage, boards, rails, slides_fixed, slides_moving, door, cabinet, keepouts, envelope, print, none]
// With part = print: which part (index in the PULLGRID part list)
print_index = 0;
// Preview only: how far the frame is pulled out (0 = closed, 1 = full slide travel)
extension = 0; // [0:0.05:1]

/* [Hidden] */
include <lib/envelope.scad>
include <lib/carriage.scad>
include <lib/cabinet_preview.scad>

// ---------- Auto defaults (v0 guesses — see docs/parameters.md) ----------
FF = frame_type == "face_frame";
auto_off_side = FF ? 10 : 0;
auto_off_bottom = FF ? 15 : 0;
auto_off_top = FF ? 10 : 0;

o_l = offset_left   >= 0 ? offset_left   : auto_off_side;
o_r = offset_right  >= 0 ? offset_right  : auto_off_side;
o_b = offset_bottom >= 0 ? offset_bottom : auto_off_bottom;
o_t = offset_top    >= 0 ? offset_top    : auto_off_top;

front_w = opening_w + o_l + o_r;
front_h = opening_h + o_b + o_t;
r_w = rear_w > 0 ? rear_w : front_w;
r_h = rear_h > 0 ? rear_h : front_h;

// Euro hinges: 2 under 600mm of door, 3 under 1000mm, else 4; ~80mm from the ends
auto_hinge_count = opening_h < 600 ? 2 : (opening_h < 1000 ? 3 : 4);
auto_hinge_intrusion = FF ? 12 : 20;
auto_hinges = [for (i = [0 : auto_hinge_count - 1])
    [o_b + 80 + i * (opening_h - 160) / (auto_hinge_count - 1), auto_hinge_intrusion, 50, 45]];
// a mounted door has no hinges, so nothing to dodge
MOUNT = door_mode == "mount";
hinge_list = (hinge_side == "none" || MOUNT) ? [] : (len(hinges) > 0 ? hinges : auto_hinges);

// Hinges → keep-outs on the hinge side of the opening
function hinge_x(intr) = hinge_side == "left" ? o_l : front_w - o_r - intr;
hinge_keepouts = [for (h = hinge_list) [hinge_x(h[1]), 0, h[0] - h[2] / 2, h[1], h[3], h[2]]];
door_keepouts = (hinge_side == "none" || MOUNT || door_intrusion <= 0) ? [] :
    [[hinge_x(door_intrusion), 0, o_b, door_intrusion, 30, opening_h]];
all_keepouts = concat(hinge_keepouts, door_keepouts, keepouts);
// OpenSCAD counts [0:-1] backwards, so empty lists need a guard
function seq(n) = n > 0 ? [0 : n - 1] : [];
keepout_labels = concat(
    [for (i = seq(len(hinge_keepouts))) str("hinge ", i + 1)],
    len(door_keepouts) > 0 ? ["door swing"] : [],
    [for (i = seq(len(keepouts))) str("keep-out ", i + 1)]);

// ---------- Solve ----------
FFT = face_frame_thickness >= 0 ? face_frame_thickness : (FF ? 19 : 0);
// front gap: tie-rod nuts stick out 7.2 mm and must clear the closed door
CF = clear_front >= 0 ? clear_front : max(0, 9 - FFT);
AT = angle_thickness > 0 ? angle_thickness : (region == "metric" ? 3.0 : 3.2);
env0 = base_envelope(front_w, front_h, r_w, r_h, interior_depth,
                     o_l, o_r, o_b, o_t, clear_side, clear_top, clear_rear, CF);
solved = apply_keepouts(env0, all_keepouts);
env = solved[0];
OPTS = [["panels", max(1, panel_count)], ["board_t", panel_thickness], ["slide_t", slide_t], ["slide_h", slide_h],
        ["bed", bed_size], ["pullouts", pullouts], ["region", region], ["rail_type", rail_type],
        ["angle_t", AT], ["door_mode", door_mode], ["fft", FFT]];
G = env_valid(env) ? carriage_geometry(env, OPTS) : [];
fits = env_valid(env) && carriage_valid(G);
specs = fits ? part_specs(G) : [];
M = region == "metric";

// ---------- Report (the site parses lines starting with PULLGRID) ----------
function inch(mm) = round(mm / 25.4 * 8) / 8;  // nearest 1/8"
echo(str("PULLGRID envelope_mm=", [env_w(env), env_d(env), env_h(env)]));
for (l = solved[1])
    echo(str("PULLGRID keepout=", l[0], " dodged_by=", ko_option_names[l[1]], " label=", keepout_labels[l[0]]));
echo(str("PULLGRID hinges=", len(hinge_keepouts)));
echo(str("PULLGRID door=", door_mode, " region=", region, " rails=", rail_type));
if (!fits) echo("PULLGRID ERROR no_fit");
if (fits) {
    N = g(G, "N"); sl = g(G, "slide_len"); nr = g(G, "n_rail"); nrods = g(G, "n_rods") * N;
    rl = g(G, "rod_len"); stick = M ? 1000 : 1828.8;             // M6 x 1 m / 1/4" x 6 ft
    per_stick = max(1, floor(stick / (rl + 3)));
    rail_seg = g(G, "rail_len") / nr - 36;
    floor_screws = N * 2 * (rail_type == "angle" ? max(2, ceil(g(G, "rail_len") / 120)) : nr * (max(1, ceil(rail_seg / 110)) + 1));
    nbr = MOUNT ? N * len(g(G, "br_x")) * len(g(G, "br_z")) : 0;
    echo(str("PULLGRID slide_mm=", sl));
    echo(str("PULLGRID panel_cells=", [g(G, "ny"), g(G, "nz")], " x", g(G, "panels")));
    echo(str("PULLGRID pullouts=", N));
    echo(str("PULLGRID carriage_mm=", [g(G, "Wc"), g(G, "Lc"), g(G, "z_top") - g(G, "zs0")]));
    // where to put the floor rails: outer face from the interior left wall, front end
    // behind the front plane, and the gap between the two rail walls
    echo(str("PULLGRID rails_mm=", [for (x = g(G, "xo")) x], " front=", g(G, "y_f"), " spacing=", g(G, "wp") - 2 * g(G, "RAIL_T")));
    echo(str("PULLGRID boards_y=", chunks(g(G, "ny")), " boards_z=", chunks(g(G, "nz")),
             " type=", panel_thickness < 5 ? "lite" : "full"));
    echo(str("PULLGRID cut=", nrods, " len=", rl, " item=tie rod"));
    if (rail_type == "angle") echo(str("PULLGRID cut=", 2 * N, " len=", g(G, "rail_len"), " item=aluminum angle rail"));
    if (MOUNT) echo(str("PULLGRID bracket_mm=", g(G, "br_len")));
    for (i = seq(len(specs))) let(s = specs[i], sz = print_size(s))
        echo(str("PULLGRID part=", i, " id=", s[0], " qty=", s[2], " size=", sz, " label=", s[1]));
    // shopping list, in the names each market uses
    if (sl > 0) echo(str("PULLGRID hw=", N, " item=", M
        ? str("pair of ", sl, " mm full-extension ball-bearing drawer runners (45 mm, side-mount, 12.7 mm clearance)")
        : str("pair of ", round(sl / 25.4), "in full-extension side-mount ball-bearing drawer slides (45 mm tall, 1/2in clearance)")));
    if (rail_type == "angle") let(leg = g(G, "leg"), total = 2 * N * g(G, "rail_len"))
        echo(str("PULLGRID hw=", ceil(total / (M ? 1000 : 1219.2)), " item=", M
            ? str("aluminium equal angle ", leg > 0 ? leg : 50, " x ", leg > 0 ? leg : 50, " mm, 1.5-3 mm thick, 1 m lengths")
            : str("aluminum angle ", leg == 38.1 ? "1-1/2in" : "2in", ", 1/16-1/8in thick, 4 ft lengths")));
    echo(str("PULLGRID hw=", ceil(nrods / per_stick), " item=", M ? "M6 threaded rod, 1 m" : "1/4in-20 threaded rod, 6 ft"));
    echo(str("PULLGRID hw=", 2 * nrods, " item=", M ? "M6 nuts (acorn nuts look tidier at the front)" : "1/4in-20 hex nuts (acorn nuts look tidier at the front)"));
    echo(str("PULLGRID hw=", 2 * nrods, " item=", M ? "M6 flat washers" : "1/4in flat washers"));
    echo(str("PULLGRID hw=", floor_screws, " item=", M ? "4 x 20 mm wood screws (floor rails to cabinet)" : "#8 x 3/4in wood screws (floor rails to cabinet)"));
    echo(str("PULLGRID hw=", N * 16 + 2 * nbr, " item=", M ? "4 x 13 mm pan-head self-tapping screws (slides; brackets to plate)" : "#8 x 1/2in pan-head sheet-metal screws (slides; brackets to plate)"));
    if (MOUNT) echo(str("PULLGRID hw=", 2 * nbr, " item=", M ? "4 x 16 mm wood screws (brackets to door)" : "#8 x 5/8in wood screws (brackets to door)"));
    echo("PULLGRID hw=1 item=CA glue or epoxy (plate seams)");
    for (s = specs) let(sz = print_size(s)) if (sz[0] > bed_size || sz[1] > bed_size)
        echo(str("PULLGRID WARNING part_exceeds_bed ", s[0]));
    if (sl == 0) echo("PULLGRID WARNING no_standard_slide_fits");
    if (g(G, "Wc") < 100) echo("PULLGRID WARNING too_narrow");
    if (rail_type == "angle" && g(G, "leg") == 0) echo("PULLGRID WARNING angle_too_short");
    if (MOUNT && door_thickness < 15) echo("PULLGRID WARNING door_too_thin");
}

// ---------- Render ----------
P = part == "frame" ? "carriage" : part;  // v0 name
// door: in mount mode it rides on the pull-out; kept doors are shown open at 90 degrees
DOOR_Y = -FFT - 2;
module door_part() {
    dw = (opening_w + 2 * door_overlay) / (MOUNT && fits ? g(G, "N") : 1);
    z0 = o_b - door_overlay; h = opening_h + 2 * door_overlay;
    if (MOUNT && fits)
        for (i = seq(g(G, "N"))) translate([o_l - door_overlay + i * dw + 1, DOOR_Y - door_thickness, z0]) cube([dw - 2, door_thickness, h]);
    else if (hinge_side != "none") {
        hx = hinge_side == "left" ? o_l - door_overlay : front_w - o_r + door_overlay;
        translate([hinge_side == "left" ? hx - door_thickness : hx, DOOR_Y - dw, z0]) cube([door_thickness, dw, h]);
    }
}
if (fits) {
    ext = -extension * g(G, "slide_len");
    for (x = g(G, "xo")) translate([x, 0, 0]) {
        if (P == "assembly") {
            if (rail_type == "printed") { color("DimGray") rail_full(G, "L"); color("DimGray") rail_full(G, "R"); }
            color("Silver") hardware_part(G, "fixed");
            translate([0, ext, 0]) {
                color("SteelBlue") carriage_part(G);
                color("Gainsboro") boards_part(G);
                color("Silver") hardware_part(G, "moving");
            }
        }
        if (P == "carriage") carriage_part(G);
        if (P == "boards") boards_part(G);
        if (P == "rails" && rail_type == "printed") { rail_full(G, "L"); rail_full(G, "R"); }
        if (P == "slides_fixed") hardware_part(G, "fixed");
        if (P == "slides_moving") hardware_part(G, "moving");
    }
    if (P == "assembly") translate([0, MOUNT ? ext : 0, 0]) color("Tan", 0.6) door_part();
    if (P == "door") door_part();
    if (P == "print" && print_index >= 0 && print_index < len(specs)) print_part(G, specs[print_index]);
    if (P == "envelope")
        color("SteelBlue", 0.4) translate([env[0], env[4], env[2]]) cube([env_w(env), env_d(env), env_h(env)]);
}
if (P == "assembly" && show_cabinet) {
    cabinet_preview(front_w, front_h, r_w, r_h, interior_depth, o_l, o_r, o_b, o_t);
    keepout_preview(all_keepouts);
}
if (P == "cabinet") cabinet_preview(front_w, front_h, r_w, r_h, interior_depth, o_l, o_r, o_b, o_t);
if (P == "keepouts") keepout_preview(all_keepouts);
