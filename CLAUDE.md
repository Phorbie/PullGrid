# PullGrid — notes for Claude

- **OpenSCAD is the single source of truth** for geometry. The site and the MakerWorld customizer both run `scad/pullgrid.scad`. Never duplicate geometry logic in JS.
- Target **OpenSCAD 2021.01** (MakerWorld's customizer and the WASM build lag behind). No `object()`, no newer builtins.
- Units are mm internally. Inches are a UI concern.
- Customizer params live at the top of `scad/pullgrid.scad`, grouped Basic / Advanced / Expert. Hide inputs, never the data model: advanced params default from basic ones (`-1` = auto).
- The site reads `echo` lines prefixed `PULLGRID`. Changing their format is a breaking change.
- Run `tests/run.sh` before committing geometry changes.
- openGrid pitch is 28 mm. Reuse the openGrid OpenSCAD libraries for tile geometry instead of re-modeling it.
