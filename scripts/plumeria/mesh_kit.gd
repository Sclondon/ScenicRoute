extends RefCounted
## Collects triangles for one mesh: boxes, tubes along a path, lathes, ellipsoids and quads, each with a
## vertex colour (and UV2 for the shaders' extras). Triangles are turned to face the way their normals say,
## so nothing built here comes out inside out. `mesh()` makes the ArrayMesh.

var v := PackedVector3Array()
var n := PackedVector3Array()
var c := PackedColorArray()
var uv := PackedVector2Array()
var uv2 := PackedVector2Array()
var idx := PackedInt32Array()


func vert(p: Vector3, nn: Vector3, col: Color, t := Vector2.ZERO, t2 := Vector2.ZERO) -> int:
	v.append(p)
	n.append(nn)
	c.append(col)
	uv.append(t)
	uv2.append(t2)
	return v.size() - 1


## A triangle, wound so its front faces the way its vertices' normals point.
func tri(a: int, b: int, d: int) -> void:
	var face := (v[d] - v[a]).cross(v[b] - v[a])
	if face.dot(n[a] + n[b] + n[d]) < 0.0:
		idx.append_array([a, d, b])
	else:
		idx.append_array([a, b, d])


func quad(a: int, b: int, d: int, e: int) -> void:
	tri(a, b, d)
	tri(a, d, e)


func size() -> int:
	return idx.size() / 3


## A box: `xf` places its middle, `s` its whole size.
func box(xf: Transform3D, s: Vector3, col: Color, t2 := Vector2.ZERO) -> void:
	var h := s * 0.5
	for axis in 3:
		for sgn in [-1.0, 1.0]:
			var nn := Vector3.ZERO
			nn[axis] = sgn
			var u := Vector3.ZERO
			u[(axis + 1) % 3] = 1.0
			var w := Vector3.ZERO
			w[(axis + 2) % 3] = 1.0
			var ids := []
			for k in 4:
				var a := -1.0 if k == 0 or k == 3 else 1.0
				var b := -1.0 if k < 2 else 1.0
				var p := nn * h + u * h * a + w * h * b
				ids.append(vert(xf * p, (xf.basis * nn).normalized(), col, Vector2(a, b) * 0.5 + Vector2(0.5, 0.5), t2))
			quad(ids[0], ids[1], ids[2], ids[3])


## A box from `a` to `b` (its long axis), `w` by `h` across it.
func beam(a: Vector3, b: Vector3, w: float, h: float, col: Color, t2 := Vector2.ZERO) -> void:
	var along := b - a
	var z := along.normalized()
	var ref := Vector3.UP if absf(z.y) < 0.95 else Vector3.RIGHT
	var x := ref.cross(z).normalized()
	var y := z.cross(x)
	box(Transform3D(Basis(x, y, z), (a + b) * 0.5), Vector3(w, h, along.length()), col, t2)


## A tube through `points` with a radius at each; UV.x round it 0..1, UV.y metres along it.
## `t2s` gives each ring its own UV2 (or one for all).
func tube(points: PackedVector3Array, radii: PackedFloat32Array, sides: int, col: Color, t2s := [], cap := false) -> void:
	var count := points.size()
	var ref := Vector3.UP
	var along := 0.0
	var rings := []
	var prev_x := Vector3.ZERO
	for i in count:
		var tangent: Vector3
		if i == 0:
			tangent = points[1] - points[0]
		elif i == count - 1:
			tangent = points[i] - points[i - 1]
		else:
			tangent = points[i + 1] - points[i - 1]
		tangent = tangent.normalized()
		var x: Vector3
		if i == 0:
			var r0 := ref if absf(tangent.dot(ref)) < 0.9 else Vector3.RIGHT
			x = r0.cross(tangent).normalized()
		else:
			# carried along from the last ring, so the tube does not twist
			x = (prev_x - tangent * prev_x.dot(tangent)).normalized()
		prev_x = x
		var y := tangent.cross(x)
		if i > 0:
			along += points[i].distance_to(points[i - 1])
		var t2: Vector2 = Vector2.ZERO
		if t2s.size() == count:
			t2 = t2s[i]
		elif t2s.size() == 1:
			t2 = t2s[0]
		var ring := []
		for s in sides + 1:
			var a := TAU * s / sides
			var dir := x * cos(a) + y * sin(a)
			ring.append(vert(points[i] + dir * radii[i], dir, col, Vector2(float(s) / sides, along), t2))
		rings.append(ring)
	for i in count - 1:
		for s in sides:
			quad(rings[i][s], rings[i][s + 1], rings[i + 1][s + 1], rings[i + 1][s])
	if cap:
		for end in [0, count - 1]:
			var tangent := (points[mini(end + 1, count - 1)] - points[maxi(end - 1, 0)]).normalized() * (-1.0 if end == 0 else 1.0)
			var t2: Vector2 = Vector2.ZERO if t2s.is_empty() else (t2s[end] if t2s.size() == count else t2s[0])
			var mid := vert(points[end], tangent, col, Vector2.ZERO, t2)
			var ids := []
			for s in sides + 1:
				ids.append(vert(v[rings[end][s]], tangent, col, Vector2.ZERO, t2))
			for s in sides:
				tri(mid, ids[s], ids[s + 1])


func cylinder(a: Vector3, b: Vector3, r0: float, r1: float, sides: int, col: Color, t2 := Vector2.ZERO, cap := true) -> void:
	tube(PackedVector3Array([a, b]), PackedFloat32Array([r0, r1]), sides, col, [t2], cap)


## Turned on a lathe: `profile` is (radius, height) from the bottom up, stood at `xf`.
func lathe(xf: Transform3D, profile: Array, sides: int, col: Color, t2 := Vector2.ZERO) -> void:
	var rings := []
	for i in profile.size():
		var pr: Vector2 = profile[i]
		# the normal: across the profile's slope
		var a: Vector2 = profile[maxi(i - 1, 0)]
		var b: Vector2 = profile[mini(i + 1, profile.size() - 1)]
		var slope := (b - a).normalized()
		var out := Vector2(slope.y, -slope.x)
		var ring := []
		for s in sides + 1:
			var ang := TAU * s / sides
			var dir := Vector3(cos(ang), 0.0, sin(ang))
			var p := dir * pr.x + Vector3.UP * pr.y
			var nn := (dir * out.x + Vector3.UP * out.y).normalized()
			ring.append(vert(xf * p, (xf.basis * nn).normalized(), col, Vector2(float(s) / sides, pr.y), t2))
		rings.append(ring)
	for i in profile.size() - 1:
		for s in sides:
			quad(rings[i][s], rings[i][s + 1], rings[i + 1][s + 1], rings[i + 1][s])


## An ellipsoid of half-sizes `r` at `xf`.
func blob(xf: Transform3D, r: Vector3, col: Color, rings := 6, segs := 8, t2 := Vector2.ZERO) -> void:
	var rows := []
	for i in rings + 1:
		var lat := PI * float(i) / rings - PI * 0.5
		var row := []
		for s in segs + 1:
			var lon := TAU * s / segs
			var unit := Vector3(cos(lat) * cos(lon), sin(lat), cos(lat) * sin(lon))
			var p := unit * r
			var nn := Vector3(unit.x / r.x, unit.y / r.y, unit.z / r.z).normalized()
			row.append(vert(xf * p, (xf.basis * nn).normalized(), col, Vector2(float(s) / segs, float(i) / rings), t2))
		rows.append(row)
	for i in rings:
		for s in segs:
			quad(rows[i][s], rows[i][s + 1], rows[i + 1][s + 1], rows[i + 1][s])


## A flat card: middle `at`, sides `right` and `up` (half-sizes), facing `right x up`.
func card(at: Vector3, right: Vector3, up: Vector3, col: Color, t2 := Vector2.ZERO) -> void:
	var nn := right.cross(up).normalized()
	var a := vert(at - right - up, nn, col, Vector2(0, 1), t2)
	var b := vert(at + right - up, nn, col, Vector2(1, 1), t2)
	var d := vert(at + right + up, nn, col, Vector2(1, 0), t2)
	var e := vert(at - right + up, nn, col, Vector2(0, 0), t2)
	quad(a, b, d, e)


func mesh() -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = n
	arrays[Mesh.ARRAY_COLOR] = c
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	if v.size() > 0:
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m
