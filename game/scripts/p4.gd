## 4D math library: polytope data, rotations in the six coordinate planes of R^4,
## and exact hyperplane cross-sections (slices). See docs/MATH.md.
class_name P4
extends RefCounted

const PLANES := [[0, 1], [0, 2], [0, 3], [1, 2], [1, 3], [2, 3]]
const PLANE_NAMES := ["xy", "xz", "xw", "yz", "yw", "zw"]
static var _cache := {}

static func poly(id: String) -> Dictionary:
	if _cache.is_empty():
		var f := FileAccess.open("res://data/polytopes.json", FileAccess.READ)
		var raw: Dictionary = JSON.parse_string(f.get_as_text())
		for k in raw:
			var p: Dictionary = raw[k]
			var verts: Array[Vector4] = []
			for v in p["verts"]:
				verts.append(Vector4(v[0], v[1], v[2], v[3]))
			var edges := PackedInt32Array()
			for e in p["edges"]:
				edges.append(int(e[0])); edges.append(int(e[1]))
			p["v4"] = verts
			p["e2"] = edges
			_cache[k] = p
	return _cache[id]

## Rotation by angle a in the coordinate plane (i, j): only coordinates i and j change,
## the completely orthogonal plane is left fixed.
static func plane_rot(i: int, j: int, a: float) -> Projection:
	var cols := [Vector4(1, 0, 0, 0), Vector4(0, 1, 0, 0), Vector4(0, 0, 1, 0), Vector4(0, 0, 0, 1)]
	var c := cos(a)
	var s := sin(a)
	var ci: Vector4 = cols[i]
	var cj: Vector4 = cols[j]
	ci[i] = c; ci[j] = s
	cj[i] = -s; cj[j] = c
	cols[i] = ci; cols[j] = cj
	return Projection(cols[0], cols[1], cols[2], cols[3])

static func rot_plane_idx(k: int, a: float) -> Projection:
	return plane_rot(PLANES[k][0], PLANES[k][1], a)

## Gram-Schmidt re-orthonormalisation to stop numerical drift of an accumulated rotation.
static func orthonormalize(m: Projection) -> Projection:
	var c: Array[Vector4] = [m.x, m.y, m.z, m.w]
	for i in 4:
		var v: Vector4 = c[i]
		for j in i:
			v -= c[j] * v.dot(c[j])
		c[i] = v.normalized()
	return Projection(c[0], c[1], c[2], c[3])

static func mat_text(m: Projection) -> String:
	var s := ""
	for r in 4:
		var row := []
		for cidx in 4:
			row.append("%+.2f" % m[cidx][r])
		s += "│ " + " ".join(row) + " │\n"
	return s

## Exact 3D cross-section of a convex 4-polytope with the hyperplane w = h (after rotation R).
## Slice vertices = edges crossing the hyperplane; slice edges = 2-faces crossing it;
## slice faces = 3-cells crossing it (each gives a convex polygon).
static func slice(p: Dictionary, R: Projection, h: float, scale4: Vector4 = Vector4.ONE) -> Dictionary:
	var v4: Array[Vector4] = p["v4"]
	var e2: PackedInt32Array = p["e2"]
	var n := v4.size()
	var q: Array[Vector4] = []
	q.resize(n)
	for i in n:
		q[i] = R * (v4[i] * scale4)
	var ne := e2.size() / 2
	var hitp := PackedVector3Array()
	hitp.resize(ne)
	var hit := PackedByteArray()
	hit.resize(ne)
	var pts := PackedVector3Array()
	for k in ne:
		var a: Vector4 = q[e2[2 * k]]
		var b: Vector4 = q[e2[2 * k + 1]]
		var da := a.w - h
		var db := b.w - h
		if (da > 0.0) != (db > 0.0):
			var t := da / (da - db)
			var pa := Vector3(a.x, a.y, a.z)
			var pb := Vector3(b.x, b.y, b.z)
			hitp[k] = pa.lerp(pb, t)
			hit[k] = 1
			pts.append(hitp[k])
	var face_seg := {}
	var segs := PackedVector3Array()
	var fe: Array = p["face_edges"]
	for fi in fe.size():
		var ids := []
		for e in fe[fi]:
			if hit[int(e)] == 1:
				ids.append(int(e))
		if ids.size() >= 2:
			face_seg[fi] = [ids[0], ids[1]]
			segs.append(hitp[ids[0]]); segs.append(hitp[ids[1]])
	var tris := PackedVector3Array()
	var npoly := 0
	for cell in p["cells"]:
		var adj := {}
		for f in cell:
			if face_seg.has(int(f)):
				var sg: Array = face_seg[int(f)]
				if not adj.has(sg[0]): adj[sg[0]] = []
				if not adj.has(sg[1]): adj[sg[1]] = []
				adj[sg[0]].append(sg[1]); adj[sg[1]].append(sg[0])
		if adj.size() < 3:
			continue
		var start = adj.keys()[0]
		var loop := [start]
		var prev = -1
		var cur = start
		for _i in adj.size():
			var nx = -1
			for c in adj[cur]:
				if c != prev and c != start:
					nx = c; break
			if nx == -1 or loop.has(nx): break
			loop.append(nx); prev = cur; cur = nx
		if loop.size() < 3:
			continue
		npoly += 1
		var cen := Vector3.ZERO
		for id in loop: cen += hitp[id]
		cen /= loop.size()
		for i in loop.size():
			tris.append(cen); tris.append(hitp[loop[i]]); tris.append(hitp[loop[(i + 1) % loop.size()]])
	return {"points": pts, "segs": segs, "tris": tris, "faces": npoly}

static func bbox(pts: PackedVector3Array) -> AABB:
	if pts.is_empty(): return AABB()
	var bb := AABB(pts[0], Vector3.ZERO)
	for pt in pts: bb = bb.expand(pt)
	return bb
