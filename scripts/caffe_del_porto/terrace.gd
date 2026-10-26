extends Node3D
## Where you sit: the cafe's terrace on the quay, tiled in cotto, with a railing along the water, little
## marble tables and green iron chairs, your espresso and a cornetto in front of you (steam curling off
## it), the striped awning over it all, lemon trees in pots, bougainvillea over the wall on the left, a
## Vespa parked by the lane, and a few people at the other tables.

const Geo := preload("res://scripts/caffe_del_porto/geo.gd")
const AWNING := preload("res://shaders/caffe_del_porto/awning.gdshader")
const STEAM := preload("res://shaders/caffe_del_porto/steam.gdshader")

const IRON := Color(0.1, 0.2, 0.16)
const TERRACOTTA := Color(0.72, 0.4, 0.27)
## Your table, and the others (x, z).
const TABLE := Vector3(0.0, 0.0, -0.95)
const TABLES := [Vector2(-2.9, -1.6), Vector2(2.9, -1.5), Vector2(-4.6, 1.2), Vector2(-1.7, 2.4),
	Vector2(2.2, 1.7), Vector2(5.0, 0.4), Vector2(5.2, -2.4)]

var place: Node3D
var rng := RandomNumberGenerator.new()
var x0 := -6.2
var x1 := 7.15
## The people at the tables: their MultiMesh and where each sits.
var sitters: MultiMesh
var sit_xf: Array[Transform3D] = []


func build(p: Node3D) -> void:
	place = p
	rng.seed = 919
	var g: Geo = place.terrace_geo
	var fz: float = place.FRONT_Z
	var qz: float = place.QUAY_Z
	# the floor: cotto tiles, a step down to the quay at the open side
	g.box(Transform3D(Basis(), Vector3((x0 + x1) * 0.5, 0.0, (qz + fz) * 0.5)), Vector3(x1 - x0, 0.08, fz - qz), TERRACOTTA, 2.0, 0.0, ["bottom", "front"])
	_railing(g, qz)
	_quay_edges(g)
	_tables(g)
	_your_table(g)
	_awning()
	_wall_and_bougainvillea(g)
	for at in [Vector3(6.6, 0.04, qz + 0.55), Vector3(6.65, 0.04, fz - 0.6), Vector3(-5.5, 0.04, fz - 0.55)]:
		_lemon_tree(g, at)
	_vespa(g, Vector3(9.4, 0.0, -1.6), 0.55)
	_people()


# --- the railing along the water ---

func _railing(g: Geo, qz: float) -> void:
	var z := qz + 0.1
	var h := 0.95
	var x := x0 + 0.1
	while x < x1 - 0.05:
		g.rod(Vector3(x, 0.04, z), Vector3(x, h, z), 0.008, IRON, 3.0, 4)
		x += 0.2
	# top rail, a lower rail, and posts
	g.box(Transform3D(Basis(), Vector3((x0 + x1) * 0.5, h, z)), Vector3(x1 - x0, 0.045, 0.06), IRON, 3.0)
	g.box(Transform3D(Basis(), Vector3((x0 + x1) * 0.5, 0.12, z)), Vector3(x1 - x0, 0.03, 0.03), IRON, 3.0)
	for px in [x0 + 0.1, -2.0, 2.2, x1 - 0.1]:
		g.box(Transform3D(Basis(), Vector3(px, h * 0.5, z)), Vector3(0.05, h, 0.05), IRON, 3.0)
	# boxes of red geraniums hung on it
	for px in [-4.2, 4.0]:
		g.box(Transform3D(Basis(), Vector3(px, h - 0.12, z + 0.12)), Vector3(0.9, 0.2, 0.2), TERRACOTTA, 0.0)
		for k in 9:
			var c := Color(0.86, 0.12, 0.14) if rng.randf() < 0.6 else Color(0.25, 0.45, 0.18)
			g.blob(Transform3D(Basis(), Vector3(px + rng.randf_range(-0.42, 0.42), h + rng.randf_range(0.0, 0.1), z + 0.12 + rng.randf_range(-0.08, 0.08))),
				Vector3.ONE * rng.randf_range(0.12, 0.2), c, 8.0, 0.0, 3, 5)


# --- the quay's edges, stone walls down into the sea, with a kerb ---

func _quay_edges(g: Geo) -> void:
	var stone := Color(0.64, 0.6, 0.52)
	var kerb := Color(0.82, 0.79, 0.72)
	var sea: float = place.SEA
	var qz: float = place.QUAY_Z
	var lx: float = place.shore_l(qz)
	var rx: float = place.shore_r(qz)
	var q := Geo.new()
	# the head of the harbour, in front of the terrace
	q.quad(Vector3(rx, sea - 2.0, qz), Vector3(lx, sea - 2.0, qz), Vector3(lx, 0.0, qz), Vector3(rx, 0.0, qz), stone, 7.0)
	q.box(Transform3D(Basis(), Vector3((lx + rx) * 0.5, 0.03, qz + 0.15)), Vector3(rx - lx, 0.1, 0.32), kerb, 7.0)
	# along the left and right quays, in short runs following the shore
	var z := qz
	while z > -37.0:
		var za := z
		var zb := z - 2.0
		var a := Vector3(place.shore_l(za), 0.0, za)
		var b := Vector3(place.shore_l(zb), 0.0, zb)
		q.quad(Vector3(a.x, sea - 2.0, za), Vector3(b.x, sea - 2.0, zb), b, a, stone, 7.0)
		q.quad(b + Vector3(-0.3, 0.07, 0), a + Vector3(-0.3, 0.07, 0), a + Vector3(0.02, 0.07, 0), b + Vector3(0.02, 0.07, 0), kerb, 7.0)
		q.quad(a + Vector3(0.02, 0.07, 0), a + Vector3(0.02, -0.05, 0), b + Vector3(0.02, -0.05, 0), b + Vector3(0.02, 0.07, 0), kerb * 0.9, 7.0)
		z = zb
	z = qz
	while z > -42.0:
		var za := z
		var zb := z - 2.0
		var a := Vector3(place.shore_r(za), 0.0, za)
		var b := Vector3(place.shore_r(zb), 0.0, zb)
		q.quad(Vector3(b.x, sea - 2.0, zb), Vector3(a.x, sea - 2.0, za), a, b, stone, 7.0)
		q.quad(a + Vector3(0.3, 0.07, 0), b + Vector3(0.3, 0.07, 0), b + Vector3(-0.02, 0.07, 0), a + Vector3(-0.02, 0.07, 0), kerb, 7.0)
		z = zb
	# iron bollards along them
	var bollard := [Vector2(0.0, 0.0), Vector2(0.13, 0.0), Vector2(0.1, 0.12), Vector2(0.09, 0.32), Vector2(0.15, 0.38), Vector2(0.15, 0.44), Vector2(0.0, 0.47)]
	for bx in [-9.5, -14.0, -18.5]:
		q.lathe(Transform3D(Basis(), Vector3(bx, 0.0, qz + 0.4)), bollard, 7, Color(0.12, 0.12, 0.12), 3.0)
	z = -6.0
	while z > -36.0:
		q.lathe(Transform3D(Basis(), Vector3(place.shore_l(z) - 0.45, 0.0, z)), bollard, 7, Color(0.12, 0.12, 0.12), 3.0)
		z -= 7.2
	place.put(q, place.lit_still, true)


# --- tables and chairs ---

func _table_mesh() -> ArrayMesh:
	var t := Geo.new()
	t.lathe(Transform3D(), [Vector2(0.0, 0.0), Vector2(0.24, 0.0), Vector2(0.24, 0.025), Vector2(0.09, 0.07), Vector2(0.035, 0.16), Vector2(0.0, 0.17)], 10, IRON, 3.0)
	t.rod(Vector3(0, 0.1, 0), Vector3(0, 0.71, 0), 0.025, IRON, 3.0, 6)
	t.lathe(Transform3D(), [Vector2(0.0, 0.68), Vector2(0.12, 0.69), Vector2(0.12, 0.72), Vector2(0.0, 0.72)], 8, IRON, 3.0)
	t.lathe(Transform3D(), [Vector2(0.0, 0.715), Vector2(0.34, 0.715), Vector2(0.345, 0.73), Vector2(0.34, 0.75), Vector2(0.0, 0.75)], 20, Color(0.95, 0.94, 0.91), 1.0)
	t.lathe(Transform3D(), [Vector2(0.347, 0.712), Vector2(0.347, 0.745)], 20, Color(0.55, 0.45, 0.25), 3.0)
	return t.mesh()


func _chair_mesh() -> ArrayMesh:
	var c := Geo.new()
	var s := 0.21
	var seat := 0.46
	for p in [Vector2(-s, -s), Vector2(s, -s), Vector2(-s, s), Vector2(s, s)]:
		var top := Vector3(p.x * 0.95, seat, p.y * 0.95)
		var foot := Vector3(p.x * 1.15, 0.0, p.y * 1.15)
		c.rod(foot, top, 0.012, IRON, 3.0, 4)
	# a round seat of slats
	c.lathe(Transform3D(), [Vector2(0.0, seat), Vector2(0.25, seat), Vector2(0.25, seat + 0.035), Vector2(0.0, seat + 0.035)], 10, IRON * 1.3, 3.0)
	# the back: two uprights curving back, a rail and a few slats (the back is to +Z)
	var b0 := Vector3(-s, seat, s)
	var b1 := Vector3(s, seat, s)
	var lean := Vector3(0, 0.42, 0.08)
	c.rod(b0, b0 + lean, 0.012, IRON, 3.0, 4)
	c.rod(b1, b1 + lean, 0.012, IRON, 3.0, 4)
	c.box(Transform3D(Basis(Vector3.RIGHT, -0.19), (b0 + b1) * 0.5 + lean * 0.95), Vector3(s * 2.0 + 0.03, 0.09, 0.02), IRON, 3.0)
	for k in 3:
		var x := -s * 0.5 + k * s * 0.5
		c.rod(Vector3(x, seat + 0.03, s + 0.01), Vector3(x, seat + 0.38, s + 0.08), 0.008, IRON, 3.0, 3)
	return c.mesh()


func _tables(g: Geo) -> void:
	var tables: Array = [Transform3D(Basis(), TABLE)]
	var chairs: Array = []
	for t in TABLES:
		tables.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(t.x, 0.04, t.y)))
		var a0 := rng.randf() * TAU
		for k in 2:
			var a := a0 + k * PI + rng.randf_range(-0.4, 0.4)
			var at := Vector3(t.x + sin(a) * 0.58, 0.04, t.y + cos(a) * 0.58)
			# the chair's back away from the table (its back is +Z)
			chairs.append(Transform3D(Basis(Vector3.UP, a + rng.randf_range(-0.2, 0.2)), at))
	# a chair across your table, pushed back a little; yours is under you
	chairs.append(Transform3D(Basis(Vector3.UP, 2.0), TABLE + Vector3(0.62, 0.04, -0.27)))
	# two chairs stacked by the door, folded tables against the wall
	chairs.append(Transform3D(Basis(Vector3.UP, 0.2), Vector3(5.6, 0.04, 3.9)))
	place.many(_table_mesh(), tables, place.lit_still, [], true, self)
	place.many(_chair_mesh(), chairs, place.lit_still, [], true, self)
	# things left on the other tables: a cup and saucer, a glass, a carafe
	for t in TABLES:
		var y := 0.79
		var r := rng.randf()
		var at := Vector3(t.x + rng.randf_range(-0.12, 0.12), y, t.y + rng.randf_range(-0.12, 0.12))
		if r < 0.6:
			_cup(g, at, rng.randf() * TAU, rng.randf() < 0.5)
		if r > 0.35:
			_glass(g, at + Vector3(0.15, 0, 0.1), Color(0.95, 0.55, 0.2) if rng.randf() < 0.5 else Color(0.8, 0.88, 0.9))


func _cup(g: Geo, at: Vector3, yaw: float, full: bool) -> void:
	var white := Color(0.96, 0.95, 0.92)
	var xf := Transform3D(Basis(Vector3.UP, yaw), at)
	g.lathe(xf, [Vector2(0.0, 0.0), Vector2(0.05, 0.0), Vector2(0.07, 0.009), Vector2(0.076, 0.016), Vector2(0.06, 0.012), Vector2(0.0, 0.008)], 12, white, 3.0)
	g.lathe(xf, [Vector2(0.0, 0.01), Vector2(0.021, 0.012), Vector2(0.03, 0.025), Vector2(0.034, 0.055), Vector2(0.035, 0.066), Vector2(0.031, 0.066), Vector2(0.029, 0.03), Vector2(0.0, 0.026)], 12, white, 3.0)
	if full:
		g.lathe(xf, [Vector2(0.03, 0.056), Vector2(0.0, 0.056)], 12, Color(0.62, 0.4, 0.2), 0.0)
	# the handle, a little loop
	var b := Basis(Vector3.UP, yaw)
	var h0 := at + b * Vector3(0.033, 0.055, 0)
	var h1 := at + b * Vector3(0.055, 0.05, 0)
	var h2 := at + b * Vector3(0.052, 0.027, 0)
	var h3 := at + b * Vector3(0.031, 0.025, 0)
	g.rod(h0, h1, 0.005, white, 3.0, 4)
	g.rod(h1, h2, 0.005, white, 3.0, 4)
	g.rod(h2, h3, 0.005, white, 3.0, 4)
	# a spoon on the saucer
	var s0 := at + b * Vector3(-0.02, 0.018, 0.05)
	var s1 := at + b * Vector3(-0.07, 0.022, 0.085)
	g.rod(s0, s1, 0.003, Color(0.8, 0.8, 0.82), 3.0, 3)
	g.blob(Transform3D(b, s0), Vector3(0.016, 0.005, 0.022), Color(0.8, 0.8, 0.82), 3.0, 0.0, 3, 6)


func _glass(g: Geo, at: Vector3, drink: Color) -> void:
	var glass := Color(0.82, 0.9, 0.92)
	g.lathe(Transform3D(Basis(), at), [Vector2(0.0, 0.0), Vector2(0.03, 0.0), Vector2(0.034, 0.11), Vector2(0.031, 0.11), Vector2(0.0, 0.1)], 10, glass, 3.0)
	g.lathe(Transform3D(Basis(), at), [Vector2(0.0, 0.07), Vector2(0.0315, 0.07), Vector2(0.0315, 0.072)], 10, drink, 3.0)


# --- your table: an espresso, a cornetto, water, a flower ---

func _your_table(g: Geo) -> void:
	var top := TABLE.y + 0.75
	_cup(g, Vector3(0.07, top, -0.74), 0.6, true)
	# a sugar packet by the saucer
	g.box(Transform3D(Basis(Vector3.UP, 0.4), Vector3(-0.04, top + 0.004, -0.7)), Vector3(0.025, 0.006, 0.06), Color(0.95, 0.94, 0.9), 0.0)
	g.box(Transform3D(Basis(Vector3.UP, 0.4), Vector3(-0.04, top + 0.0045, -0.7)), Vector3(0.026, 0.006, 0.02), Color(0.15, 0.3, 0.6), 0.0)
	# the cornetto on its plate, sugar on its back
	var plate := Vector3(-0.15, top, -0.92)
	g.lathe(Transform3D(Basis(), plate), [Vector2(0.0, 0.0), Vector2(0.07, 0.0), Vector2(0.1, 0.012), Vector2(0.105, 0.017), Vector2(0.09, 0.013), Vector2(0.0, 0.01)], 14, Color(0.96, 0.95, 0.92), 3.0)
	_cornetto(g, plate + Vector3(0.0, 0.017, 0.0))
	_glass(g, Vector3(0.2, top, -1.05), Color(0.8, 0.88, 0.9))
	# a bud vase with a red flower
	var vase := Vector3(0.02, top, -1.12)
	g.lathe(Transform3D(Basis(), vase), [Vector2(0.0, 0.0), Vector2(0.02, 0.0), Vector2(0.026, 0.03), Vector2(0.01, 0.09), Vector2(0.013, 0.1), Vector2(0.0, 0.1)], 8, Color(0.3, 0.55, 0.62), 3.0)
	g.rod(vase + Vector3(0, 0.09, 0), vase + Vector3(0.01, 0.18, 0.0), 0.002, Color(0.25, 0.45, 0.2), 0.0, 3)
	g.blob(Transform3D(Basis(), vase + Vector3(0.012, 0.19, 0)), Vector3(0.03, 0.025, 0.03), Color(0.85, 0.1, 0.18), 8.0, 0.0, 3, 6)
	g.blob(Transform3D(Basis(Vector3.FORWARD, 0.6), vase + Vector3(-0.012, 0.15, 0)), Vector3(0.025, 0.006, 0.012), Color(0.25, 0.45, 0.2), 0.0, 0.0, 2, 4)
	# steam off the coffee: a few wisps, each its corners at its foot
	var st := Geo.new()
	for k in 4:
		var foot := Vector3(0.07, top + 0.06, -0.74) + Vector3(rng.randf_range(-0.01, 0.01), 0, rng.randf_range(-0.01, 0.01))
		var n := Vector3.BACK
		st.tri(foot, foot, foot, n, n, n, Color.WHITE, float(k) / 4.0, 0.0, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1))
		st.tri(foot, foot, foot, n, n, n, Color.WHITE, float(k) / 4.0, 0.0, Vector2(0, 0), Vector2(1, 1), Vector2(0, 1))
	var mi := MeshInstance3D.new()
	mi.mesh = st.mesh()
	mi.material_override = place._mat(STEAM)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(-0.3, 0.6, -0.9), Vector3(0.6, 0.6, 0.6))
	add_child(mi)


# A cornetto: a fat crescent rolled from a triangle of dough, the rolls showing as ridges round it,
# golden on top and paler underneath and at its tips
func _cornetto(g: Geo, at: Vector3) -> void:
	var steps := 16
	var around := 9
	var arc := 0.05
	var rings: Array = []
	for i in steps + 1:
		var t := float(i) / steps
		var a := lerpf(-1.35, 1.35, t)
		var c := at + Vector3(sin(a) * arc, 0.0, -cos(a) * arc + arc * 0.6)
		var along := Vector3(cos(a), 0.0, sin(a))
		var side := Vector3(-sin(a), 0.0, cos(a))
		var fat := 0.004 + 0.027 * pow(sin(PI * t), 0.8)
		var ridge := 1.0 + 0.13 * absf(sin(t * PI * 5.0))
		var ring: Array = []
		for k in around + 1:
			var u := TAU * k / around
			var d := side * cos(u) * fat * ridge + Vector3.UP * (sin(u) * 0.75 + 0.55) * fat * ridge
			ring.append([c + d, (side * cos(u) + Vector3.UP * sin(u)).normalized(), sin(u)])
		rings.append(ring)
	for i in steps:
		var t := (float(i) + 0.5) / steps
		for k in around:
			var p00: Array = rings[i][k]
			var p01: Array = rings[i][k + 1]
			var p10: Array = rings[i + 1][k]
			var p11: Array = rings[i + 1][k + 1]
			var top: float = (float(p00[2]) + 1.0) * 0.5
			var col := Color(0.93, 0.74, 0.45).lerp(Color(0.78, 0.45, 0.16), top * (0.4 + 0.6 * sin(PI * t)))
			if top > 0.8 and (i + k) % 3 == 0:
				col = Color(0.98, 0.95, 0.88)
			g.tri(p00[0], p11[0], p01[0], p00[1], p11[1], p01[1], col, 0.0)
			g.tri(p00[0], p10[0], p11[0], p00[1], p10[1], p11[1], col, 0.0)


# --- the awning ---

func _awning() -> void:
	var g := Geo.new()
	var fz: float = place.FRONT_Z - 0.05
	var ax0 := -6.05
	var ax1 := 7.05
	var back := Vector3(0, 3.38, fz)
	var edge := Vector3(0, 2.25, -1.6)
	var nx := 62
	var nz := 8
	# the canopy, its top facing up: UV.x metres along it, UV2.y how far down it
	for i in nx:
		for j in nz:
			var xa := lerpf(ax0, ax1, float(i) / nx)
			var xb := lerpf(ax0, ax1, float(i + 1) / nx)
			var ta := float(j) / nz
			var tb := float(j + 1) / nz
			var pa := back.lerp(edge, ta)
			var pb := back.lerp(edge, tb)
			# a little sag in the middle of the cloth between the arms
			var sag := func(x: float, t: float) -> float: return -0.05 * sin(PI * t) * (0.6 + 0.4 * absf(sin(PI * (x - ax0) / ((ax1 - ax0) * 0.5))))
			var v00 := Vector3(xa, pa.y + sag.call(xa, ta), pa.z)
			var v10 := Vector3(xb, pa.y + sag.call(xb, ta), pa.z)
			var v01 := Vector3(xa, pb.y + sag.call(xa, tb), pb.z)
			var v11 := Vector3(xb, pb.y + sag.call(xb, tb), pb.z)
			var n := (v10 - v00).cross(v01 - v00).normalized()
			if n.y < 0.0:
				n = -n
			# seen from above (x right, the back towards you): back left -> back right -> front right
			g.tri(v00, v10, v11, n, n, n, Color.WHITE, 0.0, 0.0, Vector2(xa - ax0, ta), Vector2(xb - ax0, ta), Vector2(xb - ax0, tb))
			g.tri(v00, v11, v01, n, n, n, Color.WHITE, 0.0, 0.0, Vector2(xa - ax0, ta), Vector2(xb - ax0, tb), Vector2(xa - ax0, tb))
	# the valance along the front edge: scallops, one to a stripe
	var drop := 0.26
	var seg := 0.42
	var steps := int(roundf((ax1 - ax0) / seg)) * 4
	for i in steps:
		var xa := lerpf(ax0, ax1, float(i) / steps)
		var xb := lerpf(ax0, ax1, float(i + 1) / steps)
		var ba := drop + 0.07 * sin(PI * fmod((xa - ax0) / seg, 1.0))
		var bb := drop + 0.07 * sin(PI * fmod((xb - ax0) / seg, 1.0))
		if i % 4 == 3:
			bb = drop
		var ta := Vector3(xa, edge.y, edge.z)
		var tb := Vector3(xb, edge.y, edge.z)
		var n := Vector3.FORWARD
		# facing out to sea (-Z): seen from there, x runs right to left
		g.tri(tb - Vector3(0, bb, 0), ta - Vector3(0, ba, 0), ta, n, n, n, Color.WHITE, 1.0, 0.0, Vector2(xb - ax0, 0), Vector2(xa - ax0, 0), Vector2(xa - ax0, 1))
		g.tri(tb - Vector3(0, bb, 0), ta, tb, n, n, n, Color.WHITE, 1.0, 0.0, Vector2(xb - ax0, 0), Vector2(xa - ax0, 1), Vector2(xb - ax0, 1))
	var mi := MeshInstance3D.new()
	mi.mesh = g.mesh()
	mi.material_override = place._mat(AWNING)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mi)
	# its arms and the bar along its front
	var a := Geo.new()
	var steel := Color(0.3, 0.3, 0.3)
	a.rod(Vector3(ax0 + 0.05, edge.y - 0.02, edge.z), Vector3(ax1 - 0.05, edge.y - 0.02, edge.z), 0.03, steel, 3.0, 6)
	for x in [ax0 + 0.4, -2.6, ax1 - 0.4]:
		var mid := Vector3(x + 0.2, 2.45, 1.4)
		a.rod(Vector3(x, 2.75, fz), mid, 0.022, steel, 3.0, 5)
		a.rod(mid, Vector3(x, edge.y - 0.02, edge.z), 0.022, steel, 3.0, 5)
		a.box(Transform3D(Basis(), Vector3(x, 2.75, fz - 0.04)), Vector3(0.12, 0.2, 0.08), steel, 3.0)
	a.box(Transform3D(Basis(), Vector3((ax0 + ax1) * 0.5, back.y + 0.05, fz - 0.08)), Vector3(ax1 - ax0 + 0.2, 0.16, 0.16), steel * 1.4, 3.0)
	place.put(a, place.lit_still, true, self)


# --- the wall on the left, under bougainvillea ---

func _wall_and_bougainvillea(g: Geo) -> void:
	var qz: float = place.QUAY_Z
	var fz: float = place.FRONT_Z
	var white := Color(0.96, 0.95, 0.9)
	var wx := x0 - 0.15
	g.box(Transform3D(Basis(), Vector3(wx, 0.36, (qz + fz) * 0.5 - 0.3)), Vector3(0.3, 0.72, fz - qz - 0.6), white, 11.0)
	g.box(Transform3D(Basis(), Vector3(wx, 0.76, (qz + fz) * 0.5 - 0.3)), Vector3(0.36, 0.08, fz - qz - 0.5), white * 0.95, 11.0)
	# a pillar at the corner, up to the awning
	g.box(Transform3D(Basis(), Vector3(wx, 1.25, qz + 0.2)), Vector3(0.4, 2.5, 0.4), white, 11.0)
	var fl := Geo.new()
	var magenta := [Color(0.86, 0.13, 0.52), Color(0.78, 0.1, 0.45), Color(0.92, 0.3, 0.62), Color(0.7, 0.08, 0.4)]
	var leaf := Color(0.22, 0.42, 0.17)
	# along the top of the wall and spilling down its outside
	for k in 170:
		var z := rng.randf_range(qz + 0.1, fz - 1.4)
		var spill := rng.randf()
		var y := 0.84 - spill * spill * 0.75 + rng.randf_range(-0.05, 0.12)
		var x := wx - 0.1 - spill * 0.35 + rng.randf_range(-0.12, 0.12)
		var c: Color = magenta[rng.randi() % 4] if rng.randf() < 0.72 else leaf
		var s := rng.randf_range(0.14, 0.32) * (1.0 - spill * 0.4)
		fl.blob(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(x, y, z)), Vector3(s, s * 0.8, s), c, 8.0, 0.0, 4, 7)
	# climbing the pillar and bursting out over its top
	for k in 80:
		var t := rng.randf()
		var at := Vector3(wx + rng.randf_range(-0.25, 0.25), 0.8 + t * 1.7, qz + 0.2 + rng.randf_range(-0.25, 0.25))
		if t > 0.75:
			at += Vector3(rng.randf_range(-0.5, 0.4), rng.randf_range(-0.1, 0.35), rng.randf_range(-0.45, 0.5))
		var c: Color = magenta[rng.randi() % 4] if rng.randf() < 0.65 else leaf
		var s := rng.randf_range(0.14, 0.3)
		fl.blob(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), at), Vector3(s, s * 0.8, s), c, 8.0, 0.0, 4, 7)
	# more over the mouth of the lane, in the sun: up the cafe's corner and along a beam across the lane
	var lx: float = place.LANE_X
	var lh: float = place.LANE_HALF
	g.box(Transform3D(Basis(), Vector3(lx, 3.05, fz + 0.5)), Vector3(lh * 2.0 + 0.3, 0.14, 0.14), Color(0.45, 0.3, 0.18), 9.0)
	for k in 150:
		var t := rng.randf()
		var at: Vector3
		if t < 0.45:
			# up the corner
			at = Vector3(x1 + rng.randf_range(-0.15, 0.3), rng.randf_range(0.3, 3.2), fz + rng.randf_range(-0.35, 0.6))
		else:
			# along the beam, hanging down from it
			var hang := rng.randf()
			at = Vector3(rng.randf_range(lx - lh, lx + lh), 3.15 - hang * hang * 1.1, fz + 0.5 + rng.randf_range(-0.35, 0.35))
		var c: Color = magenta[rng.randi() % 4] if rng.randf() < 0.75 else leaf
		var s := rng.randf_range(0.14, 0.3)
		fl.blob(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), at), Vector3(s, s * 0.8, s), c, 8.0, 0.0, 4, 7)
	# a few hanging trails, and flowers fallen on the tiles
	for k in 14:
		var at := Vector3(x0 + rng.randf_range(0.2, 1.0), 0.045, rng.randf_range(qz + 0.3, 1.5))
		fl.blob(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), at), Vector3(0.05, 0.01, 0.04), magenta[rng.randi() % 4], 0.0, 0.0, 2, 4)
	place.put(fl, place.lit, true, self)


# --- lemon trees in pots ---

func _lemon_tree(g: Geo, at: Vector3) -> void:
	g.lathe(Transform3D(Basis(), at), [Vector2(0.0, 0.0), Vector2(0.24, 0.0), Vector2(0.34, 0.55), Vector2(0.38, 0.6), Vector2(0.38, 0.66), Vector2(0.31, 0.66), Vector2(0.3, 0.6), Vector2(0.0, 0.6)], 12, TERRACOTTA * 1.05, 0.0)
	# the tree itself: GameCommon's leafy-tree, small and round, glossy dark leaves with now and then a clump
	# gone yellow with fruit
	var lemon := LeafyTree.new()
	lemon.height = 1.75
	lemon.trunk_radius = 0.045
	lemon.crown_base = 0.42
	lemon.spread = 0.62
	lemon.limbs = 3
	lemon.clumps = 12
	lemon.clump_size = 0.3
	lemon.tufts = 4
	lemon.openness = 0.15
	lemon.leaves_dark = Color(0.06, 0.16, 0.07)
	lemon.leaves = Color(0.13, 0.32, 0.12)
	lemon.leaves_light = Color(0.3, 0.5, 0.2)
	lemon.accent = Color(0.95, 0.82, 0.18, 0.12)
	lemon.material = place.lit_tree
	lemon.seed = 3
	var tree := lemon.instance(int(at.x * 10.0) & 3)
	tree.position = at + Vector3(0, 0.58, 0)
	tree.rotation.y = at.z
	add_child(tree)
	var t := Geo.new()
	var crown := at + Vector3(0.0, 0.58 + 1.75 * 0.68, 0.0)
	for k in 16:
		var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.7, 0.7), rng.randf_range(-1, 1)).normalized() * rng.randf_range(0.42, 0.55)
		t.blob(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), crown + d), Vector3(0.07, 0.06, 0.06), Color(0.98, 0.85, 0.15), 3.0, 0.0, 3, 5)
	place.put(t, place.lit, true, self)


# --- a Vespa ---

func _vespa(g: Geo, at: Vector3, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	var lean := Basis(Vector3.FORWARD, 0.08)
	var xf := Transform3D(b * lean, at)
	var body := Color(0.55, 0.82, 0.76)
	var dark := Color(0.1, 0.1, 0.1)
	var chrome := Color(0.85, 0.85, 0.85)
	var v := Geo.new()
	# wheels (the scooter runs along local X: front at -X)
	for wx in [-0.62, 0.55]:
		v.lathe(xf * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(wx, 0.2, 0.0)) * Transform3D(Basis(), Vector3(0, -0.05, 0)),
			[Vector2(0.0, 0.0), Vector2(0.15, 0.0), Vector2(0.2, 0.02), Vector2(0.2, 0.08), Vector2(0.15, 0.1), Vector2(0.0, 0.1)], 12, dark, 0.0)
		v.lathe(xf * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(wx, 0.2, 0.0)) * Transform3D(Basis(), Vector3(0, -0.055, 0)),
			[Vector2(0.0, 0.0), Vector2(0.1, 0.0), Vector2(0.1, 0.11), Vector2(0.0, 0.11)], 8, chrome, 3.0)
	# the rear cowl, the floorboard, the leg shield and front mudguard, the seat
	v.blob(xf * Transform3D(Basis(), Vector3(0.45, 0.48, 0.0)), Vector3(0.75, 0.5, 0.46), body, 3.0, 0.0, 5, 10)
	v.box(xf * Transform3D(Basis(), Vector3(-0.1, 0.25, 0.0)), Vector3(0.65, 0.06, 0.32), dark, 0.0)
	v.box(xf * Transform3D(Basis(Vector3.BACK, -0.25), Vector3(-0.47, 0.6, 0.0)), Vector3(0.08, 0.75, 0.42), body, 3.0)
	v.blob(xf * Transform3D(Basis(), Vector3(-0.62, 0.36, 0.0)), Vector3(0.38, 0.2, 0.2), body, 3.0, 0.0, 4, 8)
	v.blob(xf * Transform3D(Basis(), Vector3(0.38, 0.8, 0.0)), Vector3(0.62, 0.14, 0.28), Color(0.35, 0.22, 0.14), 3.0, 0.0, 4, 8)
	# steering column, handlebars, headlamp, a mirror
	v.rod(xf * Vector3(-0.52, 0.85, 0.0), xf * Vector3(-0.6, 1.02, 0.0), 0.04, body, 3.0, 6)
	v.box(xf * Transform3D(Basis(), Vector3(-0.6, 1.05, 0.0)), Vector3(0.16, 0.08, 0.62), body, 3.0)
	for sz in [-0.33, 0.33]:
		v.rod(xf * Vector3(-0.6, 1.05, sz), xf * Vector3(-0.58, 1.04, sz * 1.25), 0.02, dark, 0.0, 5)
	v.blob(xf * Transform3D(Basis(), Vector3(-0.68, 1.06, 0.0)), Vector3(0.1, 0.11, 0.11), chrome, 3.0, 0.0, 4, 8)
	v.rod(xf * Vector3(-0.6, 1.08, -0.25), xf * Vector3(-0.62, 1.28, -0.28), 0.006, chrome, 3.0, 3)
	v.blob(xf * Transform3D(Basis(), Vector3(-0.62, 1.3, -0.28)), Vector3(0.03, 0.06, 0.08), chrome, 3.0, 0.0, 3, 6)
	# the stand
	v.rod(xf * Vector3(0.0, 0.22, 0.12), at + b * Vector3(0.05, 0.0, 0.2), 0.012, dark, 0.0, 3)
	place.put(v, place.lit_still, true, self)


# --- people at the tables ---

func _sitter_mesh(reading: bool) -> ArrayMesh:
	var m := Geo.new()
	var shirt := Color(1, 1, 1, 0)
	var skin := Color(0.85, 0.62, 0.48)
	var trousers := Color(0.25, 0.27, 0.32)
	var seat := 0.5
	# facing -Z: thighs forward over the seat, shins down
	for sx in [-0.1, 0.1]:
		m.rod(Vector3(sx, seat, 0.05), Vector3(sx, seat, -0.38), 0.07, trousers, 12.0, 5)
		m.rod(Vector3(sx, seat - 0.02, -0.38), Vector3(sx, 0.05, -0.42), 0.055, trousers, 12.0, 5)
		m.blob(Transform3D(Basis(), Vector3(sx, 0.05, -0.47)), Vector3(0.1, 0.07, 0.22), Color(0.2, 0.14, 0.1), 0.0, 0.0, 3, 5)
	m.lathe(Transform3D(Basis(Vector3.RIGHT, 0.08), Vector3(0, seat - 0.03, 0.04)), [Vector2(0.0, 0.0), Vector2(0.17, 0.0), Vector2(0.2, 0.25), Vector2(0.21, 0.42), Vector2(0.14, 0.58), Vector2(0.06, 0.62), Vector2(0.0, 0.62)], 8, shirt, 12.0)
	m.rod(Vector3(0, seat + 0.58, 0.07), Vector3(0, seat + 0.66, 0.07), 0.045, skin, 0.0, 5)
	m.blob(Transform3D(Basis(), Vector3(0, seat + 0.76, 0.06)), Vector3(0.19, 0.24, 0.21), skin, 0.0, 0.0, 4, 7)
	m.blob(Transform3D(Basis(), Vector3(0, seat + 0.82, 0.09)), Vector3(0.2, 0.15, 0.2), Color(0.2, 0.14, 0.1), 0.0, 0.0, 3, 7)
	# arms forward to the table (and a newspaper held up, for one)
	for sx in [-0.21, 0.21]:
		var sh := Vector3(sx, seat + 0.5, 0.06)
		var el := Vector3(sx * 1.05, seat + 0.25, -0.12)
		var hand := Vector3(sx * 0.6, seat + (0.5 if reading else 0.3), -0.38)
		m.rod(sh, el, 0.045, shirt, 12.0, 5)
		m.rod(el, hand, 0.04, skin, 0.0, 5)
	if reading:
		m.quad(Vector3(0.22, seat + 0.32, -0.42), Vector3(-0.22, seat + 0.32, -0.42), Vector3(-0.22, seat + 0.72, -0.38), Vector3(0.22, seat + 0.72, -0.38), Color(0.92, 0.9, 0.84), 12.0)
		m.quad(Vector3(-0.22, seat + 0.32, -0.41), Vector3(0.22, seat + 0.32, -0.41), Vector3(0.22, seat + 0.72, -0.37), Vector3(-0.22, seat + 0.72, -0.37), Color(0.86, 0.84, 0.78), 12.0)
	return m.mesh()


func _people() -> void:
	# who sits where: at a table (index in TABLES), and which way round
	var seats := [[0, 0.0, Color(0.92, 0.9, 0.85)], [0, PI, Color(0.85, 0.3, 0.32)], [5, PI * 0.5, Color(0.35, 0.5, 0.7)], [3, PI * 0.8, Color(0.98, 0.85, 0.45)]]
	var xfs: Array = []
	var customs: Array = []
	for s in seats:
		var t: Vector2 = TABLES[s[0]]
		var a: float = s[1]
		var at := Vector3(t.x + sin(a) * 0.62, 0.04, t.y + cos(a) * 0.62)
		var xf := Transform3D(Basis(Vector3.UP, a), at)
		sit_xf.append(xf)
		xfs.append(xf)
		customs.append(s[2])
	var mmi: MultiMeshInstance3D = place.many(_sitter_mesh(false), xfs.slice(0, 2) + xfs.slice(3), place.lit_still, customs.slice(0, 2) + customs.slice(3), true, self)
	sitters = mmi.multimesh
	sit_xf = [sit_xf[0], sit_xf[1], sit_xf[3]]
	place.many(_sitter_mesh(true), [xfs[2]], place.lit_still, [customs[2]], true, self)


var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	# the people at the tables shift a little: lean in, sit back, turn to talk
	for i in sit_xf.size():
		var lean := sin(_t * 0.35 + i * 2.1) * 0.05 + sin(_t * 0.9 + i) * 0.015
		var turn := sin(_t * 0.21 + i * 1.3) * 0.12
		var xf := sit_xf[i]
		sitters.set_instance_transform(i, Transform3D(xf.basis * Basis(Vector3.UP, turn) * Basis(Vector3.RIGHT, -lean), xf.origin))
