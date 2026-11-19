// PullGrid generator UI. Geometry lives in scad/ — this file only collects
// inputs, asks the workers to render, and displays what comes back.
import * as THREE from "three";
import { OrbitControls } from "./vendor/three/OrbitControls.js";
import { STLLoader } from "./vendor/three/STLLoader.js";
import { zipBytes } from "./zip.js";
import { build3mf, printersForBed, defaultPrinter } from "./threemf.js";

const MM = 25.4;
const DEFAULTS = {
  unit: "in",
  opening_w: 11 * MM, opening_h: 24 * MM, interior_depth: 22 * MM,
  frame_type: "face_frame", hinge_side: "left",
  door_mode: "mount", door_thickness: 19, door_overlay: 12.7, face_frame_thickness: null,
  region: null, rail_type: "angle", clear_front: null,
  offset_left: null, offset_right: null, offset_bottom: null, offset_top: null,
  rear_w: null, rear_h: null, door_intrusion: 0,
  hinges: [], keepouts: [], shelves: [], shelf_thickness: 19, shelf_setback: 0,
  door_opens: "past_90", sides: {}, printer: null,
  handle: "slot", handle_dir: "horizontal", handle_pos: "top", handle_across: "center", handle_count: "auto", handle_size: null,
  panel_count: 1, panel_thickness: "6.8", pullouts: null, bed_size: "256",
  slide_t: 13, slide_h: 45,
  clear_side: 3, clear_top: 5, clear_rear: 10,
};
const DODGE = {
  left: "narrowed the frame from the left",
  right: "narrowed the frame from the right",
  bottom: "raised the frame's floor",
  top: "lowered the frame's top",
  back: "shortened the frame from the back",
};
// preview parts: [name, moves with the slide?]
const PREVIEW = [["carriage", true], ["boards", true], ["slides_moving", true], ["door", true],
                 ["rails", false], ["slides_fixed", false], ["cabinet", false], ["keepouts", false]];
// printed pieces in place, seams and keys showing: rendered only when the view asks for them
const PIECES = [["pieces", true], ["rail_pieces", false]];
const DOCS = "docs/";
const HANDLE_NAME = { slot: "finger slot", bar: "printed bar handle", arch: "printed arch handle", knob: "printed knob", pull: "store-bought pull" };
const PETG = 1.27, FILL = 0.45;  // g/cm³, rough share of solid volume at typical walls/infill

const $ = (s, el = document) => el.querySelector(s);
const $$ = (s, el = document) => [...el.querySelectorAll(s)];
const clone = (o) => JSON.parse(JSON.stringify(o));
const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]);
const cap = (s) => s[0].toUpperCase() + s.slice(1);

// ---------- state ----------
// inch hardware in the US and Canada, metric in the rest of the English-speaking world
function autoRegion() {
  for (const l of navigator.languages || [navigator.language || "en-US"]) {
    const r = (l.split("-")[1] || "").toUpperCase();
    if (["US", "CA"].includes(r)) return "inch";
    if (["GB", "UK", "IE", "AU", "NZ", "ZA"].includes(r)) return "metric";
  }
  return "inch";
}
let state = loadState();
if (!state.region) {
  state.region = autoRegion();
  let saved = false;
  try { saved = !!localStorage.getItem("pullgrid"); } catch {}
  if (!saved && state.region === "metric") state.unit = "mm";  // metric markets measure in mm
}
const bad = new Set();
let report = null;
let lastDefines = null;
let meshVolume = 0;
let firstFit = true;

function loadState() {
  try {
    if (location.hash.length > 1) return { ...clone(DEFAULTS), ...JSON.parse(decodeURIComponent(location.hash.slice(1))) };
  } catch {}
  try {
    const s = localStorage.getItem("pullgrid");
    if (s) return { ...clone(DEFAULTS), ...JSON.parse(s) };
  } catch {}
  return clone(DEFAULTS);
}
function saveState() {
  try { localStorage.setItem("pullgrid", JSON.stringify(state)); } catch {}
  // a shared link is a starting point; once edited, stop reloading it
  if (location.hash) history.replaceState(null, "", location.pathname + location.search);
}

// ---------- units ----------
function parseLen(raw, unit) {
  let s = raw.trim().toLowerCase();
  if (!s) return { empty: true };
  let u = unit;
  const m = s.match(/(mm|in|")\s*$/);
  if (m) { u = m[1] === "mm" ? "mm" : "in"; s = s.slice(0, m.index).trim(); }
  const r = s.match(/^(?:(\d+(?:\.\d+)?|\.\d+)(?:[\s-]+(\d+)\/(\d+))?|(\d+)\/(\d+))$/);
  if (!r) return { bad: true };
  const v = r[4] ? +r[4] / +r[5] : +r[1] + (r[2] ? +r[2] / +r[3] : 0);
  if (!isFinite(v)) return { bad: true };
  return { mm: u === "in" ? v * MM : v };
}
const gcd = (a, b) => (b ? gcd(b, a % b) : a);
function formatLen(mm, unit = state.unit) {
  if (mm == null) return "";
  if (unit === "mm") return String(Math.round(mm * 10) / 10);
  const s = Math.round((mm / MM) * 16);
  const whole = Math.floor(s / 16), f = s % 16;
  if (!f) return String(whole);
  const g = gcd(f, 16), frac = `${f / g}/${16 / g}`;
  return whole ? `${whole} ${frac}` : frac;
}
const fmt = (mm, unit = state.unit) => formatLen(mm, unit) + (unit === "in" ? "″" : " mm");
const alt = (mm) => fmt(mm, state.unit === "in" ? "mm" : "in");

// ---------- form ----------
const form = $("#form");

function fillForm() {
  for (const el of $$("input[data-key]", form)) {
    const k = el.dataset.key, kind = el.dataset.kind;
    el.value = kind === "len" ? formatLen(state[k]) : String(state[k] ?? "");
    if (el.hasAttribute("data-auto")) el.placeholder = el.dataset.auto || "auto";
    el.classList.remove("bad");
  }
  for (const seg of $$(".seg[data-key]", form))
    for (const b of $$("button", seg)) b.classList.toggle("on", b.dataset.v === String(state[seg.dataset.key]));
  for (const b of $$(".units button")) b.classList.toggle("on", b.dataset.unit === state.unit);
  bad.clear();
  buildRows();
  applyShow();
}
// elements tagged data-show="key=value" only appear when the state matches
function applyShow() {
  for (const el of $$("[data-show]")) {
    const [k, v] = el.dataset.show.split("=");
    el.hidden = !v.split("|").includes(String(state[k]));
  }
}

form.addEventListener("input", (e) => {
  const el = e.target;
  if (el.dataset.key) readField(el);
  else if (el.dataset.row != null) readRow(el);
  else return;
  changed();
});

function readField(el) {
  const k = el.dataset.key, kind = el.dataset.kind, auto = el.hasAttribute("data-auto");
  let ok = true;
  if (kind === "len") {
    const p = parseLen(el.value, state.unit);
    if (p.empty && auto) state[k] = null;
    else if (p.mm != null && p.mm >= 0) state[k] = p.mm;
    else ok = false;
  } else if (kind === "int") {
    if (!el.value.trim() && auto) state[k] = null;
    else {
      const n = parseInt(el.value, 10);
      ok = Number.isInteger(n) && n >= +el.dataset.min && n <= +el.dataset.max;
      if (ok) state[k] = n;
    }
  }
  mark(el, k, ok);
}
function mark(el, key, ok) {
  el.classList.toggle("bad", !ok);
  ok ? bad.delete(key) : bad.add(key);
}

form.addEventListener("click", (e) => {
  const b = e.target.closest(".seg[data-key] button");   // per pull-out sides have their own handler
  if (!b) return;
  const seg = b.parentElement;
  state[seg.dataset.key] = b.dataset.v;
  for (const x of $$("button", seg)) x.classList.toggle("on", x === b);
  applyShow();
  changed();
});

// hinge + keep-out rows
const HF = [["z", "Center height"], ["intrusion", "Sticks in"]];
const KF = [["x", "X"], ["y", "Y"], ["z", "Z"], ["w", "Width"], ["d", "Depth"], ["h", "Height"]];
const SF = [["z", "Shelf top, from the floor"]];

function rowInput(list, i, f, label) {
  return `<div><label>${label}</label><input data-row="${i}" data-list="${list}" data-f="${f}" value="${formatLen(state[list][i][f])}" inputmode="decimal"></div>`;
}
function buildRows() {
  $("#hinges").innerHTML = state.hinges.map((h, i) =>
    `<div class="row h">${HF.map(([f, l]) => rowInput("hinges", i, f, l)).join("")}<button type="button" class="x" data-del="hinges" data-i="${i}" aria-label="Remove hinge">×</button></div>`).join("");
  $("#shelves").innerHTML = state.shelves.map((h, i) =>
    `<div class="row s">${SF.map(([f, l]) => rowInput("shelves", i, f, l)).join("")}<button type="button" class="x" data-del="shelves" data-i="${i}" aria-label="Remove shelf">×</button></div>`).join("");
  $("#keepouts").innerHTML = state.keepouts.map((k, i) =>
    `<div class="kgroup"><div class="row k">${KF.slice(0, 3).map(([f, l]) => rowInput("keepouts", i, f, "Position " + l)).join("")}<button type="button" class="x" data-del="keepouts" data-i="${i}" aria-label="Remove keep-out">×</button></div>
     <div class="row k">${KF.slice(3).map(([f, l]) => rowInput("keepouts", i, f, l)).join("")}<span></span></div></div>`).join("");
  hingeHint();
}
function readRow(el) {
  const p = parseLen(el.value, state.unit), key = `${el.dataset.list}${el.dataset.row}${el.dataset.f}`;
  const ok = p.mm != null;
  if (ok) state[el.dataset.list][+el.dataset.row][el.dataset.f] = p.mm;
  mark(el, key, ok);
}
form.addEventListener("click", (e) => {
  const d = e.target.closest("[data-del]");
  if (!d) return;
  state[d.dataset.del].splice(+d.dataset.i, 1);
  for (const k of [...bad]) if (k.startsWith(d.dataset.del)) bad.delete(k);
  buildRows();
  changed();
});
$("#add-hinge").onclick = () => {
  state.hinges.push({ z: state.opening_h / 2, intrusion: 12 });
  buildRows(); changed();
};
$("#add-shelf").onclick = () => {
  // next one up: halfway between the last shelf and the top, or mid-height
  const top = Math.max(0, ...state.shelves.map((s) => s.z));
  state.shelves.push({ z: Math.round(top ? (top + state.opening_h) / 2 : state.opening_h / 2) });
  buildRows(); changed();
};
$("#add-keepout").onclick = () => {
  state.keepouts.push({ x: 0, y: Math.max(0, state.interior_depth - 80), z: 0, w: 100, d: 60, h: 150 });
  buildRows(); changed();
};
function hingeHint() {
  const n = report?.hinges;
  $("#hinge-hint").textContent = state.hinges.length
    ? "Custom hinges. Remove them all to go back to auto."
    : `Blank = auto${n != null ? ` (${n} standard hinge${n === 1 ? "" : "s"})` : ""}. Height is from the interior floor.`;
}

for (const b of $$(".units button")) b.onclick = () => { state.unit = b.dataset.unit; fillForm(); showReport(); saveState(); };
$("#reset").onclick = () => { state = { ...clone(DEFAULTS), unit: state.unit }; firstFit = true; fillForm(); changed(); };
$("#share").onclick = async (e) => {
  const url = `${location.origin}${location.pathname}#${encodeURIComponent(JSON.stringify(state))}`;
  history.replaceState(null, "", url);
  let msg = "Link in address bar";
  try { await navigator.clipboard.writeText(url); msg = "Copied!"; } catch {}
  e.target.textContent = msg;
  setTimeout(() => (e.target.textContent = "Copy link"), 1600);
};

// ---------- workers ----------
const POOL = Array.from({ length: Math.min(3, Math.max(1, (navigator.hardwareConcurrency || 2) - 1)) },
  () => new Worker("./worker.js", { type: "module" }));
let msgId = 0;
const pending = new Map();
for (const w of POOL) {
  w.onmessage = (e) => { const p = pending.get(e.data.id); pending.delete(e.data.id); e.data.ok ? p.resolve(e.data.out) : p.reject(new Error(e.data.error)); };
  w.onerror = (e) => setStatus("bad", `Couldn't start OpenSCAD: ${e.message || "worker error"}`);
}
function runOn(w, defines, parts) {
  return new Promise((resolve, reject) => {
    const id = ++msgId;
    pending.set(id, { resolve, reject });
    w.postMessage({ id, defines, parts });
  });
}
// spread parts over the pool, merge results
async function renderParts(defines, parts) {
  const buckets = POOL.map(() => []);
  parts.forEach((p, i) => buckets[i % POOL.length].push(p));
  const outs = await Promise.all(buckets.map((b, i) => (b.length ? runOn(POOL[i], defines, b) : {})));
  return Object.assign({}, ...outs);
}

// ---------- render pipeline ----------
let inflight = false, queued = null, debounce = 0;
const r2 = (v) => Math.round(v * 100) / 100;
const L = (v) => (v == null ? -1 : r2(v));
function defines(s) {
  return {
    opening_w: L(s.opening_w), opening_h: L(s.opening_h), interior_depth: L(s.interior_depth),
    frame_type: `"${s.frame_type}"`, hinge_side: `"${s.hinge_side}"`,
    offset_left: L(s.offset_left), offset_right: L(s.offset_right),
    offset_bottom: L(s.offset_bottom), offset_top: L(s.offset_top),
    rear_w: L(s.rear_w), rear_h: L(s.rear_h), door_intrusion: L(s.door_intrusion),
    hinges: `[${s.hinges.map((h) => `[${r2(h.z)},${r2(h.intrusion)},50,45]`).join(",")}]`,
    keepouts: `[${s.keepouts.map((k) => `[${[k.x, k.y, k.z, k.w, k.d, k.h].map(r2).join(",")}]`).join(",")}]`,
    shelves: `[${s.shelves.map((h) => r2(h.z)).join(",")}]`,
    shelf_thickness: L(s.shelf_thickness), shelf_setback: L(s.shelf_setback),
    door_opens: `"${s.door_opens}"`, reach_from: '"auto"',
    // per pull-out overrides: { "tier.position": "both" | "left" | "right" }
    sides: `[${Object.entries(s.sides || {}).filter(([, v]) => v !== "auto").map(([k, v]) => `[${k.split(".").map(Number).join(",")},"${v}"]`).join(",")}]`,
    panel_count: s.panel_count, panel_thickness: s.panel_thickness,
    pullouts: s.pullouts == null ? -1 : s.pullouts, bed_size: s.bed_size,
    door_mode: `"${s.door_mode}"`, door_thickness: L(s.door_thickness), door_overlay: L(s.door_overlay),
    face_frame_thickness: L(s.face_frame_thickness), region: `"${s.region}"`, rail_type: `"${s.rail_type}"`,
    clear_front: L(s.clear_front),
    handle: `"${s.handle}"`, handle_dir: `"${s.handle_dir}"`, handle_pos: `"${s.handle_pos}"`, handle_across: `"${s.handle_across}"`,
    handle_count: s.handle_count === "auto" ? -1 : +s.handle_count, handle_size: L(s.handle_size),
    slide_t: L(s.slide_t), slide_h: L(s.slide_h),
    clear_side: L(s.clear_side), clear_top: L(s.clear_top), clear_rear: L(s.clear_rear),
  };
}

function changed() {
  saveState();
  if (bad.size) { setStatus("bad", "Fix the highlighted fields"); return; }
  clearTimeout(debounce);
  debounce = setTimeout(requestRender, 250);
}
function requestRender() {
  const d = defines(state);
  if (inflight) { queued = d; return; }
  run(d);
}
async function run(d) {
  inflight = true;
  $("#busy").hidden = false;
  try {
    const out = await renderParts(d, [...PREVIEW.map((p) => p[0]), ...piecesWanted()]);
    if (!queued) apply(d, out);
  } catch (err) {
    setStatus("bad", `Render failed: ${err.message}`);
  }
  inflight = false;
  if (queued) { const q = queued; queued = null; run(q); } else $("#busy").hidden = true;
}
function apply(d, out) {
  report = parseReport(out.carriage.log);
  lastDefines = d;
  meshVolume = 0;
  (report.door === "mount" ? moving : scene).add(groups.door);  // a kept door stays put; "none" renders nothing
  for (const [name] of PREVIEW) {
    const v = setPart(name, report.fits ? out[name].stl : name === "cabinet" || name === "keepouts" ? out[name].stl : null);
    if (name === "carriage" || name === "rails") meshVolume += v;
  }
  piecesFor = null;
  if (out.pieces) setPieces(d, out);
  else for (const [name] of PIECES) setPart(name, null);
  unitExt = {};
  buildHandles();
  applyExtension();
  applyView();
  if (firstFit) { fitView(); firstFit = false; }
  showReport();
  hingeHint();
}

function parseReport(log) {
  const r = { keepouts: [], errors: [], warnings: [], scadErrors: [], parts: [], hw: [], cuts: [], tiers: [] };
  for (const line of log) {
    if (/^ERROR:/.test(line)) r.scadErrors.push(line);
    const m = line.match(/PULLGRID (.*?)"?$/);
    if (!m) continue;
    let t = m[1], x, T = r;
    // tier header: "tier=2 floor=400 envelope_mm=[...]" or "tier=3 floor=800 skipped height=30"
    if ((x = t.match(/^tier=(\d+) floor=([\d.]+) (?:envelope_mm=\[([^\]]+)\]|skipped height=(\d+))/))) {
      const tr = { n: +x[1], floor: +x[2] };
      if (x[3]) tr.env = x[3].split(",").map(Number); else tr.skipped = +x[4];
      r.tiers[tr.n - 1] = tr;
      continue;
    }
    // every other per-tier line: "tier=<n> key=..."
    if ((x = t.match(/^tier=(\d+) (.*)$/))) { T = r.tiers[+x[1] - 1] || (r.tiers[+x[1] - 1] = { n: +x[1] }); t = x[2]; }
    if ((x = t.match(/^slide_mm=([\d.]+)/))) T.slide = +x[1];
    else if ((x = t.match(/^panel_cells=\[(\d+), (\d+)\] x(\d+)/))) T.cells = [+x[1], +x[2], +x[3]];
    else if ((x = t.match(/^pullouts=(\d+)/))) T.pullouts = +x[1];
    else if ((x = t.match(/^carriage_mm=\[([^\]]+)\]/))) T.carriage = x[1].split(",").map(Number);
    else if ((x = t.match(/^rails_mm=\[([^\]]*)\] front=([\d.]+) spacing=([\d.]+)/)))
      T.rails = { xs: x[1].split(",").map(Number), front: +x[2], spacing: +x[3] };
    else if ((x = t.match(/^boards_y=\[([^\]]*)\] boards_z=\[([^\]]*)\] type=(\w+)/)))
      T.boards = { y: x[1].split(",").map(Number), z: x[2].split(",").map(Number), type: x[3] };
    else if ((x = t.match(/^bracket_mm=([\d.]+)/))) T.bracket = +x[1];
    else if ((x = t.match(/^pullout=(\d+) reach=(\w+) panels=(\d+)(?: box=\[([^\]]+)\] grid=\[([^\]]+)\])?/)))
      (T.units ||= [])[+x[1] - 1] = { p: +x[1], reach: x[2], panels: +x[3],
        box: x[4] && x[4].split(",").map(Number), grid: x[5] && x[5].split(",").map(Number) };
    else if ((x = t.match(/^tiers=(\d+)/))) r.nTiers = +x[1];
    else if ((x = t.match(/^part=(\d+) id=(\S+) qty=(\d+) size=\[([^\]]+)\] label=(.*)$/)))
      r.parts.push({ index: +x[1], id: x[2], qty: +x[3], size: x[4].split(",").map(Number), label: x[5] });
    else if ((x = t.match(/^part_tiers=(\d+) qty=\[(.*)\]$/))) (r.partTiers ||= {})[x[1]] = JSON.parse(`[${x[2]}]`);
    else if ((x = t.match(/^hw=(\d+) item=(.*)$/))) r.hw.push({ qty: +x[1], item: x[2] });
    else if ((x = t.match(/^cut=(\d+) len=([\d.]+) item=(.*)$/))) r.cuts.push({ qty: +x[1], len: +x[2], item: x[3] });
    else if ((x = t.match(/^door=(\w+) region=(\w+) rails=(\w+)(?: reach=(\w+))?/)))
      Object.assign(r, { door: x[1], region: x[2], railType: x[3], reachSetting: x[4] || "auto" });
    else if ((x = t.match(/^keepout=(\d+) dodged_by=(\w+) label=(.*)$/))) r.keepouts.push({ by: x[2], label: x[3] });
    else if ((x = t.match(/^hinges=(\d+)/))) r.hinges = +x[1];
    else if ((x = t.match(/^handle=(\w+) dir=(\w+) total=(\d+) size=([\d.]+) depth=([\d.]+)/)))
      r.handle = { shape: x[1], dir: x[2], total: +x[3], size: +x[4], depth: +x[5] };
    else if (t.startsWith("ERROR")) r.errors.push(t.slice(6));
    else if (t.startsWith("WARNING")) r.warnings.push(t.slice(8));
  }
  r.tiers = r.tiers.filter(Boolean);
  r.ok = r.tiers.filter((t) => t.env);
  r.units = r.ok.flatMap((t) => (t.units || []).map((u) => ({ ...u, t: t.n, N: t.units.length })));
  r.oneSided = r.units.some((u) => u.reach !== "both");
  // the first usable tier stands in for "the pull-out" (slider travel, file names)
  Object.assign(r, { env: r.ok[0]?.env, slide: r.ok[0]?.slide, carriage: r.ok[0]?.carriage, pullouts: r.ok[0]?.pullouts });
  r.fits = r.ok.length > 0 && !r.errors.includes("no_fit") && !r.scadErrors.length;
  return r;
}

// ---------- report ----------
function setStatus(kind, text) {
  const s = $("#status");
  s.className = `status ${kind}`;
  s.textContent = text;
}
const inch = (s) => s.replace(/(\d+)in\b/g, "$1″");
const spell = (s) => (report?.region === "metric" ? s.replace(/aluminum/g, "aluminium") : s);
function showReport() {
  const dl = $("#facts"), ul = $("#tradeoffs"), build = $("#build");
  if (!report) return;
  dl.innerHTML = ""; ul.innerHTML = "";
  build.hidden = !report.fits;
  if (report.scadErrors.length) { setStatus("bad", "OpenSCAD error"); ul.innerHTML = report.scadErrors.map((e) => `<li>${esc(e)}</li>`).join(""); return; }
  if (!report.fits) {
    setStatus("bad", "Doesn't fit");
    ul.innerHTML = `<li>After hinges, rails, slides and clearances there's no room for a pull-out with at least one openGrid cell. Check the opening and hinge settings.</li>`;
    return;
  }
  const [w, d, h] = report.env, W = report.warnings;
  if (W.includes("angle_too_short")) setStatus("warn", "Fits, but the bottom rail is tall enough that aluminum angle won't reach the slides. Switch to printed rails.");
  else if (W.includes("door_too_thin")) setStatus("warn", "Fits, but that door is too thin for the bracket screws. Keep it hinged, or check the screw length.");
  else if (W.includes("too_narrow")) setStatus("warn", "Fits, but the pull-out is narrow: room for slim items only");
  else if (W.includes("no_standard_slide_fits")) setStatus("warn", "Fits, but it's shallower than the shortest standard slide (10″)");
  else if (W.includes("handle_hits_door")) setStatus("warn", "Fits, but the handles won't clear the closed door. Set Front clearance back to auto.");
  else if (W.includes("handle_blocked")) setStatus("warn", "Fits, but there's no room for every handle. Try a smaller size, another height, or fewer.");
  else if (W.some((x) => x.startsWith("part_exceeds_bed"))) setStatus("warn", "Fits, but some parts are bigger than your print bed");
  else setStatus("good", "Fits");
  const row = (k, v, a = "") => `<dt>${k}</dt><dd>${v}${a ? `<span class="alt">${a}</span>` : ""}</dd>`;
  const size = (c) => `${fmt(c[0])} W × ${fmt(c[1])} D × ${fmt(c[2])} H`;
  const slides = (t) => (!t.slide ? "" : report.region === "metric" ? `${t.slide} mm slides` : `${Math.round(t.slide / MM)}″ slides`);
  const tierName = (t) => `Tier ${t.n}${t.floor ? ` <span class="hint">on the shelf at ${fmt(t.floor)}</span>` : report.tiers.length > 1 ? ` <span class="hint">floor</span>` : ""}`;
  const c = report.carriage, n = report.pullouts, T = report.tiers;
  let html = "";
  if (T.length === 1) {
    html = row("Usable space", `${fmt(w)} W × ${fmt(d)} D × ${fmt(h)} H`) +
      (c ? row(n > 1 ? `${n} pull-outs, each` : "Pull-out", size(c)) : "") +
      (report.slide ? (report.region === "metric" ? row("Slides", `${report.slide} mm full-extension`)
        : row("Slides", `${Math.round(report.slide / MM)}″ full-extension`, `${report.slide} mm`)) : "") +
      (report.ok[0].cells ? row("openGrid", `${report.ok[0].cells[2]} panel${report.ok[0].cells[2] > 1 ? "s" : ""}${n > 1 ? " per pull-out" : ""}, ${report.ok[0].cells[0]} × ${report.ok[0].cells[1]} cells`, `${fmt(report.ok[0].cells[0] * 28)} × ${fmt(report.ok[0].cells[1] * 28)}`) : "");
  } else {
    // one row per tier, bottom up
    html = T.map((t) => t.env
      ? row(tierName(t), `${t.pullouts > 1 ? `${t.pullouts} × ` : ""}${size(t.carriage)}`,
            [slides(t), t.cells ? `${t.cells[0]} × ${t.cells[1]} cells` : ""].filter(Boolean).join(" · "))
      : row(tierName(t), `<span class="hint">left empty: only ${fmt(t.skipped)} tall</span>`)).join("");
  }
  if (report.oneSided)
    html += row("Reach", report.units.length === 1 ? `from the ${report.units[0].reach} only`
      : report.units.filter((u) => u.reach !== "both").map((u) => `${unitName(u, report)}: ${u.reach} only`).join("<br>"),
      "one panel against the blocked side, accessories face you");
  html += report.door === "mount"
    ? row("Door", report.ok.length > 1 ? `mounted on all ${report.ok.length} tiers` : "mounted on the pull-out",
          report.ok[0]?.bracket ? `brackets ${fmt(report.ok[0].bracket)} deep` : "")
    : report.door === "none" ? row("Door", "none", "the front plate is the face")
    : row("Hinges", state.hinges.length ? `${state.hinges.length} custom` : state.hinge_side === "none" ? "none" : `${report.hinges} auto`);
  const hd = report.handle;
  if (report.door !== "mount")
    html += row("Handles", !hd || !hd.total ? "none" : `${hd.total} ${HANDLE_NAME[hd.shape]}${hd.total > 1 ? "s" : ""}`,
      !hd || !hd.total ? "" : [hd.shape === "knob" ? `${fmt(hd.size)} across` : hd.shape === "slot" ? `${fmt(hd.size)} long` : `${fmt(hd.size)} screw spacing`,
                             hd.depth ? `sticks out ${fmt(hd.depth)}` : ""].filter(Boolean).join(" · "));
  dl.innerHTML = html;
  showSides();
  ul.innerHTML = report.keepouts.map((k) => `<li><strong>${esc(cap(k.label))}</strong>: ${DODGE[k.by] || k.by}</li>`).join("") +
    (W.includes("handle_moved") ? "<li><strong>Handles</strong>: moved a little to clear a board groove or a plate seam</li>" : "");
  showBuild();
}

// "Pull-out", "Left pull-out", "Tier 2 left", matching the part labels
function unitName(u, r) {
  const K = r.tiers.length, side = u.N === 2 ? (u.p === 1 ? "left" : "right") : `pull-out ${u.p}`;
  if (u.N === 1) return K > 1 ? `Tier ${u.t}` : "Pull-out";
  return K > 1 ? `Tier ${u.t} ${side}` : u.N === 2 ? `${cap(side)} pull-out` : cap(side);
}
const SIDE_OPTS = [["auto", "Auto"], ["both", "Both"], ["left", "Left only"], ["right", "Right only"]];
function showSides() {
  const el = $("#sides");
  if (!report?.units?.length) return;
  el.innerHTML = report.units.map((u) => {
    const key = `${u.t}.${u.p}`, cur = state.sides[key] || "auto";
    const got = u.reach === "both" ? "both sides" : `${u.reach} side only`;
    return `<div class="srow"><b>${esc(unitName(u, report))}</b><div class="seg">` +
      SIDE_OPTS.map(([v, l]) => `<button type="button" data-side="${key}" data-v="${v}"${v === cur ? ' class="on"' : ""}>${l}</button>`).join("") +
      `</div>${cur === "auto" ? `<small>Auto: ${got}</small>` : ""}</div>`;
  }).join("");
}
$("#sides").addEventListener("click", (e) => {
  const b = e.target.closest("button[data-side]");
  if (!b) return;
  if (b.dataset.v === "auto") delete state.sides[b.dataset.side]; else state.sides[b.dataset.side] = b.dataset.v;
  showSides(); changed();
});

function showBuild() {
  const r = report, n = r.pullouts || 1;
  fillPrinters();
  // parts
  // group split pieces into families: "Base 1/3", "Base 2/3" → Base, 3 pieces
  const fam = new Map();
  for (const p of r.parts) {
    const k = p.label.replace(/ \d+\/\d+$/, "");
    if (!fam.has(k)) fam.set(k, []);
    fam.get(k).push(p);
  }
  const keys = r.parts.filter((p) => p.id === "key").reduce((a, p) => a + p.qty, 0);
  const pieces = r.parts.filter((p) => p.id !== "key").reduce((a, p) => a + p.qty, 0);
  const kg = (meshVolume / 1000) * PETG * FILL / 1000;
  $("#print-sum").textContent = `${pieces} pieces${keys ? ` + ${keys} keys` : ""} · roughly ${kg >= 1 ? kg.toFixed(1) + " kg" : Math.round(kg * 1000) + " g"} of PETG`;
  $("#parts").innerHTML = [...fam].map(([k, ps]) => {
    const q = ps[0].qty, big = ps.reduce((m, p) => (p.size[1] > m.size[1] ? p : m), ps[0]);
    const what = ps.length > 1 ? `${esc(k)} <span class="hint">in ${ps.length} pieces</span>` : esc(k);
    const btns = ps.map((p, i) => `<button type="button" data-part="${p.index}" title="${esc(p.label)}">${ps.length > 1 ? i + 1 : ".stl"}</button>`).join(" ");
    return `<tr><td class="n">${q}×</td><td>${what}</td><td class="sz">${fmt(big.size[0])} × ${fmt(big.size[1])}</td><td class="btns">${btns}</td></tr>`;
  }).join("");
  // boards: every tier's panels, grouped by layout
  const lay = new Map();
  for (const t of r.ok) {
    if (!t.boards) continue;
    const k = `${t.boards.y}|${t.boards.z}`;
    if (!lay.has(k)) lay.set(k, { b: t.boards, tiers: [], panels: 0 });
    const L = lay.get(k);
    L.tiers.push(t.n); L.panels += t.units ? t.units.reduce((a, u) => a + u.panels, 0) : (t.cells?.[2] || 1) * (t.pullouts || 1);
  }
  if (lay.size) {
    const counts = {}, type = r.ok[0].boards.type, cell = 5;
    let total = 0, html = "";
    for (const { b, tiers, panels } of lay.values()) {
      for (const y of b.y) for (const z of b.z) counts[`${y} × ${z}`] = (counts[`${y} × ${z}`] || 0) + panels;
      total += b.y.length * b.z.length * panels;
      const grid = `<div class="bgrid" style="grid-template-columns:${b.y.map((y) => y * cell + "px").join(" ")};grid-template-rows:${[...b.z].reverse().map((z) => z * cell + "px").join(" ")}">` +
        [...b.z].reverse().map((z) => b.y.map((y) => `<span>${y}×${z}</span>`).join("")).join("") + "</div>";
      html += (lay.size > 1 ? `<p class="hint">${tiers.length > 1 ? "Tiers" : "Tier"} ${tiers.join(", ")}: ${panels} panel${panels > 1 ? "s" : ""}</p>` : "") + grid;
    }
    const panels = [...lay.values()].reduce((a, l) => a + l.panels, 0);
    const lite = r.oneSided && type === "full"
      ? (r.units.every((u) => u.reach !== "both") ? " Accessories only go on one side, so Lite boards would do."
         : " The one-sided pull-outs only use one face, so Lite boards would do for those.") : "";
    $("#boards").innerHTML =
      `<p>${total} ${type === "full" ? "Full" : "Lite"} boards for ${panels} panel${panels > 1 ? "s" : ""}. Sizes in cells, wide × tall (front-to-back × up).${lite}</p>` +
      html + `<ul class="hw">${Object.entries(counts).map(([k, v]) => `<li><b>${v}×</b> ${k} cells</li>`).join("")}<li>openGrid connector pegs for the board seams</li></ul>`;
  }
  // hardware + cuts
  $("#hw").innerHTML = r.hw.map((h) => `<li><b>${h.qty}×</b> ${esc(inch(h.item))}</li>`).join("");
  const cutLen = (mm) => (r.region === "metric" ? `${Math.round(mm)} mm` : `${formatLen(mm, "in")}″ (${Math.round(mm)} mm)`);
  $("#cut").innerHTML = r.cuts.map((c) => `<li><b>${c.qty}×</b> ${esc(spell(c.item))} at ${cutLen(c.len)}</li>`).join("") ||
    "<li>Nothing to cut.</li>";
  // install
  const mount = r.door === "mount", angle = r.railType === "angle", tiers = r.ok.length > 1;
  const where = (t) => {
    const rl = t.rails;
    if (!rl) return "";
    return `${fmt(rl.spacing)} apart (inside faces)${rl.xs.length === 1 ? `, the left one ${fmt(rl.xs[0])} from the cabinet's left wall` : `, left rails at ${rl.xs.map((x) => fmt(x)).join(", ")} from the left wall`}, front ends ${fmt(rl.front)} behind the opening`;
  };
  const place = tiers
    ? `<ul>${r.ok.map((t) => `<li>Tier ${t.n} (${t.floor ? `shelf at ${fmt(t.floor)}` : "floor"}): ${where(t)}</li>`).join("")}</ul>`
    : `${where(r.ok[0])}.`;
  $("#steps").innerHTML = [
    "Check the cabinet is fixed to the wall or its neighbours. A loaded pull-out at full extension puts its weight out front.",
    // clear the cabinet first: mount and no-door builds are sized as if the hinge hardware were gone
    mount ? "Take the door off its hinges and set it somewhere flat. Unscrew the hinge plates from the cabinet, and any catches or bumpers: the pull-out uses that space."
      : r.door === "none" ? "If the cabinet still has hinge plates, catches or bumpers from an old door, unscrew them: the pull-out uses that space."
      : "Leave the door on. Open it as far as it goes while you work.",
    "Glue the plate pieces together with the bowtie keys on the inside face. Let them cure.",
    !mount && ["bar", "arch", "knob"].includes(r.handle?.shape) && r.handle.total
      ? `Screw the ${r.handle.shape === "knob" ? "knobs" : "handles"} to the front plate from the inside, one screw into each post. Snug, not tight.` : "",
    !mount && r.handle?.shape === "pull" && r.handle.total
      ? "Bolt the pulls to the front plate from the inside with the short machine screws (not the ones in the pull's bag)." : "",
    `Cut the tie rods${angle ? " and the aluminum angle" : ""} (see Cut). File the ends smooth.`,
    "Unclip each slide. Screw the inner members to the base cheeks, front ends flush with the front of the base.",
    "Stand the front and rear plates against the base. Push the two bottom rods through, add washers and nuts.",
    "Slide the openGrid boards down into the grooves. Set the top rails on, push their rods through, then snug every nut. Don't crush the plastic.",
    mount ? "Screw the door brackets to the front plate from the inside, in the middle of their slots." : "",
    angle ? `Screw the outer slide members to the upright leg of each angle, front ends flush. Set the angles ${place}`
          : `Screw the outer slide members to the floor rails. Set the rails ${place}`,
    `Clip the carriage on to check it runs straight. Mark the rails, unclip the carriage, ${angle ? "drill the inward leg and " : ""}screw the rails to the floor${tiers ? " or shelf" : ""}.`,
    mount && tiers ? "Every tier's front ends must be the same distance behind the opening. Push all the tiers in and check their front plates line up with a straightedge before you screw the last rails down." : "",
    mount ? `Stick double-sided tape on the bracket faces and clip ${tiers ? "every tier" : "the carriage"} in. Push it closed, hold the door in place with even gaps all round (coins make good spacers) and press it onto the tape.` : "",
    mount ? "Pull out gently, unscrew the brackets from the plate (they stay taped to the door), screw them to the door, then screw them back to the plate. The slots let you fine-tune height and side-to-side." : "",
    mount && tiers ? "If one tier sits back from the door, put washers between its brackets and the plate until it touches." : "",
    !r.oneSided ? "Snap openGrid accessories onto both sides."
      : r.units.length === 1 ? `Snap openGrid accessories onto the ${r.units[0].reach} side of the panel.`
      : `Snap openGrid accessories on: ${r.units.map((u) => `${unitName(u, r).toLowerCase()} ${u.reach === "both" ? "both sides" : `${u.reach} side`}`).join(", ")}.`,
  ].filter(Boolean).map((s) => `<li>${spell(s)}</li>`).join("");
}

// ---------- downloads ----------
function save(blob, name) {
  const a = document.createElement("a");
  a.href = URL.createObjectURL(blob);
  a.download = name;
  a.click();
  setTimeout(() => URL.revokeObjectURL(a.href), 4000);
}
const slug = () => { const c = report.carriage.map(Math.round); return `pullgrid-${c[0]}x${c[1]}x${c[2]}`; };

$("#parts").addEventListener("click", async (e) => {
  const b = e.target.closest("[data-part]");
  if (!b || !lastDefines) return;
  const p = report.parts.find((x) => x.index === +b.dataset.part);
  const label = b.textContent;
  b.textContent = "…";
  const out = await renderParts(lastDefines, [`print:${p.index}`]);
  b.textContent = label;
  save(new Blob([out[`print:${p.index}`].stl], { type: "model/stl" }), `${slug()}-${p.id}.stl`);
});

// every print part, rendered once per settings
let printCache = null;
async function renderPrints() {
  const key = JSON.stringify(lastDefines);
  if (printCache?.key === key) return printCache.out;
  const out = await renderParts(lastDefines, report.parts.map((p) => `print:${p.index}`));
  printCache = { key, out };
  return out;
}
const printerId = () => state.printer && printersForBed(state.bed_size).some((p) => p.id === state.printer) ? state.printer
  : state.printer === "none" ? "none" : defaultPrinter(state.bed_size);
async function projectFiles(out) {
  if (printerId() === "none") return [];
  const parts = report.parts.map((p) => ({ ...p, tiers: report.partTiers?.[p.index], stl: out[`print:${p.index}`].stl }));
  const { files } = await build3mf(parts, {
    printer: printerId(), base: slug(),
    title: `PullGrid ${report.carriage.map((v) => Math.round(v)).join(" x ")} mm`,
    description: "PullGrid by Phorbie Designs. Print plate 1 first and test-fit it (https://phorbie.github.io/PullGrid/docs/printing.html#test-print-first). Settings: PETG or PETG-GF, 0.2 mm layers; walls and infill are set per part.",
  });
  return files;
}
function fillPrinters() {
  const sel = $("#printer"), list = printersForBed(state.bed_size), cur = printerId();
  sel.innerHTML = list.map((p) => `<option value="${p.id}">Bambu ${esc(p.label)}</option>`).join("") + `<option value="none">Other printer (STLs only)</option>`;
  sel.value = cur;
  $("#download3mf").hidden = cur === "none";
}
$("#printer").onchange = (e) => { state.printer = e.target.value; saveState(); fillPrinters(); };

$("#download").onclick = async () => {
  if (!report?.fits || !lastDefines) return;
  const btn = $("#download"), st = $("#dl-status"), parts = report.parts;
  btn.disabled = true;
  st.textContent = `Rendering ${parts.length} parts…`;
  try {
    const out = await renderPrints();
    const files = parts.map((p, i) => ({
      name: `${String(i + 1).padStart(2, "0")}-${p.id}-x${p.qty}.stl`,
      data: out[`print:${p.index}`].stl,
    }));
    const projects = await projectFiles(out);
    for (const f of projects) files.push({ name: f.name, data: f.bytes });
    files.push({ name: "README.txt", data: new TextEncoder().encode(readme(projects)) });
    save(new Blob([await zipBytes(files)], { type: "application/zip" }), `${slug()}.zip`);
    st.textContent = `Downloaded ${parts.length} parts${projects.length ? ` and ${projects.length > 1 ? `${projects.length} Bambu Studio projects` : "a Bambu Studio project"}` : ""}. Quantities are in the file names.`;
  } catch (err) {
    st.textContent = `Download failed: ${err.message}`;
  }
  btn.disabled = false;
};

$("#download3mf").onclick = async () => {
  if (!report?.fits || !lastDefines) return;
  const btn = $("#download3mf"), st = $("#dl-status"), label = btn.textContent;
  btn.disabled = true;
  st.textContent = `Rendering ${report.parts.length} parts…`;
  try {
    const files = await projectFiles(await renderPrints());
    if (files.length === 1) save(new Blob([files[0].bytes], { type: "model/3mf" }), files[0].name);
    else save(new Blob([await zipBytes(files.map((f) => ({ name: f.name, data: f.bytes })), { compress: false })], { type: "application/zip" }), `${slug()}-bambu.zip`);
    const n = files.reduce((a, f) => a + f.plates.length, 0);
    const perTier = files.some((f) => f.tier);
    st.textContent = files.length === 1 ? `Bambu Studio project: ${n} plates. Print plate 1 first.`
      : perTier ? `${n} plates: one project per tier. Print plate 1 of ${files[0].name} first.`
      : `${n} plates in ${files.length} projects (Bambu Studio allows 36 per project). Print plate 1 of the first one first.`;
  } catch (err) {
    st.textContent = `Download failed: ${err.message}`;
  }
  btn.disabled = false;
  btn.textContent = label;
};

function readme(projects = []) {
  const r = report, txt = (el) => $$("li", el).map((li) => "- " + li.textContent).join("\n");
  return [
    "PullGrid by Phorbie Designs — CC BY-SA 4.0",
    "https://phorbie.github.io/PullGrid/",
    "Docs: https://phorbie.github.io/PullGrid/docs/",
    "",
    `Settings link: ${location.origin}${location.pathname}#${encodeURIComponent(JSON.stringify(state))}`,
    "",
    ...(projects.length ? [
      "BAMBU STUDIO / ORCASLICER",
      projects.some((f) => f.tier)
        ? `One project per tier: ${projects.map((f) => f.name).join(", ")}. Every part is laid out on plates with walls and infill set per part.`
        : `Open ${projects.map((f) => f.name).join(", then ")}: every part is laid out on plates with walls and infill set per part.`,
      `Print plate 1 of ${projects[0].name} (one base piece) first and test-fit it: https://phorbie.github.io/PullGrid/docs/printing.html#test-print-first`,
      "Your printer isn't the one in the file? Pick yours in the printer list; the plates and per-part settings carry over.",
      ""] : []),
    "PRINT (quantity is in each file name, e.g. -x2)",
    "PETG or PETG-GF. 4 walls, 25% gyroid. Base and any printed rails: 5 walls (they hold screws).",
    "Plates print face-down, top rails cap-down. Everything is already oriented.",
    ...r.parts.map((p) => `- ${p.qty}x ${p.label}  (${p.size[0]} x ${p.size[1]} x ${p.size[2]} mm)`),
    "",
    "OPENGRID BOARDS (print from openGrid's own files)",
    $("#boards p")?.textContent || "",
    txt($("#boards")),
    "",
    "BUY  (what to look for: https://phorbie.github.io/PullGrid/docs/hardware.html)",
    txt($("#hw")),
    "",
    "CUT",
    txt($("#cut")),
    "",
    "INSTALL  (with pictures: https://phorbie.github.io/PullGrid/docs/assembly.html)",
    $$("#steps > li").map((li, i) => `${i + 1}. ${li.textContent}`).join("\n"),
    "",
  ].join("\n");
}

// ---------- 3D view (scad coordinates: x across, y depth, z up) ----------
const viewer = $("#viewer");
const renderer = new THREE.WebGLRenderer({ antialias: true });
renderer.setPixelRatio(Math.min(devicePixelRatio, 2));
viewer.prepend(renderer.domElement);
const scene = new THREE.Scene();
scene.background = new THREE.Color(0xe9e4d8);
const camera = new THREE.PerspectiveCamera(35, 1, 1, 50000);
camera.up.set(0, 0, 1);
const controls = new OrbitControls(camera, renderer.domElement);
controls.enableDamping = true;
scene.add(new THREE.HemisphereLight(0xffffff, 0xa89a80, 1.8));
const sun = new THREE.DirectionalLight(0xffffff, 1.5);
sun.position.set(-700, -1200, 1500);
scene.add(sun);
const grid = new THREE.GridHelper(4000, 40, 0xc9c0ad, 0xd8d0bf);
grid.rotation.x = Math.PI / 2;
grid.position.z = -4;
scene.add(grid);

const loader = new STLLoader();
const moving = new THREE.Group();
scene.add(moving);
const groups = {};
for (const [name, moves] of [...PREVIEW, ...PIECES]) { groups[name] = new THREE.Group(); (moves ? moving : scene).add(groups[name]); }
const std = (color, extra = {}) => new THREE.MeshStandardMaterial({ color, roughness: 0.6, ...extra });
const ghost = { transparent: true, depthWrite: false };
const mats = {
  carriage: std(0x2f6d9c), boards: std(0xd6d2c8, { roughness: 0.8 }),
  slides_moving: std(0x9aa0a6, { metalness: 0.5, roughness: 0.4 }), slides_fixed: std(0x9aa0a6, { metalness: 0.5, roughness: 0.4 }),
  rails: std(0x4c5866), cabinet: std(0xc9a77a, { ...ghost, opacity: 0.2, roughness: 0.9, side: THREE.DoubleSide }),
  keepouts: std(0xc8324f, { ...ghost, opacity: 0.6 }),
  door: std(0xc8a676, { ...ghost, opacity: 0.55, roughness: 0.8 }),
  pieces: std(0xffffff, { vertexColors: true, roughness: 0.55 }), rail_pieces: std(0xffffff, { vertexColors: true, roughness: 0.55 }),
};
const edgeColor = { door: 0x8a6d48, carriage: 0x163650, boards: 0x9a9488, slides_moving: 0x5f6368, slides_fixed: 0x5f6368, rails: 0x252c33, cabinet: 0x8a6d48, keepouts: 0x8e1c33,
                    pieces: 0x163650, rail_pieces: 0x252c33 };

function stlVolume(geo) {  // cm³·1000 = mm³; signed tetrahedra
  const p = geo.attributes.position.array;
  let v = 0;
  for (let i = 0; i < p.length; i += 9)
    v += (p[i] * (p[i + 4] * p[i + 8] - p[i + 5] * p[i + 7]) - p[i + 1] * (p[i + 3] * p[i + 8] - p[i + 5] * p[i + 6]) + p[i + 2] * (p[i + 3] * p[i + 7] - p[i + 4] * p[i + 6])) / 6;
  return Math.abs(v);
}
// ---------- view controls (display only: nothing here changes the model) ----------
const CAT = { carriage: "printed", rails: "printed", pieces: "printed", rail_pieces: "printed", boards: "boards",
              slides_moving: "hardware", slides_fixed: "hardware", door: "door", cabinet: "cabinet", keepouts: "keepouts" };
const SPLIT = new Set(["carriage", "rails", "boards", "slides_moving", "slides_fixed", "pieces", "rail_pieces"]);   // one mesh per pull-out
const view = (() => {
  const d = { show: { printed: true, boards: true, hardware: true, door: true, cabinet: true, keepouts: true },
              printed: "solid", boards: "plain", handles: "on" };
  try {
    const v = JSON.parse(localStorage.getItem("pullgrid-view"));
    if (v) {
      const o = { ...d, ...v, show: { ...d.show, ...v.show } };
      if (o.printed === "outline") o.printed = "pieces";   // earlier names
      if (o.boards === "grid") o.boards = "opengrid";
      delete o.hidden;
      return o;
    }
  } catch {}
  return d;
})();
const saveView = () => { try { localStorage.setItem("pullgrid-view", JSON.stringify(view)); } catch {} };

const ACCENT = 0xe0662d;
const lineMat = (color, opacity = 1) => new THREE.LineBasicMaterial({ color, transparent: opacity < 1, opacity });
const lineSolid = Object.fromEntries(Object.entries(edgeColor).map(([k, c]) => [k, lineMat(c, k === "cabinet" ? 0.55 : 1)]));
const look = {
  hlPrinted: std(ACCENT, { roughness: 0.5 }), hlLine: lineMat(0x8a3510),
  dim: std(0xb9b4a8, { ...ghost, opacity: 0.16 }), dimLine: lineMat(0x9a9488, 0.25),
  xray: std(0x2f6d9c, { ...ghost, opacity: 0.1 }), xrayLine: lineMat(ACCENT),
};
// Board looks, drawn on the board faces from where the model says openGrid's
// cells start (object coordinates = cabinet, pull-out closed). Looks only:
// the frame is grooved for openGrid. Patterns, from each system's public numbers:
//   openGrid    28 mm square cells
//   hex         Honeycomb Storage Wall: 20 mm hexes on a 23.6 mm pitch
//   SKÅDIS      5 x 15 mm slots on a 40 mm grid, plus the same grid shifted 20 / 20
//   Multiboard  25 mm grid: octagonal multiholes, small peg holes between them
const LOOKS = { opengrid: 0, hex: 1, skadis: 2, multiboard: 3 };
const LOOK_GLSL = `
  vec2 q = vObj.yz - uOrigin;
  float f = 1.0;
#if LOOK == 0
  vec2 d = abs(fract(q / 28.0) - 0.5);
  float e = max(d.x, d.y);
  f = e < 0.3 ? 0.58 : (e > 0.47 ? 0.82 : 1.0);
#elif LOOK == 1
  vec2 s = vec2(23.6, 40.876);
  vec2 a = mod(q, s) - 0.5 * s, b = mod(q - 0.5 * s, s) - 0.5 * s;
  vec2 h = abs(dot(a, a) < dot(b, b) ? a : b);
  float m = max(h.x, 0.5 * h.x + 0.8660254 * h.y);
  f = m < 10.0 ? 0.55 : (m < 11.0 ? 0.86 : 1.0);
#elif LOOK == 2
  vec2 a = mod(q, 40.0) - 20.0, b = mod(q + 20.0, 40.0) - 20.0;
  float sd = min(length(vec2(abs(a.x), max(abs(a.y) - 5.0, 0.0))), length(vec2(abs(b.x), max(abs(b.y) - 5.0, 0.0)))) - 2.5;
  f = sd < 0.0 ? 0.5 : (sd < 0.9 ? 0.86 : 1.0);
#else
  vec2 d = abs(mod(q, 25.0) - 12.5);
  float o = max(max(d.x, d.y), (d.x + d.y) * 0.7071068);
  float pg = length(vec2(12.5) - d);
  f = (o < 10.5 || pg < 3.2) ? 0.55 : ((o < 11.4 || pg < 4.0) ? 0.86 : 1.0);
#endif
  diffuseColor.rgb *= f;`;
function lookMat(origin, kind) {
  const m = std(0xd6d2c8, { roughness: 0.8 });
  m.onBeforeCompile = (sh) => {
    sh.uniforms.uOrigin = { value: new THREE.Vector2(origin[0], origin[1]) };
    sh.vertexShader = sh.vertexShader.replace("#include <common>", "#include <common>\nvarying vec3 vObj;\nvarying vec3 vObjN;")
      .replace("#include <begin_vertex>", "#include <begin_vertex>\nvObj = position;\nvObjN = normal;");
    sh.fragmentShader = `#define LOOK ${LOOKS[kind]}\n` + sh.fragmentShader
      .replace("#include <common>", "#include <common>\nvarying vec3 vObj;\nvarying vec3 vObjN;\nuniform vec2 uOrigin;")
      .replace("#include <color_fragment>", `#include <color_fragment>\n  if (abs(vObjN.x) > 0.5) {${LOOK_GLSL}\n  }`);
  };
  m.customProgramCacheKey = () => `pullgrid-look-${kind}`;
  return m;
}

// Pieces view: colour each separate body so neighbours differ; bowtie keys in the accent.
const PIECE_SHADES = [0x2f6d9c, 0x5b97c4, 0x1f4f75, 0x4a86b3, 0x3a5f80, 0x7aaed3].map((c) => new THREE.Color(c).toArray());
const KEY_SHADE = new THREE.Color(ACCENT).toArray();
function colorPieces(geo) {
  const p = geo.attributes.position.array, n = p.length / 3;
  const parent = new Int32Array(n);
  for (let i = 0; i < n; i++) parent[i] = i;
  const find = (a) => { while (parent[a] !== a) { parent[a] = parent[parent[a]]; a = parent[a]; } return a; };
  const join = (a, b) => { a = find(a); b = find(b); if (a !== b) parent[b] = a; };
  const seen = new Map();   // weld shared corners
  for (let i = 0; i < n; i++) {
    const k = `${Math.round(p[3 * i] * 50)},${Math.round(p[3 * i + 1] * 50)},${Math.round(p[3 * i + 2] * 50)}`;
    const f = seen.get(k);
    if (f === undefined) seen.set(k, i); else join(f, i);
  }
  for (let t = 0; t < n; t += 3) { join(t, t + 1); join(t, t + 2); }
  const comps = new Map();
  for (let i = 0; i < n; i++) {
    const r = find(i);
    let c = comps.get(r);
    if (!c) comps.set(r, (c = { lo: [Infinity, Infinity, Infinity], hi: [-Infinity, -Infinity, -Infinity], shade: -1 }));
    for (let a = 0; a < 3; a++) { const v = p[3 * i + a]; if (v < c.lo[a]) c.lo[a] = v; if (v > c.hi[a]) c.hi[a] = v; }
  }
  const list = [...comps.values()];
  for (const c of list) {
    const d = [0, 1, 2].map((a) => c.hi[a] - c.lo[a]).sort((x, y) => x - y);
    c.key = d[0] < 4 && d[2] < 32;   // a bowtie key: 28 x 12 x 3 mm
  }
  const near = (a, b) => [0, 1, 2].every((k) => a.lo[k] <= b.hi[k] + 2 && b.lo[k] <= a.hi[k] + 2);
  for (const c of list) {
    if (c.key) continue;
    const used = new Set(list.filter((o) => o !== c && o.shade >= 0 && near(c, o)).map((o) => o.shade));
    while (used.has(++c.shade));
  }
  const col = new Float32Array(n * 3);
  for (let i = 0; i < n; i++) {
    const c = comps.get(find(i));
    col.set(c.key ? KEY_SHADE : PIECE_SHADES[c.shade % PIECE_SHADES.length], 3 * i);
  }
  geo.setAttribute("color", new THREE.BufferAttribute(col, 3));
}

// split one rendered part into a mesh per pull-out, by the boxes the model reports
function splitByUnit(geo, units) {
  const p = geo.attributes.position.array, idx = units.map(() => []), rest = [];
  for (let i = 0; i < p.length; i += 9) {
    const x = (p[i] + p[i + 3] + p[i + 6]) / 3, z = (p[i + 2] + p[i + 5] + p[i + 8]) / 3;
    let k = -1;
    for (let j = 0; j < units.length && k < 0; j++) {
      const b = units[j].box;
      if (x >= b[0] - 1 && x <= b[1] + 1 && z >= b[2] - 1 && z <= b[3] + 1) k = j;
    }
    (k >= 0 ? idx[k] : rest).push(i);
  }
  const make = (list) => {
    const a = new Float32Array(list.length * 9);
    list.forEach((i, n) => a.set(p.subarray(i, i + 9), n * 9));
    const g = new THREE.BufferGeometry();
    g.setAttribute("position", new THREE.BufferAttribute(a, 3));
    return g;
  };
  const out = units.map((u, j) => (idx[j].length ? { geo: make(idx[j]), unit: `${u.t}.${u.p}`, grid: u.grid } : null)).filter(Boolean);
  if (rest.length) out.push({ geo: make(rest), unit: null, grid: units[0].grid });
  geo.dispose();
  return out;
}

function setPart(name, stl) {
  const g = groups[name];
  for (const c of g.children) { c.geometry.dispose(); for (const m of Object.values(c.userData.looks || {})) m.dispose(); }
  g.clear();
  if (!stl || stl.byteLength < 134) return 0;
  const geo = loader.parse(stl.buffer.slice(stl.byteOffset, stl.byteOffset + stl.byteLength));
  const vol = stlVolume(geo);
  const units = report?.units || [];
  const pieces = SPLIT.has(name) && units.length && units.every((u) => u.box)
    ? splitByUnit(geo, units) : [{ geo, unit: null, grid: units[0]?.grid }];
  for (const pc of pieces) {
    pc.geo.computeVertexNormals();
    if (name === "pieces" || name === "rail_pieces") colorPieces(pc.geo);
    const mesh = new THREE.Mesh(pc.geo, mats[name]);
    const line = new THREE.LineSegments(new THREE.EdgesGeometry(pc.geo, 25), lineSolid[name]);
    mesh.userData = { name, unit: pc.unit, grid: name === "boards" ? pc.grid : null, looks: {} };
    line.userData = { name, unit: pc.unit, line: true };
    const order = { keepouts: 2, cabinet: 3, door: 4 }[name];
    if (order) mesh.renderOrder = line.renderOrder = order;
    g.add(mesh, line);
  }
  return vol;
}

// materials and visibility from the view settings
function applyView() {
  const pieces = view.printed === "pieces" && piecesFor === lastDefines;
  const has = (n) => groups[n].children.length > 0;
  for (const [name, grp] of Object.entries(groups)) {
    const cat = CAT[name], printed = cat === "printed", ghosted = name === "cabinet" || name === "keepouts";
    // in Pieces, the pieces stand in for the whole printed parts they're cut from
    const swapped = pieces && ((name === "carriage" && has("pieces")) || (name === "rails" && has("rail_pieces")));
    grp.visible = view.show[cat] !== false && !swapped && (pieces || (name !== "pieces" && name !== "rail_pieces"));
    const mode = view.printed === "pieces" ? "solid" : view.printed;
    for (const o of grp.children) {
      const u = o.userData;
      if (u.line) {
        o.material = mode === "highlight" ? (printed ? look.hlLine : ghosted ? lineSolid[name] : look.dimLine) : lineSolid[name];
      } else {
        let base = mats[name];
        if (name === "boards" && view.boards !== "plain" && u.grid) base = u.looks[view.boards] ||= lookMat(u.grid, view.boards);
        o.material = mode === "highlight" ? (printed ? look.hlPrinted : ghosted ? mats[name] : look.dim) : base;
      }
    }
  }
  handles.visible = tracks.visible = view.handles !== "off";
  for (const b of $$(".legend button[data-cat]")) {
    const on = view.show[b.dataset.cat] !== false;
    b.classList.toggle("off", !on);
    b.setAttribute("aria-pressed", on);
  }
  for (const seg of $$("#viewpanel .seg[data-view]"))
    for (const b of $$("button", seg)) b.classList.toggle("on", b.dataset.v === view[seg.dataset.view]);
  if (view.printed === "pieces" && piecesFor !== lastDefines && report?.fits) loadPieces();
}
$(".legend").addEventListener("click", (e) => {
  const b = e.target.closest("button[data-cat]");
  if (!b) return;
  view.show[b.dataset.cat] = view.show[b.dataset.cat] === false;
  saveView(); applyView();
});
$("#viewpanel").addEventListener("click", (e) => {
  const b = e.target.closest("button");
  const seg = b?.closest(".seg[data-view]");
  if (!seg) return;
  view[seg.dataset.view] = b.dataset.v;
  saveView(); applyView();
});
$("#view-toggle").onclick = () => {
  const p = $("#viewpanel");
  p.hidden = !p.hidden;
  $("#view-toggle").setAttribute("aria-expanded", !p.hidden);
};

// pieces: rendered on demand, then kept until the model changes
let piecesFor = null, piecesBusy = null;
const piecesWanted = () => (view.printed === "pieces" ? PIECES.map((p) => p[0]).filter((n) => n !== "rail_pieces" || state.rail_type === "printed") : []);
function setPieces(d, out) {
  for (const [name] of PIECES) setPart(name, out[name]?.stl || null);
  piecesFor = d;
}
async function loadPieces() {
  const d = lastDefines;
  if (piecesBusy === d) return;
  piecesBusy = d;
  $("#busy").hidden = false;
  try {
    const out = await renderParts(d, piecesWanted());
    if (d === lastDefines) { setPieces(d, out); applyExtension(); applyView(); }
  } catch (err) {
    setStatus("bad", `Render failed: ${err.message}`);
  }
  piecesBusy = null;
  if (!inflight) $("#busy").hidden = true;
}

// ---------- pulling out: the slider moves them all; a handle moves one ----------
const ext = $("#extension");
let unitExt = {};   // "tier.pullout" -> 0..1, once a handle has moved it
const ganged = () => report?.door === "mount";   // a mounted door carries every pull-out at once
const travelOf = (unit) => (unit && report?.ok?.find((t) => t.n === +unit.split(".")[0])?.slide) || report?.slide || report?.carriage?.[1] || 0;
const extOf = (unit) => (!unit || ganged() ? +ext.value / 100 : unitExt[unit] ?? +ext.value / 100);
function applyExtension() {
  for (const grp of moving.children)
    for (const o of grp.children) o.position.y = -extOf(o.userData.unit) * travelOf(o.userData.unit);
  for (const h of handles.children) h.position.y = h.userData.y0 - extOf(h.userData.unit) * travelOf(h.userData.unit);
}
ext.oninput = () => { unitExt = {}; applyExtension(); };

// Drag arrows are viewer controls, not parts: drawn in their own pass on top of
// everything, a constant size on screen, floating over each pull-out's top
// front edge. While one is hot, a dashed line shows its travel.
const overlayScene = new THREE.Scene();
overlayScene.add(new THREE.HemisphereLight(0xffffff, 0x9a8a70, 2.0));
const osun = new THREE.DirectionalLight(0xffffff, 1.4);
osun.position.set(-700, -1200, 1500);
overlayScene.add(osun);
const handles = new THREE.Group(), tracks = new THREE.Group();
overlayScene.add(handles, tracks);
const handleMat = new THREE.MeshLambertMaterial({ color: ACCENT, emissive: 0x3a1200 });
const handleHot = new THREE.MeshLambertMaterial({ color: 0xff9a5e, emissive: 0x6a2800 });
const trackMat = new THREE.LineDashedMaterial({ color: ACCENT, dashSize: 12, gapSize: 8 });
const GIZMO = {   // a ball on a shaft: big arrowhead out (pull), small one back (push); unit size, scaled per frame
  ball: new THREE.SphereGeometry(0.75, 24, 16),
  shaft: new THREE.CylinderGeometry(0.2, 0.2, 3.2, 12).translate(0, -0.1, 0),
  out: new THREE.ConeGeometry(0.62, 1.2, 24).rotateZ(Math.PI).translate(0, -2.2, 0),
  back: new THREE.ConeGeometry(0.42, 0.8, 24).translate(0, 1.9, 0),
};
function closedBox(objs) {
  const b = new THREE.Box3();
  for (const o of objs) if (o.isMesh) { o.geometry.computeBoundingBox(); b.union(o.geometry.boundingBox); }
  return b;
}
function addHandle(b, unit) {
  if (b.isEmpty()) return;
  const h = new THREE.Group(), y0 = b.min.y, x = (b.min.x + b.max.x) / 2, z = b.max.z + 45;
  for (const geo of Object.values(GIZMO)) {
    h.add(new THREE.Mesh(geo, handleMat));
  }
  h.position.set(x, y0, z);
  h.userData = { unit, y0 };
  handles.add(h);
  const line = new THREE.Line(new THREE.BufferGeometry().setFromPoints([new THREE.Vector3(x, y0, z), new THREE.Vector3(x, y0 - travelOf(unit), z)]), trackMat);
  line.computeLineDistances();
  line.visible = false;
  line.userData = { unit };
  tracks.add(line);
}
function buildHandles() {
  handles.clear();
  for (const t of tracks.children) t.geometry.dispose();
  tracks.clear();
  hot = null;
  if (!report?.fits) return;
  if (ganged()) { addHandle(closedBox(groups.door.children.length ? groups.door.children : groups.carriage.children), null); return; }
  for (const u of report.units) {
    const k = `${u.t}.${u.p}`;
    addHandle(closedBox(groups.carriage.children.filter((o) => o.userData.unit === k)), k);
  }
}
const _gp = new THREE.Vector3();
function sizeHandles() {   // ~same size on screen at any zoom
  for (const h of handles.children) {
    h.getWorldPosition(_gp);
    h.scale.setScalar(camera.position.distanceTo(_gp) * 0.0125 * (h === hot ? 1.18 : 1));
  }
}

const ray = new THREE.Raycaster(), ndc = new THREE.Vector2();
let drag = null, hot = null;
function aim(e) {
  const r = renderer.domElement.getBoundingClientRect();
  ndc.set(((e.clientX - r.left) / r.width) * 2 - 1, -((e.clientY - r.top) / r.height) * 2 + 1);
  ray.setFromCamera(ndc, camera);
}
function handleAt(e) {
  if (!handles.visible || !handles.children.length) return null;
  aim(e);
  const hit = ray.intersectObjects(handles.children, true)[0];
  if (!hit) return null;
  let h = hit.object;
  while (h.parent !== handles) h = h.parent;
  return { h, point: hit.point };
}
function setHot(h) {
  if (h === hot) return;
  for (const o of [hot, h]) if (o) for (const m of o.children) m.material = o === h ? handleHot : handleMat;
  hot = h;
  for (const t of tracks.children) t.visible = !!h && t.userData.unit === h.userData.unit;
  if (!drag) renderer.domElement.style.cursor = h ? "grab" : "";
}
// grab before OrbitControls sees the press (capture on the parent), then drag along the slide
viewer.addEventListener("pointerdown", (e) => {
  if (e.button !== 0 || e.target !== renderer.domElement) return;
  const hit = handleAt(e);
  if (!hit) return;
  e.stopPropagation();
  e.preventDefault();
  const n = camera.getWorldDirection(new THREE.Vector3()).setY(0);   // a plane holding the slide axis, facing the camera
  if (n.lengthSq() < 1e-6) n.set(0, 0, 1);
  drag = { h: hit.h, unit: hit.h.userData.unit, y: hit.point.y, e0: extOf(hit.h.userData.unit), id: e.pointerId,
           plane: new THREE.Plane().setFromNormalAndCoplanarPoint(n.normalize(), hit.point) };
  setHot(hit.h);
  renderer.domElement.setPointerCapture(e.pointerId);
  renderer.domElement.style.cursor = "grabbing";
}, true);
renderer.domElement.addEventListener("pointermove", (e) => {
  if (!drag) { if (e.pointerType === "mouse" && !e.buttons) setHot(handleAt(e)?.h || null); return; }
  if (e.pointerId !== drag.id) return;
  aim(e);
  const p = ray.ray.intersectPlane(drag.plane, new THREE.Vector3());
  const travel = travelOf(drag.unit);
  if (!p || !travel) return;
  const v = Math.min(1, Math.max(0, drag.e0 - (p.y - drag.y) / travel));
  if (drag.unit && !ganged()) unitExt[drag.unit] = v;
  else { ext.value = v * 100; unitExt = {}; }
  applyExtension();
});
const endDrag = (e) => {
  if (!drag || e.pointerId !== drag.id) return;
  drag = null;
  if (e.pointerType !== "mouse") setHot(null);
  renderer.domElement.style.cursor = hot ? "grab" : "";
};
renderer.domElement.addEventListener("pointerup", endDrag);
renderer.domElement.addEventListener("pointercancel", endDrag);
renderer.domElement.addEventListener("pointerleave", () => { if (!drag) setHot(null); });

function fitView() {
  // frame it all: the cabinet plus the pull-outs closed and at full travel
  const box = new THREE.Box3().setFromObject(groups.cabinet);
  const fb = closedBox(moving.children.flatMap((g) => g.children));
  if (!fb.isEmpty()) {
    box.union(fb);
    box.union(fb.clone().translate(new THREE.Vector3(0, -travelOf(null) - 40, 0)));
  }
  if (box.isEmpty()) return;
  const c = box.getCenter(new THREE.Vector3()), size = box.getSize(new THREE.Vector3());
  const dist = Math.max(size.x, size.y, size.z) * 2.6;
  camera.position.copy(c).add(new THREE.Vector3(-0.6, -1.25, 0.7).normalize().multiplyScalar(dist));
  controls.target.copy(c);
  controls.update();
}
$("#view-reset").onclick = fitView;

new ResizeObserver(() => {
  const { clientWidth: w, clientHeight: h } = viewer;
  renderer.setSize(w, h, false);
  camera.aspect = w / h;
  camera.updateProjectionMatrix();
}).observe(viewer);
renderer.autoClear = false;
renderer.setAnimationLoop(() => {
  controls.update();
  sizeHandles();
  renderer.clear();
  renderer.render(scene, camera);
  renderer.clearDepth();   // drag arrows always on top
  renderer.render(overlayScene, camera);
});

// ---------- go ----------
fillForm();
requestRender();
