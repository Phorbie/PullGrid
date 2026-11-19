#!/usr/bin/env bash
# Interference check: tests/interference.sh [extra -D args...]
cd "$(dirname "$0")/.."
fail=0
for k in $(seq 0 24); do
  out=$(openscad -o /tmp/pg_int_$k.stl -D 'part="none"' -D "pair=$k" "$@" tests/interference.scad 2>&1)
  name=$(echo "$out" | grep -o 'PAIR [^"]*' | head -1)
  if echo "$out" | grep -q "top level object is empty"; then echo "ok   $name"; continue; fi
  v=$(python3 tests/stlvol.py /tmp/pg_int_$k.stl 2>/dev/null || echo 999)
  # face contact leaves a zero-volume sliver; anything over 1 mm^3 is a real collision
  if python3 -c "import sys; sys.exit(0 if float('$v') < 1 else 1)"; then echo "ok   $name (touching, ${v} mm3)"
  else echo "HIT  $name (${v} mm3)"; fail=1; fi
done
rm -f /tmp/pg_int_*.stl
exit $fail
