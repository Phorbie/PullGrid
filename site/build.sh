#!/usr/bin/env bash
# Assemble the static site into _site/ (repo root). No bundler.
# Usage: (cd site && npm ci) && bash site/build.sh
set -euo pipefail
cd "$(dirname "$0")/.."
OUT=${1:-_site}
NM=site/node_modules

rm -rf "$OUT"
mkdir -p "$OUT/scad/lib" "$OUT/vendor/openscad" "$OUT/vendor/three"

cp site/index.html site/app.js site/worker.js site/zip.js site/threemf.js site/style.css "$OUT/"
cp scad/pullgrid.scad "$OUT/scad/"
cp scad/lib/*.scad "$OUT/scad/lib/"
cp LICENSE "$OUT/"

# OpenSCAD (GPL-2.0) — single file with the wasm inlined
cp "$NM/openscad-wasm-prebuilt/dist/openscad.js" "$OUT/vendor/openscad/"
cp "$NM/openscad-wasm-prebuilt/COPYING" "$OUT/vendor/openscad/"

# three.js (MIT)
cp "$NM/three/build/three.module.min.js" "$OUT/vendor/three/three.module.js"
cp "$NM/three/examples/jsm/controls/OrbitControls.js" "$OUT/vendor/three/"
cp "$NM/three/examples/jsm/loaders/STLLoader.js" "$OUT/vendor/three/"
cp "$NM/three/LICENSE" "$OUT/vendor/three/"

# docs: Markdown -> pages
node site/build-docs.mjs "$OUT"

# list of scad files for the worker to load
(cd "$OUT/scad" && find . -name '*.scad' | sed 's|^\./||' | sort) > "$OUT/scad/files.txt"

touch "$OUT/.nojekyll"
echo "built $OUT ($(du -sh "$OUT" | cut -f1))"
