#!/usr/bin/env bash
# Smoke tests: evaluate many cabinets and modes, check the PULLGRID report lines.
# Usage: tests/run.sh   (needs openscad on PATH)
set -u
cd "$(dirname "$0")/.."
SCAD=scad/pullgrid.scad
OUT=$(mktemp -d)
fail=0

run() {  # name, expected-substring, -D args...
  local name=$1 expect=$2; shift 2
  local log="$OUT/$name.log"
  # .echo export evaluates the model without rendering geometry: fast, and the
  # report is all these tests check (print_parts.sh / interference.sh render)
  openscad -o "$OUT/$name.echo" -D 'part="frame"' "$@" "$SCAD" >"$log" 2>&1
  cat "$OUT/$name.echo" >>"$log" 2>/dev/null
  if grep -q "$expect" "$log"; then
    echo "ok   $name  $(grep -o 'envelope_mm=[^"]*' "$log" | head -1)"
  else
    echo "FAIL $name (expected: $expect)"; grep PULLGRID "$log"; fail=1
  fi
}

run default         "slide_mm=508"
run clearance_13    "carriage_mm=\[241.6"
run frameless       "dodged_by=left"      -D 'frame_type="frameless"' -D 'door_mode="keep"'
run right_hinge     "dodged_by=right"     -D 'hinge_side="right"' -D 'door_mode="keep"'
run no_hinge        "hinges=0"            -D 'hinge_side="none"'
run rear_pipe       "dodged_by=back label=keep-out 1"      -D 'keepouts=[[0,500,0,300,60,200]]'
run tapered         "envelope_mm"         -D 'rear_w=240' -D 'rear_h=560'
run too_small       "ERROR no_fit"        -D 'opening_w=20' -D 'frame_type="frameless"' -D 'door_intrusion=25'
run too_narrow      "WARNING too_narrow"  -D 'opening_w=130'
run wide_two        "pullouts=2"          -D 'opening_w=480'
run small_bed       "Base 3/4"            -D 'bed_size=180'
run lite_panels     "type=lite"           -D 'panel_thickness=4.0'
run three_panels    "x3"                  -D 'opening_w=400' -D 'panel_count=3' -D 'pullouts=1' -D 'bed_size=400'
run no_room_height  "ERROR no_fit"        -D 'opening_h=40'
run two_panels      "x2"                  -D 'panel_count=2'
run door_swing      "label=door swing"    -D 'door_intrusion=25' -D 'door_mode="keep"'
run hinge_count     "hinges=3"            -D 'opening_h=700' -D 'door_mode="keep"'
run cabinet_part    "PULLGRID"            -D 'part="cabinet"'
run keepouts_part   "PULLGRID"            -D 'part="keepouts"'
run print_part      "id=base_1"           -D 'part="print"' -D 'print_index=0'
run keep_door       "hinges=3"            -D 'door_mode="keep"'
run mount_no_hinge  "hinges=0"            -D 'door_mode="mount"'
run bracket_ff      "bracket_mm=21"       -D 'frame_type="face_frame"'
run bracket_fl      "bracket_mm=11"       -D 'frame_type="frameless"'
run printed_rails   "id=rail_L_1"         -D 'rail_type="printed"'
run angle_2in       "angle 2in"           -D 'frame_type="face_frame"'
run angle_1_5in     "angle 1-1/2in"       -D 'frame_type="frameless"'
run angle_short     "angle_too_short"     -D 'offset_bottom=40'
run metric_slide    "slide_mm=500"        -D 'region="metric"'
run metric_rod      "M6 threaded rod"     -D 'region="metric"'
run inch_rod        "1/4in-20 threaded"   -D 'region="inch"'
run rod_cut         "item=tie rod"        -D 'panel_count=2'
run deep_28in       "slide_mm=711.2"      -D 'interior_depth=760'
run thin_door       "door_too_thin"       -D 'door_thickness=12'

rm -rf "$OUT"
exit $fail
