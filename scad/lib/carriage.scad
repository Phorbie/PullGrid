// PullGrid — printable pull-out (v1)
//
// Fixed:   two floor rails (screwed to the cabinet floor) carrying metal slides.
// Moving:  carriage = base tray with slide cheeks, front plate, rear plate,
//          one top rail per panel. Standard openGrid boards stand in grooves
//          between base, plates and top rail.
// Joints:  long parts are split to fit the print bed. Seams get printed
//          bowtie keys + glue; the steel slides bridge base and rail seams.
//          Plates bolt to the base cheeks with M3 + captive nuts; top rails
//          drop into dovetail sockets on the plates.
//
// Geometry is described in a key/value list G (see carriage_geometry) so
// every module takes the same layout. X is local to one pull-out (0..wp);
// the assembly shifts each pull-out by g(G,"xo")[p].

function g(G, k) = G[search([k], G)[0]][1];

BIG = 10000;
FOOT_IN = 15;  // floor rail foot reaches this far in past the slide

// ---------------------------------------------------------------- layout

function standard_slide(len_mm) =
    let(s = [254, 305, 356, 406, 457, 508, 559], f = [for (v = s) if (v <= len_mm) v])
    len(f) > 0 ? f[len(f) - 1] : 0;

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

function carriage_geometry(env, panels, board_t, slide_t, slide_h, bed, pullouts_req) =
    let(
        RAIL_T = 8, FOOT_T = 4, CHEEK_T = 8, BASE_T = 6, PT = 6,
        RIB_T = 3, RIB_D = 8, GW = board_t + 0.6, CAP_H = 12, CAP_W = 20,
        BOSS_W = 24, BOSS_D = 10, GAP = 2, BED_MAX = bed - 6,
        edge = RAIL_T + slide_t,
        W = env[1] - env[0],
        N = pullouts_req > 0 ? pullouts_req : auto_pullouts(W, edge, GAP, BED_MAX),
        wp = (W - (N - 1) * GAP) / N,
        Wc = wp - 2 * edge,
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
        slide_len = standard_slide(L_in),
        rail_len = slide_len > 0 ? slide_len : L_in,
        iw = Wc - 2 * CHEEK_T,
        px = [for (i = [0 : panels - 1]) cx0 + CHEEK_T + (i + 1) * iw / (panels + 1)],
        edges_x = concat([cx0 + CHEEK_T], px, [cx1 - CHEEK_T]),
        bays = [for (i = [0 : len(edges_x) - 2]) [edges_x[i], edges_x[i + 1]]],
        key_x = [for (b = bays) if (b[1] - b[0] >= GW + 2 * RIB_T + 16) (b[0] + b[1]) / 2],
        n_rail = nseg(rail_len, BED_MAX),
        n_base = nseg(L_in, BED_MAX),
        n_plate = nseg(z_top - zs0, BED_MAX),
        n_top = nseg(L_in - 8, BED_MAX),
        xo = [for (p = [0 : N - 1]) env[0] + p * (wp + GAP)]
    )
    [["RAIL_T", RAIL_T], ["FOOT_T", FOOT_T], ["CHEEK_T", CHEEK_T], ["BASE_T", BASE_T],
     ["PT", PT], ["RIB_T", RIB_T], ["RIB_D", RIB_D], ["GW", GW], ["CAP_H", CAP_H],
     ["CAP_W", CAP_W], ["BOSS_W", BOSS_W], ["BOSS_D", BOSS_D], ["BED_MAX", BED_MAX],
     ["board_t", board_t], ["slide_t", slide_t], ["slide_h", slide_h],
     ["N", N], ["wp", wp], ["Wc", Wc], ["cx0", cx0], ["cx1", cx1],
     ["zs0", zs0], ["zs1", zs1], ["zb", zb], ["nz", nz], ["z_top", z_top],
     ["y0", y0], ["y_f", y_f], ["ny", ny], ["L_in", L_in], ["y_r", y_r],
     ["slide_len", slide_len], ["rail_len", rail_len],
     ["panels", panels], ["px", px], ["bays", bays], ["key_x", key_x],
     ["n_rail", n_rail], ["n_base", n_base], ["n_plate", n_plate], ["n_top", n_top],
     ["xo", xo]];

function carriage_valid(G) =
    g(G, "nz") >= 1 && g(G, "ny") >= 1 && g(G, "Wc") > 2 * g(G, "CHEEK_T") +
    g(G, "panels") * (g(G, "GW") + 2 * g(G, "RIB_T")) + 10;

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
// pocket for a key, long axis along local x, opening up (+z), depth KEY_T + 0.2
module key_pocket() { translate([0, 0, -KEY_T - 0.2]) linear_extrude(KEY_T + 1.2) bowtie2d(0.15); }

module box(a, b) { translate(a) cube(b - a); }

module countersink_down(d_hole = 4.5, d_head = 9, h = 20) {  // head at z=0 opening up
    translate([0, 0, -h]) cylinder(d = d_hole, h = h + 1, $fn = 20);
    translate([0, 0, -d_head / 2]) cylinder(d1 = 0, d2 = d_head + 0.01, h = d_head / 2 + 0.01, $fn = 24);
    cylinder(d = d_head, h = 5, $fn = 24);
}

// dovetail in plan (x-y), neck at y=0 flaring to +y
module dovetail2d(off = 0) {
    offset(delta = off) polygon([[-4, 0], [4, 0], [6, 6], [-6, 6]]);
}

// ---------------------------------------------------------------- fixed parts

module rail_full(G, side = "L") {
    RT = g(G, "RAIL_T"); FT = g(G, "FOOT_T"); st = g(G, "slide_t");
    y_f = g(G, "y_f"); L = g(G, "rail_len"); zs1 = g(G, "zs1"); wp = g(G, "wp");
    n = g(G, "n_rail"); bm = L / n;
    mx = side == "L" ? 0 : 1;
    translate([mx * wp, 0, 0]) mirror([mx, 0, 0]) difference() {
        union() {
            box([0, y_f, 0], [RT, y_f + L, zs1]);            // wall
            // foot runs under the slide and on under the carriage, where the
            // screws can be reached with the carriage unclipped
            box([0, y_f, 0], [RT + st + FOOT_IN, y_f + L, FT]);
        }
        // floor screws: two per segment, plus one per ~110 mm
        for (i = [0 : n - 1]) let(a = y_f + i * bm + 18, b = y_f + (i + 1) * bm - 18,
                                  k = max(1, ceil((b - a) / 110)))
            for (j = [0 : k]) translate([RT + st + FOOT_IN / 2, a + j * (b - a) / k, FT]) countersink_down(4.5, 8.6, FT + 2);
    }
}

module slides_part(G, which = "outer") {  // metal hardware, preview only
    RT = g(G, "RAIL_T"); st = g(G, "slide_t"); wp = g(G, "wp");
    y_f = g(G, "y_f"); L = g(G, "slide_len"); zs0 = g(G, "zs0"); zs1 = g(G, "zs1");
    if (L > 0) for (mx = [0, 1]) translate([mx * wp, 0, 0]) mirror([mx, 0, 0])
        if (which == "outer") box([RT, y_f, zs0 + 1], [RT + st / 2, y_f + L, zs1 - 1]);
        else box([RT + st / 2 + 0.2, y_f, zs0 + 3], [RT + st, y_f + L, zs1 - 3]);
}

// ---------------------------------------------------------------- moving parts

// M3 bolt along y with a nut slot opening sideways (inward = +1 opens toward +x)
module nut_slot_y(at, inward) {
    translate(at) {
        rotate([-90, 0, 0]) cylinder(d = 3.4, h = 30, center = true, $fn = 16);
        translate([inward > 0 ? -3.3 : -6, -1.3, -2.95]) cube([9.3, 2.6, 5.9]);
    }
}

module base_full(G) {
    cx0 = g(G, "cx0"); cx1 = g(G, "cx1"); CT = g(G, "CHEEK_T");
    y_f = g(G, "y_f"); y_r = g(G, "y_r"); zs0 = g(G, "zs0"); zs1 = g(G, "zs1"); zb = g(G, "zb");
    RT = g(G, "RIB_T"); RD = g(G, "RIB_D"); GW = g(G, "GW");
    n = g(G, "n_base"); bm = (y_r - y_f) / n;
    difference() {
        union() {
            box([cx0, y_f, zs0], [cx1, y_r, zb]);                         // floor
            box([cx0, y_f, zs0], [cx0 + CT, y_r, zs1]);                   // cheeks
            box([cx1 - CT, y_f, zs0], [cx1, y_r, zs1]);
            for (x = g(G, "px")) for (s = [-1, 1])                       // board groove
                translate([x + s * (GW + RT) / 2 - RT / 2, y_f + RD, zb]) cube([RT, y_r - y_f - 2 * RD, RD]);
        }
        // plate bolts: nuts drop in from the inside face of each cheek
        for (y = [y_f + 6.3, y_r - 6.3], z = [zs0 + 12, zs1 - 10]) {
            nut_slot_y([cx0 + CT / 2, y, z], +1);
            nut_slot_y([cx1 - CT / 2, y, z], -1);
        }
        // lightening / drain slots, kept clear of seams and grooves
        for (b = g(G, "bays")) let(m = GW / 2 + RT + 6, xa = b[0] + m, xb = b[1] - m) if (xb - xa >= 14)
            for (i = [0 : n - 1]) let(a = y_f + i * bm + 22, c = y_f + (i + 1) * bm - 22, k = floor((c - a + 10) / 60))
                if (k > 0) for (j = [0 : k - 1]) let(ys = a + j * (c - a) / k)
                    box([xa, ys, zs0 - 1], [xb, ys + (c - a) / k - 10, zb + 1]);
    }
}

module plate_full(G, which = "front") {
    cx0 = g(G, "cx0"); cx1 = g(G, "cx1"); CT = g(G, "CHEEK_T"); Wc = g(G, "Wc");
    PT = g(G, "PT"); RT = g(G, "RIB_T"); RD = g(G, "RIB_D"); GW = g(G, "GW");
    BW = g(G, "BOSS_W"); BD = g(G, "BOSS_D"); CH = g(G, "CAP_H");
    zs0 = g(G, "zs0"); zs1 = g(G, "zs1"); zb = g(G, "zb"); zt = g(G, "z_top");
    F = which == "front";
    yi = F ? g(G, "y_f") : g(G, "y_r");          // inner face
    dir = F ? 1 : -1;                              // toward the inside of the carriage
    yo = yi - dir * PT;                            // outer face
    difference() {
        union() {
            if (F) box([cx0, yo, zs0], [cx1, yi, zt]);
            else union() {                         // rear: ladder frame, not a solid sheet
                box([cx0, yi, zs0], [cx1, yo, zs1]);                              // bottom band
                box([cx0, yi, zt - CH - 4], [cx1, yo, zt]);                      // top band
                box([cx0, yi, zs0], [cx0 + 18, yo, zt]);                          // stiles
                box([cx1 - 18, yi, zs0], [cx1, yo, zt]);
                for (x = g(G, "px")) box([x - GW / 2 - RT - 5, yi, zs0], [x + GW / 2 + RT + 5, yo, zt]);
                for (s = seams(zs0, zt, g(G, "n_plate")))                         // rungs at seams
                    box([cx0, yi, s - 20], [cx1, yo, s + 20]);
            }
            for (x = g(G, "px")) {
                for (s = [-1, 1])                                                   // board groove
                    translate([x + s * (GW + RT) / 2 - RT / 2, min(yi, yi + dir * RD), zb])
                        cube([RT, RD, zt - CH - zb]);
                translate([x - BW / 2, min(yi, yi + dir * BD), zt - CH]) cube([BW, BD, CH]);  // boss
            }
        }
        // dovetail sockets for the top rails (open at the top)
        // same placement as the tails in top_rail_full, plus clearance
        for (x = g(G, "px"))
            translate([x, F ? yi + BD : yi - BD, zt - CH - 1]) mirror([0, F ? 1 : 0, 0])
                linear_extrude(CH + 2) dovetail2d(0.25);
        // bolt holes into the cheeks, counterbored on the outer face
        for (x = [cx0 + CT / 2, cx1 - CT / 2], z = [zs0 + 12, zs1 - 10]) translate([x, 0, z]) {
            translate([0, yo - dir, 0]) rotate([-90 * dir, 0, 0]) cylinder(d = 3.4, h = PT + 2, $fn = 16);
            translate([0, yo - dir, 0]) rotate([-90 * dir, 0, 0]) cylinder(d = 6.2, h = 3.2 + 1, $fn = 20);
        }
        // finger slots on the front, in the central bay(s)
        if (F) {
            bays = g(G, "bays"); nb = len(bays);
            pick = nb % 2 == 1 ? [floor(nb / 2)] : [nb / 2 - 1, nb / 2];
            zc = zt - CH - 34;
            for (i = pick) let(b = bays[i], w = min(b[1] - b[0] - 2 * (GW / 2 + RT + 6), 90))
                if (w >= 30 && zc - 12 >= zs1 + 6)
                    translate([(b[0] + b[1]) / 2, 0, zc]) hull() for (s = [-1, 1])
                        translate([s * (w / 2 - 12), yi + 1, 0]) rotate([90, 0, 0]) cylinder(r = 12, h = PT + 2, $fn = 32);
        }
    }
}

module top_rail_full(G, i) {
    x = g(G, "px")[i]; CW = g(G, "CAP_W"); CH = g(G, "CAP_H"); RT = g(G, "RIB_T"); RD = g(G, "RIB_D");
    GW = g(G, "GW"); BD = g(G, "BOSS_D"); zt = g(G, "z_top");
    ya = g(G, "y_f") + BD; yb = g(G, "y_r") - BD;
    box([x - CW / 2, ya, zt - CH], [x + CW / 2, yb, zt]);                          // cap
    for (s = [-1, 1]) box([x + s * (GW + RT) / 2 - RT / 2, ya, zt - CH - RD], [x + s * (GW + RT) / 2 + RT / 2, yb, zt - CH]);
    // dovetail tails into the plate bosses
    translate([x, ya, zt - CH]) mirror([0, 1, 0]) linear_extrude(CH) dovetail2d();
    translate([x, yb, zt - CH]) linear_extrude(CH) dovetail2d();
}

module boards_part(G) {  // the user's openGrid boards, preview only
    t = g(G, "board_t"); zb = g(G, "zb"); y_f = g(G, "y_f") + 0.3;
    cy = chunks(g(G, "ny")); cz = chunks(g(G, "nz"));
    for (x = g(G, "px")) for (a = [0 : len(cy) - 1], b = [0 : len(cz) - 1]) {
        y = y_f + 28 * sum(cy, a); z = zb + 28 * sum(cz, b);
        box([x - t / 2, y + 0.3, z + 0.3], [x + t / 2, y + cy[a] * 28 - 0.3, z + cz[b] * 28 - 0.3]);
    }
}
function sum(v, n) = n <= 0 ? 0 : v[n - 1] + sum(v, n - 1);

module carriage_part(G) {
    base_full_keyed(G);
    plate_keyed(G, "front");
    plate_keyed(G, "rear");
    for (i = [0 : g(G, "panels") - 1]) top_rail_keyed(G, i);
}

// ---------------------------------------------------------------- seam keys

module base_full_keyed(G) difference() {
    base_full(G);
    for (s = seams(g(G, "y_f"), g(G, "y_r"), g(G, "n_base")), x = g(G, "key_x"))
        translate([x, s, g(G, "zs0")]) rotate([0, 180, 90]) key_pocket();
}
module plate_keyed(G, which) difference() {
    plate_full(G, which);
    F = which == "front"; yi = F ? g(G, "y_f") : g(G, "y_r");
    for (s = seams(g(G, "zs0"), g(G, "z_top"), g(G, "n_plate")), x = g(G, "key_x"))
        translate([x, yi, s]) rotate([F ? -90 : 90, 0, 0]) rotate([0, 0, 90]) key_pocket();
}
module top_rail_keyed(G, i) difference() {
    top_rail_full(G, i);
    for (s = seams(g(G, "y_f") + 4, g(G, "y_r") - 4, g(G, "n_top")))
        translate([g(G, "px")[i], s, g(G, "z_top")]) rotate([0, 0, 90]) key_pocket();
}

// ---------------------------------------------------------------- print parts
// spec: [id, label, qty, kind, seg, nseg, axis(0=x,1=y,2=z), lo, hi, bbox_min, bbox_max, rot]

function part_specs(G) =
    let(N = g(G, "N"), wp = g(G, "wp"), RT = g(G, "RAIL_T"), st = g(G, "slide_t"),
        cx0 = g(G, "cx0"), cx1 = g(G, "cx1"), y0 = g(G, "y0"), y_f = g(G, "y_f"), y_r = g(G, "y_r"),
        zs0 = g(G, "zs0"), zs1 = g(G, "zs1"), zt = g(G, "z_top"), PT = g(G, "PT"), BD = g(G, "BOSS_D"),
        CW = g(G, "CAP_W"), CH = g(G, "CAP_H"), RD = g(G, "RIB_D"), L = g(G, "rail_len"),
        nr = g(G, "n_rail"), nb = g(G, "n_base"), np = g(G, "n_plate"), nt = g(G, "n_top"),
        P = g(G, "panels"), nk = len(g(G, "key_x")),
        keys = N * ((nb - 1) * nk + 2 * (np - 1) * nk + P * (nt - 1)))
    concat(
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
             str("toprail_", p), i, nt, 1, y_f + 4, y_r - 4,
             [g(G, "px")[p] - CW / 2, y_f + 4, zt - CH - RD], [g(G, "px")[p] + CW / 2, y_r - 4, zt], [0, 180, 0]]],
        keys > 0 ? [["key", "Bowtie key", keys + 2, "key", 0, 1, 0, 0, 0,
                     [-KEY_L / 2, -KEY_W / 2, 0], [KEY_L / 2, KEY_W / 2, KEY_T], [0, 0, 0]]] : []
    );

module part_geom(G, kind) {
    if (kind == "rail_L") rail_full(G, "L");
    else if (kind == "rail_R") rail_full(G, "R");
    else if (kind == "base") base_full_keyed(G);
    else if (kind == "front") plate_keyed(G, "front");
    else if (kind == "rear") plate_keyed(G, "rear");
    else if (kind == "key") bowtie_key();
    else top_rail_keyed(G, search(kind[8], "0123456789")[0]);  // "toprail_<p>", p < 10
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
