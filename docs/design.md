# Design notes

How PullGrid is put together, for anyone who wants to change it.

## One source of truth

All geometry lives in OpenSCAD: `scad/pullgrid.scad` plus `scad/lib/`. The same file runs in three places:

| Where | How |
|---|---|
| The [website](https://phorbie.github.io/PullGrid/) | OpenSCAD compiled to WebAssembly, in a pool of Web Workers, with the Manifold backend (about 40× faster than CGAL) |
| Desktop OpenSCAD | Open `scad/pullgrid.scad` and use the Customizer |
| CI | OpenSCAD from Ubuntu's packages runs the test suites on every push |

The site never computes geometry in JavaScript. It sends `-D` overrides to OpenSCAD, renders STLs with three.js, and reads a text report.

The code targets **OpenSCAD 2021.01**, because MakerWorld's customizer lags behind. One trap: `[0:-1]` ranges count backwards in OpenSCAD, so empty lists use `seq(n)`.

## The pipeline

1. **Defaults** (`pullgrid.scad`): basic inputs fill in the advanced ones (`-1` = auto), and hinges become keep-out boxes unless the door is mounted.
2. **Tiers** (`pullgrid.scad`): fixed shelves split the cabinet into gaps, each solved on its own.
3. **Sweep envelope** (`lib/envelope.scad`), per tier: the largest box that passes through the opening, fits the interior over its full travel, and misses every keep-out. The envelope carries `zf`, the height its rails stand on. Keep-outs block from `zf` up, and only a keep-out covering the whole width and rail run can raise `zf` (the rails stand on it).
4. **Carriage layout** (`lib/carriage.scad`, `carriage_geometry()`), per tier, in **tier-local coordinates** (z = 0 is what the rails stand on): splits wide envelopes into side-by-side pull-outs, sizes the frame to whole openGrid cells, picks the slide length and angle size, and places tie rods and door brackets. The result is a key/value list `G`, read with `g(G, "key")`. Modules take `G` and never read globals. With a mounted door the tiers are solved three times: alone, then with a shared front plane, then with a shared slide length and angle size.
   Each tier then gets one `G` per pull-out (`units()`, `UNITS` in `pullgrid.scad`): same envelope, slides and position, its own panel layout from `reach_of()` (the `sides` override, then `reach_from`, then auto).
5. **Parts** (`part_specs()`): each part family is split along one axis to fit the bed. Each spec carries its assembled bounding box and a print rotation, so `print_part()` can slice, rotate and drop it onto z = 0. Specs from every pull-out are grouped by a **shape signature** (`part_sig()`, everything relative to the part itself), so a base that every tier shares is one file, not one per tier.

## The Bambu Studio project

`site/threemf.js` turns the print STLs into a Bambu Studio / OrcaSlicer project 3MF. It computes no geometry: parts arrive from OpenSCAD already oriented and split, and it only lays them out on plates (`packPlates()`). What Bambu Studio needs to load more than geometry comes from its loader source (`Plater.cpp`, `bbs_3mf.cpp`):

- `Application` metadata starting `BambuStudio-`. We claim 2.0.0, so any 2.x app loads it without a "newer file" prompt.
- A project config that only **names** Bambu's system presets and marks nothing as changed. Studio fills every value from its own presets.
- Plates in `model_settings.config`, with each instance placed inside its plate on Studio's grid (plates are rebuilt from position). Per-object `wall_loops` and infill.
- At most 36 plates per file.

The carriage splits wide pieces short enough to sit above the 18 × 28 mm calibration corner on P1 and X1 beds (`SPLIT_MAX` in `carriage_geometry()`), so the layout never has to put a part there.

`tests/threemf.sh <printer>` builds the project exactly as the site does and checks it with `tests/threemf_check.py`: references, instance counts, plate membership and bounds, overlaps, the corner, watertight meshes and the preset names. It can't open the file in Bambu Studio itself, so a real-app check is still worth doing after format changes.

## The report

OpenSCAD `echo` lines starting with `PULLGRID` are the interface between the model and the site:

```
PULLGRID tiers=2
PULLGRID door=mount region=inch rails=angle reach=both
PULLGRID tier=1 floor=0 envelope_mm=[274, 550, 361]
PULLGRID tier=1 slide_mm=508
PULLGRID tier=1 pullouts=1
PULLGRID tier=1 pullout=1 reach=both panels=1
PULLGRID tier=2 floor=400 envelope_mm=[274, 550, 222]
PULLGRID tier=3 floor=640 skipped height=40
PULLGRID part=0 id=base_1 qty=2 size=[241.6, 177.5, 45] label=Base 1/3
PULLGRID part=3 id=t1_front_1 qty=1 size=[241.6, 177.3, 16] label=Tier 1: Front plate 1/2
PULLGRID hw=2 item=1/4in-20 threaded rod, 6 ft
PULLGRID cut=6 len=561 item=tie rod
PULLGRID WARNING tier_skipped
```

Lines about one tier start with `tier=<n> `; everything else (parts, hardware, cuts, warnings) covers the whole build. Part ids and labels carry a tier prefix only when not every tier uses that part. Adding new keys is fine. Changing the format of existing ones breaks the site.

## Tests

```sh
tests/run.sh            # smoke tests: 50+ cabinets and modes, checks report lines
tests/interference.sh   # every pair of parts must not overlap; tie rods must thread every hole;
                        # nothing in any tier may hit a keep-out or shelf
tests/print_parts.sh    # every print part exports, sits on z = 0 and fits the bed; the Pieces
                        # view shows exactly one body per printed piece
tests/threemf.sh p1s    # the Bambu Studio project builds, and every part lands on its plate
```

The interference test intersects pairs of parts and measures the result's volume. Part pairs use one tier (`-D test_tier=k` picks which); the whole-cabinet pairs use every tier in cabinet coordinates. Zero-volume face contact is fine; anything over 1 mm³ is a collision. All three suites accept extra `-D` arguments, so you can run them against any configuration, and CI runs all three.

## Front handles

`handle_fields()` in `lib/carriage.scad` adds the handle layout to each pull-out's `G` (`h_at` centres, `h_cuts` slot cuts, `h_pts` screw holes) when the front plate is the face. Anything through the plate must clear the board grooves (`fix_x`), the plate seams and their keys (`fix_z`), the base below and the top rail above. Printed handles are their own print part, modelled in a local frame (along x, out toward −y, face at y = 0) and placed with `handle_place()`. With a hung door, `CF` grows by the handle depth so the door closes over them; `tests/interference.sh` checks that with a closed-door pair.

## The viewer

The 3D view only displays what the model renders; nothing in it feeds back into the geometry.

- **Pieces** renders `part="pieces"` (and `"rail_pieces"` for printed rails): the same slices `print_part()` prints, in place, each shrunk 0.25 mm about its own centre so seams show and no two pieces fuse, with the bowtie keys in their pockets. The site colours each separate body so neighbours differ and paints the keys orange. It renders only when someone picks Pieces.
- **Board looks** (openGrid, Hex, SKÅDIS, Multiboard) are a shader on the board faces, measured from the openGrid cell origin the report gives. They're looks only: the frame is grooved for openGrid boards.
- **Drag arrows** float over each pull-out (always on top, a constant size on screen, so they never read as parts) and slide one pull-out each (all of them at once with a mounted door, which carries every pull-out). The slider moves them all.

## Why openGrid boards aren't modeled

The frame holds standard openGrid boards in grooves instead of printing its own panels. openGrid is CC BY 4.0, but the popular openGrid tile generator is CC BY-NC-SA, whose non-commercial clause conflicts with PullGrid's CC BY-SA. Re-modeling the tile profile from memory would risk snaps that don't fit. Holding real boards sidesteps both problems and keeps PullGrid inside openGrid's own ecosystem.

## Hardware rules

Non-printed hardware must be stocked by ordinary hardware stores in both inch markets (US, Canada) and metric ones (UK, Ireland, Australia, NZ). Printed holes accept both sizes (6.8 mm rod holes fit ¼″-20 and M6; 4.5 mm holes fit #8 and 4 mm screws), and nothing relies on a size-specific nut trap. See [Hardware](hardware.md).

## Contributing

Issues and pull requests are welcome at [github.com/Phorbie/PullGrid](https://github.com/Phorbie/PullGrid). The most useful contribution right now is a **real install**: photos, your settings link, and what didn't fit.

Before opening a pull request that touches geometry, run all three test suites.

## License

PullGrid by Phorbie Designs: [CC BY-SA 4.0](../LICENSE). The website bundles OpenSCAD (GPL-2.0, via [openscad-wasm](https://github.com/lorenzowritescode/openscad-wasm)) and three.js (MIT). openGrid is by David D, CC BY 4.0.
