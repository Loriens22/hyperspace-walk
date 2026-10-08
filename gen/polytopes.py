"""Generate the six convex regular 4-polytopes (vertices, edges, 2-faces, 3-cells) and verify
their f-vectors against Coxeter (1973), Table I / Wikipedia "Regular 4-polytope".
Writes game/data/polytopes.json. All polytopes are scaled to circumradius 1."""
import itertools, json, math, sys
import numpy as np

PHI = (1 + 5 ** 0.5) / 2

def even_perms(n=4):
    out = []
    for p in itertools.permutations(range(n)):
        inv = sum(1 for i in range(n) for j in range(i + 1, n) if p[i] > p[j])
        if inv % 2 == 0: out.append(p)
    return out

def signs(v):
    """all sign changes of non-zero entries"""
    idx = [i for i, x in enumerate(v) if x != 0]
    for s in itertools.product([1, -1], repeat=len(idx)):
        w = list(v)
        for i, si in zip(idx, s): w[i] *= si
        yield tuple(w)

def uniq(points, eps=1e-6):
    out = []
    for p in points:
        if not any(np.linalg.norm(np.array(p) - np.array(q)) < eps for q in out): out.append(p)
    return out

def all_perms_signs(base):
    pts = set()
    for p in itertools.permutations(base):
        for s in signs(p): pts.add(tuple(round(x, 12) for x in s))
    return list(pts)

def even_perms_signs(base, odd=False):
    pts = set()
    allp = list(itertools.permutations(range(4)))
    ev = even_perms()
    for p in ([q for q in allp if q not in ev] if odd else ev):
        v = tuple(base[i] for i in p)
        for s in signs(v): pts.add(tuple(round(x, 12) for x in s))
    return list(pts)

def five_cell():
    s5 = 5 ** 0.5
    return [(1, 1, 1, -1 / s5), (1, -1, -1, -1 / s5), (-1, 1, -1, -1 / s5), (-1, -1, 1, -1 / s5), (0, 0, 0, 4 / s5)]

def tesseract(): return list(itertools.product([-1, 1], repeat=4))
def sixteen_cell(): return all_perms_signs((1, 0, 0, 0))
def twentyfour_cell(): return all_perms_signs((1, 1, 0, 0))

def six_hundred_cell(odd=False):
    pts = all_perms_signs((1, 0, 0, 0)) + list(itertools.product([-.5, .5], repeat=4))
    pts += even_perms_signs((PHI / 2, 0.5, 1 / (2 * PHI), 0), odd)
    return pts

def one_twenty_cell():
    s5 = 5 ** 0.5; p = PHI; ip = 1 / PHI; ip2 = 1 / PHI ** 2; p2 = PHI ** 2
    pts = all_perms_signs((0, 0, 2, 2)) + all_perms_signs((1, 1, 1, s5))
    pts += all_perms_signs((ip2, p, p, p)) + all_perms_signs((ip, ip, ip, p2))
    pts += even_perms_signs((0, ip2, 1, p2)) + even_perms_signs((0, ip, p, s5)) + even_perms_signs((ip, 1, p, 2))
    return pts

def normalize(pts):
    a = np.array(pts, dtype=float)
    r = np.linalg.norm(a, axis=1)
    assert np.allclose(r, r[0], atol=1e-9), "not on a sphere"
    return a / r[0]

def edges_of(V):
    D = np.linalg.norm(V[:, None, :] - V[None, :, :], axis=2)
    np.fill_diagonal(D, 1e9)
    m = D.min()
    E = [(i, j) for i in range(len(V)) for j in range(i + 1, len(V)) if D[i, j] < m + 1e-6]
    return E, m

def faces_of(V, E, kind):
    n = len(V); adj = [set() for _ in range(n)]
    for i, j in E: adj[i].add(j); adj[j].add(i)
    faces = []
    if kind == 3:
        for i, j in E:
            for k in adj[i] & adj[j]:
                if k > j: faces.append([i, j, k])
    elif kind == 4:   # squares: 4-cycles i-j-k-l
        seen = set()
        for i in range(n):
            for j in adj[i]:
                for l in adj[i]:
                    if l <= j: continue
                    for k in (adj[j] & adj[l]) - {i}:
                        key = frozenset((i, j, k, l))
                        if key not in seen: seen.add(key); faces.append([i, j, k, l])
    elif kind == 5:   # pentagons: 5-cycles (girth 5 graph)
        seen = set()
        for a in range(n):
            for b in adj[a]:
                for c in adj[b] - {a}:
                    for d in adj[c] - {a, b}:
                        for e in (adj[d] & adj[a]) - {b, c}:
                            key = frozenset((a, b, c, d, e))
                            if key not in seen: seen.add(key); faces.append([a, b, c, d, e])
    # check planarity
    for f in faces:
        P = V[f] - V[f].mean(0)
        assert np.linalg.matrix_rank(P, tol=1e-6) == 2, "non planar face"
    return faces

def tetra_centroids(pts):
    V = normalize(pts); E, _ = edges_of(V)
    adj = [set() for _ in range(len(V))]
    for i, j in E: adj[i].add(j); adj[j].add(i)
    out = set()
    for i, j in E:
        for k in adj[i] & adj[j]:
            for l in adj[i] & adj[j] & adj[k]:
                out.add(tuple(sorted((i, j, k, l))))
    return [tuple(V[list(t)].mean(0)) for t in out]

def cells_of(V, F, normals):
    cells = []
    for nrm in normals:
        d = V @ nrm; mx = d.max()
        vs = set(np.where(d > mx - 1e-6)[0].tolist())
        fs = [fi for fi, f in enumerate(F) if set(f) <= vs]
        cells.append(fs)
    return cells

def build(name, schlafli, pts, face_kind, dual_pts):
    V = normalize(pts)
    E, el = edges_of(V)
    F = faces_of(V, E, face_kind)
    eidx = {}
    for k, (i, j) in enumerate(E): eidx[(i, j)] = k; eidx[(j, i)] = k
    Fe = [[eidx[(f[k], f[(k + 1) % len(f)])] for k in range(len(f))] for f in F]
    C = cells_of(V, F, normalize(dual_pts))
    return dict(name=name, schlafli=schlafli, edge_length=el, verts=[[round(x, 7) for x in v] for v in V.tolist()],
                edges=[list(e) for e in E], faces=F, face_edges=Fe, cells=C)

P = {}
P['5cell'] = build('5-cell', '{3,3,3}', five_cell(), 3, [tuple(-x for x in v) for v in five_cell()])
P['tesseract'] = build('8-cell (tesseract)', '{4,3,3}', tesseract(), 4, sixteen_cell())
P['16cell'] = build('16-cell', '{3,3,4}', sixteen_cell(), 3, tesseract())
P['24cell'] = build('24-cell', '{3,4,3}', twentyfour_cell(), 3, sixteen_cell() + list(itertools.product([-.5, .5], repeat=4)))
P['600cell'] = build('600-cell', '{3,3,5}', six_hundred_cell(), 3, tetra_centroids(six_hundred_cell()))
P['120cell'] = build('120-cell', '{5,3,3}', one_twenty_cell(), 5, six_hundred_cell(odd=True))

expected = {'5cell': (5, 10, 10, 5), 'tesseract': (16, 32, 24, 8), '16cell': (8, 24, 32, 16),
            '24cell': (24, 96, 96, 24), '600cell': (120, 720, 1200, 600), '120cell': (600, 1200, 720, 120)}
ok = True
for k, p in P.items():
    f = (len(p['verts']), len(p['edges']), len(p['faces']), len(p['cells']))
    cellsizes = sorted(set(len(c) for c in p['cells']))
    euler = f[0] - f[1] + f[2] - f[3]
    good = f == expected[k] and euler == 0 and 0 not in cellsizes and len(cellsizes) == 1
    ok &= good
    print(f"{k:10s} {p['schlafli']:8s} V,E,F,C={f} expected={expected[k]} faces/cell={cellsizes} edge={p['edge_length']:.6f} euler={euler} {'OK' if good else 'FAIL'}")
json.dump(P, open(sys.argv[1] if len(sys.argv) > 1 else 'polytopes.json', 'w'), separators=(',', ':'))
print('ALL OK' if ok else 'MISMATCH'); sys.exit(0 if ok else 1)
