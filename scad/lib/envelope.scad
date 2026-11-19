// PullGrid — sweep envelope
//
// Coordinate system (all mm), relative to the cabinet INTERIOR:
//   x = across, 0 at the interior left wall (front plane)
//   y = depth,  0 at the front plane (back face of face frame / door line), +y into cabinet
//   z = up,     0 at the interior floor
//
// The pull-out travels along y. Pulled out, every point of its x-z profile
// sweeps through every y from the back of the cabinet to outside the door.
// So a keep-out blocks the frame if its x-z projection overlaps the frame's
// x-z profile, UNLESS the frame is shortened to end in front of it (y).
//
// Envelope format: [x0, x1, z0, z1, y0, y1, zf]
//   zf = what the floor rails stand on (cabinet floor, a shelf, or a platform).
//   The rails live between zf and the carriage, so anything above zf in the
//   envelope's footprint is in the way, even below z0.
// Keep-out format: [x, y, z, w, d, h]   (min corner + size)

function env_w(e) = e[1] - e[0];
function env_h(e) = e[3] - e[2];
function env_d(e) = e[5] - e[4];
function env_valid(e) = env_w(e) > 0 && env_h(e) > 0 && env_d(e) > 0;
function env_vol(e) = env_valid(e) ? env_w(e) * env_h(e) * env_d(e) : 0;

// Does keep-out k overlap the envelope (in 3D, given full travel)?
// Travel means only x-z overlap matters, plus whether k starts before y1.
// The z test starts at zf: the rails stand below the carriage.
function ko_blocks(e, k) =
    k[0] < e[1] && k[0] + k[3] > e[0] &&
    k[2] < e[3] && k[2] + k[5] > e[6] &&
    k[1] < e[5];

// A keep-out the rails can stand on: it covers the whole width and the whole
// rail run (y0 + plate .. y1 - plate). Anything smaller would leave a rail
// standing on air or running through it.
PLATE_Y = 6;
function ko_platform(e, k) =
    k[0] <= e[0] && k[0] + k[3] >= e[1] &&
    k[1] <= e[4] + PLATE_Y && k[1] + k[4] >= e[5] - PLATE_Y &&
    k[2] + k[5] < e[3];

NO_ENV = [0, 0, 0, 0, 0, 0, 0];

// The five ways to dodge a keep-out. Each returns a candidate envelope.
function ko_options(e, k) = [
    [max(e[0], k[0] + k[3]), e[1], e[2], e[3], e[4], e[5], e[6]],  // shrink from left
    [e[0], min(e[1], k[0]),      e[2], e[3], e[4], e[5], e[6]],     // shrink from right
    ko_platform(e, k)                                               // stand on it
        ? [e[0], e[1], max(e[2], k[2] + k[5]), e[3], e[4], e[5], max(e[6], k[2] + k[5])] : NO_ENV,
    [e[0], e[1], e[2], min(e[3], k[2]),      e[4], e[5], e[6]],     // lower top
    [e[0], e[1], e[2], e[3], e[4], min(e[5], k[1]), e[6]]           // shorten depth
];

ko_option_names = ["left", "right", "bottom", "top", "back"];

function argmax(v, i = 0, best = 0) =
    i >= len(v) ? best : argmax(v, i + 1, v[i] > v[best] ? i : best);

// Pick the dodge that keeps the most volume. Returns [env, option_index].
function dodge(e, k) =
    !ko_blocks(e, k) ? [e, -1] :
    let(opts = ko_options(e, k), vols = [for (o = opts) env_vol(o)], i = argmax(vols))
    [opts[i], i];

// Greedy pass over all keep-outs. Returns [env, log] where log is a list of
// [keepout_index, option_index] for every keep-out that cost something.
// v0 limitation: greedy and order-dependent. Good enough for hinges + a pipe.
function apply_keepouts(e, ks, i = 0, log = []) =
    i >= len(ks) ? [e, log] :
    let(r = dodge(e, ks[i]))
    apply_keepouts(r[0], ks, i + 1, r[1] >= 0 ? concat(log, [[i, r[1]]]) : log);

// Largest box that fits through the opening AND inside the interior.
// Non-square cabinets: rear assumed centered on the front; the usable
// section is the smaller of the two (conservative for a linear taper).
function base_envelope(front_w, front_h, rear_w, rear_h, depth,
                       off_l, off_r, off_b, off_t,
                       clear_side, clear_top, clear_rear, clear_front) =
    let(
        taper_x0 = max(0, (front_w - rear_w) / 2),
        taper_x1 = min(front_w, (front_w + rear_w) / 2),
        x0 = max(off_l, taper_x0) + clear_side,
        x1 = min(front_w - off_r, taper_x1) - clear_side,
        z0 = off_b,
        z1 = min(front_h - off_t, rear_h) - clear_top
    )
    [x0, x1, z0, z1, clear_front, depth - clear_rear, 0];

// One tier: the slice of env between a support (floor or shelf top) and a
// ceiling (shelf underside or the opening top), set back to y0.
function tier_envelope(e, zf, zlo, zhi, y0) =
    [e[0], e[1], max(e[2], zlo), min(e[3], zhi), max(e[4], y0), e[5], zf];
