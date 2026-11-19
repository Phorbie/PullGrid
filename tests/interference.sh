#!/usr/bin/env bash
# Interference check: tests/interference.sh [extra -D args...]
cd "$(dirname "$0")/.."
T=$(mktemp -d); fail=0
openscad -o "$T/n.echo" -D 'part="none"' "$@" tests/interference.scad >/dev/null 2>&1
n=$(grep -o 'PAIRS [0-9]*' "$T/n.echo" | head -1 | cut -d' ' -f2)
for k in $(seq 0 $((n - 1))); do
  out=$(openscad -o "$T/$k.stl" -D 'part="none"' -D "pair=$k" "$@" tests/interference.scad 2>&1)
  name=$(echo "$out" | grep -o 'PAIR [^"]*' | head -1)
  if echo "$out" | grep -q "top level object is empty"; then echo "ok   $name"; continue; fi
  v=$(python3 tests/stlvol.py "$T/$k.stl" 2>/dev/null || echo 999)
  # face contact leaves a zero-volume sliver; anything over 1 mm^3 is a real collision
  if python3 -c "import sys; sys.exit(0 if float('$v') < 1 else 1)"; then echo "ok   $name (touching, ${v} mm3)"
  else echo "HIT  $name (${v} mm3)"; fail=1; fi
done
rm -rf "$T"
exit $fail
