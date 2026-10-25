extends RefCounted
## Builds one tree's wood (trunk and branches) as a mesh, and says where its leaves go. Branches mostly
## reach towards +X, so a tree turned to face the path leans its crown out over it.
##
## The mesh has UV.x round the wood, UV.y up it in metres and COLOR.r for how far out it is (bark.gdshader).

const SIDES := 7

var st: SurfaceTool
## Where the leaf clumps go: Vector4(x, y, z, size) in the tree's own space.
var crowns: Array[Vector4] = []


## A trunk `height` tall and `radius` thick at the foot; `reach` is how far the branches go out.
func build(rng: RandomNumberGenerator, height: float, radius: float, reach: float, bare := false, branches := true, tip := 0.18) -> ArrayMesh:
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	crowns.clear()
	# the trunk: a gentle bend, a flared foot
	var bend := Vector3(rng.randf_range(-0.5, 0.9), 0.0, rng.randf_range(-0.5, 0.5)) * height * 0.06
	var pts: Array[Vector3] = []
	var radii: Array[float] = []
	var steps := 9
	for i in steps + 1:
		var t := float(i) / steps
		var p := Vector3(0.0, t * height, 0.0) + bend * t * t
		p += Vector3(rng.randf_range(-0.1, 0.1), 0.0, rng.randf_range(-0.1, 0.1)) * radius * float(i > 0)
		pts.append(p)
		var r := radius * lerpf(1.0, tip, pow(t, 0.8))
		if i == 0:
			r *= 1.5
		radii.append(r)
	_tube(pts, radii, 0.0, 0.5, true)
	if not bare:
		crowns.append(Vector4(pts[-1].x, pts[-1].y + 0.4, pts[-1].z, 1.6 + reach * 0.15))
	# branches off the upper trunk
	var count := rng.randi_range(4, 7) if branches else 0
	for b in count:
		var t := rng.randf_range(0.38, 0.88)
		var at := _along(pts, t)
		var out_angle := rng.randf_range(-1.2, 1.2) if rng.randf() < 0.75 else rng.randf_range(2.0, 4.3)
		var dir := Vector3(cos(out_angle), rng.randf_range(0.35, 1.0), sin(out_angle)).normalized()
		var length := reach * rng.randf_range(0.55, 1.0) * lerpf(1.1, 0.6, t)
		if absf(out_angle) > 1.6:
			length *= 0.6
		_branch(rng, at, dir, length, radius * lerpf(0.55, 0.3, t), 0.5 + t * 0.3, bare, 0)
	return st.commit()


func _branch(rng: RandomNumberGenerator, from: Vector3, dir: Vector3, length: float, radius: float, outness: float, bare: bool, depth: int) -> void:
	var pts: Array[Vector3] = []
	var radii: Array[float] = []
	var p := from
	var d := dir
	var steps := 4
	for i in steps + 1:
		pts.append(p)
		radii.append(radius * lerpf(1.0, 0.15, float(i) / steps))
		# droop a little under its own weight, and wander
		d = (d + Vector3(rng.randf_range(-0.25, 0.25), -0.08, rng.randf_range(-0.25, 0.25))).normalized()
		p += d * length / steps
	_tube(pts, radii, outness, 1.0, false)
	if depth < 1 and length > 1.5:
		for k in rng.randi_range(1, 2):
			var t := rng.randf_range(0.4, 0.8)
			var at := _along(pts, t)
			var nd := (dir + Vector3(rng.randf_range(-0.8, 0.8), rng.randf_range(0.1, 0.6), rng.randf_range(-0.8, 0.8))).normalized()
			_branch(rng, at, nd, length * 0.5, radius * 0.45, outness + 0.2, bare, depth + 1)
	if bare:
		return
	# leaves along the outer half and at the tip
	var clumps := 1 + int(length / 1.6)
	for k in clumps:
		var t := lerpf(0.5, 1.0, float(k + 1) / clumps)
		var c := _along(pts, t)
		crowns.append(Vector4(c.x, c.y + 0.2, c.z, lerpf(0.9, 1.6, rng.randf()) * (1.0 if depth == 0 else 0.8)))


func _along(pts: Array[Vector3], t: float) -> Vector3:
	var f := t * (pts.size() - 1)
	var i := mini(int(f), pts.size() - 2)
	return pts[i].lerp(pts[i + 1], f - i)


# A tube through `pts`, thinning by `radii`, rings of SIDES; a cap on the far end
func _tube(pts: Array[Vector3], radii: Array[float], out0: float, out1: float, flare: bool) -> void:
	var rings: Array = []
	var v := 0.0
	for i in pts.size():
		var fwd: Vector3
		if i == 0:
			fwd = pts[1] - pts[0]
		elif i == pts.size() - 1:
			fwd = pts[i] - pts[i - 1]
		else:
			fwd = pts[i + 1] - pts[i - 1]
		fwd = fwd.normalized()
		var side := fwd.cross(Vector3.FORWARD if absf(fwd.z) < 0.9 else Vector3.RIGHT).normalized()
		var up := side.cross(fwd).normalized()
		if i > 0:
			v += pts[i].distance_to(pts[i - 1])
		var ring: Array = []
		for s in SIDES + 1:
			var a := TAU * s / SIDES
			var r: float = radii[i]
			if flare and i == 0:
				r *= 1.0 + 0.25 * sin(a * 3.0)
			var radial := side * cos(a) + up * sin(a)
			ring.append([pts[i] + radial * r, Vector2(float(s) / SIDES, v), radial])
		rings.append(ring)
	for i in rings.size() - 1:
		var o0 := lerpf(out0, out1, float(i) / (rings.size() - 1))
		var o1 := lerpf(out0, out1, float(i + 1) / (rings.size() - 1))
		for s in SIDES:
			var a: Array = rings[i][s]
			var b: Array = rings[i][s + 1]
			var c: Array = rings[i + 1][s]
			var d: Array = rings[i + 1][s + 1]
			_vert(a, o0); _vert(c, o1); _vert(b, o0)
			_vert(b, o0); _vert(c, o1); _vert(d, o1)


func _vert(rv: Array, outness: float) -> void:
	st.set_color(Color(outness, 0, 0))
	st.set_uv(rv[1])
	st.set_normal(rv[2])
	st.add_vertex(rv[0])
