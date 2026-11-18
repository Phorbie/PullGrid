# PullGrid — notes for Claude

- **OpenSCAD is the single source of truth** for geometry. The site and the MakerWorld customizer both run `scad/pullgrid.scad`. Never duplicate geometry logic in JS.
- Target **OpenSCAD 2021.01** (MakerWorld's customizer lags behind; the site's WASM build is newer). No `object()`, no newer builtins. Watch for `[0:-1]` ranges: they count backwards — use `seq(n)`.
- Units are mm internally. Inches are a UI concern.
- Customizer params live at the top of `scad/pullgrid.scad`, grouped Basic / Advanced / Expert. Hide inputs, never the data model: advanced params default from basic ones (`-1` = auto).
- The site reads `echo` lines prefixed `PULLGRID`. Changing their format is a breaking change.
- Run `tests/run.sh`, `tests/interference.sh` and `tests/print_parts.sh` before committing geometry changes. CI runs all three. Interference counts zero-volume face contact as OK.
- Frame layout lives in a key/value list `G` from `carriage_geometry()`; read it with `g(G, "key")`. Modules take `G`, never globals.
- The site renders with `--backend=manifold` (~40x faster than CGAL). Desktop 2021.01 uses CGAL, so keep CSG simple.
- openGrid pitch is 28 mm. Tiles are NOT modeled: the frame holds standard boards in grooves. The popular openGrid tile generator is CC BY-NC-SA, which conflicts with our CC BY-SA, so don't copy from it.
- Site (`site/`): plain ES modules, no bundler. `site/build.sh` assembles `_site/` and vendors OpenSCAD WASM + three.js from npm. The worker passes `-D` values verbatim, so strings need quotes.
