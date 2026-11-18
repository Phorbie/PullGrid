// Runs OpenSCAD off the main thread. One fresh WASM instance per render
// (callMain can only run once per instance).
import { createOpenSCAD } from "./vendor/openscad/openscad.js";

let sources = null;  // { "pullgrid.scad": "...", "lib/frame.scad": "..." }

async function loadSources() {
  if (sources) return sources;
  const list = (await (await fetch("./scad/files.txt")).text()).trim().split("\n");
  const texts = await Promise.all(list.map((f) => fetch(`./scad/${f}`).then((r) => r.text())));
  sources = Object.fromEntries(list.map((f, i) => [f, texts[i]]));
  return sources;
}

async function render(defines, part) {
  const src = await loadSources();
  const log = [];
  const os = await createOpenSCAD({
    noInitialRun: true,
    print: (t) => log.push(t),
    printErr: (t) => log.push(t),
  });
  const I = os.getInstance();
  I.FS.mkdir("/pg");
  I.FS.mkdir("/pg/lib");
  for (const [f, text] of Object.entries(src)) I.FS.writeFile(`/pg/${f}`, text);

  const args = ["/pg/pullgrid.scad", "-o", "/out.stl", "--export-format=binstl"];
  for (const [k, v] of Object.entries({ ...defines, part: `"${part}"` })) args.push("-D", `${k}=${v}`);

  let stl = null;
  try {
    I.callMain(args);
    stl = I.FS.readFile("/out.stl");  // Uint8Array
  } catch (e) {
    // no geometry (e.g. no fit) leaves no output file — that's reported via log
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
    self.postMessage({ id, ok: false, error: String(err && err.message || err) });
  }
};
