// PullGrid — ghost cabinet for previews and debugging. Not printed.

module ghost_box(p, s) { translate(p) cube(s); }

module cabinet_preview(front_w, front_h, rear_w, rear_h, depth,
                       off_l, off_r, off_b, off_t, keepouts, wall = 3) {
    // floor + walls (front section only; taper shown by rear wall size)
    color("BurlyWood", 0.15) {
        ghost_box([0, 0, -wall], [front_w, depth, wall]);                       // floor
        ghost_box([-wall, 0, 0], [wall, depth, front_h]);                       // left
        ghost_box([front_w, 0, 0], [wall, depth, front_h]);                     // right
        translate([(front_w - rear_w) / 2, depth, 0]) cube([rear_w, wall, rear_h]); // back
    }
    // face frame: everything in the front plane outside the opening
    color("SaddleBrown", 0.35) translate([0, -19, 0]) difference() {
        cube([front_w, 19, front_h]);
        translate([off_l, -1, off_b]) cube([front_w - off_l - off_r, 21, front_h - off_b - off_t]);
    }
    // keep-outs (hinges, plumbing, ...)
    color("Red", 0.5) for (k = keepouts) ghost_box([k[0], k[1], k[2]], [k[3], k[4], k[5]]);
}
