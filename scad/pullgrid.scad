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
// Fixed shelves: height of each shelf's TOP above the interior floor. Each gap gets its own pull-out (tier).
shelves = [];

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

/* [Advanced: fixed shelves] */
// Shelf thickness
shelf_thickness = 19;
// How far each shelf's front edge sits behind the front plane
shelf_setback = 0;

/* [Advanced: hinges] */
// Override auto hinges: list of [center height, intrusion, hinge height, hinge depth]. Empty = auto.
hinges = [];
// Extra intrusion along the hinge side if the door can't swing past 90 degrees
door_intrusion = 0;

/* [Expert: keep-outs] */
// Extra obstacles: list of [x, y, z, width, depth, height] in interior coordinates
keepouts = [];

/* [Door] */
// mount = your door comes off its hinges and becomes the pull-out's front; keep = door stays hinged;
// none = no door (or it stays off)
door_mode = "mount"; // [mount, keep, none]
// Door thickness
door_thickness = 19;
// How far the door overlaps the opening on each side (preview only)
door_overlay = 12.7;
// Face frame depth, front to back (-1 = auto: 19 for face frame, 0 for frameless)
face_frame_thickness = -1;
// Kept doors: can the door swing past 90 degrees? If not, it blocks the hinge side of a pulled-out tier
door_opens = "past_90"; // [past_90, only_90]

/* [Front handle] */
// When the front plate is the face (door kept, or no door). A mounted door keeps its own pull.
// slot = finger slot through the plate; bar, arch, knob = printed, screwed on from inside;
// pull = a store-bought cabinet pull
handle = "slot"; // [slot, bar, arch, knob, pull, none]
handle_dir = "horizontal"; // [horizontal, vertical]
handle_pos = "top"; // [top, middle, bottom]
// With one handle: across the front
handle_across = "center"; // [center, left, right]
// Per pull-out, side by side (-1 = auto: one, or one each side of a board down the middle)
handle_count = -1; // [-1, 1, 2]
// Slot length, hole spacing (bar, arch, pull: 96 and 128 are stocked everywhere) or knob diameter (-1 = auto)
handle_size = -1;

/* [Frame] */
// openGrid panels per pull-out, running front to back
panel_count = 1;
// Sides of a pulled-out tier you can reach. auto = both, unless a kept door only opens to 90 degrees.
// One side = a single panel against the other side, every accessory facing you.
reach_from = "auto"; // [auto, both, left, right]
// Per pull-out override, beats reach_from: [[tier, position from the left, "both" | "left" | "right" | "auto"], ...]
sides = [];
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
part = "assembly"; // [assembly, carriage, pieces, rail_pieces, boards, rails, slides_fixed, slides_moving, door, cabinet, keepouts, envelope, print, none]
// With part = print: which part (index in the PULLGRID part list)
print_index = 0;
// Preview only: how far the frame is pulled out (0 = closed, 1 = full slide travel)
extension = 0; // [0:0.05:1]

/* [Hidden] */
// tests: which pull-out G describes (tier index from 0, position from 1)
test_tier = 0;
test_pullout = 1;
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
HUNG = door_mode == "keep" && hinge_side != "none";   // "none": no door, nothing to dodge
hinge_list = !HUNG ? [] : (len(hinges) > 0 ? hinges : auto_hinges);

// Hinges → keep-outs on the hinge side of the opening
function hinge_x(intr) = hinge_side == "left" ? o_l : front_w - o_r - intr;
hinge_keepouts = [for (h = hinge_list) [hinge_x(h[1]), 0, h[0] - h[2] / 2, h[1], h[3], h[2]]];
door_keepouts = (!HUNG || door_intrusion <= 0) ? [] :
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
// front gap: tie-rod nuts stick out 7.2 mm, and handles their own depth, and both
// must clear a closed door
HD = HUNG ? handle_depth(handle) : 0;
CF = clear_front >= 0 ? clear_front : max(0, 9 - FFT, HD + 2 - FFT);
AT = angle_thickness > 0 ? angle_thickness : (region == "metric" ? 3.0 : 3.2);
M = region == "metric";
// Which sides of each pull-out you can reach. Auto: a kept door stopped at 90
// degrees blocks the pull-out next to its hinges (the others pull out past it);
// side-by-side pull-outs on a mounted door come out together and face each other
// across a ~40 mm gap, so the outer ones face outward.
function reach_of(t, p, N) = let(m = [for (s = sides) if (s[0] == t && s[1] == p && s[2] != "auto") s[2]])
    len(m) ? m[0]
  : reach_from != "auto" ? reach_from
  : HUNG && door_opens == "only_90" && p == (hinge_side == "left" ? 1 : N)
    ? (hinge_side == "left" ? "right" : "left")
  : MOUNT && N > 1 && (p == 1 || p == N) ? (p == 1 ? "left" : "right")
  : "both";
TIER_REACH = reach_from == "auto" ? "both" : reach_from;   // tier-level layout: validity, slides, sizes
env0 = base_envelope(front_w, front_h, r_w, r_h, interior_depth,
                     o_l, o_r, o_b, o_t, clear_side, clear_top, clear_rear, CF);

// Shelves split the cabinet into tiers. Each tier is solved on its own, in
// local coordinates: z = 0 is what its rails stand on (floor, shelf or a
// platform keep-out), so identical gaps give identical parts.
function sort_asc(v) = len(v) <= 1 ? v : let(p = v[0], r = [for (i = [1 : len(v) - 1]) v[i]])
    concat(sort_asc([for (x = r) if (x < p) x]), [p], sort_asc([for (x = r) if (x >= p) x]));
SH = [for (s = sort_asc(shelves)) if (s > 0 && s - shelf_thickness < front_h - o_t) s];
K = len(SH) + 1;
// [support, bottom, top, front] per gap
BAYS = [for (i = seq(K)) [i == 0 ? 0 : SH[i - 1], i == 0 ? o_b : SH[i - 1],
                          i < K - 1 ? SH[i] - shelf_thickness - clear_top : BIG, i == 0 ? CF : max(CF, shelf_setback)]];
SOLVED = [for (b = BAYS) apply_keepouts(tier_envelope(env0, b[0], b[1], b[2], b[3]), all_keepouts)];

function local_env(e) = [e[0], e[1], e[2] - e[6], e[3] - e[6], e[4], e[5], 0];
function opts(smax, leg, rows, reach) =
    [["panels", max(1, panel_count)], ["board_t", panel_thickness], ["slide_t", slide_t], ["slide_h", slide_h],
     ["bed", bed_size], ["pullouts", pullouts], ["region", region], ["rail_type", rail_type],
     ["angle_t", AT], ["door_mode", door_mode], ["fft", FFT], ["reach", reach],
     ["slide_max", smax], ["leg_force", leg], ["br_rows", rows],
     ["handle", handle], ["handle_dir", handle_dir], ["handle_pos", handle_pos], ["handle_across", handle_across],
     ["handle_count", handle_count], ["handle_size", handle_size]];
function geom(e, smax = BIG, leg = -1, rows = 2, reach = TIER_REACH) =
    env_valid(e) ? carriage_geometry(local_env(e), opts(smax, leg, rows, reach)) : [];
function ok(Gt) = len(Gt) > 0 && carriage_valid(Gt);
function vmax(v) = len(v) ? max(v) : 0;
function vmin(v) = len(v) ? min(v) : 0;
function vsum(v) = sum(v, len(v));
function uniq(v) = [for (i = seq(len(v))) if (len([for (j = seq(i)) if (v[j] == v[i]) 1]) == 0) v[i]];

// Pass 1: each tier alone. A mounted door gangs every tier, so they share a
// front plane (the deepest set-back wins) and a slide length (the shortest wins).
GA = [for (r = SOLVED) geom(r[0])];
Y0 = vmax([for (i = seq(K)) if (ok(GA[i])) SOLVED[i][0][4]]);
ENV = [for (r = SOLVED) let(e = r[0]) MOUNT ? [e[0], e[1], e[2], e[3], max(e[4], Y0), e[5], e[6]] : e];
GB = [for (e = ENV) geom(e)];
SMAX = MOUNT ? vmin([for (Gt = GB) if (ok(Gt) && g(Gt, "slide_len") > 0) g(Gt, "slide_len")]) : 0;
LEGS = [for (Gt = GB) if (ok(Gt)) g(Gt, "leg")];
LEG = rail_type == "angle" && vmin(LEGS) > 0 ? vmax(LEGS) : -1;   // one stock size of angle
GANGED = MOUNT && len([for (Gt = GB) if (ok(Gt)) 1]) > 1;
GC = [for (e = ENV) geom(e, SMAX > 0 ? SMAX : BIG, LEG, GANGED ? 1 : 2)];
// One G per pull-out: the tier's envelope, slides and position, its own panel layout.
// [position, reach, G with N = 1 and its own xo]
function gset(Gt, k, v) = [for (kv = Gt) kv[0] == k ? [k, v] : kv];
function units(i) = let(Gt = GC[i], N = g(Gt, "N"), xs = g(Gt, "xo"))
    [for (p = seq(N)) let(r = reach_of(i + 1, p + 1, N),
                          Gr = r == TIER_REACH ? Gt : geom(ENV[i], SMAX > 0 ? SMAX : BIG, LEG, GANGED ? 1 : 2, r),
                          use = ok(Gr) ? Gr : Gt)
        [p + 1, ok(Gr) ? r : TIER_REACH, gset(gset(use, "N", 1), "xo", [xs[p]])]];
// [tier number, z of its support, G, envelope (cabinet coordinates), keep-out log, pull-outs]
TL = [for (i = seq(K)) [i + 1, ENV[i][6], GC[i], ENV[i], SOLVED[i][1], ok(GC[i]) ? units(i) : []]];
TV = [for (t = TL) if (ok(t[2])) t];
fits = len(TV) > 0;
// every pull-out: [tier, position, G, pull-outs in its tier, reach, z of its support]
UNITS = [for (t = TV) for (u = t[5]) [t[0], u[0], u[2], len(t[5]), u[1], t[1]]];
TT = fits ? TV[min(test_tier, len(TV) - 1)] : [];
G = fits ? TT[5][max(0, min(test_pullout, len(TT[5])) - 1)][2] : [];   // one pull-out's layout (tests)

// Parts with the same shape share a print file, whichever pull-outs they come from.
// A part every pull-out uses gets no label; otherwise the label names the tiers
// (or single pull-outs) that use it. Order: by family, then tier.
FAMS = ["rail_L", "rail_R", "base", "front", "rear", "toprail", "bracket", "handle", "key"];
function starts(s, p) = len(s) >= len(p) && len([for (i = seq(len(p))) if (s[i] != p[i]) 1]) == 0;
function join(v, sep) = len(v) == 0 ? "" : len(v) == 1 ? str(v[0]) : str(v[0], sep, join([for (i = [1 : len(v) - 1]) v[i]], sep));
function join_and(v) = len(v) <= 2 ? join(v, " & ") : str(v[0], ", ", join_and([for (i = [1 : len(v) - 1]) v[i]]));
function tier_names(ns) = str(len(ns) > 1 ? "Tiers " : "Tier ", join_and(ns));
function unit_name(u) = let(t = u[0], p = u[1], N = u[3])
    N == 1 ? str("Tier ", t)
  : K == 1 ? (N == 2 ? (p == 1 ? "Left pull-out" : "Right pull-out") : str("Pull-out ", p))
  : str("Tier ", t, " ", N == 2 ? (p == 1 ? "left" : "right") : str("pull-out ", p));
// whole tiers by number, single pull-outs by name; the same position in every
// tier is "Left pull-outs"
function group_label(us) = let(pos = uniq([for (ui = us) UNITS[ui][1]]), Ns = uniq([for (ui = us) UNITS[ui][3]]),
        tiers = uniq([for (ui = us) UNITS[ui][0]]), every = len(us) == len([for (u = UNITS) if (u[1] == pos[0] && u[3] == Ns[0]) 1]))
    len(tiers) > 1 && len(pos) == 1 && len(Ns) == 1 && Ns[0] > 1
      ? [str(Ns[0] == 2 ? (pos[0] == 1 ? "Left pull-outs" : "Right pull-outs") : str("Pull-out ", pos[0], " in each tier"),
             every ? "" : str(", tiers ", join_and(tiers))),
         str(every ? "" : str("t", join(tiers, "-")), "p", pos[0])]
      : group_label_(us);
function group_label_(us) = let(tiers = uniq([for (ui = us) UNITS[ui][0]]),
        full = [for (t = tiers) if (len([for (u = UNITS) if (u[0] == t) 1]) == len([for (ui = us) if (UNITS[ui][0] == t) 1])) t],
        part = [for (ui = us) if (len(search(UNITS[ui][0], full)) == 0) ui])
    [join(concat(len(full) ? [tier_names(full)] : [], [for (ui = part) unit_name(UNITS[ui])]), ", "),
     join(concat([for (t = full) str("t", t)], [for (ui = part) str("t", UNITS[ui][0], "p", UNITS[ui][1])]), "-")];
TSPECS = [for (u = UNITS) part_specs(u[2])];
ALL = [for (f = FAMS) for (ui = seq(len(UNITS))) for (s = TSPECS[ui]) if (starts(s[3], f)) [part_sig(UNITS[ui][2], s), s, UNITS[ui][0], ui]];
SIGS = [for (a = ALL) a[0]];
specs = [for (sg = uniq(SIGS)) let(m = [for (a = ALL) if (a[0] == sg) a], s = m[0][1], us = uniq([for (a = m) a[3]]),
                                   tagged = len(us) < len(UNITS), L = tagged ? group_label(us) : ["", ""],
                                   // keys come with 2 spares per pull-out; keep 2 for the build
                                   q = s[0] == "key" ? vsum([for (a = m) a[1][2] - 2]) + 2 : vsum([for (a = m) a[1][2]]))
    [tagged ? str(L[1], "_", s[0]) : s[0], tagged ? str(L[0], ": ", s[1]) : s[1],
     q, s[3], s[4], s[5], s[6], s[7], s[8], s[9], s[10], s[11], m[0][3]]];   // [12] = index in UNITS

// ---------- Report (the site parses lines starting with PULLGRID) ----------
// Per-tier lines start "tier=<n> "; everything else covers the whole build.
function inch(mm) = round(mm / 25.4 * 8) / 8;  // nearest 1/8"
function nrods(Gt) = g(Gt, "n_rods") * g(Gt, "N");
function nbr(Gt) = MOUNT ? g(Gt, "N") * len(g(Gt, "br_x")) * len(g(Gt, "br_z")) : 0;
function floor_screws(Gt) = let(N = g(Gt, "N"), nr = g(Gt, "n_rail"), rs = g(Gt, "rail_len") / nr - 36)
    N * 2 * (rail_type == "angle" ? max(2, ceil(g(Gt, "rail_len") / 120)) : nr * (max(1, ceil(rs / 110)) + 1));
echo(str("PULLGRID tiers=", K));
for (t = TL) for (l = t[4])
    echo(str("PULLGRID keepout=", l[0], " dodged_by=", ko_option_names[l[1]], " label=", keepout_labels[l[0]], K > 1 ? str(", tier ", t[0]) : ""));
echo(str("PULLGRID hinges=", len(hinge_keepouts)));
echo(str("PULLGRID door=", door_mode, " region=", region, " rails=", rail_type, " reach=", reach_from));
if (!fits) echo("PULLGRID ERROR no_fit");
for (t = TL) let(n = t[0], e = t[3], Gt = t[2]) if (!ok(Gt))
    echo(str("PULLGRID tier=", n, " floor=", t[1], " skipped height=", max(0, round(env_h(e)))));
else {
    echo(str("PULLGRID tier=", n, " floor=", t[1], " envelope_mm=", [env_w(e), env_d(e), env_h(e)]));
    echo(str("PULLGRID tier=", n, " slide_mm=", g(Gt, "slide_len")));
    echo(str("PULLGRID tier=", n, " panel_cells=", [g(Gt, "ny"), g(Gt, "nz")], " x", g(Gt, "panels")));
    echo(str("PULLGRID tier=", n, " pullouts=", g(Gt, "N")));
    echo(str("PULLGRID tier=", n, " carriage_mm=", [g(Gt, "Wc"), g(Gt, "Lc"), g(Gt, "z_top") - g(Gt, "zs0")]));
    // where to put the floor rails: outer face from the interior left wall, front end
    // behind the front plane, and the gap between the two rail walls
    echo(str("PULLGRID tier=", n, " rails_mm=", [for (x = g(Gt, "xo")) x], " front=", g(Gt, "y_f"), " spacing=", g(Gt, "wp") - 2 * g(Gt, "RAIL_T")));
    echo(str("PULLGRID tier=", n, " boards_y=", chunks(g(Gt, "ny")), " boards_z=", chunks(g(Gt, "nz")),
             " type=", panel_thickness < 5 ? "lite" : "full"));
    if (MOUNT) echo(str("PULLGRID tier=", n, " bracket_mm=", g(Gt, "br_len")));
    // each pull-out, left to right: which sides you can reach, how many panels, and
    // for the viewer: its box in cabinet x/z, and where its openGrid cells start (y, z)
    for (u = t[5]) let(Gu = u[2], x0 = g(Gu, "xo")[0])
        echo(str("PULLGRID tier=", n, " pullout=", u[0], " reach=", u[1], " panels=", g(Gu, "panels"),
                 " box=", [x0, x0 + g(Gu, "wp"), t[1], t[1] + g(Gu, "z_top") + 1],
                 " grid=", [g(Gu, "y_f") + 0.6, t[1] + g(Gu, "zb") + 0.3]));
}
if (fits) {
    GS = [for (u = UNITS) u[2]];
    stick = M ? 1000 : 1828.8;                                         // M6 x 1 m / 1/4" x 6 ft
    astick = M ? 1000 : 1219.2;                                        // angle: 1 m / 4 ft
    rods = vsum([for (Gt = GS) nrods(Gt)]);
    brackets = vsum([for (Gt = GS) nbr(Gt)]);
    RLS = uniq([for (Gt = GS) g(Gt, "rod_len")]);
    ALS = uniq([for (Gt = GS) g(Gt, "rail_len")]);
    SLS = uniq([for (Gt = GS) if (g(Gt, "slide_len") > 0) g(Gt, "slide_len")]);
    for (rl = RLS) echo(str("PULLGRID cut=", vsum([for (Gt = GS) if (g(Gt, "rod_len") == rl) nrods(Gt)]), " len=", rl, " item=tie rod"));
    if (rail_type == "angle") for (al = ALS)
        echo(str("PULLGRID cut=", vsum([for (Gt = GS) if (g(Gt, "rail_len") == al) 2 * g(Gt, "N")]), " len=", al, " item=aluminum angle rail"));
    for (i = seq(len(specs))) let(s = specs[i], sz = print_size(s))
        echo(str("PULLGRID part=", i, " id=", s[0], " qty=", s[2], " size=", sz, " label=", s[1]));
    // shopping list, in the names each market uses
    for (sl = SLS) let(n = vsum([for (Gt = GS) if (g(Gt, "slide_len") == sl) g(Gt, "N")]))
        echo(str("PULLGRID hw=", n, " item=", M
            ? str("pair of ", sl, " mm full-extension ball-bearing drawer runners (45 mm, side-mount, 12.7 mm clearance)")
            : str("pair of ", round(sl / 25.4), "in full-extension side-mount ball-bearing drawer slides (45 mm tall, 1/2in clearance)")));
    if (rail_type == "angle") let(leg = vmax([for (Gt = GS) g(Gt, "leg")]),
        // whole rails per stick, with a saw kerf
        sticks = vsum([for (al = ALS) ceil(vsum([for (Gt = GS) if (g(Gt, "rail_len") == al) 2 * g(Gt, "N")]) / max(1, floor(astick / (al + 3))))]))
        echo(str("PULLGRID hw=", sticks, " item=", M
            ? str("aluminium equal angle ", leg > 0 ? leg : 50, " x ", leg > 0 ? leg : 50, " mm, 1.5-3 mm thick, 1 m lengths")
            : str("aluminum angle ", leg == 38.1 ? "1-1/2in" : "2in", ", 1/16-1/8in thick, 4 ft lengths")));
    echo(str("PULLGRID hw=", vsum([for (rl = RLS) ceil(vsum([for (Gt = GS) if (g(Gt, "rod_len") == rl) nrods(Gt)]) / max(1, floor(stick / (rl + 3))))]),
             " item=", M ? "M6 threaded rod, 1 m" : "1/4in-20 threaded rod, 6 ft"));
    echo(str("PULLGRID hw=", 2 * rods, " item=", M ? "M6 nuts (acorn nuts look tidier at the front)" : "1/4in-20 hex nuts (acorn nuts look tidier at the front)"));
    echo(str("PULLGRID hw=", 2 * rods, " item=", M ? "M6 flat washers" : "1/4in flat washers"));
    echo(str("PULLGRID hw=", vsum([for (Gt = GS) floor_screws(Gt)]), " item=", M ? "4 x 20 mm wood screws (floor rails to cabinet)" : "#8 x 3/4in wood screws (floor rails to cabinet)"));
    hs = vsum([for (Gt = GS) printed_handle(Gt) ? len(g(Gt, "h_pts")) : 0]);   // printed handles: a screw per post
    echo(str("PULLGRID hw=", vsum([for (Gt = GS) g(Gt, "N") * 16]) + 2 * brackets + hs, " item=", str(M ? "4 x 13 mm pan-head self-tapping screws" : "#8 x 1/2in pan-head sheet-metal screws",
             MOUNT ? " (slides; brackets to plate)" : hs > 0 ? " (slides; handles)" : " (slides)")));
    if (handle == "pull") let(np = vsum([for (Gt = GS) g(Gt, "handle") == "pull" ? len(g(Gt, "h_at")) : 0]), L = g(GS[0], "h_L")) if (np > 0) {
        echo(str("PULLGRID hw=", np, " item=", M ? str("cabinet pulls, ", L, " mm hole centres") : str("cabinet pulls, ", L == 96 ? "3-3/4in (96 mm)" : L == 128 ? "5-1/16in (128 mm)" : str(inch(L), "in"), " hole centers")));
        echo(str("PULLGRID hw=", 2 * np, " item=", M ? "M4 x 12 mm machine screws (pulls: theirs are too long for the 6 mm plate)" : "8-32 x 1/2in machine screws (pulls: theirs are too long for the 6 mm plate)"));
    }
    if (MOUNT) echo(str("PULLGRID hw=", 2 * brackets, " item=", M ? "4 x 16 mm wood screws (brackets to door)" : "#8 x 5/8in wood screws (brackets to door)"));
    if (MOUNT && len(TV) > 1) echo(str("PULLGRID hw=8 item=", M ? "M4 flat washers (shims, if one tier sits back from the door)" : "#8 flat washers (shims, if one tier sits back from the door)"));
    echo("PULLGRID hw=1 item=CA glue or epoxy (plate seams)");
    for (s = specs) let(sz = print_size(s)) if (sz[0] > bed_size || sz[1] > bed_size)
        echo(str("PULLGRID WARNING part_exceeds_bed ", s[0]));
    if (len([for (Gt = GS) if (g(Gt, "slide_len") == 0) 1])) echo("PULLGRID WARNING no_standard_slide_fits");
    if (len([for (Gt = GS) if (g(Gt, "Wc") < 100) 1])) echo("PULLGRID WARNING too_narrow");
    if (rail_type == "angle" && vmin([for (Gt = GS) g(Gt, "leg")]) == 0) echo("PULLGRID WARNING angle_too_short");
    if (MOUNT && door_thickness < 15) echo("PULLGRID WARNING door_too_thin");
    if (len(TV) < K) echo("PULLGRID WARNING tier_skipped");
    if (!MOUNT && handle != "none") {
        echo(str("PULLGRID handle=", handle, " dir=", handle == "knob" ? "none" : handle_dir, " total=", vsum([for (Gt = GS) len(g(Gt, "h_at"))]),
                 " size=", g(GS[0], "h_L"), " depth=", handle_depth(handle)));
        if (len([for (Gt = GS) if (len(g(Gt, "h_at")) < g(Gt, "h_want")) 1])) echo("PULLGRID WARNING handle_blocked");
        else if (len([for (Gt = GS) if (g(Gt, "h_moved")) 1])) echo("PULLGRID WARNING handle_moved");
        if (HUNG && clear_front >= 0 && clear_front < HD + 2 - FFT) echo("PULLGRID WARNING handle_hits_door");
    }
}

// ---------- Render ----------
P = part == "frame" ? "carriage" : part;  // v0 name
SHELF_LIST = [for (s = SH) [s, shelf_thickness, shelf_setback]];
// door: in mount mode it rides on the pull-outs (one door, every tier); kept doors are shown open at 90 degrees
DOOR_Y = -FFT - 2;
module door_part() {
    dw = opening_w + 2 * door_overlay;
    z0 = o_b - door_overlay; h = opening_h + 2 * door_overlay;
    if (MOUNT && fits) translate([o_l - door_overlay, DOOR_Y - door_thickness, z0]) cube([dw, door_thickness, h]);
    else if (HUNG) {
        hx = hinge_side == "left" ? o_l - door_overlay : front_w - o_r + door_overlay;
        translate([hinge_side == "left" ? hx - door_thickness : hx, DOOR_Y - dw, z0]) cube([door_thickness, dw, h]);
    }
}
module tier_parts(Gt, ext) for (x = g(Gt, "xo")) translate([x, 0, 0]) {
    if (P == "assembly") {
        if (rail_type == "printed") { color("DimGray") rail_full(Gt, "L"); color("DimGray") rail_full(Gt, "R"); }
        color("Silver") hardware_part(Gt, "fixed");
        translate([0, ext, 0]) {
            color("SteelBlue") carriage_part(Gt);
            color("Gainsboro") boards_part(Gt);
            color("Silver") hardware_part(Gt, "moving");
        }
    }
    if (P == "carriage") carriage_part(Gt);
    if (P == "pieces") carriage_pieces(Gt);
    if (P == "rail_pieces" && rail_type == "printed") carriage_pieces(Gt, rails = true);
    if (P == "boards") boards_part(Gt);
    if (P == "rails" && rail_type == "printed") { rail_full(Gt, "L"); rail_full(Gt, "R"); }
    if (P == "slides_fixed") hardware_part(Gt, "fixed");
    if (P == "slides_moving") hardware_part(Gt, "moving");
}
if (fits) {
    // ganged tiers all travel the shared slide length; kept-door tiers each pull their own
    for (u = UNITS) translate([0, 0, u[5]]) tier_parts(u[2], -extension * g(u[2], "slide_len"));
    if (P == "assembly") translate([0, MOUNT ? -extension * g(TV[0][2], "slide_len") : 0, 0]) color("Tan", 0.6) door_part();
    if (P == "door") door_part();
    if (P == "print" && print_index >= 0 && print_index < len(specs))
        let(s = specs[print_index]) print_part(UNITS[s[12]][2], s);
    if (P == "envelope") for (t = TV) let(e = t[3])
        color("SteelBlue", 0.4) translate([e[0], e[4], e[2]]) cube([env_w(e), env_d(e), env_h(e)]);
}
if (P == "assembly" && show_cabinet) {
    cabinet_preview(front_w, front_h, r_w, r_h, interior_depth, o_l, o_r, o_b, o_t);
    shelves_preview(front_w, interior_depth, SHELF_LIST);
    keepout_preview(all_keepouts);
}
if (P == "cabinet") {
    cabinet_preview(front_w, front_h, r_w, r_h, interior_depth, o_l, o_r, o_b, o_t);
    shelves_preview(front_w, interior_depth, SHELF_LIST);
}
if (P == "keepouts") keepout_preview(all_keepouts);
