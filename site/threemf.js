// Bambu Studio / OrcaSlicer project 3MF, built from the print STLs.
//
// What Bambu Studio needs before it loads more than geometry (from its loader,
// src/slic3r/GUI/Plater.cpp and src/libslic3r/Format/bbs_3mf.cpp):
//  - 3D/3dmodel.model metadata Application = "BambuStudio-<version>". We claim
//    2.0.0: newer 2.x apps load it without a "newer file" dialog, and it's past
//    the 1.x/2.0 conversion paths.
//  - Metadata/project_settings.config: a non-empty config with filament_colour.
//    It only NAMES Bambu's system presets and marks nothing as changed
//    (different_settings_to_system), so Studio fills every value from its own
//    presets and selects them unmodified.
//  - Metadata/model_settings.config: object names, per-object overrides (walls,
//    infill) and plates. Studio rebuilds plate membership from world position,
//    so each instance is placed inside its plate's area on Studio's plate grid.
// No geometry is computed here: parts come out of OpenSCAD already oriented
// and split; this only lays the finished pieces out on plates.

import { zipBytes } from "./zip.js";

const APP = "BambuStudio-02.00.00.00";
const PLATE_GAP = 1 / 5;            // PartPlate.cpp LOGICAL_PART_PLATE_GAP
const MARGIN = 3, SPACING = 6;      // mm from the bed edge / between parts
export const MAX_PLATES = 36;       // PartPlate.hpp MAX_PLATE_COUNT: bigger builds become several files

// System preset names, checked against Bambu Studio 2.8.2's profiles.
export const PRINTERS = [
  { id: "a1mini", label: "A1 mini", bed: [180, 180], printer: "Bambu Lab A1 mini 0.4 nozzle", model: "Bambu Lab A1 mini",
    process: "0.20mm Standard @BBL A1M", filament: "Generic PETG @BBL A1M" },
  { id: "a1", label: "A1", bed: [256, 256], printer: "Bambu Lab A1 0.4 nozzle", model: "Bambu Lab A1",
    process: "0.20mm Standard @BBL A1", filament: "Generic PETG @BBL A1" },
  { id: "p1s", label: "P1S / P1P", bed: [256, 256], excl: [18, 28], printer: "Bambu Lab P1S 0.4 nozzle", model: "Bambu Lab P1S",
    process: "0.20mm Standard @BBL X1C", filament: "Generic PETG" },
  { id: "x1c", label: "X1 Carbon / X1E", bed: [256, 256], excl: [18, 28], printer: "Bambu Lab X1 Carbon 0.4 nozzle", model: "Bambu Lab X1 Carbon",
    process: "0.20mm Standard @BBL X1C", filament: "Generic PETG" },
  { id: "p2s", label: "P2S", bed: [256, 256], printer: "Bambu Lab P2S 0.4 nozzle", model: "Bambu Lab P2S",
    process: "0.20mm Standard @BBL P2S", filament: "Generic PETG @BBL P2S" },
  { id: "h2s", label: "H2S / H2D", bed: [340, 320], printer: "Bambu Lab H2S 0.4 nozzle", model: "Bambu Lab H2S",
    process: "0.20mm Standard @BBL H2S", filament: "Generic PETG @BBL H2S" },
];
export const printersForBed = (bed) => PRINTERS.filter((p) => +bed <= Math.min(...p.bed) + 6);
export const defaultPrinter = (bed) => (+bed <= 180 ? "a1mini" : +bed <= 256 ? "p1s" : "h2s");

// print settings per part (docs/printing.md): parts that hold screws get 5 walls
const settings = (kind) => ({
  wall_loops: /^(base|rail)/.test(kind) ? "5" : "4",
  sparse_infill_density: "25%",
  sparse_infill_pattern: "gyroid",
});
const SMALL = new Set(["bracket", "key"]);  // share one plate

// ---------- STL ----------
export function parseStl(u8) {
  const dv = new DataView(u8.buffer, u8.byteOffset, u8.byteLength);
  const n = u8.byteLength >= 84 ? dv.getUint32(80, true) : 0;
  const tri = [];
  if (n > 0 && 84 + n * 50 === u8.byteLength) {           // binary
    for (let i = 0; i < n; i++) {
      const o = 84 + i * 50 + 12;
      for (let v = 0; v < 3; v++) tri.push(dv.getFloat32(o + v * 12, true), dv.getFloat32(o + v * 12 + 4, true), dv.getFloat32(o + v * 12 + 8, true));
    }
  } else {                                                  // ASCII
    const re = /vertex\s+(\S+)\s+(\S+)\s+(\S+)/g, s = new TextDecoder().decode(u8);
    let m;
    while ((m = re.exec(s))) tri.push(+m[1], +m[2], +m[3]);
  }
  return Float64Array.from(tri);
}

// indexed mesh, centred on its footprint and sitting on z = 0
function indexMesh(tri) {
  let mn = [Infinity, Infinity, Infinity], mx = [-Infinity, -Infinity, -Infinity];
  for (let i = 0; i < tri.length; i += 3)
    for (let a = 0; a < 3; a++) { mn[a] = Math.min(mn[a], tri[i + a]); mx[a] = Math.max(mx[a], tri[i + a]); }
  const c = [(mn[0] + mx[0]) / 2, (mn[1] + mx[1]) / 2, mn[2]];
  const map = new Map(), verts = [], faces = [];
  for (let i = 0; i < tri.length; i += 3) {
    const p = [tri[i] - c[0], tri[i + 1] - c[1], tri[i + 2] - c[2]].map((v) => Math.round(v * 1e4) / 1e4);
    const k = p.join(",");
    let id = map.get(k);
    if (id === undefined) { id = verts.length; map.set(k, id); verts.push(p); }
    faces.push(id);
  }
  const tris = [];
  for (let i = 0; i < faces.length; i += 3)
    if (faces[i] !== faces[i + 1] && faces[i + 1] !== faces[i + 2] && faces[i] !== faces[i + 2]) tris.push(faces.slice(i, i + 3));
  return { verts, tris, size: [mx[0] - mn[0], mx[1] - mn[1], mx[2] - mn[2]] };
}

// ---------- plates ----------
// Shelf packing in plate coordinates (0..w, 0..d). Skips the front-left
// calibration corner on printers that have one.
export function packPlates(items, bed, excl) {
  const [W, D] = bed, plates = [];
  const inCorner = (yy) => !!excl && yy < excl[1] + SPACING;
  const rowStart = (yy) => (inCorner(yy) ? excl[0] + SPACING : MARGIN);
  let plate, x, y, rowH;
  const newPlate = () => { plate = []; plates.push(plate); y = MARGIN; rowH = 0; x = rowStart(y); };
  newPlate();
  // tallest first (in 10 mm steps, so near-equal pieces keep their 1/3, 2/3 order)
  const key = (it) => Math.round(it.d / 10);
  for (const it of [...items].sort((a, b) => key(b) - key(a) || a.part - b.part)) {
    if (rowH > 0 && x + it.w > W - MARGIN) { y += rowH + SPACING; rowH = 0; x = rowStart(y); }  // next row
    if (plate.length && y + it.d > D - MARGIN) newPlate();                                      // next plate
    if (rowH === 0 && inCorner(y) && x + it.w > W - MARGIN) {
      // too wide to sit beside the corner: start the row above it, or (if it
      // can't fit there either) overlap the corner and let Studio flag it
      if (excl[1] + SPACING + it.d <= D - MARGIN) y = excl[1] + SPACING;
      x = MARGIN;
    }
    plate.push({ ...it, x, y });
    x += it.w + SPACING;
    rowH = Math.max(rowH, it.d);
  }
  return plates;
}

// Studio's plate grid (PartPlate.hpp compute_colum_count, compute_shape_position)
export function plateOrigin(i, count, bed) {
  const v = Math.sqrt(count), r = Math.round(v), cols = v > r ? r + 1 : r;
  return [(i % cols) * bed[0] * (1 + PLATE_GAP), -Math.floor(i / cols) * bed[1] * (1 + PLATE_GAP)];
}

// ---------- 3MF ----------
const esc = (s) => String(s).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&apos;" })[c]);
const num = (v) => String(Math.round(v * 1e4) / 1e4);
const family = (label) => label.replace(/ \d+\/\d+$/, "");
const kindOf = (p) => p.id.replace(/^t[\d-]+_/, "").replace(/_.*$/, "");   // base, front, rail, toprail, bracket, key

// parts: [{ id, label, qty, stl: Uint8Array }] in report order.
// Returns { plates: [{ name, items: [{ part, x, y, w, d }] }], files: [{ name, data }] }
export function layout3mf(parts, printer) {
  const P = PRINTERS.find((p) => p.id === printer) || PRINTERS[2];
  const meshes = parts.map((p) => indexMesh(parseStl(p.stl)));
  const item = (i) => ({ part: i, w: meshes[i].size[0], d: meshes[i].size[1] });
  const plates = [];
  // plate 1: the test piece from docs/printing.md
  const test = parts.findIndex((p) => /(^|_)base_1$/.test(p.id));
  if (test >= 0) plates.push({ name: "TEST FIRST: one base piece", items: packPlates([item(test)], P.bed, P.excl)[0] });
  // then one family per plate (or several), small parts together at the end
  const groups = new Map();
  parts.forEach((p, i) => {
    // left and right rails print together
    const k = SMALL.has(kindOf(p)) ? "Brackets & keys" : family(p.label).replace(/^(.*Floor rail) (left|right)$/, "$1s");
    if (!groups.has(k)) groups.set(k, []);
    for (let q = 0; q < p.qty - (i === test ? 1 : 0); q++) groups.get(k).push(item(i));
  });
  for (const [k, items] of groups) {
    if (!items.length) continue;
    const packed = packPlates(items, P.bed, P.excl);
    const walls = new Set(items.map((it) => settings(kindOf(parts[it.part])).wall_loops));
    // one piece: its own name ("Base 2/3"); several: the family and a count
    packed.forEach((pl, j) => plates.push({
      name: `${pl.length === 1 ? parts[pl[0].part].label : `${k} ×${pl.length}${packed.length > 1 ? ` (${j + 1}/${packed.length})` : ""}`}` +
            ` · ${[...walls].join("/")} walls`,
      items: pl,
    }));
  }
  return { P, meshes, plates };
}

// One project file per MAX_PLATES plates. Returns { files: [{ name, bytes, plates }], printer }.
export async function build3mf(parts, { printer, title = "PullGrid", description = "", base = "pullgrid" } = {}) {
  const { P, meshes, plates } = layout3mf(parts, printer);
  const chunks = [];
  for (let i = 0; i < plates.length; i += MAX_PLATES) chunks.push(plates.slice(i, i + MAX_PLATES));
  const files = [];
  for (const [n, chunk] of chunks.entries()) {
    const multi = chunks.length > 1, first = n * MAX_PLATES + 1;
    files.push({
      name: multi ? `${base}-plates-${first}-${first + chunk.length - 1}.3mf` : `${base}.3mf`,
      bytes: await project(parts, meshes, chunk, P, multi ? `${title} (${n + 1} of ${chunks.length})` : title, description),
      plates: chunk,
    });
  }
  return { files, printer: P };
}

async function project(parts, meshes, plates, P, title, description) {
  // instances in plate order; only the parts this file places become objects, numbered 1..k
  const inst = parts.map(() => []);
  plates.forEach((pl, pi) => {
    const o = plateOrigin(pi, plates.length, P.bed);
    for (const it of pl.items) inst[it.part].push({ plate: pi, tx: o[0] + it.x + it.w / 2, ty: o[1] + it.y + it.d / 2 });
  });
  const used = parts.map((_, i) => i).filter((i) => inst[i].length);
  const oid = new Map(used.map((i, k) => [i, k + 1]));
  const date = new Date().toISOString().slice(0, 10);
  const model = [
    `<?xml version="1.0" encoding="UTF-8"?>`,
    `<model unit="millimeter" xml:lang="en-US" xmlns="http://schemas.microsoft.com/3dmanufacturing/core/2015/02" xmlns:BambuStudio="http://schemas.bambulab.com/package/2021">`,
    ...[["Application", APP], ["BambuStudio:3mfVersion", "1"], ["Title", title], ["Designer", "PullGrid by Phorbie Designs"],
        ["Description", description], ["License", "CC BY-SA 4.0"], ["Copyright", "PullGrid by Phorbie Designs"],
        ["CreationDate", date], ["ModificationDate", date]]
      .map(([k, v]) => ` <metadata name="${k}">${esc(v)}</metadata>`),
    ` <resources>`,
  ];
  for (const i of used) {
    const m = meshes[i];
    model.push(`  <object id="${oid.get(i)}" name="${esc(parts[i].label)}" type="model">`, `   <mesh>`, `    <vertices>`);
    for (const v of m.verts) model.push(`     <vertex x="${num(v[0])}" y="${num(v[1])}" z="${num(v[2])}"/>`);
    model.push(`    </vertices>`, `    <triangles>`);
    for (const t of m.tris) model.push(`     <triangle v1="${t[0]}" v2="${t[1]}" v3="${t[2]}"/>`);
    model.push(`    </triangles>`, `   </mesh>`, `  </object>`);
  }
  model.push(` </resources>`, ` <build>`);
  for (const i of used) inst[i].forEach((t) =>
    model.push(`  <item objectid="${oid.get(i)}" transform="1 0 0 0 1 0 0 0 1 ${num(t.tx)} ${num(t.ty)} 0" printable="1"/>`));
  model.push(` </build>`, `</model>`);

  const cfg = [`<?xml version="1.0" encoding="UTF-8"?>`, `<config>`];
  for (const i of used) {
    const p = parts[i], meta = { name: p.label, extruder: "1", ...settings(kindOf(p)) };
    cfg.push(`  <object id="${oid.get(i)}">`, ...Object.entries(meta).map(([k, v]) => `    <metadata key="${k}" value="${esc(v)}"/>`),
      `    <part id="${oid.get(i)}" subtype="normal_part">`,
      `      <metadata key="name" value="${esc(p.label)}"/>`,
      `      <metadata key="matrix" value="1 0 0 0 0 1 0 0 0 0 1 0 0 0 0 1"/>`,
      `      <mesh_stat face_count="${meshes[i].tris.length}" edges_fixed="0" degenerate_facets="0" facets_removed="0" facets_reversed="0" backwards_edges="0"/>`,
      `    </part>`, `  </object>`);
  }
  let ident = 100;
  plates.forEach((pl, pi) => {
    cfg.push(`  <plate>`, `    <metadata key="plater_id" value="${pi + 1}"/>`, `    <metadata key="plater_name" value="${esc(pl.name)}"/>`,
      `    <metadata key="locked" value="false"/>`);
    used.forEach((i) => inst[i].forEach((t, k) => {
      if (t.plate === pi) cfg.push(`    <model_instance>`, `      <metadata key="object_id" value="${oid.get(i)}"/>`,
        `      <metadata key="instance_id" value="${k}"/>`, `      <metadata key="identify_id" value="${++ident}"/>`, `    </model_instance>`);
    }));
    cfg.push(`  </plate>`);
  });
  cfg.push(`</config>`);

  const project = {
    name: "project_settings", from: "project", version: APP.slice(12),
    printer_technology: "FFF", printer_model: P.model,
    printer_settings_id: P.printer, print_settings_id: P.process, filament_settings_id: [P.filament],
    inherits_group: ["", "", ""], different_settings_to_system: ["", "", ""],
    nozzle_diameter: ["0.4"], filament_type: ["PETG"], filament_colour: ["#3D7FB0"],
  };

  const files = [
    { name: "[Content_Types].xml", data: `<?xml version="1.0" encoding="UTF-8"?>\n<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">\n <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>\n <Default Extension="model" ContentType="application/vnd.ms-package.3dmanufacturing-3dmodel+xml"/>\n <Default Extension="config" ContentType="text/xml"/>\n</Types>\n` },
    { name: "_rels/.rels", data: `<?xml version="1.0" encoding="UTF-8"?>\n<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\n <Relationship Target="/3D/3dmodel.model" Id="rel-1" Type="http://schemas.microsoft.com/3dmanufacturing/2013/01/3dmodel"/>\n</Relationships>\n` },
    { name: "3D/3dmodel.model", data: model.join("\n") + "\n" },
    { name: "Metadata/model_settings.config", data: cfg.join("\n") + "\n" },
    { name: "Metadata/project_settings.config", data: JSON.stringify(project, null, 4) + "\n" },
  ];
  return zipBytes(files);
}
