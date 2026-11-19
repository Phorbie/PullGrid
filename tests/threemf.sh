#!/usr/bin/env bash
# Build the Bambu project 3MF the site would build, then check it.
# Usage: tests/threemf.sh <printer id> [extra -D args...]   (needs openscad, node, python3)
cd "$(dirname "$0")/.."
printer=${1:-p1s}; shift
T=$(mktemp -d)
openscad -o "$T/x.echo" -D 'part="none"' "$@" scad/pullgrid.scad >/dev/null 2>&1
grep -o 'PULLGRID part=[^"]*' "$T/x.echo" | sed 's/^PULLGRID //' > "$T/parts.txt"
grep -o 'PULLGRID part_tiers=[^"]*' "$T/x.echo" | sed 's/^PULLGRID //' > "$T/tiers.txt"   # stacked tiers: one file each
while read -r line; do
  i=$(echo "$line" | sed 's/part=\([0-9]*\).*/\1/')
  openscad -o "$T/$i.stl" -D 'part="print"' -D "print_index=$i" "$@" scad/pullgrid.scad >/dev/null 2>&1 &
  while [ "$(jobs -r | wc -l)" -ge 4 ]; do sleep 0.2; done
done < "$T/parts.txt"
wait
mkdir -p "$T/out"
node tests/build3mf.mjs "$T" "$printer" "$T/out"; s=$?
for f in "$T"/out/*.3mf; do python3 tests/threemf_check.py "$f" || s=1; done
[ -n "$KEEP" ] && mkdir -p "$KEEP" && cp "$T"/out/*.3mf "$KEEP"/
rm -rf "$T"; exit $s
