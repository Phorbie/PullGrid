# PullGrid

Turn a deep cabinet into a pull-out. Enter your cabinet's measurements, and PullGrid gives you 3D-printable parts sized to it, a short list of cheap hardware-store items, and install steps. The panels are standard [openGrid](https://www.printables.com/model/1214361-opengrid-walldesk-mounting-framework-and-ecosystem) boards, so the whole openGrid accessory ecosystem snaps onto both sides.

**[Open the generator →](https://phorbie.github.io/PullGrid/)**  ·  **[Read the docs →](https://phorbie.github.io/PullGrid/docs/)**

![A PullGrid pull-out with the cabinet door mounted on its front, pulled out of a cabinet](docs/img/assembly-mount.png)

> **Status: beta.** The parts are tested in software (fit, interference, every part exports and fits the bed) but haven't been proven in a real cabinet yet. Print one base piece and dry-fit your slides before printing everything: [how](docs/printing.md#test-print-first).

## What you build

| | |
|---|---|
| **Door** | Your cabinet door comes off its hinges and screws to printed brackets: it becomes the pull-out's front, so nothing blocks the sides. Or keep it hinged |
| **Rails** | Two pieces of aluminum angle screwed to the cabinet floor, carrying a standard pair of 45 mm full-extension slides. Printed rails if you'd rather not cut metal |
| **Carriage** | Printed base, plates and top rails, clamped into one box by threaded tie rods. Split to fit your print bed |
| **Panels** | Standard openGrid boards in grooves, printed from openGrid's own files |
| **Fixed shelves** | One pull-out (tier) per gap. With a mounted door they all come out together; shared parts print from one file |
| **Blocked side** | A kept door that only opens to 90°? Each tier gets one panel against that side, every accessory facing you |

All hardware is stocked by ordinary big-box stores in the US, Canada, UK, Ireland, Australia and New Zealand. The generator switches sizes and names for your region.

## Docs

- [Measuring your cabinet](docs/measuring.md)
- [Mounting your door](docs/door-mount.md)
- [Hardware](docs/hardware.md)
- [Printing](docs/printing.md)
- [Assembly and install](docs/assembly.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Parameters](docs/parameters.md) · [Design notes](docs/design.md)

## Run it yourself

```sh
openscad scad/pullgrid.scad          # desktop OpenSCAD: use the Customizer

tests/run.sh                         # smoke tests: 50+ cabinets and modes
tests/interference.sh                # no two parts overlap; tie rods thread every hole;
                                     # nothing hits a keep-out or shelf
tests/print_parts.sh                 # every part exports and fits the bed

(cd site && npm ci) && bash site/build.sh && python3 -m http.server -d _site   # the website
```

Pushing to `main` runs the tests and deploys the site and docs to GitHub Pages.

## Roadmap

- [x] Fit solver: opening, hinges, keep-outs, non-square cabinets
- [x] Generator site: in-browser OpenSCAD, 3D preview, inch/mm with fractions, share links
- [x] Printable frame: openGrid panels, bed splitting, parts zip, hardware list
- [x] Door mount, aluminum angle rails, tie rods, inch/metric hardware
- [x] Documentation
- [x] Fixed shelves (stacked tiers), one-sided tiers for doors stuck at 90°
- [ ] First real install, then tune the auto defaults
- [ ] Mid rails at board seams for heavy loads
- [ ] Inset doors in door-mount mode
- [ ] Guided measuring flow in the generator

## License

PullGrid by Phorbie Designs is licensed under [CC BY-SA 4.0](LICENSE): use it, remix it, sell prints of it. Credit **PullGrid by Phorbie Designs** and share remixes under the same license.

The generator site bundles [OpenSCAD](https://openscad.org) (GPL-2.0, via [openscad-wasm](https://github.com/lorenzowritescode/openscad-wasm)), [three.js](https://threejs.org) (MIT) and [marked](https://marked.js.org) (MIT, docs build only). openGrid is by David D, CC BY 4.0.
