// PullGrid — pull-out frame (v0 placeholder geometry)
//
// v0 is deliberately chunky: a base, a front plate, a rear post, a top rail,
// and N vertical panels running front-to-back. The panels are plain slabs
// sized to whole openGrid cells. Real openGrid tile geometry gets swapped in
// later (see README roadmap) — don't polish this, replace it.

OG_CELL = 28;  // openGrid pitch

function grid_cells(len_mm) = floor(len_mm / OG_CELL);

// Frame layout derived from the envelope. Returns a "dict" as a list:
// [inner_x0, inner_x1, z_base_top, z_top, y_front_in, y_rear_in, panel_xs, panel_len, panel_h]
function frame_layout(env, slide_h, base_t, plate_t, rail_t, panel_count, panel_t) =
    let(
        x0 = env[0], x1 = env[1],
        z_base_top = env[2] + slide_h + base_t,
        z_top = env[3] - rail_t,
        y_front_in = env[4] + plate_t,
        y_rear_in = env[5] - plate_t,
        w = x1 - x0,
        pitch = w / (panel_count + 1),
        panel_xs = [for (i = [1 : panel_count]) x0 + i * pitch - panel_t / 2],
        panel_len = y_rear_in - y_front_in,
        panel_h = z_top - z_base_top
    )
    [x0, x1, z_base_top, z_top, y_front_in, y_rear_in, panel_xs, panel_len, panel_h];

module frame(env, slide_h = 15, base_t = 5, plate_t = 5, rail_t = 8,
             panel_count = 1, panel_t = 6.8, handle = true) {
    L = frame_layout(env, slide_h, base_t, plate_t, rail_t, panel_count, panel_t);
    x0 = L[0]; x1 = L[1]; w = x1 - x0;
    zb = env[2] + slide_h;  // underside of base
    zt = env[3];
    y0 = env[4]; y1 = env[5];

    // base
    translate([x0, y0, zb]) cube([w, y1 - y0, base_t]);
    // front plate (this is what you see with the door open)
    difference() {
        translate([x0, y0, zb]) cube([w, plate_t, zt - zb]);
        if (handle)  // finger slot near the top
            translate([x0 + w * 0.3, y0 - 1, zt - 40]) cube([w * 0.4, plate_t + 2, 22]);
    }
    // rear post
    translate([x0, y1 - plate_t, zb]) cube([w, plate_t, zt - zb]);
    // top rail
    translate([x0 + w / 2 - 10, y0, zt - rail_t]) cube([20, y1 - y0, rail_t]);
    // panels — snapped to whole cells, centered in the available span
    cells_y = grid_cells(L[7]);
    cells_z = grid_cells(L[8]);
    for (px = L[6])
        translate([px, L[4] + (L[7] - cells_y * OG_CELL) / 2, L[2]])
            cube([panel_t, cells_y * OG_CELL, cells_z * OG_CELL]);
}
