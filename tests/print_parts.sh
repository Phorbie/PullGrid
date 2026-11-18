#!/usr/bin/env bash
# Export every print part; check it's non-empty, sits on z=0, and fits the bed.
# Usage: tests/print_parts.sh [extra -D args...]
cd "$(dirname "$0")/.."
OUT=$(mktemp -d); fail=0
list=$(openscad -o "$OUT/x.stl" -D 'part="none"' "$@" scad/pullgrid.scad 2>&1 | grep -o 'PULLGRID part=[^"]*')
bed=$(echo "$@" | grep -o 'bed_size=[0-9]*' | cut -d= -f2); bed=${bed:-256}
while read -r line; do
  [ -z "$line" ] && continue
  i=$(echo "$line" | sed 's/.*part=\([0-9]*\).*/\1/'); id=$(echo "$line" | sed 's/.* id=\([^ ]*\).*/\1/')
  openscad -o "$OUT/$i.stl" -D 'part="print"' -D "print_index=$i" "$@" scad/pullgrid.scad >/dev/null 2>&1
  python3 - "$OUT/$i.stl" "$id" "$bed" <<'PY' || fail=1
import sys; sys.path.insert(0, "tests"); from stlvol import tris, vol
path, pid, bed = sys.argv[1], sys.argv[2], float(sys.argv[3])
t = tris(path); pts = [p for tr in t for p in tr]
if not pts: print(f"FAIL {pid}: empty"); sys.exit(1)
mn = [min(p[a] for p in pts) for a in range(3)]; mx = [max(p[a] for p in pts) for a in range(3)]
size = [mx[a] - mn[a] for a in range(3)]
ok = abs(mn[2]) < 0.01 and size[0] <= bed and size[1] <= bed
print(f"{'ok  ' if ok else 'FAIL'} {pid:14s} {size[0]:6.1f} x {size[1]:6.1f} x {size[2]:5.1f} mm  {vol(path)/1000:6.1f} cm3")
sys.exit(0 if ok else 1)
PY
done <<< "$list"
rm -rf "$OUT"; exit $fail
