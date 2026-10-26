extends RefCounted
## A little mesh builder for The Velvet Moth: boxes, tapered prisms, spheres, lathes and tubes, all into one
## set of arrays (positions, normals, vertex colours, UVs), made into one ArrayMesh at the end, so a whole
## material's worth of the room is one draw.

var verts := PackedVector3Array()
var normals := PackedVector3Array()
var colors := PackedColorArray()
var uvs := PackedVector2Array()
var indices := PackedInt32Array()


func _v(p: Vector3, n: Vector3, c: Color, uv := Vector2.ZERO) -> int:
	verts.append(p)
	normals.append(n)
	colors.append(c)
	uvs.append(uv)
	return verts.size() - 1


func tri(a: int, b: int, c: int) -> void:
	indices.append(a)
	indices.append(b)
	indices.append(c)


## A flat quad a-b-c-d (counter-clockwise seen from the front), facing n.
func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, col: Color, uv0 := Vector2(0, 1), uv1 := Vector2(1, 0)) -> void:
	var i := _v(a, n, col, Vector2(uv0.x, uv0.y))
	_v(b, n, col, Vector2(uv1.x, uv0.y))
	_v(c, n, col, Vector2(uv1.x, uv1.y))
	_v(d, n, col, Vector2(uv0.x, uv1.y))
	tri(i, i + 2, i + 1)
	tri(i, i + 3, i + 2)


## A box from its two corners (axis aligned), or turned by `basis` about its middle.
func box(lo: Vector3, hi: Vector3, col: Color, basis := Basis(), skip_bottom := false) -> void:
	var mid := (lo + hi) * 0.5
	var h := (hi - lo) * 0.5
	var p := func(x: float, y: float, z: float) -> Vector3: return mid + basis * Vector3(h.x * x, h.y * y, h.z * z)
	var X := basis.x.normalized()
	var Y := basis.y.normalized()
	var Z := basis.z.normalized()
	quad(p.call(-1, -1, 1), p.call(1, -1, 1), p.call(1, 1, 1), p.call(-1, 1, 1), Z, col)
	quad(p.call(1, -1, -1), p.call(-1, -1, -1), p.call(-1, 1, -1), p.call(1, 1, -1), -Z, col)
	quad(p.call(1, -1, 1), p.call(1, -1, -1), p.call(1, 1, -1), p.call(1, 1, 1), X, col)
	quad(p.call(-1, -1, -1), p.call(-1, -1, 1), p.call(-1, 1, 1), p.call(-1, 1, -1), -X, col)
	quad(p.call(-1, 1, 1), p.call(1, 1, 1), p.call(1, 1, -1), p.call(-1, 1, -1), Y, col)
	if not skip_bottom:
		quad(p.call(-1, -1, -1), p.call(1, -1, -1), p.call(1, -1, 1), p.call(-1, -1, 1), -Y, col)


## A tapered prism (a limb, a post, a lamp shade) from a to b: radii r0 at a and r1 at b, `sides` round,
## squashed to `depth` front to back. `caps` closes the ends. UV.y runs 0 at a to 1 at b.
func prism(a: Vector3, b: Vector3, r0: float, r1: float, sides: int, col: Color, caps := true, depth := 1.0, col_b := Color(-1, 0, 0)) -> void:
	var axis := (b - a).normalized()
	var side := axis.cross(Vector3.FORWARD if absf(axis.z) < 0.9 else Vector3.RIGHT).normalized()
	if absf(axis.y) > 0.9:
		side = Vector3.RIGHT
	var fwd := side.cross(axis).normalized()
	var cb := col if col_b.r < 0.0 else col_b
	var start := verts.size()
	for k in sides + 1:
		var ang := TAU * k / sides
		var dir := side * cos(ang) + fwd * sin(ang) * depth
		var n := (side * cos(ang) + fwd * sin(ang) / maxf(depth, 0.01)).normalized()
		var slope := (r0 - r1) / maxf(a.distance_to(b), 0.001)
		n = (n + axis * slope).normalized()
		_v(a + dir * r0, n, col, Vector2(float(k) / sides, 0.0))
		_v(b + dir * r1, n, cb, Vector2(float(k) / sides, 1.0))
	for k in sides:
		var i := start + k * 2
		tri(i, i + 3, i + 1)
		tri(i, i + 2, i + 3)
	if caps:
		var ca := _v(a, -axis, col, Vector2(0.5, 0.0))
		var cbi := _v(b, axis, cb, Vector2(0.5, 1.0))
		for k in sides:
			var ang0 := TAU * k / sides
			var ang1 := TAU * (k + 1) / sides
			var d0 := side * cos(ang0) + fwd * sin(ang0) * depth
			var d1 := side * cos(ang1) + fwd * sin(ang1) * depth
			var i0 := _v(a + d0 * r0, -axis, col)
			var i1 := _v(a + d1 * r0, -axis, col)
			tri(ca, i1, i0)
			var j0 := _v(b + d0 * r1, axis, cb)
			var j1 := _v(b + d1 * r1, axis, cb)
			tri(cbi, j0, j1)


## A low sphere (or an egg, with `squash`).
func sphere(c: Vector3, r: float, lon: int, lat: int, col: Color, squash := Vector3.ONE) -> void:
	var start := verts.size()
	for j in lat + 1:
		var v := float(j) / lat
		var phi := PI * v
		for i in lon + 1:
			var u := float(i) / lon
			var th := TAU * u
			var n := Vector3(sin(phi) * cos(th), cos(phi), sin(phi) * sin(th))
			_v(c + n * r * squash, (n / squash).normalized(), col, Vector2(u, v))
	for j in lat:
		for i in lon:
			var a := start + j * (lon + 1) + i
			var b := a + lon + 1
			tri(a, b, a + 1)
			tri(a + 1, b, b + 1)


## A shape turned on a lathe round the Y axis: profile is (radius, height) from the bottom up.
func lathe(c: Vector3, profile: PackedVector2Array, sides: int, col: Color) -> void:
	var start := verts.size()
	for j in profile.size():
		var p := profile[j]
		var t := profile[mini(j + 1, profile.size() - 1)] - profile[maxi(j - 1, 0)]
		var n2 := Vector2(t.y, -t.x).normalized()
		for i in sides + 1:
			var th := TAU * i / sides
			var dir := Vector3(cos(th), 0, sin(th))
			_v(c + dir * p.x + Vector3.UP * p.y, (dir * n2.x + Vector3.UP * n2.y).normalized(), col,
				Vector2(float(i) / sides, float(j) / (profile.size() - 1)))
	for j in profile.size() - 1:
		for i in sides:
			var a := start + j * (sides + 1) + i
			var b := a + sides + 1
			tri(a, a + 1, b)
			tri(a + 1, b + 1, b)


## A round tube along a polyline (neon, rails). UV.x is `group` (the shader's business), UV.y how far along.
func tube(points: PackedVector3Array, r: float, sides: int, col: Color, group := 0.0, closed := false) -> void:
	var pts := points.duplicate()
	if closed:
		pts.append(points[0])
	var n := pts.size()
	var start := verts.size()
	var prev_side := Vector3.ZERO
	for j in n:
		var t: Vector3
		if closed and (j == 0 or j == n - 1):
			t = (pts[1] - pts[n - 2]).normalized()
		else:
			t = (pts[mini(j + 1, n - 1)] - pts[maxi(j - 1, 0)]).normalized()
		var side := t.cross(Vector3.BACK if absf(t.z) < 0.9 else Vector3.UP).normalized()
		if prev_side != Vector3.ZERO and side.dot(prev_side) < 0.0:
			side = -side
		prev_side = side
		var up := side.cross(t).normalized()
		for i in sides + 1:
			var th := TAU * i / sides
			var d := side * cos(th) + up * sin(th)
			_v(pts[j] + d * r, d, col, Vector2(group, float(j) / (n - 1)))
	for j in n - 1:
		for i in sides:
			var a := start + j * (sides + 1) + i
			var b := a + sides + 1
			tri(a, a + 1, b)
			tri(a + 1, b + 1, b)


func is_empty() -> bool:
	return verts.is_empty()


func commit() -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
