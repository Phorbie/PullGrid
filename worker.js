// Runs OpenSCAD off the main thread. One fresh WASM instance per render
// (callMain can only run once per instance). Manifold backend: ~40x faster.
import { createOpenSCAD } from "./vendor/openscad/openscad.js";

let sources = null;  // { "pullgrid.scad": "...", "lib/carriage.scad": "..." }

async function loadSources() {
  if (sources) return sources;
  const list = (await (await fetch("./scad/files.txt")).text()).trim().split("\n");
  const texts = await Promise.all(list.map((f) => fetch(`./scad/${f}`).then((r) => r.text())));
  sources = Object.fromEntries(list.map((f, i) => [f, texts[i]]));
  return sources;
}

// part is a preview part name ("carriage") or "print:<index>"
async function render(defines, part) {
  const src = await loadSources();
  const log = [];
  const os = await createOpenSCAD({ noInitialRun: true, print: (t) => log.push(t), printErr: (t) => log.push(t) });
  const I = os.getInstance();
  const dirs = new Set(Object.keys(src).map((f) => f.split("/").slice(0, -1).join("/")).filter(Boolean));
  I.FS.mkdir("/pg");
  for (const d of dirs) I.FS.mkdir(`/pg/${d}`);
  for (const [f, text] of Object.entries(src)) I.FS.writeFile(`/pg/${f}`, text);

  const extra = part.startsWith("print:")
    ? { part: '"print"', print_index: part.slice(6) }
    : { part: `"${part}"` };
  const args = ["/pg/pullgrid.scad", "-o", "/out.stl", "--export-format=binstl", "--backend=manifold"];
  for (const [k, v] of Object.entries({ ...defines, ...extra })) args.push("-D", `${k}=${v}`);

  let stl = null;
  try {
    I.callMain(args);
    stl = I.FS.readFile("/out.stl");
  } catch {
    // no geometry (e.g. no fit) leaves no output file — reported via the log
  }
  return { log, stl };
}

self.onmessage = async (e) => {
  const { id, defines, parts } = e.data;
  try {
    const out = {};
    for (const p of parts) out[p] = await render(defines, p);
    const transfer = Object.values(out).filter((o) => o.stl).map((o) => o.stl.buffer);
    self.postMessage({ id, ok: true, out }, transfer);
  } catch (err) {
    self.postMessage({ id, ok: false, error: String((err && err.message) || err) });
  }
};
