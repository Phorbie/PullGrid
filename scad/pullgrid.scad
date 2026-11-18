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

/* [Frame] */
// Height the slide hardware adds under the base
slide_height = 15;
// Number of openGrid panels, running front to back
panel_count = 1;
// 6.8 = openGrid full, 4.0 = openGrid lite
panel_thickness = 6.8;

/* [Clearances] */
clear_side = 3;
clear_top = 5;
clear_rear = 10;
clear_front = 0;

/* [Render] */
show_cabinet = true;
part = "assembly"; // [assembly, frame, envelope, cabinet, keepouts]
// Preview only: how far the frame is pulled out (0 = closed, 1 = full slide travel)
extension = 0; // [0:0.05:1]

/* [Hidden] */
include <lib/envelope.scad>
include <lib/frame.scad>
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
hinge_list = hinge_side == "none" ? [] : (len(hinges) > 0 ? hinges : auto_hinges);

// Hinges → keep-outs on the hinge side of the opening
function hinge_x(intr) = hinge_side == "left" ? o_l : front_w - o_r - intr;
hinge_keepouts = [for (h = hinge_list) [hinge_x(h[1]), 0, h[0] - h[2] / 2, h[1], h[3], h[2]]];
door_keepouts = (hinge_side == "none" || door_intrusion <= 0) ? [] :
    [[hinge_x(door_intrusion), 0, o_b, door_intrusion, 30, opening_h]];
all_keepouts = concat(hinge_keepouts, door_keepouts, keepouts);
// OpenSCAD counts [0:-1] backwards, so empty lists need a guard
function seq(n) = n > 0 ? [0 : n - 1] : [];
keepout_labels = concat(
    [for (i = seq(len(hinge_keepouts))) str("hinge ", i + 1)],
    len(door_keepouts) > 0 ? ["door swing"] : [],
    [for (i = seq(len(keepouts))) str("keep-out ", i + 1)]);

// ---------- Solve ----------
env0 = base_envelope(front_w, front_h, r_w, r_h, interior_depth,
                     o_l, o_r, o_b, o_t, clear_side, clear_top, clear_rear, clear_front);
solved = apply_keepouts(env0, all_keepouts);
env = solved[0];

// ---------- Report (the site parses lines starting with PULLGRID) ----------
standard_slides = [254, 305, 356, 406, 457, 508, 559];  // 10"–22"
fitting = [for (s = standard_slides) if (s <= env_d(env)) s];
slide_len = len(fitting) > 0 ? fitting[len(fitting) - 1] : 0;
layout = frame_layout(env, slide_height, 5, 5, 8, panel_count, panel_thickness);

echo(str("PULLGRID envelope_mm=", [env_w(env), env_d(env), env_h(env)]));
echo(str("PULLGRID slide_mm=", slide_len));
echo(str("PULLGRID panel_cells=", [grid_cells(layout[7]), grid_cells(layout[8])], " x", panel_count));
for (l = solved[1])
    echo(str("PULLGRID keepout=", l[0], " dodged_by=", ko_option_names[l[1]], " label=", keepout_labels[l[0]]));
echo(str("PULLGRID hinges=", len(hinge_keepouts)));
if (!env_valid(env)) echo("PULLGRID ERROR no_fit");
if (slide_len == 0) echo("PULLGRID WARNING no_standard_slide_fits");
// narrower than this and there's no room for anything on the panels
MIN_USEFUL_W = 60;
if (env_valid(env) && env_w(env) < MIN_USEFUL_W) echo("PULLGRID WARNING too_narrow");

// ---------- Render ----------
if (env_valid(env)) {
    if (part == "frame")
        color("SteelBlue") frame(env, slide_h = slide_height,
                                 panel_count = panel_count, panel_t = panel_thickness);
    if (part == "assembly")
        translate([0, -extension * slide_len, 0]) color("SteelBlue") frame(env, slide_h = slide_height,
                                 panel_count = panel_count, panel_t = panel_thickness);
    if (part == "envelope")
        color("SteelBlue", 0.4) translate([env[0], env[4], env[2]]) cube([env_w(env), env_d(env), env_h(env)]);
}
if (part == "assembly" && show_cabinet) {
    cabinet_preview(front_w, front_h, r_w, r_h, interior_depth, o_l, o_r, o_b, o_t);
    keepout_preview(all_keepouts);
}
if (part == "cabinet") cabinet_preview(front_w, front_h, r_w, r_h, interior_depth, o_l, o_r, o_b, o_t);
if (part == "keepouts") keepout_preview(all_keepouts);
