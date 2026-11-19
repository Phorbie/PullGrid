// PullGrid — printable pull-out (v2)
//
// Fixed:   two floor rails carrying standard 45 mm ball-bearing slides. Rails are
//          aluminum angle (default) or printed (no-tools fallback).
// Moving:  carriage = base tray with slide cheeks, front plate, rear plate, one top
//          rail per panel. Standard openGrid boards stand in grooves.
//          Threaded tie rods clamp front plate + base + rear plate (and each top
//          rail) into one box: seams are held in compression, no glue there.
// Door:    "mount" mode takes the cabinet door off its hinges and screws it to
//          printed brackets on the front plate. The door becomes the drawer front.
//
// Only plate seams still use printed bowtie keys + glue.
// Geometry lives in a key/value list G (see carriage_geometry); modules take G.
// X is local to one pull-out (0..wp); the assembly shifts each by g(G,"xo")[p].

function g(G, k) = G[search([k], G)[0]][1];

BIG = 10000;
FOOT_IN = 15;                                     // printed rail foot, past the slide
SLIDES_INCH = [for (i = [5 : 14]) i * 2 * 25.4];  // 10"–28" in 2" steps
SLIDES_METRIC = [250, 300, 350, 400, 450, 500, 550, 600];
ANGLE_INCH = [38.1, 50.8];                        // 1-1/2", 2"
ANGLE_METRIC = [40, 50];
ROD_HOLE = 6.8;                                   // fits 1/4"-20 and M6
NUT_STACK = 7.2;                                  // washer + nut, either system
BEAD_W = 18; BEAD_H = 16;                         // rod channel along each cheek
DOOR_GAP = 2;                                     // door back to face frame when closed
BR_W = 40; BR_H = 40; BR_FLANGE = 5;              // door bracket
CORNER = [18, 28];                                // Bambu P1/X1 calibration corner (bed_exclude_area)

// ---------------------------------------------------------------- layout

function pick_le(v, list) = let(f = [for (x = list) if (x <= v) x]) len(f) > 0 ? f[len(f) - 1] : 0;
function pick_ge(v, list) = let(f = [for (x = list) if (x >= v) x]) len(f) > 0 ? f[0] : 0;

// fewest pull-outs whose carriage fits the bed
function auto_pullouts(W, edge, gap, bed_max, n = 1) =
    n >= 6 ? 6 :
    ((W - (n - 1) * gap) / n - 2 * edge <= bed_max) ? n : auto_pullouts(W, edge, gap, bed_max, n + 1);

// split n cells into chunks of at most m, as even as possible
function chunks(n, m = 9) =
    n <= 0 ? [] :
    let(k = ceil(n / m), b = floor(n / k), r = n - b * k)
    [for (i = [0 : k - 1]) b + (i < r ? 1 : 0)];

function nseg(len_mm, bed_max) = max(1, ceil(len_mm / bed_max));
function sum(v, n) = n <= 0 ? 0 : v[n - 1] + sum(v, n - 1);

// o: options key/value list (see pullgrid.scad)
function carriage_geometry(env, o) =
    let(
        reach = g(o, "reach"), one = reach == "left" || reach == "right",
        panels = one ? 1 : g(o, "panels"), board_t = g(o, "board_t"), slide_t = g(o, "slide_t"),
        slide_h = g(o, "slide_h"), bed = g(o, "bed"), metric = g(o, "region") == "metric",
        angle = g(o, "rail_type") == "angle", at = g(o, "angle_t"),
        mount = g(o, "door_mode") == "mount", fft = g(o, "fft"),
        RAIL_T = angle ? at : 8, FOOT_T = angle ? at : 4,
        CHEEK_T = 8, BASE_T = 6, PT = 6, RIB_T = 3, RIB_D = 8, GW = board_t + 0.6,
        CAP_H = 12, CAP_W = 20, BOSS_W = 24, BOSS_D = 10, GAP = 2, BED_MAX = bed - 6,
        edge = RAIL_T + slide_t,
        W = env[1] - env[0],
        N = g(o, "pullouts") > 0 ? g(o, "pullouts") : auto_pullouts(W, edge, GAP, BED_MAX),
        wp = (W - (N - 1) * GAP) / N,
        Wc = wp - 2 * edge,
        // Bambu P1/X1 beds keep the front-left 18 x 28 mm clear for calibration.
        // A piece too wide to sit beside that corner must be short enough to sit
        // above it (site/threemf.js lays plates out the same way).
        SPLIT_MAX = Wc <= bed - (CORNER[0] + 9) ? BED_MAX : bed - (CORNER[1] + 9),
        cx0 = edge, cx1 = edge + Wc,
        zs0 = max(env[2], FOOT_T + 0.5),
        zs1 = zs0 + slide_h,
        zb = zs0 + BASE_T,
        nz = floor((env[3] - (CAP_H + 0.5) - zb) / 28),
        z_top = zb + nz * 28 + 0.5 + CAP_H,
        y0 = env[4],
        y_f = y0 + PT,
        ny = floor((env[5] - y0 - 2 * PT - 0.6) / 28),
        L_in = ny * 28 + 0.6,
        y_r = y_f + L_in,
        // stacked tiers on one door must share a slide length (slide_max), and
        // one stock size of angle (leg_force)
        slide_len = pick_le(min(L_in, g(o, "slide_max")), metric ? SLIDES_METRIC : SLIDES_INCH),
        rail_len = slide_len > 0 ? slide_len : L_in,
        leg_need = zs0 + slide_h / 2 + 6,          // angle must reach past the slide's screw line
        leg = !angle ? 0 : g(o, "leg_force") >= leg_need ? g(o, "leg_force")
                         : pick_ge(leg_need, metric ? ANGLE_METRIC : ANGLE_INCH),
        iw = Wc - 2 * CHEEK_T,
        // one-sided: the single panel hugs the blocked side, just clear of the rod bead,
        // so every accessory faces the side you can reach
        tuck = BEAD_W + GW / 2 + RIB_T + 1,
        px = one ? [reach == "left" ? cx1 - tuck : cx0 + tuck]
                 : [for (i = [0 : panels - 1]) cx0 + CHEEK_T + (i + 1) * iw / (panels + 1)],
        edges_x = concat([cx0 + CHEEK_T], px, [cx1 - CHEEK_T]),
        bays = [for (i = [0 : len(edges_x) - 2]) [edges_x[i], edges_x[i + 1]]],
        key_x = [for (b = bays) if (b[1] - b[0] >= GW + 2 * RIB_T + 16) (b[0] + b[1]) / 2],
        Lc = y_r + PT - y0,
        br_len = y0 + fft + DOOR_GAP,
        br_lo = zs1 + 22, br_hi = z_top - CAP_H - 4 - 24,
        // one row of brackets when the door is shared with other tiers
        br_z = br_hi - br_lo >= BR_H + 20 && g(o, "br_rows") != 1 ? [br_lo, br_hi] : [(zs1 + z_top - CAP_H) / 2],
        // door brackets go in bays wide enough to reach their screws from inside:
        // the middle of the outer two, or the quarter points of a lone wide bay
        wide = [for (b = bays) if (b[1] - b[0] >= BR_W + 2 * (GW / 2 + RIB_T) + 12) b],
        br_x = len(wide) >= 2 ? [(wide[0][0] + wide[0][1]) / 2, (wide[len(wide) - 1][0] + wide[len(wide) - 1][1]) / 2]
             : len(wide) == 1 ? [wide[0][0] + (wide[0][1] - wide[0][0]) / 4, wide[0][0] + 3 * (wide[0][1] - wide[0][0]) / 4]
             : [(bays[0][0] + bays[0][1]) / 2, (bays[len(bays) - 1][0] + bays[len(bays) - 1][1]) / 2]
    )
    [["RAIL_T", RAIL_T], ["FOOT_T", FOOT_T], ["CHEEK_T", CHEEK_T], ["BASE_T", BASE_T],
     ["PT", PT], ["RIB_T", RIB_T], ["RIB_D", RIB_D], ["GW", GW], ["CAP_H", CAP_H],
     ["CAP_W", CAP_W], ["BOSS_W", BOSS_W], ["BOSS_D", BOSS_D], ["BED_MAX", BED_MAX],
     ["board_t", board_t], ["slide_t", slide_t], ["slide_h", slide_h],
     ["angle", angle], ["leg", leg], ["leg_need", leg_need], ["mount", mount], ["metric", metric],
     ["N", N], ["wp", wp], ["Wc", Wc], ["cx0", cx0], ["cx1", cx1],
     ["zs0", zs0], ["zs1", zs1], ["zb", zb], ["nz", nz], ["z_top", z_top],
     ["y0", y0], ["y_f", y_f], ["ny", ny], ["L_in", L_in], ["y_r", y_r], ["Lc", Lc],
     ["slide_len", slide_len], ["rail_len", rail_len],
     ["panels", panels], ["px", px], ["bays", bays], ["key_x", key_x], ["reach", one ? reach : "both"],
     ["rod_x", [cx0 + BEAD_W / 2 + 1.5, cx1 - BEAD_W / 2 - 1.5]], ["rod_z", zs0 + 9],
     ["top_rod_z", z_top - CAP_H / 2], ["rod_len", round(Lc + 2 * NUT_STACK + 2)], ["n_rods", 2 + panels],
     ["br_len", br_len], ["br_x", br_x], ["br_z", br_z],
     ["n_rail", nseg(rail_len, BED_MAX)], ["n_base", nseg(L_in, SPLIT_MAX)],
     ["n_plate", nseg(z_top - zs0, SPLIT_MAX)], ["n_top", nseg(L_in - 2 * BOSS_D, BED_MAX)],
     ["xo", [for (p = [0 : N - 1]) env[0] + p * (wp + GAP)]]];

// Shape signatures: two specs with the same signature print the same file,
// even from tiers at different heights. Everything is relative to the part.
Z_KEYS = ["zs0", "zs1", "zb", "z_top", "rod_z", "top_rod_z", "br_z", "leg_need",
          "n_rail", "rail_len", "FOOT_T", "RAIL_T", "leg", "slide_len", "xo"];
function carriage_sig(G) = concat([for (kv = G) if (search([kv[0]], Z_KEYS, 1)[0] == []) kv],
    [["h", g(G, "z_top") - g(G, "zs0")], ["br_dz", [for (z = g(G, "br_z")) z - g(G, "zs0")]]]);
// round away float noise (21.0 - 15 vs 9.7 - 3.7)
function rnd(v) = is_list(v) ? [for (x = v) rnd(x)] : is_num(v) ? round(v * 1000) / 1000 : v;
function part_sig(G, s) = rnd(part_sig_(G, s));
function part_sig_(G, s) = let(k = s[3], x0 = g(G, "cx0"), z0 = g(G, "zs0"))
    k == "key" ? ["key"] :
    k == "bracket" ? ["bracket", g(G, "br_len")] :
    k == "rail_L" || k == "rail_R" ? [k, s[4], s[5], g(G, "rail_len"), g(G, "zs1"), g(G, "FOOT_T"), g(G, "RAIL_T"), g(G, "slide_t")] :
    k == "base" ? [k, s[4], s[5], g(G, "cx1") - x0, g(G, "y_r") - g(G, "y_f"), g(G, "slide_h"), g(G, "zb") - z0, g(G, "GW"),
                   [for (x = g(G, "px")) x - x0], [for (x = g(G, "rod_x")) x - x0], g(G, "rod_z") - z0] :
    k == "front" || k == "rear" ? [k, s[4], carriage_sig(G)] :
    [k, s[4], s[5], g(G, "CAP_W"), g(G, "GW"), g(G, "L_in")];   // top rails

function carriage_valid(G) =
    g(G, "nz") >= 2 && g(G, "ny") >= 1 &&
    g(G, "Wc") > 2 * BEAD_W + g(G, "panels") * (g(G, "GW") + 2 * g(G, "RIB_T")) + 10;

// seams split [lo, hi] into n equal pieces; outer slabs run to infinity
function seams(lo, hi, n) = n > 1 ? [for (k = [1 : n - 1]) lo + k * (hi - lo) / n] : [];
function slab(lo, hi, n, i) = [i == 0 ? -BIG : lo + i * (hi - lo) / n,
                               i == n - 1 ? BIG : lo + (i + 1) * (hi - lo) / n];

// ---------------------------------------------------------------- helpers

KEY_L = 28; KEY_W = 12; KEY_WAIST = 6; KEY_T = 3;

module bowtie2d(off = 0) {
    offset(delta = off) polygon([[-KEY_L / 2, -KEY_W / 2], [0, -KEY_WAIST / 2], [KEY_L / 2, -KEY_W / 2],
                                 [KEY_L / 2, KEY_W / 2], [0, KEY_WAIST / 2], [-KEY_L / 2, KEY_W / 2]]);
}
module bowtie_key() { linear_extrude(KEY_T) bowtie2d(); }
module key_pocket() { translate([0, 0, -KEY_T - 0.2]) linear_extrude(KEY_T + 1.2) bowtie2d(0.15); }

module box(a, b) { translate(a) cube(b - a); }

module countersink_down(d_hole = 4.5, d_head = 9, h = 20) {  // head at z=0 opening up
    translate([0, 0, -h]) cylinder(d = d_hole, h = h + 1, $fn = 20);
    translate([0, 0, -d_head / 2]) cylinder(d1 = 0, d2 = d_head + 0.01, h = d_head / 2 + 0.01, $fn = 24);
    cylinder(d = d_head, h = 5, $fn = 24);
}

module rod_y(x, z, y_a, y_b, d = ROD_HOLE) {  // cylinder along y
    translate([x, y_a, z]) rotate([-90, 0, 0]) cylinder(d = d, h = y_b - y_a, $fn = 24);
}

module slot_y(x, z, y_a, y_b, d, travel, along = "z") {  // slotted hole along y
    hull() for (s = [-1, 1]) rod_y(x + (along == "x" ? s * travel / 2 : 0), z + (along == "z" ? s * travel / 2 : 0), y_a, y_b, d);
}

// ---------------------------------------------------------------- fixed parts

module rail_full(G, side = "L") {  // printed fallback rail
    RT = g(G, "RAIL_T"); FT = g(G, "FOOT_T"); st = g(G, "slide_t");
    y_f = g(G, "y_f"); L = g(G, "rail_len"); zs1 = g(G, "zs1"); wp = g(G, "wp");
    n = g(G, "n_rail"); bm = L / n;
    mx = side == "L" ? 0 : 1;
    translate([mx * wp, 0, 0]) mirror([mx, 0, 0]) difference() {
        union() {
            box([0, y_f, 0], [RT, y_f + L, zs1]);
            box([0, y_f, 0], [RT + st + FOOT_IN, y_f + L, FT]);   // foot reaches under the carriage
        }
        for (i = [0 : n - 1]) let(a = y_f + i * bm + 18, b = y_f + (i + 1) * bm - 18,
                                  k = max(1, ceil((b - a) / 110)))
            for (j = [0 : k]) translate([RT + st + FOOT_IN / 2, a + j * (b - a) / k, FT]) countersink_down(4.5, 8.6, FT + 2);
    }
}

module angle_part(G) {  // aluminum angle rails, preview only
    at = g(G, "RAIL_T"); leg = max(g(G, "leg"), g(G, "leg_need")); wp = g(G, "wp");
    y_f = g(G, "y_f"); L = g(G, "rail_len");
    for (mx = [0, 1]) translate([mx * wp, 0, 0]) mirror([mx, 0, 0]) {
        box([0, y_f, 0], [at, y_f + L, leg]);
        box([0, y_f, 0], [leg, y_f + L, at]);
    }
}

module slides_part(G, which = "outer") {  // metal slides, preview only
    RT = g(G, "RAIL_T"); st = g(G, "slide_t"); wp = g(G, "wp");
    y_f = g(G, "y_f"); L = g(G, "slide_len"); zs0 = g(G, "zs0"); zs1 = g(G, "zs1");
    if (L > 0) for (mx = [0, 1]) translate([mx * wp, 0, 0]) mirror([mx, 0, 0])
        if (which == "outer") box([RT, y_f, zs0 + 1], [RT + st / 2, y_f + L, zs1 - 1]);
        else box([RT + st / 2 + 0.2, y_f, zs0 + 3], [RT + st - 0.2, y_f + L, zs1 - 3]);
}

module rods_part(G) {  // tie rods with nuts, preview only
    y_a = g(G, "y0") - NUT_STACK - 1; y_b = g(G, "y_r") + g(G, "PT") + NUT_STACK + 1;
    pts = concat([for (x = g(G, "rod_x")) [x, g(G, "rod_z")]], [for (x = g(G, "px")) [x, g(G, "top_rod_z")]]);
    for (p = pts) {
        rod_y(p[0], p[1], y_a, y_b, 6.2);
        for (ys = [[g(G, "y0") - NUT_STACK, g(G, "y0")], [g(G, "y_r") + g(G, "PT"), g(G, "y_r") + g(G, "PT") + NUT_STACK]])
            translate([p[0], ys[0], p[1]]) rotate([-90, 0, 0]) cylinder(d = 11.5, h = ys[1] - ys[0], $fn = 6);
    }
}

// ---------------------------------------------------------------- moving parts

module base_full(G) {
    cx0 = g(G, "cx0"); cx1 = g(G, "cx1"); CT = g(G, "CHEEK_T");
    y_f = g(G, "y_f"); y_r = g(G, "y_r"); zs0 = g(G, "zs0"); zs1 = g(G, "zs1"); zb = g(G, "zb");
    RT = g(G, "RIB_T"); RD = g(G, "RIB_D"); GW = g(G, "GW");
    n = g(G, "n_base"); bm = (y_r - y_f) / n;
    difference() {
        union() {
            box([cx0, y_f, zs0], [cx1, y_r, zb]);                         // floor
            box([cx0, y_f, zs0], [cx0 + CT, y_r, zs1]);                   // cheeks (slides screw on)
            box([cx1 - CT, y_f, zs0], [cx1, y_r, zs1]);
            box([cx0, y_f, zs0], [cx0 + BEAD_W, y_r, zs0 + BEAD_H]);      // tie-rod beads
            box([cx1 - BEAD_W, y_f, zs0], [cx1, y_r, zs0 + BEAD_H]);
            for (x = g(G, "px")) for (s = [-1, 1])                       // board groove
                translate([x + s * (GW + RT) / 2 - RT / 2, y_f + RD, zb]) cube([RT, y_r - y_f - 2 * RD, RD]);
        }
        for (x = g(G, "rod_x")) rod_y(x, g(G, "rod_z"), y_f - 1, y_r + 1);
        // lightening / drain slots, clear of seams, beads and grooves
        for (b = g(G, "bays")) let(m = GW / 2 + RT + 6, xa = max(b[0] + m, cx0 + BEAD_W + 3), xb = min(b[1] - m, cx1 - BEAD_W - 3))
            if (xb - xa >= 14)
                for (i = [0 : n - 1]) let(a = y_f + i * bm + 22, c = y_f + (i + 1) * bm - 22, k = floor((c - a + 10) / 60))
                    if (k > 0) for (j = [0 : k - 1]) let(ys = a + j * (c - a) / k)
                        box([xa, ys, zs0 - 1], [xb, ys + (c - a) / k - 10, zb + 1]);
    }
}

module plate_full(G, which = "front") {
    cx0 = g(G, "cx0"); cx1 = g(G, "cx1");
    PT = g(G, "PT"); RT = g(G, "RIB_T"); RD = g(G, "RIB_D"); GW = g(G, "GW");
    BW = g(G, "BOSS_W"); BD = g(G, "BOSS_D"); CH = g(G, "CAP_H");
    zs0 = g(G, "zs0"); zs1 = g(G, "zs1"); zb = g(G, "zb"); zt = g(G, "z_top");
    F = which == "front";
    ladder = !F || g(G, "mount");                  // a mounted door is the face, so no solid sheet
    yi = F ? g(G, "y_f") : g(G, "y_r");            // inner face
    dir = F ? 1 : -1;                              // toward the inside of the carriage
    yo = yi - dir * PT;                            // outer face
    ya = min(yi, yo); yb = max(yi, yo);
    difference() {
        union() {
            if (!ladder) box([cx0, ya, zs0], [cx1, yb, zt]);
            else {
                box([cx0, ya, zs0], [cx1, yb, zs1]);                              // bottom band
                box([cx0, ya, zt - CH - 4], [cx1, yb, zt]);                      // top band
                box([cx0, ya, zs0], [cx0 + 18, yb, zt]);                          // stiles
                box([cx1 - 18, ya, zs0], [cx1, yb, zt]);
                for (x = g(G, "px")) box([x - GW / 2 - RT - 5, ya, zs0], [x + GW / 2 + RT + 5, yb, zt]);
                for (s = seams(zs0, zt, g(G, "n_plate"))) box([cx0, ya, s - 20], [cx1, yb, s + 20]);  // rungs
                if (F) for (x = g(G, "br_x"), z = g(G, "br_z"))                  // bracket pads
                    box([x - BR_W / 2 - 4, ya, z - BR_H / 2 - 4], [x + BR_W / 2 + 4, yb, z + BR_H / 2 + 4]);
            }
            for (x = g(G, "px")) {
                for (s = [-1, 1])                                                   // board groove
                    translate([x + s * (GW + RT) / 2 - RT / 2, min(yi, yi + dir * RD), zb])
                        cube([RT, RD, zt - CH - zb]);
                translate([x - BW / 2, min(yi, yi + dir * BD), zt - CH]) cube([BW, BD, CH]);  // top-rail boss
            }
        }
        // tie rods: two through the base beads, one through each top rail
        for (x = g(G, "rod_x")) rod_y(x, g(G, "rod_z"), ya - 1, yb + 1);
        for (x = g(G, "px")) rod_y(x, g(G, "top_rod_z"), min(yo, yi + dir * BD) - 1, max(yo, yi + dir * BD) + 1);
        // keep-door mode: finger slots in the central bay(s)
        if (F && !ladder) {
            bays = g(G, "bays"); nb = len(bays);
            pick = nb % 2 == 1 ? [floor(nb / 2)] : [nb / 2 - 1, nb / 2];
            zc = zt - CH - 34;
            for (i = pick) let(b = bays[i], w = min(b[1] - b[0] - 2 * (GW / 2 + RT + 6), 90))
                if (w >= 30 && zc - 12 >= zs1 + 6)
                    translate([(b[0] + b[1]) / 2, 0, zc]) hull() for (s = [-1, 1])
                        translate([s * (w / 2 - 12), yi + 1, 0]) rotate([90, 0, 0]) cylinder(r = 12, h = PT + 2, $fn = 32);
        }
        // door-mount mode: slotted screw holes for the brackets (vertical adjustment)
        if (F && ladder) for (x = g(G, "br_x"), z = g(G, "br_z"), dz = [-12, 12])
            slot_y(x, z + dz, ya - 1, yb + 1, 4.5, 8, "z");
    }
}

module top_rail_full(G, i) {
    x = g(G, "px")[i]; CW = g(G, "CAP_W"); CH = g(G, "CAP_H"); RT = g(G, "RIB_T"); RD = g(G, "RIB_D");
    GW = g(G, "GW"); BD = g(G, "BOSS_D"); zt = g(G, "z_top");
    ya = g(G, "y_f") + BD; yb = g(G, "y_r") - BD;
    difference() {
        union() {
            box([x - CW / 2, ya, zt - CH], [x + CW / 2, yb, zt]);                   // cap
            for (s = [-1, 1]) box([x + s * (GW + RT) / 2 - RT / 2, ya, zt - CH - RD], [x + s * (GW + RT) / 2 + RT / 2, yb, zt - CH]);
        }
        rod_y(x, g(G, "top_rod_z"), ya - 1, yb + 1);
    }
}

// one door bracket, at the first bracket position (all are identical)
module bracket_full(G, x = undef, z = undef) {
    bx = x == undef ? g(G, "br_x")[0] : x; bz = z == undef ? g(G, "br_z")[0] : z;
    y1 = g(G, "y0"); L = g(G, "br_len"); y0 = y1 - L;          // y0 = door side
    difference() {
        box([bx - BR_W / 2, y0, bz - BR_H / 2], [bx + BR_W / 2, y1, bz + BR_H / 2]);
        // pilot holes for the screws coming through the front plate
        for (dz = [-12, 12]) rod_y(bx, bz + dz, y1 - min(10, L - 2), y1 + 1, 3.4);
        // door screws: slotted sideways, counterbored so the head sits on a thin flange
        for (dx = [-10, 10]) {
            slot_y(bx + dx, bz, y0 - 1, y0 + BR_FLANGE + 0.1, 4.5, 6, "x");
            slot_y(bx + dx, bz, y0 + BR_FLANGE, y1 + 1, 9.5, 6, "x");
        }
    }
}

module boards_part(G) {  // the user's openGrid boards, preview only
    t = g(G, "board_t"); zb = g(G, "zb"); y_f = g(G, "y_f") + 0.3;
    cy = chunks(g(G, "ny")); cz = chunks(g(G, "nz"));
    for (x = g(G, "px")) for (a = [0 : len(cy) - 1], b = [0 : len(cz) - 1]) {
        y = y_f + 28 * sum(cy, a); z = zb + 28 * sum(cz, b);
        box([x - t / 2, y + 0.3, z + 0.3], [x + t / 2, y + cy[a] * 28 - 0.3, z + cz[b] * 28 - 0.3]);
    }
}

module carriage_part(G) {
    base_full(G);
    plate_keyed(G, "front");
    plate_keyed(G, "rear");
    for (i = [0 : g(G, "panels") - 1]) top_rail_full(G, i);
    if (g(G, "mount")) for (x = g(G, "br_x"), z = g(G, "br_z")) bracket_full(G, x, z);
}

module hardware_part(G, which) {
    if (which == "fixed") { slides_part(G, "outer"); if (g(G, "angle")) angle_part(G); }
    else { slides_part(G, "inner"); rods_part(G); }
}

// ---------------------------------------------------------------- plate seam keys

module plate_keyed(G, which) difference() {
    plate_full(G, which);
    F = which == "front"; yi = F ? g(G, "y_f") : g(G, "y_r");
    for (s = seams(g(G, "zs0"), g(G, "z_top"), g(G, "n_plate")), x = g(G, "key_x"))
        translate([x, yi, s]) rotate([F ? -90 : 90, 0, 0]) rotate([0, 0, 90]) key_pocket();
}

// ---------------------------------------------------------------- print parts
// spec: [id, label, qty, kind, seg, nseg, axis(0=x,1=y,2=z), lo, hi, bbox_min, bbox_max, rot]

function part_specs(G) =
    let(N = g(G, "N"), wp = g(G, "wp"), RT = g(G, "RAIL_T"), st = g(G, "slide_t"),
        cx0 = g(G, "cx0"), cx1 = g(G, "cx1"), y0 = g(G, "y0"), y_f = g(G, "y_f"), y_r = g(G, "y_r"),
        zs0 = g(G, "zs0"), zs1 = g(G, "zs1"), zt = g(G, "z_top"), PT = g(G, "PT"), BD = g(G, "BOSS_D"),
        CW = g(G, "CAP_W"), CH = g(G, "CAP_H"), RD = g(G, "RIB_D"), L = g(G, "rail_len"),
        nr = g(G, "n_rail"), nb = g(G, "n_base"), np = g(G, "n_plate"), nt = g(G, "n_top"),
        P = g(G, "panels"), nk = len(g(G, "key_x")), keys = N * 2 * (np - 1) * nk,
        bx = g(G, "br_x")[0], bz = g(G, "br_z")[0], nbr = len(g(G, "br_x")) * len(g(G, "br_z")))
    concat(
        g(G, "angle") ? [] :
        [for (side = ["L", "R"], i = [0 : nr - 1])
            [str("rail_", side, "_", i + 1), str("Floor rail ", side == "L" ? "left" : "right", " ", i + 1, "/", nr), N,
             str("rail_", side), i, nr, 1, y_f, y_f + L,
             [side == "L" ? 0 : wp - RT - st - FOOT_IN, y_f, 0], [side == "L" ? RT + st + FOOT_IN : wp, y_f + L, zs1], [0, 0, 0]]],
        [for (i = [0 : nb - 1])
            [str("base_", i + 1), str("Base ", i + 1, "/", nb), N, "base", i, nb, 1, y_f, y_r,
             [cx0, y_f, zs0], [cx1, y_r, zs1], [0, 0, 0]]],
        [for (i = [0 : np - 1])
            [str("front_", i + 1), str("Front plate ", i + 1, "/", np), N, "front", i, np, 2, zs0, zt,
             [cx0, y0, zs0], [cx1, y_f + BD, zt], [90, 0, 0]]],
        [for (i = [0 : np - 1])
            [str("rear_", i + 1), str("Rear plate ", i + 1, "/", np), N, "rear", i, np, 2, zs0, zt,
             [cx0, y_r - BD, zs0], [cx1, y_r + PT, zt], [-90, 0, 0]]],
        [for (p = [0 : P - 1], i = [0 : nt - 1])
            [str("toprail_", p + 1, "_", i + 1), str("Top rail ", P > 1 ? str(p + 1, " ") : "", i + 1, "/", nt), N,
             str("toprail_", p), i, nt, 1, y_f + BD, y_r - BD,
             [g(G, "px")[p] - CW / 2, y_f + BD, zt - CH - RD], [g(G, "px")[p] + CW / 2, y_r - BD, zt], [0, 180, 0]]],
        g(G, "mount") ? [["bracket", "Door bracket", N * nbr, "bracket", 0, 1, 0, 0, 0,
                          [bx - BR_W / 2, y0 - g(G, "br_len"), bz - BR_H / 2], [bx + BR_W / 2, y0, bz + BR_H / 2], [90, 0, 0]]] : [],
        keys > 0 ? [["key", "Bowtie key", keys + 2, "key", 0, 1, 0, 0, 0,
                     [-KEY_L / 2, -KEY_W / 2, 0], [KEY_L / 2, KEY_W / 2, KEY_T], [0, 0, 0]]] : []
    );

module part_geom(G, kind) {
    if (kind == "rail_L") rail_full(G, "L");
    else if (kind == "rail_R") rail_full(G, "R");
    else if (kind == "base") base_full(G);
    else if (kind == "front") plate_keyed(G, "front");
    else if (kind == "rear") plate_keyed(G, "rear");
    else if (kind == "bracket") bracket_full(G);
    else if (kind == "key") bowtie_key();
    else top_rail_full(G, search(kind[8], "0123456789")[0]);  // "toprail_<p>", p < 10
}

// rotations about x, y, z (degrees), OpenSCAD order: x then y then z
function rx(a, p) = [p[0], p[1] * cos(a) - p[2] * sin(a), p[1] * sin(a) + p[2] * cos(a)];
function ry(a, p) = [p[0] * cos(a) + p[2] * sin(a), p[1], -p[0] * sin(a) + p[2] * cos(a)];
function rz(a, p) = [p[0] * cos(a) - p[1] * sin(a), p[0] * sin(a) + p[1] * cos(a), p[2]];
function rot(r, p) = rz(r[2], ry(r[1], rx(r[0], p)));

function seg_bbox(s) =
    let(ax = s[6], sl = slab(s[7], s[8], s[5], s[4]),
        mn = [for (k = [0 : 2]) k == ax ? max(s[9][k], sl[0]) : s[9][k]],
        mx = [for (k = [0 : 2]) k == ax ? min(s[10][k], sl[1]) : s[10][k]])
    [mn, mx];

function print_bbox(s) =
    let(b = seg_bbox(s),
        c = [for (i = [0 : 1], j = [0 : 1], k = [0 : 1]) rot(s[11], [b[i][0], b[j][1], b[k][2]])])
    [[for (a = [0 : 2]) min([for (p = c) p[a]])], [for (a = [0 : 2]) max([for (p = c) p[a]])]];

function print_size(s) = let(b = print_bbox(s)) [for (a = [0 : 2]) round((b[1][a] - b[0][a]) * 10) / 10];

module print_part(G, s) {
    b = print_bbox(s);
    sl = slab(s[7], s[8], s[5], s[4]);
    translate(-b[0]) rotate(s[11]) intersection() {
        part_geom(G, s[3]);
        if (s[6] == 1) translate([-BIG / 2, sl[0], -BIG / 2]) cube([BIG, sl[1] - sl[0], BIG]);
        else if (s[6] == 2) translate([-BIG / 2, -BIG / 2, sl[0]]) cube([BIG, BIG, sl[1] - sl[0]]);
        else translate([-BIG / 2, -BIG / 2, -BIG / 2]) cube(BIG);
    }
}
