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
// openGrid panels per pull-out, running front to back
panel_count = 1;
// 6.8 = openGrid Full (double-sided), 4.0 = openGrid Lite
panel_thickness = 6.8; // [6.8, 4.0]
// Pull-outs side by side (-1 = as few as fit your print bed)
pullouts = -1;
// Print bed size; parts are split to fit
bed_size = 256;

/* [Advanced: hardware] */
// Side-mount slide thickness = clearance per side (standard 1/2" = 12.7)
slide_t = 12.7;
// Slide body height (standard ball-bearing slides are 45)
slide_h = 45;

/* [Clearances] */
clear_side = 3;
clear_top = 5;
clear_rear = 10;
clear_front = 0;

/* [Render] */
show_cabinet = true;
part = "assembly"; // [assembly, carriage, boards, rails, slides_fixed, slides_moving, cabinet, keepouts, envelope, print]
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
G = env_valid(env) ? carriage_geometry(env, max(1, panel_count), panel_thickness, slide_t, slide_h,
                                       bed_size, pullouts) : [];
fits = env_valid(env) && carriage_valid(G);
specs = fits ? part_specs(G) : [];

// ---------- Report (the site parses lines starting with PULLGRID) ----------
echo(str("PULLGRID envelope_mm=", [env_w(env), env_d(env), env_h(env)]));
for (l = solved[1])
    echo(str("PULLGRID keepout=", l[0], " dodged_by=", ko_option_names[l[1]], " label=", keepout_labels[l[0]]));
echo(str("PULLGRID hinges=", len(hinge_keepouts)));
if (!fits) echo("PULLGRID ERROR no_fit");
if (fits) {
    N = g(G, "N"); sl = g(G, "slide_len"); nr = g(G, "n_rail");
    rail_seg = g(G, "rail_len") / nr - 36;
    screws_per_seg = max(1, ceil(rail_seg / 110)) + 1;
    echo(str("PULLGRID slide_mm=", sl));
    echo(str("PULLGRID panel_cells=", [g(G, "ny"), g(G, "nz")], " x", g(G, "panels")));
    echo(str("PULLGRID pullouts=", N));
    echo(str("PULLGRID carriage_mm=", [g(G, "Wc"), g(G, "y_r") + g(G, "PT") - g(G, "y0"), g(G, "z_top") - g(G, "zs0")]));
    // where to put the floor rails: outer face from the interior left wall, front end
    // behind the front plane, and the gap between the two rail walls
    echo(str("PULLGRID rails_mm=", [for (x = g(G, "xo")) x], " front=", g(G, "y_f"), " spacing=", g(G, "wp") - 2 * g(G, "RAIL_T")));
    echo(str("PULLGRID boards_y=", chunks(g(G, "ny")), " boards_z=", chunks(g(G, "nz")),
             " type=", panel_thickness < 5 ? "lite" : "full"));
    for (i = seq(len(specs))) let(s = specs[i], sz = print_size(s))
        echo(str("PULLGRID part=", i, " id=", s[0], " qty=", s[2], " size=", sz, " label=", s[1]));
    if (sl > 0) echo(str("PULLGRID hw=", N, " item=pair of ", round(sl / 25.4), "in full-extension side-mount slides (", slide_h, " mm tall, 1/2in clearance)"));
    echo(str("PULLGRID hw=", N * 2 * nr * screws_per_seg, " item=#8 x 3/4in flat-head wood screws (floor rails to cabinet)"));
    echo(str("PULLGRID hw=", N * 16, " item=#6 x 3/8in pan-head screws (slides to rails and cheeks; often included with slides)"));
    echo(str("PULLGRID hw=", N * 8, " item=M3 x 16 socket-head screws + M3 hex nuts (plates to base)"));
    echo("PULLGRID hw=1 item=CA glue or epoxy (bowtie keys)");
    for (s = specs) let(sz = print_size(s)) if (sz[0] > bed_size || sz[1] > bed_size)
        echo(str("PULLGRID WARNING part_exceeds_bed ", s[0]));
    if (sl == 0) echo("PULLGRID WARNING no_standard_slide_fits");
    if (g(G, "Wc") < 100) echo("PULLGRID WARNING too_narrow");
}

// ---------- Render ----------
P = part == "frame" ? "carriage" : part;  // v0 name
if (fits) {
    ext = -extension * g(G, "slide_len");
    for (x = g(G, "xo")) translate([x, 0, 0]) {
        if (P == "assembly") {
            color("DimGray") rail_full(G, "L");
            color("DimGray") rail_full(G, "R");
            color("Silver") slides_part(G, "outer");
            translate([0, ext, 0]) {
                color("SteelBlue") carriage_part(G);
                color("Gainsboro") boards_part(G);
                color("Silver") slides_part(G, "inner");
            }
        }
        if (P == "carriage") carriage_part(G);
        if (P == "boards") boards_part(G);
        if (P == "rails") { rail_full(G, "L"); rail_full(G, "R"); }
        if (P == "slides_fixed") slides_part(G, "outer");
        if (P == "slides_moving") slides_part(G, "inner");
    }
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
