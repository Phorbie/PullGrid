# PullGrid — notes for Claude

- **OpenSCAD is the single source of truth** for geometry. The site and the MakerWorld customizer both run `scad/pullgrid.scad`. Never duplicate geometry logic in JS.
- Target **OpenSCAD 2021.01** (MakerWorld's customizer lags behind; the site's WASM build is newer). No `object()`, no newer builtins. Watch for `[0:-1]` ranges: they count backwards — use `seq(n)`.
- Units are mm internally. Inches are a UI concern.
- Customizer params live at the top of `scad/pullgrid.scad`, grouped Basic / Advanced / Expert. Hide inputs, never the data model: advanced params default from basic ones (`-1` = auto).
- The site reads `echo` lines prefixed `PULLGRID`. Changing their format is a breaking change.
- Run `tests/run.sh` before committing geometry changes. CI runs it too.
- Site (`site/`): plain ES modules, no bundler. `site/build.sh` assembles `_site/` and vendors OpenSCAD WASM + three.js from npm. The worker passes `-D` values verbatim, so strings need quotes.
- openGrid pitch is 28 mm. Reuse the openGrid OpenSCAD libraries for tile geometry instead of re-modeling it.
