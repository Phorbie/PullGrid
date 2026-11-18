# Parameters

All dimensions in **mm**. `-1` means auto. The site will accept inches and convert.

PullGrid models a cabinet as **a shape with obstacles in it**: an opening in the front plane, an interior that can taper toward the back, and a list of keep-out boxes. Hinges are just keep-outs that get generated for you.

## Coordinates

Relative to the cabinet **interior**: `x` across from the left wall, `y` depth from the front plane (back face of the face frame), `z` up from the floor.

## Basic — what most people fill in

| Param | Meaning |
|---|---|
| `opening_w`, `opening_h` | Clear opening you can pass something through |
| `interior_depth` | Front plane to back wall |
| `frame_type` | `face_frame` or `frameless` — drives the offset defaults |
| `hinge_side` | `left`, `right`, `none` |

## Advanced — collapsed, auto-filled

| Param | Auto value | Meaning |
|---|---|---|
| `offset_left/right` | 10 face frame, 0 frameless | Face frame overhang past the interior wall |
| `offset_bottom` | 15 / 0 | Bottom rail height above the floor — the frame must clear it |
| `offset_top` | 10 / 0 | Top rail drop |
| `rear_w`, `rear_h` | same as front | Non-square cabinets; rear assumed centered |
| `hinges` | 2–4 Euro hinges by door height, 80 mm from ends, 12 mm (FF) / 20 mm intrusion | `[[center_z, intrusion, height, depth], ...]` |
| `door_intrusion` | 0 | Doors that can't open past 90° eat the hinge side |

**Auto values are v0 guesses.** They need checking against real cabinets — that's the first job of the test prints.

## Expert

| Param | Meaning |
|---|---|
| `keepouts` | `[[x, y, z, w, d, h], ...]` — plumbing, disposal, shelf pin rows |

## How keep-outs are solved

A pull-out sweeps its whole profile through every depth as it slides out, so anything whose x–z footprint overlaps the frame blocks it, wherever it sits in depth. The one escape is ending the frame in front of it.

For each keep-out the solver tries five dodges — shrink from left, right, bottom, top, or shorten from the back — and keeps the one that loses the least volume. v0 is greedy and order-dependent; good enough for hinges plus a pipe.

## Pull-out

| Param | Default | Meaning |
|---|---|---|
| `panel_count` | 1 | openGrid panels per pull-out, running front to back |
| `panel_thickness` | 6.8 | 6.8 = openGrid Full (double-sided), 4.0 = Lite |
| `pullouts` | -1 (auto) | Side-by-side pull-outs. Auto = as few as fit the print bed |
| `bed_size` | 256 | Parts are split to fit (6 mm margin) |
| `slide_t` | 12.7 | Side-mount slide thickness = clearance per side |
| `slide_h` | 45 | Slide body height |
| `clear_side/top/rear/front` | 3 / 5 / 10 / 0 | Gaps kept inside the envelope |

The frame is sized to whole 28 mm openGrid cells, so it can come out up to one cell shorter and shallower than the envelope.

## Render

`part`: `assembly`, `carriage`, `boards`, `rails`, `slides_fixed`, `slides_moving`, `cabinet`, `keepouts`, `envelope`, or `print` with `print_index` (from the `PULLGRID part=` report lines). Print parts come out oriented and sitting on z = 0.
