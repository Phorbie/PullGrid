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

## Frame & clearances

`slide_height`, `panel_count`, `panel_thickness` (6.8 openGrid full / 4.0 lite), `clear_side/top/rear/front`.
