// Minimal zip writer for the browser and Node 18+. Entries are deflated with
// CompressionStream when it's available (every current browser, Node 18+),
// otherwise stored. Plenty for STLs and a 3MF.

const CRC = (() => {
  const t = new Uint32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    t[n] = c >>> 0;
  }
  return t;
})();
export function crc32(d) {
  let c = 0xffffffff;
  for (let i = 0; i < d.length; i++) c = CRC[(c ^ d[i]) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}

async function deflateRaw(data) {
  if (typeof CompressionStream === "undefined") return null;
  try {
    const stream = new Blob([data]).stream().pipeThrough(new CompressionStream("deflate-raw"));
    return new Uint8Array(await new Response(stream).arrayBuffer());
  } catch {
    return null;
  }
}

// files: [{ name, data: Uint8Array | string }]; returns a Uint8Array
export async function zipBytes(files, { compress = true } = {}) {
  const enc = new TextEncoder(), chunks = [], central = [];
  let off = 0;
  for (const f of files) {
    const name = enc.encode(f.name);
    const raw = typeof f.data === "string" ? enc.encode(f.data) : f.data;
    const crc = crc32(raw);
    const packed = compress ? await deflateRaw(raw) : null;
    const method = packed && packed.length < raw.length ? 8 : 0;
    const body = method ? packed : raw;
    const h = new DataView(new ArrayBuffer(30));
    [[0, 0x04034b50, 4], [4, 20, 2], [6, 0x0800, 2], [8, method, 2], [12, 0x21, 2], [14, crc, 4],
     [18, body.length, 4], [22, raw.length, 4], [26, name.length, 2]]
      .forEach(([o, v, s]) => (s === 4 ? h.setUint32(o, v, true) : h.setUint16(o, v, true)));
    chunks.push(new Uint8Array(h.buffer), name, body);
    const c = new DataView(new ArrayBuffer(46));
    [[0, 0x02014b50, 4], [4, 20, 2], [6, 20, 2], [8, 0x0800, 2], [10, method, 2], [14, 0x21, 2], [16, crc, 4],
     [20, body.length, 4], [24, raw.length, 4], [28, name.length, 2], [42, off, 4]]
      .forEach(([o, v, s]) => (s === 4 ? c.setUint32(o, v, true) : c.setUint16(o, v, true)));
    central.push(new Uint8Array(c.buffer), name);
    off += 30 + name.length + body.length;
  }
  const size = central.reduce((a, b) => a + b.length, 0);
  const e = new DataView(new ArrayBuffer(22));
  e.setUint32(0, 0x06054b50, true); e.setUint16(8, files.length, true); e.setUint16(10, files.length, true);
  e.setUint32(12, size, true); e.setUint32(16, off, true);
  const parts = [...chunks, ...central, new Uint8Array(e.buffer)];
  const out = new Uint8Array(parts.reduce((a, p) => a + p.length, 0));
  let p = 0;
  for (const x of parts) { out.set(x, p); p += x.length; }
  return out;
}
