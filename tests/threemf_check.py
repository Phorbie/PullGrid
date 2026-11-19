"""Check a PullGrid Bambu project 3MF: structure, references, plate placement,
overlaps, the calibration corner, and watertight meshes.
Usage: python3 tests/threemf_check.py out.3mf   (reads out.3mf.json from build3mf.mjs)"""
import json, math, sys, zipfile
import xml.etree.ElementTree as ET
from collections import Counter

path = sys.argv[1]
exp = json.load(open(path + ".json"))
NS = {"m": "http://schemas.microsoft.com/3dmanufacturing/core/2015/02"}
fail = []
def check(ok, msg):
    if not ok: fail.append(msg)

z = zipfile.ZipFile(path)
names = set(z.namelist())
for f in ["[Content_Types].xml", "_rels/.rels", "3D/3dmodel.model", "Metadata/model_settings.config", "Metadata/project_settings.config"]:
    check(f in names, f"missing {f}")
check(z.testzip() is None, "zip CRC error")

model = ET.fromstring(z.read("3D/3dmodel.model"))
meta = {m.get("name"): m.text for m in model.findall("m:metadata", NS)}
check((meta.get("Application") or "").startswith("BambuStudio-"), "Application must start with BambuStudio-")

# objects: indices in range, watertight (every edge used twice, once each way)
foot = {}
for o in model.findall("m:resources/m:object", NS):
    oid = int(o.get("id"))
    vs = [(float(v.get("x")), float(v.get("y")), float(v.get("z"))) for v in o.findall("m:mesh/m:vertices/m:vertex", NS)]
    ts = [(int(t.get("v1")), int(t.get("v2")), int(t.get("v3"))) for t in o.findall("m:mesh/m:triangles/m:triangle", NS)]
    check(len(vs) >= 4 and len(ts) >= 4, f"object {oid}: empty mesh")
    check(all(0 <= i < len(vs) for t in ts for i in t), f"object {oid}: triangle index out of range")
    edges = Counter()
    for a, b, c in ts:
        for e in ((a, b), (b, c), (c, a)): edges[e] += 1
    bad = sum(1 for (a, b), n in edges.items() if n != 1 or edges.get((b, a), 0) != 1)
    check(bad == 0, f"object {oid}: not watertight ({bad} bad edges)")
    check(abs(min(v[2] for v in vs)) < 1e-3, f"object {oid}: not sitting on z=0")
    foot[oid] = (min(v[0] for v in vs), max(v[0] for v in vs), min(v[1] for v in vs), max(v[1] for v in vs))

# build items: per-object instance lists, in order
items = {}
for it in model.findall("m:build/m:item", NS):
    oid = int(it.get("objectid"))
    check(oid in foot, f"build item for unknown object {oid}")
    t = [float(x) for x in it.get("transform").split()]
    check(t[:9] == [1, 0, 0, 0, 1, 0, 0, 0, 1], f"object {oid}: rotation in transform")
    items.setdefault(oid, []).append((t[9], t[10]))
for oid, q in exp["qty"].items():
    check(len(items.get(int(oid), [])) == q, f"object {oid}: {len(items.get(int(oid), []))} instances, expected {q}")
check(len(cfg_plates := ET.fromstring(z.read("Metadata/model_settings.config")).findall("plate")) <= 36, "more than 36 plates")

# model_settings: objects exist, every instance on exactly one plate
cfg = ET.fromstring(z.read("Metadata/model_settings.config"))
for o in cfg.findall("object"):
    oid = int(o.get("id"))
    check(oid in foot, f"settings for unknown object {oid}")
    keys = {m.get("key"): m.get("value") for m in o.findall("metadata")}
    check(keys.get("wall_loops") in ("4", "5") and keys.get("sparse_infill_density") == "25%", f"object {oid}: print settings")
    check(o.find("part") is not None and int(o.find("part").get("id")) == oid, f"object {oid}: part id")
# names Studio would refuse (one popup per plate) or choke on when it builds file names
BAD = set('<>[]:/\\|?*"&')
for o in cfg.findall("object"):
    for el in [o] + o.findall("part"):
        nm = (el.find("metadata[@key='name']") if el is not o else o.find("metadata[@key='name']"))
        if nm is not None: check(not (set(nm.get("value")) & BAD), f"name Studio rejects: {nm.get('value')!r}")
for o in model.findall("m:resources/m:object", NS):
    check(not (set(o.get("name") or "") & BAD), f"object name Studio rejects: {o.get('name')!r}")
plates = cfg.findall("plate")
for p in plates:
    nm = p.find("metadata[@key='plater_name']").get("value")
    check(not (set(nm) & BAD), f"plate name Studio rejects: {nm!r}")
check([p.find("metadata[@key='plater_name']").get("value") for p in plates] == exp["plates"], "plate names")
seen = Counter()
W, D = exp["bed"]
v = math.sqrt(len(plates)); r = round(v); cols = r + 1 if v > r else r
for pi, p in enumerate(plates):
    check(int(p.find("metadata[@key='plater_id']").get("value")) == pi + 1, f"plate {pi + 1}: id")
    ox, oy = (pi % cols) * W * 1.2, -(pi // cols) * D * 1.2       # Studio's plate grid
    boxes = []
    for mi in p.findall("model_instance"):
        k = {m.get("key"): int(m.get("value")) for m in mi.findall("metadata")}
        oid, ii = k["object_id"], k["instance_id"]
        seen[(oid, ii)] += 1
        if oid not in items or ii >= len(items[oid]): fail.append(f"plate {pi + 1}: bad instance {oid}/{ii}"); continue
        tx, ty = items[oid][ii]; f = foot[oid]
        b = (tx + f[0] - ox, tx + f[1] - ox, ty + f[2] - oy, ty + f[3] - oy)   # plate coordinates
        check(b[0] >= -0.01 and b[1] <= W + 0.01 and b[2] >= -0.01 and b[3] <= D + 0.01,
              f"plate {pi + 1}: object {oid} instance {ii} outside the plate {tuple(round(x, 1) for x in b)}")
        if exp["excl"]:
            ex, ey = exp["excl"]
            check(not (b[0] < ex and b[2] < ey), f"plate {pi + 1}: object {oid} in the calibration corner")
        for o2 in boxes:
            check(b[1] <= o2[0] or o2[1] <= b[0] or b[3] <= o2[2] or o2[3] <= b[2], f"plate {pi + 1}: object {oid} overlaps another part")
        boxes.append(b)
for oid, lst in items.items():
    for ii in range(len(lst)):
        check(seen[(oid, ii)] == 1, f"object {oid} instance {ii} on {seen[(oid, ii)]} plates")

# project settings: names Bambu's system presets, marks nothing as changed
proj = json.loads(z.read("Metadata/project_settings.config"))
P = exp["printer"]
check(proj.get("printer_settings_id") == P["printer"] and proj.get("print_settings_id") == P["process"]
      and proj.get("filament_settings_id") == [P["filament"]], "project presets")
check(proj.get("different_settings_to_system") == ["", "", ""] and len(proj.get("filament_colour", [])) == 1, "project config shape")

print(("FAIL " if fail else "ok   ") + f"{path.split('/')[-1]}: {len(plates)} plates, {sum(len(l) for l in items.values())} pieces, {len(foot)} objects")
for f in fail[:20]: print("   ", f)
sys.exit(1 if fail else 0)
