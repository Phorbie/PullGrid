// Build the Bambu project 3MF exactly as the site does, from exported print STLs.
// Usage: node tests/build3mf.mjs <dir with parts.txt and <index>.stl> <printer id> <out dir>
import { readFileSync, writeFileSync, existsSync } from "node:fs";
import { build3mf, PRINTERS } from "../site/threemf.js";

const [dir, printer, out] = process.argv.slice(2);
const parts = readFileSync(`${dir}/parts.txt`, "utf8").trim().split("\n").map((l) => {
  const m = l.match(/part=(\d+) id=(\S+) qty=(\d+) size=\[[^\]]+\] label=(.*)$/);
  return { index: +m[1], id: m[2], qty: +m[3], label: m[4], stl: new Uint8Array(readFileSync(`${dir}/${m[1]}.stl`)) };
});
// per-tier quantities, as the site parses them
if (existsSync(`${dir}/tiers.txt`))
  for (const l of readFileSync(`${dir}/tiers.txt`, "utf8").trim().split("\n").filter(Boolean)) {
    const m = l.match(/^part_tiers=(\d+) qty=\[(.*)\]$/);
    parts.find((p) => p.index === +m[1]).tiers = JSON.parse(`[${m[2]}]`);
  }
const { files, printer: P } = await build3mf(parts, { printer, title: "PullGrid test", description: "test build" });
const counts = parts.map((p) => p.qty);
for (const f of files) {
  writeFileSync(`${out}/${f.name}`, f.bytes);
  // what the checker should expect for this file: instances per object
  const per = new Map();
  for (const pl of f.plates) for (const it of pl.items) per.set(it.part, (per.get(it.part) || 0) + 1);
  const qty = Object.fromEntries([...per.keys()].sort((a, b) => a - b).map((part, k) => [k + 1, per.get(part)]));
  writeFileSync(`${out}/${f.name}.json`, JSON.stringify({ bed: P.bed, excl: P.excl || null, printer: P, qty, plates: f.plates.map((p) => p.name) }));
  console.log(`${f.name}: ${f.plates.length} plates, ${(f.bytes.length / 1e3).toFixed(0)} kB${f.tier ? ` (tier ${f.tier})` : ""}`);
  for (const [i, p] of f.plates.entries()) if (i < 3 || i === f.plates.length - 1) console.log(`  plate ${i + 1}: ${p.name}`);
}
const placed = files.reduce((a, f) => a + f.plates.reduce((b, p) => b + p.items.length, 0), 0);
const want = counts.reduce((a, b) => a + b, 0);
if (placed !== want) { console.error(`placed ${placed} pieces, expected ${want}`); process.exit(1); }
if (!PRINTERS.some((p) => p.id === printer)) { console.error(`unknown printer ${printer}`); process.exit(1); }
