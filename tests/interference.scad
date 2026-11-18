// Every pair of parts in one pull-out must not overlap. Run with -D pair=k;
// a clean pair renders nothing ("Current top level object is empty").
include <../scad/pullgrid.scad>
pair = 0;
PAIRS = [["base","front"],["base","rear"],["base","top"],["base","boards"],["front","top"],
         ["rear","top"],["front","boards"],["rear","boards"],["top","boards"],["rails","base"],
         ["rails","front"],["rails","rear"],["rails","boards"],["slides_in","base"],["slides_out","rails"],
         ["slides_in","rails"]];
module P_(n) {
    if (n == "base") base_full_keyed(G);
    if (n == "front") plate_keyed(G, "front");
    if (n == "rear") plate_keyed(G, "rear");
    if (n == "top") for (i = [0 : g(G, "panels") - 1]) top_rail_keyed(G, i);
    if (n == "boards") boards_part(G);
    if (n == "rails") { rail_full(G, "L"); rail_full(G, "R"); }
    // hardware shrunk 0.05 so face contact doesn't count
    if (n == "slides_in") translate([0, 0.05, 0.05]) resize_slides("inner");
    if (n == "slides_out") translate([0, 0.05, 0.05]) resize_slides("outer");
}
module resize_slides(w) intersection() { slides_part(G, w); slides_shrink(w); }
module slides_shrink(w) { RT = g(G, "RAIL_T"); st = g(G, "slide_t"); wp = g(G, "wp");
    for (mx = [0, 1]) translate([mx * wp, 0, 0]) mirror([mx, 0, 0])
        translate([RT + 0.05, -BIG / 2, -BIG / 2]) cube([st - 0.1, BIG, BIG]); }
if (fits) { echo(str("PAIR ", PAIRS[pair][0], " x ", PAIRS[pair][1])); intersection() { P_(PAIRS[pair][0]); P_(PAIRS[pair][1]); } }
