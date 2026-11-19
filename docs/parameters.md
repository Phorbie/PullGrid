# Parameters

Every input the generator and `scad/pullgrid.scad` accept. All dimensions are in **mm** inside the model; the website converts inches for you. `-1` means auto.

PullGrid models a cabinet as **a shape with obstacles in it**: an opening in the front plane, an interior that can taper toward the back, and a list of keep-out boxes. Hinges are keep-outs generated for you (and dropped entirely when the door is mounted).

## Coordinates

Relative to the cabinet **interior**: `x` across from the left wall, `y` depth from the front plane (the back of the face frame; the front edge of a frameless box), `z` up from the floor.

## Basic

| Param | Meaning |
|---|---|
| `opening_w`, `opening_h` | Clear opening you can pass something through |
| `interior_depth` | Front plane to back wall, at the floor |
| `frame_type` | `face_frame` or `frameless`. Drives the offset defaults |
| `hinge_side` | `left`, `right`, `none`. Only used when the door is kept hinged |

## Door

| Param | Default | Meaning |
|---|---|---|
| `door_mode` | `mount` | `mount`: the door comes off its hinges and screws to printed brackets on the front plate. `keep`: the door stays hinged; hinges become keep-outs |
| `door_thickness` | 19 | Door mount needs at least 15 |
| `door_overlay` | 12.7 | How far the door overlaps the opening per side. Preview only |
| `face_frame_thickness` | -1 | Face frame depth, front to back. Auto: 19 face frame, 0 frameless. Sets the bracket depth |

## Advanced: offsets and odd shapes

| Param | Auto value | Meaning |
|---|---|---|
| `offset_left/right` | 10 face frame, 0 frameless | Face frame overhang past the interior wall |
| `offset_bottom` | 15 / 0 | Bottom rail height above the floor. The moving parts must clear it |
| `offset_top` | 10 / 0 | Top rail drop |
| `rear_w`, `rear_h` | same as front | Non-square cabinets; rear assumed centered |
| `hinges` | 2–4 Euro hinges by door height, 80 mm from the ends, 12 mm (face frame) / 20 mm intrusion | `[[center_z, intrusion, height, depth], ...]`. Keep mode only |
| `door_intrusion` | 0 | Keep mode: a door that can't open past 90° eats the hinge side |

**The auto values are educated guesses.** They need checking against real cabinets.

## Expert

| Param | Meaning |
|---|---|
| `keepouts` | `[[x, y, z, w, d, h], ...]`: plumbing, disposal, shelf pin rows |

### How keep-outs are solved

A pull-out sweeps its whole profile through every depth as it slides out, so anything whose x–z footprint overlaps the frame blocks it, wherever it sits in depth. The one escape is ending the frame in front of it.

For each keep-out the solver tries five dodges (shrink from the left, right, bottom or top, or shorten from the back) and keeps the one that loses the least volume. It's greedy and order-dependent: good enough for hinges plus a pipe.

## Pull-out

| Param | Default | Meaning |
|---|---|---|
| `panel_count` | 1 | openGrid panels per pull-out, running front to back |
| `panel_thickness` | 6.8 | 6.8 = openGrid Full (double-sided), 4.0 = Lite |
| `pullouts` | -1 (auto) | Side-by-side pull-outs. Auto = as few as fit the print bed |
| `bed_size` | 256 | Parts are split to fit, with a 6 mm margin |

The frame is sized to whole 28 mm openGrid cells, so it can come out up to one cell shorter and shallower than the space allows.

## Hardware

| Param | Default | Meaning |
|---|---|---|
| `region` | `inch` | `inch` (US, Canada) or `metric` (UK, IE, AU, NZ). Sets the slide length list (10–28″ in 2″ steps, or 250–600 mm in 50 mm steps), angle sizes, and shopping-list names. The website picks it from your browser's language |
| `rail_type` | `angle` | `angle`: aluminum angle floor rails. `printed`: printed rails, no metalwork |
| `angle_thickness` | -1 | Angle wall thickness. Auto: 3.2 inch, 3.0 metric |
| `slide_t` | 13.0 | Slide clearance per side. The spec is ½″ (12.7) plus up to 1/32″, so 13.0 aims mid-range |
| `slide_h` | 45 | Slide body height |

The angle must reach above the slide's screw line: leg ≥ slide bottom + 28.5 mm. The generator picks 1½″ / 40 mm, or 2″ / 50 mm when the bottom rail is tall, and warns if neither reaches.

## Clearances

| Param | Default | Meaning |
|---|---|---|
| `clear_side` | 3 | Each side, inside the opening |
| `clear_top` | 5 | Above the frame |
| `clear_rear` | 10 | Behind the rear plate. Keep ≥ 10 for the tie-rod nuts |
| `clear_front` | -1 | In front of the front plate. Auto: `max(0, 9 − face frame depth)`, which leaves room for the tie-rod nuts and door brackets |

## Render

| Param | Meaning |
|---|---|
| `part` | `assembly`, `carriage`, `boards`, `rails`, `slides_fixed` (slides + angle), `slides_moving` (slides + tie rods), `door`, `cabinet`, `keepouts`, `envelope`, `print`, `none` |
| `print_index` | With `part = "print"`: which part, from the `PULLGRID part=` report lines. Print parts come out oriented and sitting on z = 0 |
| `extension` | Preview only: 0 = closed, 1 = full slide travel |
| `show_cabinet` | Ghost cabinet in the assembly preview |
