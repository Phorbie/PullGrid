"""Volume (mm^3) of an ASCII or binary STL. Usage: python3 stlvol.py file.stl"""
import struct, sys

def tris(path):
    data = open(path, "rb").read()
    if data[:5] == b"solid" and b"facet" in data[:400]:
        pts = [tuple(map(float, l.split()[1:4])) for l in data.decode().splitlines() if l.strip().startswith("vertex")]
        return [pts[i:i + 3] for i in range(0, len(pts), 3)]
    n = struct.unpack("<I", data[80:84])[0]
    return [[struct.unpack("<3f", data[84 + 50 * i + 12 + 12 * k: 84 + 50 * i + 24 + 12 * k]) for k in range(3)] for i in range(n)]

def vol(path):
    v = 0.0
    for a, b, c in tris(path):
        v += (a[0] * (b[1] * c[2] - b[2] * c[1]) - a[1] * (b[0] * c[2] - b[2] * c[0]) + a[2] * (b[0] * c[1] - b[1] * c[0])) / 6
    return abs(v)

def bodies(path):
    """Separate solids in the file: triangles joined through shared corners."""
    parent = {}
    def find(a):
        while parent.setdefault(a, a) != a:
            parent[a] = parent[parent[a]]; a = parent[a]
        return a
    key = lambda p: tuple(round(c, 3) for c in p)
    for tr in tris(path):
        a, b, c = (key(p) for p in tr)
        parent[find(b)] = find(a); parent[find(c)] = find(a)
    return len({find(k) for k in list(parent)})

if __name__ == "__main__":
    print(f"{vol(sys.argv[1]):.3f}")
