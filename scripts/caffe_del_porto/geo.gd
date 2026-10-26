extends RefCounted
## Geometry gathered from code into one surface: boxes, lathed shapes, blobs and quads, each with its own
## vertex colour and a "kind" (UV2.x) the shaders paint by (see shaders/caffe_del_porto/lit.gdshaderinc).
## UV is metres across a face (for windows, tiles and stripes), UV2.y a number of the shape's own.
## Front faces are wound clockwise, as Godot wants.

var verts := PackedVector3Array()
var norms := PackedVector3Array()
var cols := PackedColorArray()
var uvs := PackedVector2Array()
var uv2s := PackedVector2Array()


func is_empty() -> bool:
	return verts.is_empty()


func _v(p: Vector3, n: Vector3, c: Color, uv: Vector2, uv2: Vector2) -> void:
	verts.append(p)
	norms.append(n)
	cols.append(c)
	uvs.append(uv)
	uv2s.append(uv2)


## A triangle, its corners counter-clockwise as seen from the front, with a normal each.
func tri(a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3, col: Color,
		kind := 0.0, extra := 0.0, ua := Vector2.ZERO, ub := Vector2.ZERO, uc := Vector2.ZERO) -> void:
	var k := Vector2(kind, extra)
	_v(a, na.normalized(), col, ua, k)
	_v(c, nc.normalized(), col, uc, k)
	_v(b, nb.normalized(), col, ub, k)


## A flat quad, corners counter-clockwise from the front; UV in metres from `a` along a->b and a->d.
func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, kind := 0.0, extra := 0.0) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-12:
		n = (c - b).cross(d - b)
	n = n.normalized()
	var w := a.distance_to(b)
	var h := a.distance_to(d)
	tri(a, b, c, n, n, n, col, kind, extra, Vector2(0, 0), Vector2(w, 0), Vector2(w, h))
	tri(a, c, d, n, n, n, col, kind, extra, Vector2(0, 0), Vector2(w, h), Vector2(0, h))


## A box: `xf` places its middle, `size` is its full size. `faces` can leave some out (by name:
## "top", "bottom", "front" (-Z), "back", "left" (-X), "right"). Per-face kinds override `kind`.
func box(xf: Transform3D, size: Vector3, col: Color, kind := 0.0, extra := 0.0, skip := [], kinds := {}, colors := {}) -> void:
	var h := size * 0.5
	var b := xf.basis
	var o := xf.origin
	var faces := {
		"right": [Vector3(h.x, 0, 0), Vector3(0, 0, -h.z), Vector3(0, h.y, 0)],
		"left": [Vector3(-h.x, 0, 0), Vector3(0, 0, h.z), Vector3(0, h.y, 0)],
		"back": [Vector3(0, 0, h.z), Vector3(h.x, 0, 0), Vector3(0, h.y, 0)],
		"front": [Vector3(0, 0, -h.z), Vector3(-h.x, 0, 0), Vector3(0, h.y, 0)],
		"top": [Vector3(0, h.y, 0), Vector3(h.x, 0, 0), Vector3(0, 0, -h.z)],
		"bottom": [Vector3(0, -h.y, 0), Vector3(h.x, 0, 0), Vector3(0, 0, h.z)],
	}
	for name in faces:
		if name in skip:
			continue
		var f: Array = faces[name]
		var c: Vector3 = b * f[0] + o
		var u: Vector3 = b * f[1]
		var v: Vector3 = b * f[2]
		quad(c - u - v, c + u - v, c + u + v, c - u + v, colors.get(name, col), kinds.get(name, kind), extra)


## A shape turned round the Y axis from a profile of (radius, height) points, bottom to top.
func lathe(xf: Transform3D, profile: Array, sides: int, col: Color, kind := 0.0, extra := 0.0, smooth := true) -> void:
	var n := profile.size()
	var pn: Array[Vector2] = []
	for i in n:
		var a: Vector2 = profile[maxi(i - 1, 0)]
		var b: Vector2 = profile[mini(i + 1, n - 1)]
		var t := (b - a).normalized()
		pn.append(Vector2(t.y, -t.x))  # outward
	for s in sides:
		var a0 := TAU * s / sides
		var a1 := TAU * (s + 1) / sides
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		for i in n - 1:
			var p: Vector2 = profile[i]
			var q: Vector2 = profile[i + 1]
			var v00 := d0 * p.x + Vector3.UP * p.y
			var v01 := d1 * p.x + Vector3.UP * p.y
			var v10 := d0 * q.x + Vector3.UP * q.y
			var v11 := d1 * q.x + Vector3.UP * q.y
			var n00: Vector3
			var n01: Vector3
			var n10: Vector3
			var n11: Vector3
			if smooth:
				n00 = d0 * pn[i].x + Vector3.UP * pn[i].y
				n01 = d1 * pn[i].x + Vector3.UP * pn[i].y
				n10 = d0 * pn[i + 1].x + Vector3.UP * pn[i + 1].y
				n11 = d1 * pn[i + 1].x + Vector3.UP * pn[i + 1].y
			else:
				var dm := (d0 + d1).normalized()
				var t := (q - p).normalized()
				var fn := dm * t.y + Vector3.UP * -t.x
				n00 = fn
				n01 = fn
				n10 = fn
				n11 = fn
			var bn := xf.basis.inverse().transposed()
			var uv0 := Vector2(float(s) / sides * TAU * p.x, p.y)
			var uv1 := Vector2(float(s + 1) / sides * TAU * p.x, p.y)
			var uv2 := Vector2(float(s) / sides * TAU * q.x, q.y)
			var uv3 := Vector2(float(s + 1) / sides * TAU * q.x, q.y)
			# seen from outside, up the profile then round to the next angle runs counter-clockwise
			if p.x > 0.0001 or q.x > 0.0001:
				tri(xf * v00, xf * v10, xf * v11, bn * n00, bn * n10, bn * n11, col, kind, extra, uv0, uv2, uv3)
				tri(xf * v00, xf * v11, xf * v01, bn * n00, bn * n11, bn * n01, col, kind, extra, uv0, uv3, uv1)


## A rounded lump: a sphere of `rings` bands squashed to `size` (full size).
func blob(xf: Transform3D, size: Vector3, col: Color, kind := 0.0, extra := 0.0, rings := 4, sides := 6) -> void:
	var prof := []
	for i in rings + 1:
		var a := PI * (float(i) / rings - 0.5)
		prof.append(Vector2(cos(a) * 0.5, sin(a) * 0.5))
	var s := Transform3D(Basis.from_scale(size), Vector3.ZERO)
	lathe(xf * s, prof, sides, col, kind, extra)


## A cylinder from `a` to `b` (a thin limb, a pole, a leg).
func rod(a: Vector3, b: Vector3, r: float, col: Color, kind := 0.0, sides := 5, r2 := -1.0, extra := 0.0) -> void:
	var up := b - a
	var len := up.length()
	if len < 0.0001:
		return
	var y := up / len
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	var xf := Transform3D(Basis(x, y, z), a)
	lathe(xf, [Vector2(r, 0.0), Vector2(r2 if r2 >= 0.0 else r, len)], sides, col, kind, extra)


func mesh(into: ArrayMesh = null) -> ArrayMesh:
	var m := into if into else ArrayMesh.new()
	if verts.is_empty():
		return m
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


func clear() -> void:
	verts = PackedVector3Array()
	norms = PackedVector3Array()
	cols = PackedColorArray()
	uvs = PackedVector2Array()
	uv2s = PackedVector2Array()
