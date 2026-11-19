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
run metric_kerf     "hw=2 item=aluminium" -D 'region="metric"'
# floor obstacles: rails stand on a full platform, steer around anything smaller
run platform        "tier=1 floor=40"     -D 'keepouts=[[0,0,0,400,600,40]]' -D 'rail_type="printed"'
run floor_partial   "dodged_by=back"      -D 'keepouts=[[100,300,0,80,300,60]]'
run under_ff_rail   "dodged_by="          -D 'keepouts=[[0,0,0,60,600,10]]'
# fixed shelves -> tiers
run shelves         "tier=2 floor=400"    -D 'opening_h=1200' -D 'shelves=[400,800]'
run shelf_unsorted  "tier=3 floor=800"    -D 'opening_h=1200' -D 'shelves=[800,400]'
run shelf_skip      "tier_skipped"        -D 'shelves=[590]'
run shelf_merge     "Tiers 1, 2 & 4: Front plate"   -D 'opening_h=1500' -D 'shelves=[400,800,1150]'
run shared_base     "id=base_1 qty=4"  -D 'opening_h=1500' -D 'shelves=[400,800,1150]'
run side_col_subset "Left pull-outs, tiers 1, 2 & 4: Front plate" -D 'opening_h=1500' -D 'opening_w=380' -D 'shelves=[400,800,1150]'
run gang_brackets   "id=bracket qty=6"    -D 'opening_h=1200' -D 'shelves=[400,800]'
run gang_shims      "shims"               -D 'opening_h=1200' -D 'shelves=[400,800]'
run gang_slide      "tier=1 slide_mm=355.6" -D 'opening_h=900' -D 'shelves=[400]' -D 'keepouts=[[0,400,420,400,200,100]]'
run keep_no_gang    "tier=1 slide_mm=508" -D 'opening_h=900' -D 'shelves=[400]' -D 'keepouts=[[0,400,420,400,200,100]]' -D 'door_mode="keep"'
run gang_setback    "tier=1 rails_mm=.13. front=46" -D 'opening_h=900' -D 'shelves=[400]' -D 'shelf_setback=40'
run printed_tiers   "Tier 1: Floor rail"  -D 'opening_h=900' -D 'shelves=[400]' -D 'rail_type="printed"'
# wide pieces stay short enough to sit above the P1/X1 calibration corner
run corner_split    "Tier 2: Front plate 3/3" -D 'opening_h=900' -D 'shelves=[400]'
# one-sided tiers
run reach_auto      "reach=right"         -D 'door_mode="keep"' -D 'door_opens="only_90"'
run reach_auto_r    "reach=left"          -D 'door_mode="keep"' -D 'door_opens="only_90"' -D 'hinge_side="right"'
run reach_mount     "reach=both"          -D 'door_opens="only_90"'
run reach_one_panel "pullout=1 reach=left panels=1" -D 'reach_from="left"' -D 'panel_count=2'
# no door: nothing to dodge, no brackets, both sides
run door_none       "door=none region"    -D 'door_mode="none"'
run door_none_hinge "hinges=0"            -D 'door_mode="none"' -D 'hinge_side="left"'
run door_none_reach "pullout=1 reach=both" -D 'door_mode="none"' -D 'door_opens="only_90"'
# sides per pull-out: a 90-degree door only blocks its neighbour; a mounted pair faces outward
run side_door_only  "pullout=1 reach=right" -D 'opening_w=480' -D 'door_mode="keep"' -D 'door_opens="only_90"'
run side_open_both  "pullout=2 reach=both"  -D 'opening_w=480' -D 'door_mode="keep"' -D 'door_opens="only_90"'
run side_mount_l    "pullout=1 reach=left"  -D 'opening_w=480'
run side_mount_r    "pullout=2 reach=right" -D 'opening_w=480'
run side_override   "pullout=2 reach=left"  -D 'opening_w=480' -D 'door_mode="keep"' -D 'sides=[[1,2,"left"]]'
run side_auto_entry "pullout=2 reach=both"  -D 'opening_w=480' -D 'door_mode="keep"' -D 'sides=[[1,2,"auto"]]'
run side_labels     "Left pull-out: Base 1/3" -D 'opening_w=480' -D 'door_mode="keep"' -D 'door_opens="only_90"'
run side_columns    "Left pull-outs: Base 1/3" -D 'opening_w=480' -D 'opening_h=900' -D 'shelves=[400]' -D 'door_mode="keep"' -D 'door_opens="only_90"'

rm -rf "$OUT"
exit $fail
