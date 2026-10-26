extends Node3D
## The harbour and the sea: the water and what it reflects, the wooden fishing boats (gozzi) moored along
## the quays and out on the water, bobbing, one puttering about out past the breakwater; the breakwater
## and its light; people walking the quays (GameCommon's Figures, dressed by its CharacterLook); a ferry
## and sails far out; gulls wheeling over it all.

const Geo := preload("res://scripts/caffe_del_porto/geo.gd")
const SEA_SHADER := preload("res://shaders/caffe_del_porto/sea.gdshader")
const UNDER := preload("res://shaders/caffe_del_porto/sea_under.gdshader")
const REFLECT := preload("res://shaders/caffe_del_porto/reflect.gdshader")

const TRIMS := [Color(0.12, 0.35, 0.68), Color(0.15, 0.5, 0.35), Color(0.75, 0.18, 0.15), Color(0.95, 0.75, 0.2),
	Color(0.35, 0.65, 0.85), Color(0.1, 0.2, 0.4)]
## The breakwater, from the end of the right headland out across the harbour's mouth.
const MOLE_A := Vector3(36.0, 0.0, -97.0)
const MOLE_B := Vector3(-2.0, 0.0, -113.0)

var place: Node3D
var rng := RandomNumberGenerator.new()
var sea: float
var reflect_mat: ShaderMaterial
## The boats: where each lies (x, z), which way, its bob's own time, and two MultiMeshes (above, reflected).
var boats: Array = []
var boat_mm: MultiMesh
var boat_ref_mm: MultiMesh
## The people strolling the quays: their Figure, the two ends of their stroll, which way, a pause.
var walkers: Array = []
var ferry: Node3D
var sails: Array[Node3D] = []
var gulls: Array = []
var gull_mm: MultiMesh
var _t := 0.0

const FLIP := Basis(Vector3(1, 0, 0), Vector3(0, -1, 0), Vector3(0, 0, 1))


func build(p: Node3D) -> void:
	place = p
	sea = place.SEA
	rng.seed = 3131
	reflect_mat = place._mat(REFLECT, {"sun_dir": place.SUN_DIR.normalized(), "sea_level": sea})
	_sea()
	_reflections()
	_breakwater()
	_boats()
	_walkers()
	_far_off()
	_gulls()


# --- the water ---

func _sea() -> void:
	var xs: PackedFloat32Array = place._spread(60, -460.0, 640.0)
	var zs: PackedFloat32Array = place._spread(60, -690.0, 4.0)
	var nx := xs.size()
	var nz := zs.size()
	var pts := PackedVector3Array()
	var cols := PackedColorArray()
	var land := PackedFloat32Array()
	pts.resize(nx * nz)
	cols.resize(nx * nz)
	land.resize(nx * nz)
	for j in nz:
		for i in nx:
			var x := xs[i]
			var z := zs[j]
			var d: Vector3 = place.into(x, z)
			var qw: Vector3 = place.quay_w(z)
			# rocky shallows and surf under the cliffs, none along the quays' walls
			var cliff_l := d.x if qw.x < 0.5 else -INF
			var cliff_r := d.y if qw.y < 0.5 else -INF
			var rock := maxf(cliff_l, cliff_r)
			var mole := _mole_dist(x, z)
			var shallow := smoothstep(-16.0, -1.0, rock) * 0.75
			shallow = maxf(shallow, smoothstep(9.0, 1.5, mole) * 0.6)
			# the harbour floor shows a little through the water inside the breakwater
			if z > -100.0 and d.x < 0.0 and d.y < 0.0:
				shallow = maxf(shallow, 0.18 + 0.12 * smoothstep(-40.0, -4.0, maxf(d.x, maxf(d.y, d.z))))
			var foam := maxf(smoothstep(-3.5, -0.3, rock), smoothstep(3.5, 1.0, mole))
			pts[j * nx + i] = Vector3(x, sea, z)
			cols[j * nx + i] = Color(shallow, foam, 0.0)
			land[j * nx + i] = place.height(x, z)
	var idx := PackedInt32Array()
	for j in nz - 1:
		for i in nx - 1:
			var a := j * nx + i
			var b := a + 1
			var c := a + nx
			var d := c + 1
			if minf(minf(land[a], land[b]), minf(land[c], land[d])) > sea + 1.5:
				continue
			idx.append_array([a, b, d, a, d, c])
	var nrm := PackedVector3Array()
	nrm.resize(pts.size())
	nrm.fill(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = pts
	arrays[Mesh.ARRAY_NORMAL] = nrm
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	# the glitter's sun: lower than the real one and more ahead, so its path lies out where you look
	var sd: Vector3 = place.SUN_DIR
	var glint := Vector3(sd.x * 0.06, 0.06, sd.z).normalized()
	mi.material_override = place._mat(SEA_SHADER, {"glint_dir": glint})
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	# far under it, the sky as the sea shows it
	var under := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(2400, 2400)
	under.mesh = pm
	under.position = Vector3(0, sea - 60.0, -300.0)
	under.material_override = place._mat(UNDER)
	under.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(under)


func _mole_dist(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var a := Vector2(MOLE_A.x, MOLE_A.z)
	var b := Vector2(MOLE_B.x, MOLE_B.z)
	var t := clampf((p - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
	return p.distance_to(a + (b - a) * t)


## The houses along the quays, the church and the land, turned over under the water.
func _reflections() -> void:
	var mirror := Transform3D(FLIP, Vector3(0, 2.0 * sea, 0))
	for m in place.reflect + place.reflect_lit:
		var mi := MeshInstance3D.new()
		mi.mesh = m
		mi.transform = mirror
		mi.material_override = reflect_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
	var land_ref := MeshInstance3D.new()
	land_ref.mesh = place.land_mesh
	land_ref.transform = mirror
	land_ref.material_override = place._mat(REFLECT, {"sun_dir": place.SUN_DIR.normalized(), "sea_level": sea, "tint": Color(0.3, 0.38, 0.3), "reach": 14.0})
	land_ref.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(land_ref)


# --- the breakwater and its light ---

func _breakwater() -> void:
	var g := Geo.new()
	var n := int(MOLE_A.distance_to(MOLE_B) / 1.5)
	var side := (MOLE_B - MOLE_A).cross(Vector3.UP).normalized()
	for i in n + 1:
		var t := float(i) / n
		var c := MOLE_A.lerp(MOLE_B, t)
		for row in [-1.6, 0.0, 1.6]:
			var s := Vector3(rng.randf_range(1.6, 2.6), rng.randf_range(1.2, 2.0), rng.randf_range(1.5, 2.4))
			var at: Vector3 = c + side * (row + rng.randf_range(-0.4, 0.4)) + Vector3(rng.randf_range(-0.4, 0.4), sea + 0.2 + (0.6 if row == 0.0 else 0.0) + rng.randf_range(-0.3, 0.2), 0)
			var b := Basis(Vector3(rng.randf(), rng.randf(), rng.randf()).normalized(), rng.randf_range(0.2, 0.6))
			g.box(Transform3D(b, at), s, Color(0.74, 0.72, 0.66) * rng.randf_range(0.85, 1.08), 0.0)
	# a walkway along its top, on the harbour side
	var len := MOLE_A.distance_to(MOLE_B)
	var dir := (MOLE_B - MOLE_A).normalized()
	var yaw := atan2(-dir.x, -dir.z)
	g.box(Transform3D(Basis(Vector3.UP, yaw), (MOLE_A + MOLE_B) * 0.5 + Vector3(0, sea + 1.9, 0) - side * 0.4), Vector3(2.2, 0.5, len), Color(0.8, 0.78, 0.72), 7.0)
	# the light at its end: a white tower with a red top
	var lt := MOLE_B + Vector3(0, sea + 2.1, 0) - dir * 0.8
	g.lathe(Transform3D(Basis(), lt), [Vector2(0.0, 0.0), Vector2(1.3, 0.0), Vector2(1.3, 0.6), Vector2(0.95, 0.6)], 10, Color(0.85, 0.83, 0.78), 7.0)
	g.lathe(Transform3D(Basis(), lt), [Vector2(0.95, 0.6), Vector2(0.75, 5.0), Vector2(0.0, 5.0)], 10, Color(0.97, 0.96, 0.93), 11.0)
	g.lathe(Transform3D(Basis(), lt + Vector3(0, 3.2, 0)), [Vector2(0.84, 0.0), Vector2(0.78, 1.8), Vector2(0.0, 1.8)], 10, Color(0.8, 0.15, 0.12), 3.0)
	g.lathe(Transform3D(Basis(), lt + Vector3(0, 5.0, 0)), [Vector2(0.0, 0.0), Vector2(0.5, 0.0), Vector2(0.5, 0.9), Vector2(0.6, 0.9), Vector2(0.0, 1.5)], 8, Color(0.25, 0.25, 0.28), 3.0)
	g.lathe(Transform3D(Basis(), lt + Vector3(0, 5.05, 0)), [Vector2(0.52, 0.0), Vector2(0.52, 0.8)], 8, Color(0.85, 0.3, 0.2), 3.0)
	var mi: MeshInstance3D = place.put(g, place.lit_still, false, self)
	var ref := MeshInstance3D.new()
	ref.mesh = mi.mesh
	ref.transform = Transform3D(FLIP, Vector3(0, 2.0 * sea, 0))
	ref.material_override = reflect_mat
	ref.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ref)


# --- the boats ---

func _hull() -> ArrayMesh:
	var g := Geo.new()
	var L := 5.6
	var n := 14
	var white := Color(0.95, 0.94, 0.9)
	var trim := Color(1, 1, 1, 0)
	var bottom := Color(0.5, 0.17, 0.13)
	var inside := Color(0.6, 0.66, 0.68)
	var wood := Color(0.55, 0.38, 0.22)
	var sections: Array = []
	for i in n + 1:
		var t := float(i) / n
		var e := absf(2.0 * t - 1.0)
		var w := 0.95 * pow(maxf(sin(PI * t), 0.0), 0.62)
		var top := 0.4 + 0.24 * pow(e, 2.4)
		var keel := -0.32 + 0.22 * pow(e, 3.0)
		var z := -L * 0.5 + t * L
		var ring: Array = []
		# from the keel round to the gunwale, one side (x >= 0)
		for k in 6:
			var a := PI * 0.5 * k / 5.0
			ring.append(Vector3(w * pow(sin(a), 0.7), keel + (top - keel) * (1.0 - cos(a)), z))
		sections.append(ring)
	for side in [1.0, -1.0]:
		for i in n:
			for k in 5:
				var p00: Vector3 = sections[i][k] * Vector3(side, 1, 1)
				var p01: Vector3 = sections[i][k + 1] * Vector3(side, 1, 1)
				var p10: Vector3 = sections[i + 1][k] * Vector3(side, 1, 1)
				var p11: Vector3 = sections[i + 1][k + 1] * Vector3(side, 1, 1)
				var mid_y := (p00.y + p11.y) * 0.5
				var c := white
				if mid_y < 0.0:
					c = bottom
				elif k == 4:
					c = trim
				# outside: for x > 0, seen from +X, z runs right to left
				if side > 0.0:
					g.quad(p10, p00, p01, p11, c, 0.0)
					g.quad(p00 * Vector3(0.94, 1, 1) + Vector3(0, 0.02, 0), p10 * Vector3(0.94, 1, 1) + Vector3(0, 0.02, 0), p11 * Vector3(0.94, 1, 1), p01 * Vector3(0.94, 1, 1), inside, 0.0)
				else:
					g.quad(p00, p10, p11, p01, c, 0.0)
					g.quad(p10 * Vector3(0.94, 1, 1) + Vector3(0, 0.02, 0), p00 * Vector3(0.94, 1, 1) + Vector3(0, 0.02, 0), p01 * Vector3(0.94, 1, 1), p11 * Vector3(0.94, 1, 1), inside, 0.0)
			# the gunwale's cap
			var a: Vector3 = sections[i][5] * Vector3(side, 1, 1)
			var b: Vector3 = sections[i + 1][5] * Vector3(side, 1, 1)
			if side > 0.0:
				g.quad(a * Vector3(0.94, 1, 1), b * Vector3(0.94, 1, 1), b + Vector3(0, 0.02, 0), a + Vector3(0, 0.02, 0), wood, 9.0)
			else:
				g.quad(b * Vector3(0.94, 1, 1), a * Vector3(0.94, 1, 1), a + Vector3(0, 0.02, 0), b + Vector3(0, 0.02, 0), wood, 9.0)
	# floorboards, two thwarts, the stem and stern posts rising, a coil of rope, a box
	g.box(Transform3D(Basis(), Vector3(0, -0.12, 0)), Vector3(0.9, 0.04, L * 0.6), wood, 9.0)
	for tz in [-0.9, 0.7]:
		g.box(Transform3D(Basis(), Vector3(0, 0.25, tz)), Vector3(1.7, 0.05, 0.28), wood * 1.1, 9.0)
	g.rod(Vector3(0, 0.55, -L * 0.5 + 0.05), Vector3(0, 1.05, -L * 0.5 - 0.12), 0.05, trim, 0.0, 5)
	g.rod(Vector3(0, 0.55, L * 0.5 - 0.05), Vector3(0, 0.85, L * 0.5 + 0.06), 0.045, trim, 0.0, 5)
	g.lathe(Transform3D(Basis(), Vector3(0.3, -0.1, 1.4)), [Vector2(0.0, 0.0), Vector2(0.2, 0.0), Vector2(0.22, 0.08), Vector2(0.1, 0.1), Vector2(0.0, 0.08)], 8, Color(0.85, 0.75, 0.55), 12.0)
	g.box(Transform3D(Basis(Vector3.UP, 0.2), Vector3(-0.25, 0.0, -1.5)), Vector3(0.45, 0.3, 0.35), Color(0.3, 0.45, 0.65), 0.0)
	return g.mesh()


func _boats() -> void:
	var qz: float = place.QUAY_Z
	# stern-to along the left quay, bows out across the harbour
	var z := -7.0
	while z > -34.0:
		if rng.randf() < 0.82:
			boats.append({"at": Vector2(place.shore_l(z) + 3.7, z), "yaw": -PI * 0.5 + rng.randf_range(-0.12, 0.12)})
		z -= 2.5
	# along the head of the harbour, to the left of the terrace
	for x in [-19.5, -16.9, -13.0, -10.4]:
		boats.append({"at": Vector2(x, qz - 3.7), "yaw": rng.randf_range(-0.1, 0.1)})
	# along the right quay
	for zz in [-9.0, -11.6, -16.0]:
		boats.append({"at": Vector2(place.shore_r(zz) - 3.6, zz), "yaw": PI * 0.5 + rng.randf_range(-0.1, 0.1)})
	# on moorings out in the harbour, all lying to the breeze
	for p in [Vector2(3.5, -12.0), Vector2(-4.5, -19.0), Vector2(9.0, -26.0), Vector2(-1.0, -33.0), Vector2(14.0, -40.0),
			Vector2(-9.0, -48.0), Vector2(5.0, -58.0), Vector2(-3.0, -74.0)]:
		boats.append({"at": p, "yaw": 0.35 + rng.randf_range(-0.2, 0.2), "buoy": true})
	# one going about its business out past the breakwater
	boats.append({"at": Vector2(0, -150.0), "yaw": 0.0, "moving": true})
	var xfs: Array = []
	var customs: Array = []
	for i in boats.size():
		boats[i]["phase"] = rng.randf() * TAU
		xfs.append(_boat_xf(boats[i], 0.0))
		customs.append(TRIMS[i % TRIMS.size()])
	var mesh := _hull()
	boat_mm = place.many(mesh, xfs, place.lit_still, customs, true, self).multimesh
	var ref_xfs: Array = []
	for xf in xfs:
		ref_xfs.append(Transform3D(FLIP, Vector3(0, 2.0 * sea, 0)) * xf)
	boat_ref_mm = place.many(mesh, ref_xfs, reflect_mat, customs, false, self).multimesh
	# mooring buoys and the ropes to the quay
	var g := Geo.new()
	for b in boats:
		if b.has("buoy"):
			var bp: Vector2 = b.at
			var fwd := Vector2(-sin(b.yaw), -cos(b.yaw))
			var at := Vector3(bp.x + fwd.x * 4.2, sea, bp.y + fwd.y * 4.2)
			g.blob(Transform3D(Basis(), at), Vector3(0.45, 0.4, 0.45), Color(0.95, 0.5, 0.15) if rng.randf() < 0.5 else Color(0.95, 0.94, 0.9), 3.0, 0.0, 4, 8)
	place.put(g, place.lit_still, false, self)
	var ropes := Geo.new()
	for b in boats:
		if b.has("buoy") or b.has("moving"):
			continue
		var bp: Vector2 = b.at
		var back := Vector2(sin(b.yaw), cos(b.yaw))
		var stern := Vector3(bp.x + back.x * 2.7, sea + 0.6, bp.y + back.y * 2.7)
		var shore := Vector3(bp.x + back.x * 4.0, 0.15, bp.y + back.y * 4.0)
		var mid := (stern + shore) * 0.5 + Vector3(0, -0.25, 0)
		ropes.rod(stern, mid, 0.015, Color(0.8, 0.72, 0.55), 0.0, 3)
		ropes.rod(mid, shore, 0.015, Color(0.8, 0.72, 0.55), 0.0, 3)
	place.put(ropes, place.lit_still, false, self)


func _boat_xf(b: Dictionary, t: float) -> Transform3D:
	var ph: float = b.phase
	var at: Vector2 = b.at
	var yaw: float = b.yaw
	if b.has("moving"):
		# round a long loop out past the mouth, slowly
		var a := t * 0.012 + ph
		at = Vector2(sin(a) * 90.0 + 10.0, -170.0 + cos(a) * 28.0)
		yaw = atan2(-cos(a) * 90.0, sin(a) * 28.0)
	var bob := sin(t * 1.1 + ph) * 0.05 + sin(t * 0.7 + ph * 1.7) * 0.03
	var roll := sin(t * 0.9 + ph) * 0.045
	var pitch := sin(t * 0.75 + ph * 2.3) * 0.025
	var basis := Basis(Vector3.UP, yaw + sin(t * 0.13 + ph) * 0.04) * Basis(Vector3.FORWARD, roll) * Basis(Vector3.RIGHT, pitch)
	return Transform3D(basis, Vector3(at.x, sea + 0.02 + bob, at.y))


# --- people on the quays: GameCommon's Figures (the character controller's rig, CharacterLook) ---

## Ground for them to stand on (the Figures are bodies that fall): the quays and the breakwater's top.
func _ground() -> void:
	var body := StaticBody3D.new()
	add_child(body)
	var add := func(centre: Vector3, size: Vector3, yaw: float) -> void:
		var shape := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = size
		shape.shape = b
		shape.transform = Transform3D(Basis(Vector3.UP, yaw), centre)
		body.add_child(shape)
	var qz: float = place.QUAY_Z
	var fz: float = place.FRONT_Z
	add.call(Vector3(1.0, -0.25, (qz + fz) * 0.5), Vector3(62.0, 0.5, fz - qz), 0.0)
	var z := fz
	while z > -44.0:
		for side in [-1.0, 1.0]:
			var w: float = 6.5 if side < 0.0 else 5.5
			var xa: float = (place.shore_l(z) - w * 0.5) if side < 0.0 else (place.shore_r(z) + w * 0.5)
			var xb: float = (place.shore_l(z - 8.0) - w * 0.5) if side < 0.0 else (place.shore_r(z - 8.0) + w * 0.5)
			var a := Vector3(xa, -0.25, z)
			var b := Vector3(xb, -0.25, z - 8.0)
			add.call((a + b) * 0.5, Vector3(w, 0.5, 8.6), atan2(b.x - a.x, b.z - a.z))
		z -= 8.0
	var dir := (MOLE_B - MOLE_A).normalized()
	var side := dir.cross(Vector3.UP)
	add.call((MOLE_A + MOLE_B) * 0.5 + Vector3(0, sea + 1.9, 0) - side * 0.4, Vector3(2.2, 0.5, MOLE_A.distance_to(MOLE_B)), atan2(dir.x, dir.z))


## Someone in the town: a Figure dressed by CharacterLook (seeded), at a grown-up's size.
func _person(at: Vector3, yaw: float, seed: int) -> Figure:
	var look := CharacterLook.random(seed)
	var f := Figure.new()
	f.walk_speed = rng.randf_range(0.9, 1.25)
	f.dusty = false
	add_child(f)
	f.place(at, yaw)
	CharacterLook.apply(f.rig, look)
	var s := maxf(float(look.get("size", 1.35)), 1.3)
	var build := float(look.get("build", 1.0))
	f.rig.scale = Vector3(s * build, s, s * build)
	return f


func _walkers() -> void:
	_ground()
	# strolling to and fro along the quays, stopping now and then to look at the boats
	var segs := [
		[Vector2(-27.0, -1.0), Vector2(-8.0, -1.0)],
		[Vector2(-25.0, 2.6), Vector2(-9.0, 2.6)],
		[Vector2(place.shore_l(-4.0) - 2.5, -4.0), Vector2(place.shore_l(-34.0) - 2.5, -34.0)],
		[Vector2(place.shore_l(-2.0) - 4.5, -2.0), Vector2(place.shore_l(-30.0) - 4.5, -30.0)],
		[Vector2(place.shore_r(-3.0) + 2.5, -3.0), Vector2(place.shore_r(-40.0) + 2.5, -40.0)],
		[Vector2(11.0, -1.6), Vector2(22.0, -1.6)],
	]
	for i in segs.size():
		var s: Array = segs[i]
		var a: Vector2 = s[0]
		var b: Vector2 = s[1]
		var start := a.lerp(b, rng.randf())
		var f := _person(Vector3(start.x, 0.05, start.y), 0.0, 40 + i * 7)
		walkers.append({"fig": f, "a": a, "b": b, "to_b": rng.randf() < 0.5, "wait": rng.randf_range(0.0, 3.0)})
	# and a few standing: two talking by the boats, one at the quay's edge, a fisherman out on the breakwater
	var stand := [
		[Vector3(-15.0, 0.05, -2.6), Vector3(-15.0, 0.0, -9.0)],
		[Vector3(-14.2, 0.05, -2.2), Vector3(-15.0, 0.05, -2.6)],
		[Vector3(place.shore_r(-12.0) + 0.8, 0.05, -12.0), Vector3(0.0, 0.0, -12.0)],
		[MOLE_A.lerp(MOLE_B, 0.6) + Vector3(0, sea + 2.2, 0), Vector3(0.0, sea, -200.0)],
	]
	for i in stand.size():
		var at: Vector3 = stand[i][0]
		var f := _person(at, 0.0, 90 + i * 11)
		f.face(stand[i][1])


func _walk(delta: float) -> void:
	for w in walkers:
		var f: Figure = w.fig
		if f.is_going():
			continue
		w.wait -= delta
		if w.wait > 0.0:
			continue
		# off to the other end, or a few steps along and a pause
		var a: Vector2 = w.a
		var b: Vector2 = w.b
		var goal := b if w.to_b else a
		var here := Vector2(f.global_position.x, f.global_position.z)
		if here.distance_to(goal) < 1.0:
			w.to_b = not w.to_b
			goal = b if w.to_b else a
		var next := here.move_toward(goal, rng.randf_range(4.0, 14.0))
		f.go_to(Vector3(next.x, 0.0, next.y))
		w.wait = rng.randf_range(0.5, 4.0) if rng.randf() < 0.4 else 0.0


# --- far out: a ferry, sails ---

func _far_off() -> void:
	var g := Geo.new()
	var white := Color(0.96, 0.96, 0.94)
	var blue := Color(0.15, 0.3, 0.6)
	g.box(Transform3D(Basis(), Vector3(0, 1.5, 0)), Vector3(44.0, 4.0, 9.0), white, 0.0)
	g.box(Transform3D(Basis(), Vector3(0, 0.2, 0)), Vector3(44.2, 1.4, 9.2), blue, 0.0)
	g.box(Transform3D(Basis(), Vector3(2.0, 4.6, 0)), Vector3(30.0, 2.4, 8.0), white, 0.0)
	g.box(Transform3D(Basis(), Vector3(4.0, 6.6, 0)), Vector3(16.0, 1.8, 7.0), white, 0.0)
	g.box(Transform3D(Basis(), Vector3(-1.0, 8.6, 0)), Vector3(3.0, 3.0, 2.6), Color(0.85, 0.75, 0.25), 0.0)
	g.box(Transform3D(Basis(), Vector3(2.0, 4.6, -4.02)), Vector3(28.0, 0.5, 0.05), Color(0.15, 0.18, 0.25), 0.0)
	ferry = Node3D.new()
	add_child(ferry)
	place.put(g, place.lit_still, false, ferry)
	ferry.position = Vector3(-200.0, sea, -460.0)
	for k in 3:
		var s := Geo.new()
		s.box(Transform3D(Basis(), Vector3(0, 0.3, 0)), Vector3(1.6, 0.6, 6.0), white, 0.0)
		var n := Vector3.RIGHT
		var foot := Vector3(0, 0.6, 1.2)
		var top := Vector3(0, 7.5, 0.5)
		var clew := Vector3(0, 0.9, -2.6)
		s.tri(foot, clew, top, n, n, n, Color(0.98, 0.97, 0.93), 0.0)
		s.tri(foot, top, clew, -n, -n, -n, Color(0.92, 0.9, 0.86), 0.0)
		s.tri(Vector3(0, 0.9, 1.4), Vector3(0, 6.5, 0.6), Vector3(0, 0.9, 3.2), n, n, n, Color(0.98, 0.97, 0.93), 0.0)
		s.tri(Vector3(0, 0.9, 1.4), Vector3(0, 0.9, 3.2), Vector3(0, 6.5, 0.6), -n, -n, -n, Color(0.92, 0.9, 0.86), 0.0)
		var node := Node3D.new()
		add_child(node)
		place.put(s, place.lit_still, false, node)
		node.position = Vector3(-120.0 + k * 140.0, sea, -230.0 - k * 70.0)
		node.rotation.y = 0.6 + k * 0.5
		sails.append(node)


# --- gulls, gliding round over the harbour ---

func _gulls() -> void:
	var g := Geo.new()
	var white := Color(0.97, 0.97, 0.95)
	var grey := Color(0.62, 0.65, 0.7)
	g.blob(Transform3D(Basis(), Vector3.ZERO), Vector3(0.14, 0.13, 0.55), white, 0.0, 0.0, 3, 5)
	for sx in [-1.0, 1.0]:
		var root := Vector3(0.05 * sx, 0.03, 0.0)
		var elbow := Vector3(0.5 * sx, 0.12, 0.05)
		var tip := Vector3(1.0 * sx, 0.02, 0.18)
		var n := Vector3.UP
		# both faces of each wing, so it shows from below
		var a := root + Vector3(0, 0, -0.12)
		var b := root + Vector3(0, 0, 0.12)
		var e2 := elbow + Vector3(0, 0, 0.16)
		g.tri(a, elbow, b, n, n, n, white, 0.0)
		g.tri(a, b, elbow, -n, -n, -n, white * 0.9, 0.0)
		g.tri(elbow, tip, e2, n, n, n, grey, 0.0)
		g.tri(elbow, e2, tip, -n, -n, -n, grey, 0.0)
	var xfs: Array = []
	for k in 5:
		gulls.append({"c": Vector3(rng.randf_range(-30.0, 30.0), rng.randf_range(14.0, 30.0), rng.randf_range(-70.0, -25.0)),
			"r": rng.randf_range(12.0, 30.0), "w": rng.randf_range(0.08, 0.14) * (1.0 if rng.randf() < 0.5 else -1.0), "ph": rng.randf() * TAU})
		xfs.append(Transform3D())
	gull_mm = place.many(g.mesh(), xfs, place.lit_still, [], false, self).multimesh


func _process(delta: float) -> void:
	_t += delta
	for i in boats.size():
		var xf := _boat_xf(boats[i], _t)
		boat_mm.set_instance_transform(i, xf)
		boat_ref_mm.set_instance_transform(i, Transform3D(FLIP, Vector3(0, 2.0 * sea, 0)) * xf)
	_walk(delta)
	ferry.position.x = fposmod(-200.0 + _t * 2.2 + 200.0, 520.0) - 200.0
	for k in sails.size():
		sails[k].position.x += delta * 0.4
		sails[k].rotation.z = sin(_t * 0.5 + k) * 0.04
	for i in gulls.size():
		var gl: Dictionary = gulls[i]
		var a: float = _t * gl.w + gl.ph
		var c: Vector3 = gl.c
		var r: float = gl.r
		var p := c + Vector3(cos(a) * r, sin(_t * 0.3 + gl.ph) * 2.0, sin(a) * r * 0.7)
		var vel := Vector3(-sin(a) * r, 0.0, cos(a) * r * 0.7) * signf(gl.w)
		var yaw := atan2(-vel.x, -vel.z)
		var bank := signf(gl.w) * 0.35
		gull_mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.FORWARD, bank), p))
