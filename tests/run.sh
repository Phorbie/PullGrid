#!/usr/bin/env bash
# Smoke tests: render a few cabinets, check the PULLGRID report lines.
# Usage: tests/run.sh   (needs openscad on PATH)
set -u
cd "$(dirname "$0")/.."
SCAD=scad/pullgrid.scad
OUT=$(mktemp -d)
fail=0

run() {  # name, expected-substring, -D args...
  local name=$1 expect=$2; shift 2
  local log="$OUT/$name.log"
  openscad -o "$OUT/$name.stl" "$@" -D 'part="frame"' "$SCAD" >"$log" 2>&1
  if grep -q "$expect" "$log"; then
    echo "ok   $name  $(grep -o 'envelope_mm=[^"]*' "$log" | head -1)"
  else
    echo "FAIL $name (expected: $expect)"; grep PULLGRID "$log"; fail=1
  fi
}

run default         "slide_mm=508"
run frameless       "dodged_by=left"      -D 'frame_type="frameless"'
run right_hinge     "dodged_by=right"     -D 'hinge_side="right"'
run no_hinge        "envelope_mm"         -D 'hinge_side="none"'
run rear_pipe       "dodged_by=back"      -D 'keepouts=[[0,500,0,300,60,200]]'
run tapered         "envelope_mm"         -D 'rear_w=240' -D 'rear_h=560'
run too_small       "ERROR no_fit"        -D 'opening_w=20' -D 'frame_type="frameless"' -D 'door_intrusion=25'
run two_panels      "x2"                  -D 'panel_count=2'

rm -rf "$OUT"
exit $fail
