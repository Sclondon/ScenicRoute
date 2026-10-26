extends RefCounted
## The town round the harbour: rows of tall washed houses along the quays, the cafe's own house behind you
## with the lane of steps climbing beside it, the church and its bell tower over the right quay, houses
## stacked up the cliffs, and umbrella pines, cypresses and scrub on the slopes.

const Geo := preload("res://scripts/caffe_del_porto/geo.gd")
const SERIF := preload("res://fonts/LibreBaskerville.ttf")
const ITALIC := preload("res://fonts/LibreBaskerville-Italic.ttf")

const WALLS := [
	Color(0.88, 0.63, 0.33), Color(0.82, 0.46, 0.31), Color(0.94, 0.68, 0.63), Color(0.97, 0.87, 0.58),
	Color(0.96, 0.62, 0.46), Color(0.97, 0.8, 0.64), Color(0.95, 0.92, 0.84), Color(0.93, 0.72, 0.42),
	Color(0.87, 0.53, 0.5), Color(0.98, 0.9, 0.5), Color(0.72, 0.8, 0.84), Color(0.95, 0.92, 0.84),
	Color(0.9, 0.76, 0.52),
]
const ROOF := Color(0.74, 0.37, 0.23)

var place: Node3D
var rng := RandomNumberGenerator.new()
## Where houses stand (x, z, radius), so plants keep off them.
var taken: Array[Vector3] = []
var front := Geo.new()
var chunks := {}
var church := Geo.new()


func build(p: Node3D) -> void:
	place = p
	rng.seed = 4242
	_front_rows()
	_cafe()
	_lane()
	_church()
	_hillside()
	var front_mi: MeshInstance3D = place.put(front, place.house, true)
	place.reflect.append(front_mi.mesh)
	for k in chunks:
		var g: Geo = chunks[k]
		var mid := Vector2((k.x + 0.5) * 50.0, (k.y + 0.5) * 50.0)
		place.put(g, place.house, mid.length() < 70.0)
	var church_mi: MeshInstance3D = place.put(church, place.lit_still, true)
	place.reflect_lit.append(church_mi.mesh)
	_plants()


func _wall_color() -> Color:
	var c: Color = WALLS[rng.randi() % WALLS.size()]
	return c * rng.randf_range(0.84, 0.94)


## A house: `at` the middle of the foot of its front, `yaw` turning its front (local -Z) to face the way
## it looks. Walls with windows (the front can have doors along the ground), a pitched roof of tiles or a
## flat one.
func house(g: Geo, at: Vector3, yaw: float, w: float, depth: float, h: float, col: Color, pitched: bool,
		front_kind := 0, side_kind := 0, skip := []) -> void:
	var b := Basis(Vector3.UP, yaw)
	var seed := rng.randf_range(0.0, 0.9)
	var o := at
	var hw := w * 0.5
	var corners := {
		"fl": o + b * Vector3(-hw, 0, 0), "fr": o + b * Vector3(hw, 0, 0),
		"bl": o + b * Vector3(-hw, 0, depth), "br": o + b * Vector3(hw, 0, depth),
	}
	var up := Vector3.UP * h
	# front (facing -Z local): from the right corner as seen from outside... counter-clockwise from outside
	if not "front" in skip:
		_wall(g, corners.fr, corners.fl, h, col, front_kind, w, seed)
	if not "back" in skip:
		_wall(g, corners.bl, corners.br, h, col, 0, w, seed)
	if not "left" in skip:
		_wall(g, corners.fl, corners.bl, h, col, side_kind, depth, seed)
	if not "right" in skip:
		_wall(g, corners.br, corners.fr, h, col, side_kind, depth, seed)
	var roof := ROOF * rng.randf_range(0.85, 1.1)
	if pitched:
		var over := 0.35
		var rise := depth * 0.5 * 0.42
		var ex := b * Vector3(over, 0, 0)
		var ez := b * Vector3(0, 0, over)
		var fl: Vector3 = corners.fl + up - ex - ez
		var fr: Vector3 = corners.fr + up + ex - ez
		var bl: Vector3 = corners.bl + up - ex + ez
		var br: Vector3 = corners.br + up + ex + ez
		var rl: Vector3 = (corners.fl + corners.bl) * 0.5 + up + Vector3.UP * rise - ex
		var rr: Vector3 = (corners.fr + corners.br) * 0.5 + up + Vector3.UP * rise + ex
		# the front slope (seen from in front and above: eave left -> eave right -> ridge right -> ridge left)
		g.quad(fr, fl, rl, rr, roof, 1.0, seed)
		g.quad(bl, br, rr, rl, roof, 1.0, seed)
		# the underside of the eaves, dark
		g.quad(fl, fr, fr - Vector3.UP * 0.12 + ez, fl - Vector3.UP * 0.12 + ez, col * 0.5, 2.0, seed)
		# the gables
		var gl: Vector3 = (corners.fl + corners.bl) * 0.5 + up + Vector3.UP * rise
		var gr: Vector3 = (corners.fr + corners.br) * 0.5 + up + Vector3.UP * rise
		var n := (b * Vector3.LEFT)
		g.tri(corners.fl + up, corners.bl + up, gl, n, n, n, col, 2.0, seed)
		n = b * Vector3.RIGHT
		g.tri(corners.br + up, corners.fr + up, gr, n, n, n, col, 2.0, seed)
	else:
		# a flat roof: a terrace with a low parapet round it
		var lip := 0.45
		var top := Vector3.UP * (h + lip)
		g.quad(corners.fl + up, corners.bl + up, corners.br + up, corners.fr + up, col.lerp(Color(0.92, 0.9, 0.85), 0.5), 3.0, seed)
		for pair in [[corners.fr, corners.fl], [corners.bl, corners.br], [corners.fl, corners.bl], [corners.br, corners.fr]]:
			var a: Vector3 = pair[0] + up
			var c: Vector3 = pair[1] + up
			g.quad(a, c, c + Vector3.UP * lip, a + Vector3.UP * lip, col, 2.0, seed)
			# its inside, facing the terrace
			g.quad(c, a, a + Vector3.UP * lip, c + Vector3.UP * lip, col * 0.9, 2.0, seed)
		# now and then a little stair hut or a water tank on the roof
		if rng.randf() < 0.35:
			var s := rng.randf_range(1.6, 2.4)
			var hc := o + b * Vector3(rng.randf_range(-hw + 1.2, hw - 1.2), 0, depth * rng.randf_range(0.5, 0.8)) + up
			house(g, hc + b * Vector3(0, 0, -s * 0.5), yaw, s, s, rng.randf_range(1.8, 2.4), col, false, 2, 2)
	taken.append(Vector3(at.x + (b * Vector3(0, 0, depth * 0.5)).x, at.z + (b * Vector3(0, 0, depth * 0.5)).z, maxf(w, depth) * 0.6))


# A wall from `a` to `b` (counter-clockwise from outside: `a` on the right seen from outside? no: a is the
# corner on the left seen from outside), `h` high, its width (for the windows) and the house's number in UV2.
func _wall(g: Geo, a: Vector3, b: Vector3, h: float, col: Color, kind: int, width: float, seed: float) -> void:
	var extra := roundf(width * 10.0) + seed
	g.quad(a, b, b + Vector3.UP * h, a + Vector3.UP * h, col, float(kind), extra)


func _chunk(x: float, z: float) -> Geo:
	var k := Vector2i(floori(x / 50.0), floori(z / 50.0))
	if not chunks.has(k):
		chunks[k] = Geo.new()
	return chunks[k]


# --- along the quays ---

func _front_rows() -> void:
	var fz: float = place.FRONT_Z
	# the head of the harbour, behind the terrace: left of the cafe, and right of the lane
	var x: float = place.shore_l(fz) - 6.5
	while x < -6.0 - 3.0:
		var w := minf(rng.randf_range(4.5, 7.5), -6.0 - x)
		house(front, Vector3(x + w * 0.5, 0, fz), 0.0, w, 10.0, rng.randf_range(11.0, 17.0), _wall_color(), rng.randf() < 0.6, 4)
		x += w
	if x < -6.0:
		house(front, Vector3((x - 6.0) * 0.5, 0, fz), 0.0, -6.0 - x, 10.0, 13.0, _wall_color(), true, 4)
	x = place.LANE_X + place.LANE_HALF
	var right_end: float = place.shore_r(fz) + 5.5
	while x < right_end - 2.0:
		var w := minf(rng.randf_range(4.5, 7.5), right_end - x)
		var side := 0
		house(front, Vector3(x + w * 0.5, 0, fz), 0.0, w, 10.0, rng.randf_range(11.0, 17.0), _wall_color(), rng.randf() < 0.6, 4, side)
		x += w
	# the left quay: houses facing across the harbour, from the corner out to where the quay ends
	var z := fz
	while z > -42.0:
		var w := rng.randf_range(4.5, 7.5)
		var zc := z - w * 0.5
		var fx: float = place.shore_l(zc) - 6.5
		house(front, Vector3(fx, 0, zc), -PI * 0.5, w, 11.0, rng.randf_range(11.0, 18.0), _wall_color(), rng.randf() < 0.55, 4)
		z -= w
	# the right quay, with the church in it
	z = fz
	while z > -48.0:
		var w := rng.randf_range(4.5, 7.5)
		if z - w < -21.0 and z > -37.5:
			z = -37.5
			continue
		var zc := z - w * 0.5
		var fx: float = place.shore_r(zc) + 5.5
		house(front, Vector3(fx, 0, zc), PI * 0.5, w, 11.0, rng.randf_range(11.0, 18.0), _wall_color(), rng.randf() < 0.55, 4)
		z -= w


# --- the cafe's own house, behind you ---

func _cafe() -> void:
	var g: Geo = place.terrace_geo
	var fz: float = place.FRONT_Z
	var x0 := -6.0
	var x1: float = place.LANE_X - place.LANE_HALF
	var col := Color(0.96, 0.8, 0.46)
	var gh := 3.6
	# upstairs: windows (the house shader), the side over the lane too, and a tiled roof
	var top := 13.2
	var u := Geo.new()
	_wall(u, Vector3(x1, gh, fz), Vector3(x0, gh, fz), top - gh, col, 0, x1 - x0, 0.31)
	_wall(u, Vector3(x1, gh, fz + 10.0), Vector3(x1, gh, fz), top - gh, col, 0, 10.0, 0.31)
	_wall(u, Vector3(x1, 0.0, fz + 10.0), Vector3(x1, 0.0, fz + 2.0), gh, col, 0, 8.0, 0.53)
	var b := Basis(Vector3.UP, PI)
	var over := 0.4
	var rise := 2.1
	var fl := Vector3(x1 + over, top, fz - over)
	var fr := Vector3(x0 - over, top, fz - over)
	var rl := Vector3(x1 + over, top + rise, fz + 5.0)
	var rr := Vector3(x0 - over, top + rise, fz + 5.0)
	u.quad(fl, fr, rr, rl, ROOF, 1.0, 0.2)
	u.quad(Vector3(x1, top, fz + 10.0), Vector3(x1, top, fz), Vector3(x1, top + rise, fz + 5.0), Vector3(x1, top + rise, fz + 5.0), col, 2.0, 0.2)
	u.quad(Vector3(x0 - over, top, fz - over), Vector3(x1 + over, top, fz - over), Vector3(x1 + over, top - 0.15, fz), Vector3(x0 - over, top - 0.15, fz), col * 0.5, 2.0, 0.2)
	place.put(u, place.house, true)
	# a cornice over the ground floor
	g.box(Transform3D(Basis(), Vector3((x0 + x1) * 0.5, gh + 0.06, fz - 0.12)), Vector3(x1 - x0, 0.14, 0.26), Color(0.95, 0.92, 0.84), 11.0)
	# the ground floor: plaster, a doorway, two windows full of the dark inside, a stone plinth
	var door_x := 0.9
	var dw := 1.8
	var dh := 2.65
	var wins := [[-3.6, 2.4], [4.0, 2.0]]
	var spans := [[x0, -3.6 - 1.2], [-3.6 + 1.2, door_x - dw * 0.5], [door_x + dw * 0.5, 4.0 - 1.0], [4.0 + 1.0, x1]]
	for s in spans:
		g.quad(Vector3(s[1], 0, fz), Vector3(s[0], 0, fz), Vector3(s[0], gh, fz), Vector3(s[1], gh, fz), col, 11.0)
	# over the door and windows, and under the windows
	g.quad(Vector3(door_x + dw * 0.5, dh, fz), Vector3(door_x - dw * 0.5, dh, fz), Vector3(door_x - dw * 0.5, gh, fz), Vector3(door_x + dw * 0.5, gh, fz), col, 11.0)
	for wv in wins:
		var cx: float = wv[0]
		var hw: float = wv[1] * 0.5
		g.quad(Vector3(cx + hw, 2.6, fz), Vector3(cx - hw, 2.6, fz), Vector3(cx - hw, gh, fz), Vector3(cx + hw, gh, fz), col, 11.0)
		g.quad(Vector3(cx + hw, 0, fz), Vector3(cx - hw, 0, fz), Vector3(cx - hw, 0.65, fz), Vector3(cx + hw, 0.65, fz), col, 11.0)
		# the glass, set back, and a frame of white wood with a bar across
		var dark := Color(0.16, 0.13, 0.12)
		g.quad(Vector3(cx + hw, 0.65, fz + 0.18), Vector3(cx - hw, 0.65, fz + 0.18), Vector3(cx - hw, 2.6, fz + 0.18), Vector3(cx + hw, 2.6, fz + 0.18), dark, 3.0)
		_reveal(g, cx - hw, cx + hw, 0.65, 2.6, fz, 0.18, col * 0.8)
		var frame := Color(0.93, 0.92, 0.88)
		for fx in [cx - hw + 0.04, cx + hw - 0.04, cx]:
			g.box(Transform3D(Basis(), Vector3(fx, 1.625, fz + 0.15)), Vector3(0.07, 1.95, 0.05), frame, 0.0)
		g.box(Transform3D(Basis(), Vector3(cx, 1.9, fz + 0.15)), Vector3(hw * 2.0, 0.06, 0.05), frame, 0.0)
		g.box(Transform3D(Basis(), Vector3(cx, 0.62, fz - 0.05)), Vector3(hw * 2.0 + 0.2, 0.06, 0.2), Color(0.85, 0.83, 0.78), 7.0)
		# something on the sill inside: jars and a cake stand, catching a little light
		for k in 4:
			var jx := cx - hw + 0.35 + k * (hw * 2.0 - 0.7) / 3.0
			g.lathe(Transform3D(Basis(), Vector3(jx, 0.7, fz + 0.32)), [Vector2(0.0, 0), Vector2(0.09, 0), Vector2(0.1, 0.18), Vector2(0.06, 0.24), Vector2(0.0, 0.25)], 6,
				[Color(0.9, 0.75, 0.4), Color(0.85, 0.5, 0.35), Color(0.95, 0.9, 0.8), Color(0.7, 0.55, 0.4)][k], 3.0)
	# the doorway: deep, dark, warm inside; the doors folded back, a stone frame
	var inside := Color(0.62, 0.4, 0.22)
	g.quad(Vector3(door_x + dw * 0.5, 0, fz + 0.9), Vector3(door_x - dw * 0.5, 0, fz + 0.9), Vector3(door_x - dw * 0.5, dh, fz + 0.9), Vector3(door_x + dw * 0.5, dh, fz + 0.9), inside, 14.0)
	_reveal(g, door_x - dw * 0.5, door_x + dw * 0.5, 0.0, dh, fz, 0.9, col * 0.75)
	var stone := Color(0.9, 0.86, 0.76)
	g.box(Transform3D(Basis(), Vector3(door_x - dw * 0.5 - 0.1, dh * 0.5, fz - 0.04)), Vector3(0.2, dh, 0.1), stone, 7.0)
	g.box(Transform3D(Basis(), Vector3(door_x + dw * 0.5 + 0.1, dh * 0.5, fz - 0.04)), Vector3(0.2, dh, 0.1), stone, 7.0)
	g.box(Transform3D(Basis(), Vector3(door_x, dh + 0.1, fz - 0.04)), Vector3(dw + 0.4, 0.2, 0.1), stone, 7.0)
	var green := Color(0.16, 0.38, 0.27)
	for sx in [-1.0, 1.0]:
		g.box(Transform3D(Basis(), Vector3(door_x + sx * (dw * 0.5 - 0.04), dh * 0.5, fz + 0.5)), Vector3(0.05, dh - 0.05, 0.75), green, 9.0)
	# a counter far inside, a glint of the coffee machine on it, and a bead curtain hanging in the door
	g.box(Transform3D(Basis(), Vector3(door_x - 0.2, 0.55, fz + 0.75)), Vector3(1.4, 1.1, 0.25), Color(0.45, 0.3, 0.2), 9.0)
	g.box(Transform3D(Basis(), Vector3(door_x + 0.2, 1.3, fz + 0.8)), Vector3(0.5, 0.4, 0.2), Color(0.35, 0.33, 0.32), 3.0)
	for k in 26:
		var bx := door_x - dw * 0.5 + 0.08 + k * (dw - 0.16) / 25.0
		var bc: Color = [Color(0.85, 0.3, 0.2), Color(0.95, 0.8, 0.4), Color(0.2, 0.45, 0.6), Color(0.9, 0.9, 0.85)][k % 4]
		g.box(Transform3D(Basis(), Vector3(bx, dh * 0.5 + 0.05, fz + 0.12)), Vector3(0.018, dh - 0.12, 0.018), bc, 0.0)
	# a plinth of stone along the foot
	g.box(Transform3D(Basis(), Vector3((x0 + x1) * 0.5, 0.15, fz - 0.03)), Vector3(x1 - x0, 0.3, 0.08), Color(0.78, 0.72, 0.62), 7.0)
	# the name, painted over the door and windows, and a lamp
	var sign := Label3D.new()
	sign.text = "CAFFÈ  DEL  PORTO"
	sign.font = SERIF
	sign.font_size = 72
	sign.pixel_size = 0.0034
	sign.modulate = Color(0.1, 0.27, 0.42)
	sign.outline_size = 0
	sign.shaded = true
	sign.position = Vector3(0.0, 3.07, fz - 0.015)
	sign.rotation.y = PI
	place.add_child(sign)
	g.box(Transform3D(Basis(), Vector3(door_x + 1.35, 2.35, fz - 0.15)), Vector3(0.16, 0.26, 0.16), Color(0.08, 0.08, 0.07), 3.0)
	g.box(Transform3D(Basis(), Vector3(door_x + 1.35, 2.35, fz - 0.15)), Vector3(0.12, 0.2, 0.18), Color(0.95, 0.85, 0.6), 3.0)
	# the menu board on the terrace by the door: a chalkboard on legs
	var mb := Vector3(-0.75, 0, fz - 0.9)
	var tilt := Basis(Vector3.RIGHT, -0.18)
	var frame_c := Color(0.42, 0.27, 0.16)
	g.box(Transform3D(tilt, mb + Vector3(0, 0.95, 0)), Vector3(0.7, 0.95, 0.03), Color.WHITE, 6.0)
	for sx in [-0.37, 0.37]:
		g.box(Transform3D(tilt, mb + Vector3(sx, 0.62, 0.0)), Vector3(0.05, 1.28, 0.05), frame_c, 9.0)
	g.box(Transform3D(tilt, mb + Vector3(0, 1.45, 0.0)), Vector3(0.79, 0.05, 0.05), frame_c, 9.0)
	g.box(Transform3D(tilt, mb + Vector3(0, 0.46, 0.0)), Vector3(0.79, 0.05, 0.05), frame_c, 9.0)
	g.box(Transform3D(Basis(Vector3.RIGHT, 0.25), mb + Vector3(0, 0.6, 0.3)), Vector3(0.6, 1.2, 0.03), frame_c, 9.0)
	var menu := Label3D.new()
	menu.text = "~ Oggi ~\n\nEspresso  1,20\nCappuccino  1,80\nCornetto  1,50\nSfogliatella  2,50\nGranita al limone  3,50\nSpritz  6,00"
	menu.font = ITALIC
	menu.font_size = 48
	menu.pixel_size = 0.0014
	menu.modulate = Color(0.95, 0.94, 0.88, 0.9)
	menu.outline_size = 0
	menu.line_spacing = 2.0
	menu.shaded = true
	menu.transform = Transform3D(Basis(Vector3.UP, PI) * Basis(Vector3.RIGHT, 0.18), mb + Vector3(0, 0.96, -0.03))
	place.add_child(menu)


# The sides, top and sill of an opening `depth` deep in a wall at z = fz (its face towards -Z)
func _reveal(g: Geo, xa: float, xb: float, ya: float, yb: float, fz: float, depth: float, col: Color) -> void:
	var d := depth
	g.quad(Vector3(xa, ya, fz + d), Vector3(xa, ya, fz), Vector3(xa, yb, fz), Vector3(xa, yb, fz + d), col, 11.0)
	g.quad(Vector3(xb, ya, fz), Vector3(xb, ya, fz + d), Vector3(xb, yb, fz + d), Vector3(xb, yb, fz), col, 11.0)
	g.quad(Vector3(xb, yb, fz), Vector3(xb, yb, fz + d), Vector3(xa, yb, fz + d), Vector3(xa, yb, fz), col * 0.7, 11.0)
	g.quad(Vector3(xa, ya, fz), Vector3(xa, ya, fz + d), Vector3(xb, ya, fz + d), Vector3(xb, ya, fz), col * 1.05, 11.0)


# --- the lane of steps, climbing into the town beside the cafe ---

func _lane() -> void:
	var g := Geo.new()
	var lx: float = place.LANE_X
	var hw: float = place.LANE_HALF
	var fz: float = place.FRONT_Z
	var run := 0.5
	var step_c := Color(0.78, 0.74, 0.66)
	var z := fz
	while z < 70.0:
		var y0: float = place.lane_height(z)
		var y1: float = place.lane_height(z + run)
		g.box(Transform3D(Basis(), Vector3(lx, (y1 + y0) * 0.5 - 0.5, z + run * 0.5)), Vector3(hw * 2.0, y1 - y0 + 1.0, run), step_c * rng.randf_range(0.92, 1.05), 7.0, 0.0, ["bottom", "front", "back"])
		# the step's riser, paler, its nose catching the light
		g.quad(Vector3(lx + hw, y0, z), Vector3(lx - hw, y0, z), Vector3(lx - hw, y1, z), Vector3(lx + hw, y1, z), step_c * 1.08, 7.0)
		z += run
	place.put(g, place.lit_still, true)
	# houses either side of it, fronts to the lane, an arch across it, washing strung over it
	z = fz + 10.0
	while z < 66.0:
		var w := rng.randf_range(5.0, 8.0)
		var zc := z + w * 0.5
		var y: float = place.lane_height(z) - 0.6
		var cg := _chunk(lx, zc)
		house(cg, Vector3(lx - hw, y, zc), -PI * 0.5, w, 8.0, rng.randf_range(9.0, 13.0), _wall_color(), rng.randf() < 0.5, 4)
		z += w
	z = fz + 10.0
	while z < 66.0:
		var w := rng.randf_range(5.0, 8.0)
		var zc := z + w * 0.5
		var y: float = place.lane_height(z) - 0.6
		house(_chunk(lx, zc), Vector3(lx + hw, y, zc), PI * 0.5, w, 8.0, rng.randf_range(9.0, 13.0), _wall_color(), rng.randf() < 0.5, 4)
		z += w
	# an arch carrying a room over the lane
	var az := 27.0
	var ay: float = place.lane_height(az)
	var ag := _chunk(lx, az)
	house(ag, Vector3(lx, ay + 3.6, az - 1.8), 0.0, hw * 2.0 + 0.2, 3.6, 3.4, Color(0.95, 0.9, 0.8), false, 0, 2, ["left", "right"])
	ag.quad(Vector3(lx - hw, ay + 3.6, az + 1.8), Vector3(lx + hw, ay + 3.6, az + 1.8), Vector3(lx + hw, ay + 3.6, az - 1.8), Vector3(lx - hw, ay + 3.6, az - 1.8), Color(0.7, 0.66, 0.6), 2.0, 0.5)
	# washing on a line between the houses: shirts and sheets, swaying
	var wash := Geo.new()
	for line in [[13.0, 4.6], [21.0, 5.0], [36.0, 4.8]]:
		var lz: float = line[0]
		var ly: float = place.lane_height(lz) + float(line[1])
		wash.rod(Vector3(lx - hw, ly, lz), Vector3(lx + hw, ly - 0.05, lz), 0.006, Color(0.85, 0.85, 0.8), 0.0, 3)
		var cx := lx - hw + 0.3
		while cx < lx + hw - 0.4:
			var cw := rng.randf_range(0.35, 0.8)
			var ch := rng.randf_range(0.45, 0.95)
			var cc: Color = [Color(0.96, 0.95, 0.92), Color(0.3, 0.45, 0.75), Color(0.9, 0.35, 0.3), Color(0.98, 0.85, 0.4), Color(0.95, 0.7, 0.75)][rng.randi() % 5]
			wash.quad(Vector3(cx, ly - ch, lz), Vector3(cx + cw, ly - ch, lz), Vector3(cx + cw, ly, lz), Vector3(cx, ly, lz), cc, 4.0)
			wash.quad(Vector3(cx + cw, ly - ch, lz), Vector3(cx, ly - ch, lz), Vector3(cx, ly, lz), Vector3(cx + cw, ly, lz), cc * 0.9, 4.0)
			cx += cw + rng.randf_range(0.08, 0.3)
	place.put(wash, place.lit, true)


# --- the church over the right quay ---

func _church() -> void:
	var g := church
	var zc := -27.0
	var fx: float = place.shore_r(zc) + 5.5
	var w := 11.0
	var depth := 22.0
	var h := 13.0
	var col := Color(0.97, 0.93, 0.84)
	var trim := Color(0.9, 0.72, 0.42)
	# the nave: a box, its gable end the front, to the harbour (-X)
	var xf := Transform3D(Basis(), Vector3(fx + depth * 0.5, h * 0.5, zc))
	g.box(xf, Vector3(depth, h, w), col, 11.0, 0.0, ["bottom", "top"])
	var rise := 4.2
	var f0 := Vector3(fx, h, zc + w * 0.5)
	var f1 := Vector3(fx, h, zc - w * 0.5)
	var ft := Vector3(fx, h + rise, zc)
	var n := Vector3.LEFT
	g.tri(f1, f0, ft, n, n, n, col, 11.0)
	var back := Vector3(depth, 0, 0)
	n = Vector3.RIGHT
	g.tri(f0 + back, f1 + back, ft + back, n, n, n, col, 11.0)
	var roof := ROOF * 0.95
	var over := Vector3(-0.4, 0, 0)
	g.quad(f1 + back + Vector3(0.3, 0, -0.3), f1 + over + Vector3(0, 0, -0.3), ft + over, ft + back + Vector3(0.3, 0, 0), roof, 0.0)
	g.quad(f0 + over + Vector3(0, 0, 0.3), f0 + back + Vector3(0.3, 0, 0.3), ft + back + Vector3(0.3, 0, 0), ft + over, roof, 0.0)
	# the front: pilasters and a cornice in ochre, a round window, a great door under an arch
	for zz in [zc - w * 0.5 + 0.35, zc + w * 0.5 - 0.35, zc - 2.2, zc + 2.2]:
		g.box(Transform3D(Basis(), Vector3(fx - 0.12, h * 0.5, zz)), Vector3(0.25, h, 0.6), trim, 11.0)
	g.box(Transform3D(Basis(), Vector3(fx - 0.15, h - 0.25, zc)), Vector3(0.32, 0.5, w + 0.3), trim, 11.0)
	g.box(Transform3D(Basis(), Vector3(fx - 0.15, 5.6, zc)), Vector3(0.3, 0.35, w + 0.2), trim, 11.0)
	var dark := Color(0.12, 0.1, 0.1)
	g.lathe(Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(fx - 0.05, 9.0, zc)), [Vector2(0.0, 0.0), Vector2(1.1, 0.0), Vector2(1.1, 0.06)], 14, trim, 11.0)
	g.lathe(Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(fx - 0.07, 9.0, zc)), [Vector2(0.0, 0.0), Vector2(0.8, 0.0), Vector2(0.8, 0.06)], 14, dark, 10.0)
	g.box(Transform3D(Basis(), Vector3(fx - 0.05, 1.75, zc)), Vector3(0.1, 3.5, 2.0), Color(0.36, 0.22, 0.14), 9.0)
	g.lathe(Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(fx - 0.06, 3.5, zc)), [Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 0.05)], 10, Color(0.36, 0.22, 0.14), 9.0)
	g.box(Transform3D(Basis(), Vector3(fx - 0.6, 0.1, zc)), Vector3(1.2, 0.2, 3.4), Color(0.8, 0.76, 0.68), 7.0)
	# the bell tower beside it: plain below, a belfry of open arches, a cornice, a little dome of
	# yellow and green tiles on a drum
	var tz := zc - w * 0.5 - 2.4
	var tx := fx + 2.5
	var tower := Color(0.93, 0.72, 0.44)
	var ts := 4.4
	var th := 21.0
	g.box(Transform3D(Basis(), Vector3(tx, th * 0.5, tz)), Vector3(ts, th, ts), tower, 11.0, 0.0, ["bottom"])
	for y in [th * 0.38, th * 0.7]:
		g.box(Transform3D(Basis(), Vector3(tx, y, tz)), Vector3(ts + 0.2, 0.3, ts + 0.2), col, 11.0)
	g.box(Transform3D(Basis(), Vector3(tx, th + 0.2, tz)), Vector3(ts + 0.5, 0.4, ts + 0.5), col, 11.0)
	var by := th - 4.2
	for side in 4:
		var b := Basis(Vector3.UP, side * PI * 0.5)
		var c := Vector3(tx, by + 1.6, tz) + b * Vector3(0, 0, -ts * 0.5 - 0.02)
		g.box(Transform3D(b, c), Vector3(1.5, 3.0, 0.05), dark, 10.0)
		g.lathe(Transform3D(b * Basis(Vector3.RIGHT, PI * 0.5), c + Vector3.UP * 1.5), [Vector2(0.0, 0.0), Vector2(0.75, 0.0), Vector2(0.75, 0.05)], 8, dark, 10.0)
		# a clock face on the side to the harbour, under the belfry
		if side == 1:
			var cc := Vector3(tx, th * 0.55, tz) + b * Vector3(0, 0, -ts * 0.5 - 0.03)
			g.lathe(Transform3D(b * Basis(Vector3.RIGHT, PI * 0.5), cc), [Vector2(0.0, 0.0), Vector2(0.8, 0.0), Vector2(0.8, 0.04)], 12, Color(0.95, 0.94, 0.9), 0.0)
			g.box(Transform3D(b * Basis(Vector3.BACK, 0.5), cc + b * Vector3(0, 0, -0.05) + Vector3.UP * 0.2), Vector3(0.06, 0.5, 0.02), dark, 0.0)
			g.box(Transform3D(b * Basis(Vector3.BACK, 1.9), cc + b * Vector3(0, 0, -0.05)), Vector3(0.05, 0.6, 0.02), dark, 0.0)
	# the bell, in the dark of the arches
	g.lathe(Transform3D(Basis(), Vector3(tx, by + 1.2, tz)), [Vector2(0.0, 0.0), Vector2(0.6, 0.0), Vector2(0.45, 0.4), Vector2(0.35, 0.9), Vector2(0.0, 1.0)], 8, Color(0.55, 0.42, 0.2), 3.0)
	g.lathe(Transform3D(Basis(), Vector3(tx, th + 0.4, tz)), [Vector2(1.7, 0.0), Vector2(1.7, 1.2)], 8, col, 11.0, 0.0, false)
	var dome := []
	for k in 7:
		var a := PI * 0.5 * k / 6.0
		dome.append(Vector2(cos(a) * 1.85, 1.2 + sin(a) * 2.1))
	g.lathe(Transform3D(Basis(), Vector3(tx, th + 0.4, tz)), [Vector2(1.95, 1.2), Vector2(1.95, 1.35)], 8, trim, 11.0)
	_dome(g, Vector3(tx, th + 0.4, tz), dome, 16)
	g.lathe(Transform3D(Basis(), Vector3(tx, th + 3.7, tz)), [Vector2(0.0, 0.0), Vector2(0.18, 0.0), Vector2(0.1, 0.6), Vector2(0.0, 1.0)], 6, Color(0.6, 0.55, 0.4), 3.0)
	# a cross
	g.box(Transform3D(Basis(), Vector3(tx, th + 5.1, tz)), Vector3(0.08, 0.9, 0.08), Color(0.2, 0.2, 0.18), 3.0)
	g.box(Transform3D(Basis(), Vector3(tx, th + 5.25, tz)), Vector3(0.08, 0.08, 0.5), Color(0.2, 0.2, 0.18), 3.0)
	taken.append(Vector3(fx + depth * 0.5, zc, 13.0))


# The tower's dome: tiles in yellow and green, in alternating segments
func _dome(g: Geo, at: Vector3, prof: Array, sides: int) -> void:
	var yellow := Color(0.95, 0.75, 0.2)
	var green := Color(0.15, 0.5, 0.35)
	for s in sides:
		var c := yellow if s % 2 == 0 else green
		var a0 := TAU * s / sides
		var a1 := TAU * (s + 1) / sides
		for i in prof.size() - 1:
			var p: Vector2 = prof[i]
			var q: Vector2 = prof[i + 1]
			var d0 := Vector3(cos(a0), 0, sin(a0))
			var d1 := Vector3(cos(a1), 0, sin(a1))
			var v00 := at + d0 * p.x + Vector3.UP * p.y
			var v01 := at + d1 * p.x + Vector3.UP * p.y
			var v10 := at + d0 * q.x + Vector3.UP * q.y
			var v11 := at + d1 * q.x + Vector3.UP * q.y
			var n0 := (v00 - at - Vector3.UP * 1.2).normalized()
			var n1 := (v01 - at - Vector3.UP * 1.2).normalized()
			var n2 := (v10 - at - Vector3.UP * 1.2).normalized()
			var n3 := (v11 - at - Vector3.UP * 1.2).normalized()
			g.tri(v00, v10, v11, n0, n2, n3, c, 3.0)
			g.tri(v00, v11, v01, n0, n3, n1, c, 3.0)


# --- up the cliffs ---

func _hillside() -> void:
	var step := 7.0
	var x := -260.0
	while x < 150.0:
		var z := -210.0
		while z < 210.0:
			var px := x + rng.randf_range(-2.5, 2.5)
			var pz := z + rng.randf_range(-2.5, 2.5)
			z += step
			if not _house_spot(px, pz):
				continue
			var h0: float = place.height(px, pz)
			# the way downhill: the house looks that way
			var gx: float = place.height(px + 1.5, pz) - place.height(px - 1.5, pz)
			var gz: float = place.height(px, pz + 1.5) - place.height(px, pz - 1.5)
			var down := Vector2(-gx, -gz)
			if down.length() < 0.05:
				down = Vector2(-px, -pz - 60.0)
			down = down.normalized()
			var yaw := atan2(-down.x, -down.y)
			var w := rng.randf_range(5.0, 8.5)
			var depth := rng.randf_range(5.5, 8.0)
			var b := Basis(Vector3.UP, yaw)
			var front_at := Vector3(px, 0, pz) + b * Vector3(0, 0, -depth * 0.5)
			var lo := INF
			var hi := -INF
			for c in [Vector3(-w * 0.5, 0, 0), Vector3(w * 0.5, 0, 0), Vector3(-w * 0.5, 0, depth), Vector3(w * 0.5, 0, depth)]:
				var q: Vector3 = front_at + b * c
				var hh: float = place.height(q.x, q.z)
				lo = minf(lo, hh)
				hi = maxf(hi, hh)
			if lo < 0.5:
				continue
			var h := hi - lo + rng.randf_range(5.5, 10.0)
			front_at.y = lo - 0.8
			house(_chunk(px, pz), front_at, yaw, w, depth, h + 0.8, _wall_color(), rng.randf() < 0.4, 0, 0 if rng.randf() < 0.6 else 2)
		x += step


func _house_spot(x: float, z: float) -> bool:
	var h: float = place.height(x, z)
	if h < 3.0 or h > 75.0:
		return false
	var d: Vector3 = place.into(x, z)
	var qw: Vector3 = place.quay_w(z)
	# clear of the rows along the quays and of the lane and the cafe
	if d.z > 0.0 and d.z - qw.z < 12.0 and d.x < 40.0 and d.y < 40.0:
		return false
	if d.x > 0.0 and d.x - qw.x < 13.0 and z > -52.0 and qw.x > 0.5:
		return false
	if d.y > 0.0 and d.y - qw.y < 13.0 and z > -56.0 and qw.y > 0.5:
		return false
	if absf(x - place.LANE_X) < 11.0 and z > 2.0 and z < 72.0:
		return false
	# the church
	if Vector2(x, z).distance_to(Vector2(place.shore_r(-28.0) + 16.0, -28.0)) < 17.0:
		return false
	# the town thins out up the slopes and out along the headlands
	var dist := Vector2(x, z + 20.0).length()
	var keep := (1.0 - smoothstep(25.0, 70.0, h)) * (1.0 - smoothstep(110.0, 220.0, dist))
	# steep rock: fewer
	var gx: float = place.height(x + 2.0, z) - place.height(x - 2.0, z)
	var gz: float = place.height(x, z + 2.0) - place.height(x, z - 2.0)
	var slope := Vector2(gx, gz).length() / 4.0
	keep *= 1.0 - smoothstep(0.9, 1.6, slope)
	return rng.randf() < keep * 0.9


func _clear(x: float, z: float, r: float) -> bool:
	for t in taken:
		if Vector2(x - t.x, z - t.y).length() < t.z + r:
			return false
	return true


# --- pines, cypresses and scrub on the slopes ---

func _plants() -> void:
	# GameCommon's trees, drawn in the place's own light (lit_tree): olives and maquis (leafy-tree, after its
	# pinyon), umbrella pines and cypresses (pine-tree). All far off, so their plain versions.
	var olive := LeafyTree.pinyon()
	olive.height = 4.2
	olive.spread = 1.0
	olive.leaves_dark = Color(0.13, 0.19, 0.12)
	olive.leaves = Color(0.3, 0.37, 0.22)
	olive.leaves_light = Color(0.5, 0.56, 0.38)
	olive.bark = Color(0.4, 0.35, 0.28)
	olive.material = place.lit_tree
	olive.seed = 31
	var umbrella := PineTree.new()
	umbrella.height = 13.0
	umbrella.trunk_radius = 0.3
	umbrella.crown_base = 0.72
	umbrella.whorls = 5
	umbrella.branches = 10
	umbrella.spread = 0.95
	umbrella.droop = 0.0
	umbrella.taper = 2.5
	umbrella.fullness = 0.7
	umbrella.sprigs = 1
	umbrella.lean = 0.12
	umbrella.bark = Color(0.45, 0.3, 0.22)
	umbrella.needles_inner = Color(0.1, 0.2, 0.1)
	umbrella.needles_outer = Color(0.2, 0.34, 0.16)
	umbrella.tips = Color(0.32, 0.46, 0.22)
	umbrella.material = place.lit_tree
	umbrella.seed = 77
	var cypress := PineTree.new()
	cypress.height = 11.0
	cypress.trunk_radius = 0.16
	cypress.crown_base = 0.04
	cypress.whorls = 16
	cypress.branches = 7
	cypress.spread = 0.16
	cypress.droop = 0.15
	cypress.taper = 1.4
	cypress.fullness = 0.8
	cypress.sprigs = 0
	cypress.lean = 0.0
	cypress.needles_inner = Color(0.06, 0.13, 0.08)
	cypress.needles_outer = Color(0.12, 0.22, 0.12)
	cypress.tips = Color(0.2, 0.3, 0.16)
	cypress.material = place.lit_tree
	cypress.seed = 5
	var olives := []
	var pines := []
	var cypresses := []
	var tries := 0
	while olives.size() < 260 and tries < 9000:
		tries += 1
		var x := rng.randf_range(-300.0, 230.0)
		var z := rng.randf_range(-260.0, 240.0)
		var h: float = place.height(x, z)
		if h < 1.5 or h > 140.0:
			continue
		if Vector2(x, z).length() < 22.0 or not _clear(x, z, 1.5):
			continue
		var gx: float = place.height(x + 2.0, z) - place.height(x - 2.0, z)
		var gz: float = place.height(x, z + 2.0) - place.height(x, z - 2.0)
		if Vector2(gx, gz).length() / 4.0 > 1.3 and rng.randf() < 0.7:
			continue
		var r := rng.randf()
		if r < 0.06 and h > 15.0:
			pines.append(Vector3(x, h - 0.2, z))
		elif r < 0.11 and h < 60.0:
			cypresses.append(Vector3(x, h - 0.2, z))
		else:
			olives.append(Vector3(x, h - 0.3, z))
	# a few set by hand: pines along the left headland's ridge, cypresses behind the church
	for p in [Vector2(-52, -95), Vector2(-46, -120), Vector2(-40, -140), Vector2(-60, -70), Vector2(-35, -158)]:
		pines.append(Vector3(p.x, place.height(p.x, p.y) - 0.2, p.y))
	for p in [Vector2(56, -24), Vector2(58, -30), Vector2(57, -36), Vector2(50, -42)]:
		cypresses.append(Vector3(p.x, place.height(p.x, p.y) - 0.2, p.y))
	for mmi in LeafyTree.forest(place, olives, olive, 3, Vector2(0.7, 1.5), 200.0, 1.0):
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for mmi in PineTree.forest(place, pines, umbrella, 2, Vector2(0.8, 1.2), 200.0, 1.0):
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for mmi in PineTree.forest(place, cypresses, cypress, 2, Vector2(0.75, 1.25), 200.0, 1.0):
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
