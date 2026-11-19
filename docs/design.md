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
2. **Sweep envelope** (`lib/envelope.scad`): the largest box that passes through the opening, fits the interior over its full travel, and misses every keep-out.
3. **Carriage layout** (`lib/carriage.scad`, `carriage_geometry()`): splits wide envelopes into side-by-side pull-outs, sizes the frame to whole openGrid cells, picks the slide length and angle size, and places tie rods and door brackets. The result is a key/value list `G`, read with `g(G, "key")`. Modules take `G` and never read globals.
4. **Parts** (`part_specs()`): each part family is split along one axis to fit the bed. Each spec carries its assembled bounding box and a print rotation, so `print_part()` can slice, rotate and drop it onto z = 0.

## The report

OpenSCAD `echo` lines starting with `PULLGRID` are the interface between the model and the site:

```
PULLGRID envelope_mm=[274, 550, 595]
PULLGRID pullouts=1
PULLGRID part=0 id=base_1 qty=1 size=[241.6, 177.5, 45] label=Base 1/3
PULLGRID hw=1 item=1/4in-20 threaded rod, 6 ft
PULLGRID cut=3 len=561 item=tie rod
PULLGRID WARNING angle_too_short
```

Adding new keys is fine. Changing the format of existing ones breaks the site.

## Tests

```sh
tests/run.sh            # smoke tests: 34 cabinets and modes, checks report lines
tests/interference.sh   # every pair of parts must not overlap; tie rods must thread every hole
tests/print_parts.sh    # every print part exports, sits on z = 0 and fits the bed
```

The interference test intersects pairs of parts and measures the result's volume. Zero-volume face contact is fine; anything over 1 mm³ is a collision. All three suites accept extra `-D` arguments, so you can run them against any configuration, and CI runs all three.

## Why openGrid boards aren't modeled

The frame holds standard openGrid boards in grooves instead of printing its own panels. openGrid is CC BY 4.0, but the popular openGrid tile generator is CC BY-NC-SA, whose non-commercial clause conflicts with PullGrid's CC BY-SA. Re-modeling the tile profile from memory would risk snaps that don't fit. Holding real boards sidesteps both problems and keeps PullGrid inside openGrid's own ecosystem.

## Hardware rules

Non-printed hardware must be stocked by ordinary hardware stores in both inch markets (US, Canada) and metric ones (UK, Ireland, Australia, NZ). Printed holes accept both sizes (6.8 mm rod holes fit ¼″-20 and M6; 4.5 mm holes fit #8 and 4 mm screws), and nothing relies on a size-specific nut trap. See [Hardware](hardware.md).

## Contributing

Issues and pull requests are welcome at [github.com/Phorbie/PullGrid](https://github.com/Phorbie/PullGrid). The most useful contribution right now is a **real install**: photos, your settings link, and what didn't fit.

Before opening a pull request that touches geometry, run all three test suites.

## License

PullGrid by Phorbie Designs: [CC BY-SA 4.0](../LICENSE). The website bundles OpenSCAD (GPL-2.0, via [openscad-wasm](https://github.com/lorenzowritescode/openscad-wasm)) and three.js (MIT). openGrid is by David D, CC BY 4.0.
