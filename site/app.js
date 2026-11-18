// PullGrid generator UI. Geometry lives in scad/ — this file only collects
// inputs, asks the worker to render, and displays what comes back.
import * as THREE from "three";
import { OrbitControls } from "./vendor/three/OrbitControls.js";
import { STLLoader } from "./vendor/three/STLLoader.js";

const MM = 25.4;
const DEFAULTS = {
  unit: "in",
  opening_w: 11 * MM, opening_h: 24 * MM, interior_depth: 22 * MM,
  frame_type: "face_frame", hinge_side: "left",
  offset_left: null, offset_right: null, offset_bottom: null, offset_top: null,
  rear_w: null, rear_h: null, door_intrusion: 0,
  hinges: [], keepouts: [],
  panel_count: 1, panel_thickness: "6.8",
  slide_height: 15, clear_side: 3, clear_top: 5, clear_rear: 10,
};
const DODGE = {
  left: "narrowed the frame from the left",
  right: "narrowed the frame from the right",
  bottom: "raised the frame's floor",
  top: "lowered the frame's top",
  back: "shortened the frame from the back",
};

const $ = (s, el = document) => el.querySelector(s);
const $$ = (s, el = document) => [...el.querySelectorAll(s)];
const clone = (o) => JSON.parse(JSON.stringify(o));

// ---------- state ----------
let state = loadState();
const bad = new Set();
let report = null;
let frameStl = null;
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
}

form.addEventListener("input", (e) => {
  const el = e.target;
  if (el.dataset.key) readField(el);
  else if (el.dataset.row != null) readRow(el);
  else return;
  changed();
});

function readField(el) {
  const k = el.dataset.key, kind = el.dataset.kind;
  let ok = true;
  if (kind === "len") {
    const p = parseLen(el.value, state.unit);
    if (p.empty && el.hasAttribute("data-auto")) state[k] = null;
    else if (p.mm != null && p.mm >= 0) state[k] = p.mm;
    else ok = false;
  } else if (kind === "int") {
    const n = parseInt(el.value, 10);
    ok = Number.isInteger(n) && n >= +el.dataset.min && n <= +el.dataset.max;
    if (ok) state[k] = n;
  }
  mark(el, k, ok);
}
function mark(el, key, ok) {
  el.classList.toggle("bad", !ok);
  ok ? bad.delete(key) : bad.add(key);
}

form.addEventListener("click", (e) => {
  const b = e.target.closest(".seg button");
  if (!b) return;
  const seg = b.parentElement;
  state[seg.dataset.key] = b.dataset.v;
  for (const x of $$("button", seg)) x.classList.toggle("on", x === b);
  changed();
});

// hinge + keep-out rows
const HF = [["z", "Center height"], ["intrusion", "Sticks in"]];
const KF = [["x", "X"], ["y", "Y"], ["z", "Z"], ["w", "Width"], ["d", "Depth"], ["h", "Height"]];

function rowInput(list, i, f, label) {
  return `<div><label>${label}</label><input data-row="${i}" data-list="${list}" data-f="${f}" value="${formatLen(state[list][i][f])}" inputmode="decimal"></div>`;
}
function buildRows() {
  $("#hinges").innerHTML = state.hinges.map((h, i) =>
    `<div class="row h">${HF.map(([f, l]) => rowInput("hinges", i, f, l)).join("")}<button type="button" class="x" data-del="hinges" data-i="${i}" aria-label="Remove hinge">×</button></div>`).join("");
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

// ---------- render pipeline ----------
const worker = new Worker("./worker.js", { type: "module" });
let reqId = 0, inflight = false, queued = null, debounce = 0;

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
    panel_count: s.panel_count, panel_thickness: s.panel_thickness,
    slide_height: L(s.slide_height), clear_side: L(s.clear_side), clear_top: L(s.clear_top), clear_rear: L(s.clear_rear),
  };
}

function changed() {
  saveState();
  if (bad.size) {
    setStatus("bad", "Fix the highlighted fields");
    return;
  }
  clearTimeout(debounce);
  debounce = setTimeout(requestRender, 250);
}
function requestRender() {
  const d = defines(state);
  if (inflight) { queued = d; return; }
  send(d);
}
function send(d) {
  inflight = true;
  $("#busy").hidden = false;
  worker.postMessage({ id: ++reqId, defines: d, parts: ["frame", "cabinet", "keepouts"] });
}
worker.onmessage = (e) => {
  inflight = false;
  if (queued) { const q = queued; queued = null; send(q); } else $("#busy").hidden = true;
  const msg = e.data;
  if (!msg.ok) { setStatus("bad", `Render failed: ${msg.error}`); return; }
  const { frame, cabinet, keepouts } = msg.out;
  report = parseReport(frame.log);
  frameStl = report.fits ? frame.stl : null;
  setPart("frame", frameStl);
  setPart("cabinet", cabinet.stl);
  setPart("keepouts", keepouts.stl);
  applyExtension();
  if (firstFit) { fitView(); firstFit = false; }
  showReport();
  hingeHint();
};
worker.onerror = (e) => setStatus("bad", `Couldn't start OpenSCAD: ${e.message || "worker error"}`);

function parseReport(log) {
  const r = { keepouts: [], errors: [], warnings: [], scadErrors: [] };
  for (const line of log) {
    if (/^ERROR:/.test(line)) r.scadErrors.push(line);
    const m = line.match(/PULLGRID (.*?)"?$/);
    if (!m) continue;
    const t = m[1];
    let x;
    if ((x = t.match(/^envelope_mm=\[([^\]]+)\]/))) r.env = x[1].split(",").map(Number);
    else if ((x = t.match(/^slide_mm=(\d+)/))) r.slide = +x[1];
    else if ((x = t.match(/^panel_cells=\[(\d+), (\d+)\] x(\d+)/))) r.cells = [+x[1], +x[2], +x[3]];
    else if ((x = t.match(/^keepout=(\d+) dodged_by=(\w+) label=(.*)$/))) r.keepouts.push({ by: x[2], label: x[3] });
    else if ((x = t.match(/^hinges=(\d+)/))) r.hinges = +x[1];
    else if (t.startsWith("ERROR")) r.errors.push(t.slice(6));
    else if (t.startsWith("WARNING")) r.warnings.push(t.slice(8));
  }
  r.fits = !!r.env && !r.errors.includes("no_fit") && !r.scadErrors.length;
  return r;
}

// ---------- report ----------
function setStatus(kind, text) {
  const s = $("#status");
  s.className = `status ${kind}`;
  s.textContent = text;
}
function showReport() {
  const dl = $("#facts"), ul = $("#tradeoffs"), dlBtn = $("#download");
  if (!report) return;
  dl.innerHTML = ""; ul.innerHTML = "";
  dlBtn.disabled = !report.fits;
  if (report.scadErrors.length) { setStatus("bad", "OpenSCAD error"); ul.innerHTML = report.scadErrors.map((e) => `<li>${esc(e)}</li>`).join(""); return; }
  if (!report.fits) {
    setStatus("bad", "Doesn't fit");
    ul.innerHTML = `<li>After hinges, rails and clearances there's no room left. Check the opening width and hinge settings.</li>`;
    return;
  }
  const [w, d, h] = report.env;
  if (report.warnings.includes("too_narrow")) setStatus("warn", `Fits, but only ${fmt(w)} wide: too narrow to hold much`);
  else if (report.warnings.includes("no_standard_slide_fits")) setStatus("warn", "Fits, but it's shallower than the shortest standard slide (10″)");
  else setStatus("good", "Fits");
  const row = (k, v, a = "") => `<dt>${k}</dt><dd>${v}${a ? `<span class="alt">${a}</span>` : ""}</dd>`;
  dl.innerHTML =
    row("Usable space", `${fmt(w)} W × ${fmt(d)} D × ${fmt(h)} H`) +
    (report.slide ? row("Slides", `${Math.round(report.slide / MM)}″ full-extension`, `${report.slide} mm`) : "") +
    (report.cells ? row("openGrid panels", `${report.cells[2]} × ${report.cells[0]} × ${report.cells[1]} cells`, `${fmt(report.cells[0] * 28)} × ${fmt(report.cells[1] * 28)} each`) : "") +
    row("Hinges", state.hinges.length ? `${state.hinges.length} custom` : state.hinge_side === "none" ? "none" : `${report.hinges} auto`);
  ul.innerHTML = report.keepouts.map((k) => `<li><strong>${esc(cap(k.label))}</strong>: ${DODGE[k.by] || k.by}</li>`).join("");
}
const esc = (s) => s.replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]);
const cap = (s) => s[0].toUpperCase() + s.slice(1);

$("#download").onclick = () => {
  if (!frameStl || !report?.env) return;
  const [w, d, h] = report.env.map(Math.round);
  const a = document.createElement("a");
  a.href = URL.createObjectURL(new Blob([frameStl], { type: "model/stl" }));
  a.download = `pullgrid-${w}x${d}x${h}mm.stl`;
  a.click();
  setTimeout(() => URL.revokeObjectURL(a.href), 2000);
};

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
const groups = { frame: new THREE.Group(), cabinet: new THREE.Group(), keepouts: new THREE.Group() };
for (const g of Object.values(groups)) scene.add(g);
const mats = {
  frame: new THREE.MeshStandardMaterial({ color: 0x2f6d9c, roughness: 0.55 }),
  cabinet: new THREE.MeshStandardMaterial({ color: 0xc9a77a, roughness: 0.9, transparent: true, opacity: 0.2, depthWrite: false, side: THREE.DoubleSide }),
  keepouts: new THREE.MeshStandardMaterial({ color: 0xc8324f, transparent: true, opacity: 0.6, depthWrite: false }),
};
const edges = {
  frame: new THREE.LineBasicMaterial({ color: 0x163650 }),
  cabinet: new THREE.LineBasicMaterial({ color: 0x8a6d48, transparent: true, opacity: 0.55 }),
  keepouts: new THREE.LineBasicMaterial({ color: 0x8e1c33 }),
};
function setPart(name, stl) {
  const g = groups[name];
  for (const c of g.children) c.geometry.dispose();
  g.clear();
  if (!stl || stl.byteLength < 134) return;
  const geo = loader.parse(stl.buffer.slice(stl.byteOffset, stl.byteOffset + stl.byteLength));
  geo.computeVertexNormals();
  const mesh = new THREE.Mesh(geo, mats[name]);
  const line = new THREE.LineSegments(new THREE.EdgesGeometry(geo, 25), edges[name]);
  if (name !== "frame") mesh.renderOrder = line.renderOrder = name === "keepouts" ? 2 : 3;
  g.add(mesh, line);
}

const ext = $("#extension");
function applyExtension() {
  const travel = report?.slide || report?.env?.[1] || 0;
  groups.frame.position.y = -(ext.value / 100) * travel;
}
ext.oninput = applyExtension;

function fitView() {
  // frame it all: the cabinet plus the pull-out at full travel
  const box = new THREE.Box3().setFromObject(groups.cabinet);
  const fb = new THREE.Box3().setFromObject(groups.frame);
  if (!fb.isEmpty()) {
    const travel = report?.slide || report?.env?.[1] || 0;
    fb.translate(new THREE.Vector3(0, -groups.frame.position.y - travel, 0));  // closed → fully out
    box.union(fb);
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
renderer.setAnimationLoop(() => { controls.update(); renderer.render(scene, camera); });

// ---------- go ----------
fillForm();
requestRender();
