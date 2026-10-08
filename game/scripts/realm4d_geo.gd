class_name Realm4DGeo
## Geometry for the 4D realm: genuine 4D objects (vertices in R^4) described by their
## edges, triangulated 2-faces and tetrahedralised 3-cells, plus mesh builders that pack
## the 4D coordinates into CUSTOM vertex attributes for the realm4d shaders.
## Nothing is pre-projected: every frame the GPU projects / slices with the 4D camera.

## geo = {"e": [[a, b], ...], "t": [[a, b, c], ...], "c": [[a, b, c, d], ...]} (Vector4s)
static func empty() -> Dictionary:
	return {"e": [], "t": [], "c": []}

static func merge(into: Dictionary, g: Dictionary) -> void:
	into["e"].append_array(g["e"]); into["t"].append_array(g["t"]); into["c"].append_array(g["c"])

## A regular polytope from polytopes.json, scaled per axis and moved.
static func poly(id: String, scale: Vector4, offset := Vector4.ZERO, cells := true) -> Dictionary:
	var p: Dictionary = P4.poly(id)
	var vs: Array[Vector4] = []
	for v in p["v4"]:
		vs.append(v * scale + offset)
	var g := empty()
	var e2: PackedInt32Array = p["e2"]
	for i in range(0, e2.size(), 2):
		g["e"].append([vs[e2[i]], vs[e2[i + 1]]])
	var faces: Array = p["faces"]
	for f in faces:
		for k in range(1, f.size() - 1):
			g["t"].append([vs[int(f[0])], vs[int(f[k])], vs[int(f[k + 1])]])
	if cells and p.has("cells"):
		for cell in p["cells"]:
			var ids := {}
			for fi in cell:
				for vi in faces[int(fi)]:
					ids[int(vi)] = true
			var c := Vector4.ZERO
			for vi in ids:
				c += vs[vi]
			c /= float(ids.size())
			for fi in cell:
				var f: Array = faces[int(fi)]
				for k in range(1, f.size() - 1):
					g["c"].append([c, vs[int(f[0])], vs[int(f[k])], vs[int(f[k + 1])]])
	return g

## Axis-aligned 4D box (a tesseract with half-sizes h) centred at c.
static func box(c: Vector4, h: Vector4, cells := true) -> Dictionary:
	return poly("tesseract", h * 2.0, c, cells)

static func box_minmax(lo: Vector4, hi: Vector4, cells := true) -> Dictionary:
	return box((lo + hi) * 0.5, (hi - lo) * 0.5, cells)

## Ground: the hyperplane y = 0 tiled by a lattice of cubes (3D cells of the 4D floor).
## Grid lines run along x, z and w; the slice of each square is a line on the 3D floor.
static func ground(half: float, step: float) -> Dictionary:
	var g := empty()
	var n := int(round(half * 2.0 / step))
	for i in n + 1:
		for j in n + 1:
			var a := -half + i * step
			var b := -half + j * step
			g["e"].append([Vector4(-half, 0, a, b), Vector4(half, 0, a, b)])
			g["e"].append([Vector4(a, 0, -half, b), Vector4(a, 0, half, b)])
			g["e"].append([Vector4(a, 0, b, -half), Vector4(a, 0, b, half)])
	# squares in the xw and zw planes give lines in every oriented slice
	for i in n + 1:
		for j in n:
			for k in n:
				var a := -half + i * step
				var b0 := -half + j * step
				var c0 := -half + k * step
				var b1 := b0 + step
				var c1 := c0 + step
				# square in (z, w) at x = a
				_quad(g, Vector4(a, 0, b0, c0), Vector4(a, 0, b1, c0), Vector4(a, 0, b1, c1), Vector4(a, 0, b0, c1))
				# square in (x, w) at z = a
				_quad(g, Vector4(b0, 0, a, c0), Vector4(b1, 0, a, c0), Vector4(b1, 0, a, c1), Vector4(b0, 0, a, c1))
	return g

static func _quad(g: Dictionary, a: Vector4, b: Vector4, c: Vector4, d: Vector4) -> void:
	g["t"].append([a, b, c]); g["t"].append([a, c, d])

## Clifford torus / duocylinder surface: (r cos s, r sin s, r cos t, r sin t) — a flat torus
## lying on the 3-sphere of radius r*sqrt(2). Axes order (x, z, y, w) keeps it upright.
static func clifford(c: Vector4, r: float, n: int) -> Dictionary:
	var g := empty()
	var P := func(i: int, j: int) -> Vector4:
		var s := TAU * float(i) / n
		var t := TAU * float(j) / n
		return c + Vector4(r * cos(s), r * cos(t), r * sin(s), r * sin(t))
	for i in n:
		for j in n:
			var a: Vector4 = P.call(i, j)
			g["e"].append([a, P.call(i + 1, j)])
			g["e"].append([a, P.call(i, j + 1)])
			_quad(g, a, P.call(i + 1, j), P.call(i + 1, j + 1), P.call(i, j + 1))
	return g

## A "tree" whose branches are tesseracts that fork in x, z AND w.
static func tree(base: Vector4) -> Dictionary:
	var g := empty()
	merge(g, box(base + Vector4(0, 1.5, 0, 0), Vector4(0.28, 1.5, 0.28, 0.28)))
	var dirs := [Vector4(1, 0, 0, 0), Vector4(-1, 0, 0, 0), Vector4(0, 0, 1, 0), Vector4(0, 0, -1, 0), Vector4(0, 0, 0, 1), Vector4(0, 0, 0, -1)]
	for d in dirs:
		var p: Vector4 = base + Vector4(0, 3.3, 0, 0) + d * 1.25
		merge(g, box(p, Vector4(0.36, 0.36, 0.36, 0.36)))
		merge(g, box(base + Vector4(0, 3.3, 0, 0) + d * 0.6, (Vector4(0.12, 0.12, 0.12, 0.12) + d.abs() * 0.5)))
		for d2 in dirs:
			if d2 == d or d2 == -d:
				continue
			if randf() < 0.45:
				merge(g, box(p + Vector4(0, 0.9, 0, 0) + d2 * 0.7, Vector4(0.2, 0.2, 0.2, 0.2), false))
	merge(g, box(base + Vector4(0, 4.6, 0, 0), Vector4(0.5, 0.5, 0.5, 0.5)))
	return g

# ---------------------------------------------------------------- mesh builders

static func _fmt() -> int:
	return (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) \
		| (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT) \
		| (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT) \
		| (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM3_SHIFT)

static func _put(arr: PackedFloat32Array, i: int, v: Vector4) -> void:
	arr[i] = v.x; arr[i + 1] = v.y; arr[i + 2] = v.z; arr[i + 3] = v.w

## items: Array of [Array(simplices), Color]; nv = corners per simplex; mode "edge"/"tri"/"slice"/"tet"
static func build(items: Array, mode: String) -> ArrayMesh:
	var ns := 0
	for it in items:
		ns += it[0].size()
	if ns == 0:
		return null
	var per := 4 if mode != "tri" else 3
	var nv := ns * per
	var verts := PackedVector3Array(); verts.resize(nv)
	var uvs := PackedVector2Array(); uvs.resize(nv)
	var cols := PackedColorArray(); cols.resize(nv)
	var cs: Array[PackedFloat32Array] = []
	for k in 4:
		var a := PackedFloat32Array(); a.resize(nv * 4); cs.append(a)
	var idx := PackedInt32Array()
	idx.resize(ns * (3 if mode == "tri" else 6))
	var vi := 0
	var ii := 0
	var corner_uv: Array[Vector2]
	match mode:
		"edge", "slice":
			corner_uv = [Vector2(0, -1), Vector2(0, 1), Vector2(1, -1), Vector2(1, 1)]
		"tri":
			corner_uv = [Vector2(0, 0), Vector2(1, 0), Vector2(2, 0)]
		_:
			corner_uv = [Vector2(0, 0), Vector2(1, 0), Vector2(2, 0), Vector2(3, 0)]
	for it in items:
		var col: Color = it[1]
		for s in it[0]:
			var m: int = s.size()
			for c in per:
				for k in m:
					_put(cs[k], (vi + c) * 4, s[k])
				uvs[vi + c] = corner_uv[c]
				cols[vi + c] = col
			if mode == "tri":
				idx[ii] = vi; idx[ii + 1] = vi + 1; idx[ii + 2] = vi + 2; ii += 3
			elif mode == "tet":
				idx[ii] = vi; idx[ii + 1] = vi + 1; idx[ii + 2] = vi + 2
				idx[ii + 3] = vi; idx[ii + 4] = vi + 2; idx[ii + 5] = vi + 3; ii += 6
			else:
				idx[ii] = vi; idx[ii + 1] = vi + 1; idx[ii + 2] = vi + 2
				idx[ii + 3] = vi + 2; idx[ii + 4] = vi + 1; idx[ii + 5] = vi + 3; ii += 6
			vi += per
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_CUSTOM0] = cs[0]
	arrays[Mesh.ARRAY_CUSTOM1] = cs[1]
	arrays[Mesh.ARRAY_CUSTOM2] = cs[2]
	arrays[Mesh.ARRAY_CUSTOM3] = cs[3]
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, _fmt())
	mesh.custom_aabb = AABB(Vector3(-1e5, -1e5, -1e5), Vector3(2e5, 2e5, 2e5))
	return mesh
