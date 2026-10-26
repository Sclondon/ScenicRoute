extends Node3D
## The Velvet Moth: a night club, late, the floor still full. You stand at the rail of the low mezzanine
## looking down over the dance floor to the DJ, under a great neon moth. The floor's glass tiles pulse to the
## beat, beams sweep through the haze, the mirror ball throws its specks round the walls, and the crowd
## dances, every one in its own way. Behind you, the backlit bar; to the sides, velvet booths.
##
## Everything moves to one beat, 122 BPM, kept on the music's own clock (club_sound.gd) and handed to every
## shader as `beat`. All painted by hand (shaders/velvet_moth/club.gdshaderinc's club_light), no engine
## lights; fog for the haze and the engine's glow for the neon.
##
## Built from code and seeded, the same every visit.

const Geo := preload("res://scripts/velvet_moth/geo.gd")
const Figures := preload("res://scripts/velvet_moth/figures.gd")
const ClubSound := preload("res://scripts/velvet_moth/club_sound.gd")
const ROOM := preload("res://shaders/velvet_moth/room.gdshader")
const TILES := preload("res://shaders/velvet_moth/tiles.gdshader")
const CROWD := preload("res://shaders/velvet_moth/crowd.gdshader")
const BEAM := preload("res://shaders/velvet_moth/beam.gdshader")
const HALO := preload("res://shaders/velvet_moth/halo.gdshader")
const NEON := preload("res://shaders/velvet_moth/neon.gdshader")
const BALL_SHADER := preload("res://shaders/velvet_moth/ball.gdshader")
const BOTTLE := preload("res://shaders/velvet_moth/bottle.gdshader")
const PANEL := preload("res://shaders/velvet_moth/panel.gdshader")
const ITALIC := preload("res://fonts/LibreBaskerville-Italic.ttf")

const BPM := 122.0
## The hall: its half width, the wall behind the stage, the wall behind the bar, the ceiling.
const HALL_X := 12.0
const STAGE_WALL := -18.0
const BACK_WALL := 11.5
const CEILING := 8.5
## The mezzanine: its floor, and its front edge (the rail) along z = 0.
const MEZZ_Y := 2.0
## The dance floor, as in club.gdshaderinc: x0, z0, x1, z1.
const FLOOR_RECT := Rect2(-6.0, -14.0, 12.0, 11.0)
const BALL := Vector3(-1.6, 6.4, -8.0)
const STAGE := Rect2(-5.5, -18.0, 11.0, 3.5)
const STAGE_Y := 0.9

## Where you face on arriving: down over the floor to the DJ and the moth.
const VIEW := {"look": Vector2(2.5, -9.0)}

var rng := RandomNumberGenerator.new()
var materials: Array[ShaderMaterial] = []
var halos: Array = []  # [position, size, colour, throb]
var _sound: Node
var _beat := 0.0
var _heard := -1.0

var room := Geo.new()
var drape := Geo.new()
var plush := Geo.new()
var brass := Geo.new()
var lacquer := Geo.new()
var neon := Geo.new()


static func view_position() -> Vector3:
	return Vector3(0.8, MEZZ_Y + 1.6, 0.8)


func _ready() -> void:
	rng.seed = 1931
	_environment()
	_hall()
	_mezzanine()
	_stage()
	_bar()
	_booths()
	_moths()
	_crowd()
	_beams()
	_ball()
	_signs()
	_commit()


func _process(delta: float) -> void:
	_beat += delta * BPM / 60.0
	# keep to the music: ease onto its clock (or jump, if far out)
	if is_instance_valid(_sound):
		var heard: float = _sound.beat()
		if heard >= 0.0 and heard != _heard:
			_heard = heard
			var beats := float(ClubSound.BEATS)
			var diff := wrapf(heard - fposmod(_beat, beats), -beats * 0.5, beats * 0.5)
			_beat += diff if absf(diff) > 1.0 else diff * minf(delta * 3.0, 1.0)
	for m in materials:
		m.set_shader_parameter("beat", _beat)


## The sound of the club (main.gd starts it when you arrive); the lights keep to its beat.
func make_ambience() -> Node:
	_sound = ClubSound.new()
	return _sound


func _mat(shader: Shader, params := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader
	for k in params:
		m.set_shader_parameter(k, params[k])
	materials.append(m)
	return m


func _mesh(g: Geo, material: ShaderMaterial) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = g.commit()
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.01, 0.03)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.1, 0.05, 0.15)
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color(0.13, 0.04, 0.24)
	env.fog_density = 0.022
	env.fog_sky_affect = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_strength = 1.0
	env.glow_bloom = 0.02
	env.glow_hdr_threshold = 0.8
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


# --- the hall: floor, walls, ceiling, the truss ---

func _hall() -> void:
	var dark := Color(0.32, 0.26, 0.38)
	room.quad(Vector3(-HALL_X, 0, 0), Vector3(HALL_X, 0, 0), Vector3(HALL_X, 0, STAGE_WALL), Vector3(-HALL_X, 0, STAGE_WALL), Vector3.UP, dark)
	room.quad(Vector3(-HALL_X, CEILING, STAGE_WALL), Vector3(HALL_X, CEILING, STAGE_WALL), Vector3(HALL_X, CEILING, BACK_WALL), Vector3(-HALL_X, CEILING, BACK_WALL), Vector3.DOWN, Color(0.2, 0.14, 0.24))
	# the tiles: one card, the shader draws them
	var tiles := Geo.new()
	var r := FLOOR_RECT
	tiles.quad(Vector3(r.position.x, 0.01, r.end.y), Vector3(r.end.x, 0.01, r.end.y), Vector3(r.end.x, 0.01, r.position.y), Vector3(r.position.x, 0.01, r.position.y), Vector3.UP, Color.WHITE)
	_mesh(tiles, _mat(TILES))
	# a brass edge round the floor
	var e := 0.04
	brass.box(Vector3(r.position.x - e, 0, r.position.y - e), Vector3(r.end.x + e, 0.03, r.position.y), Color.WHITE)
	brass.box(Vector3(r.position.x - e, 0, r.end.y), Vector3(r.end.x + e, 0.03, r.end.y + e), Color.WHITE)
	brass.box(Vector3(r.position.x - e, 0, r.position.y), Vector3(r.position.x, 0.03, r.end.y), Color.WHITE)
	brass.box(Vector3(r.end.x, 0, r.position.y), Vector3(r.end.x + e, 0.03, r.end.y), Color.WHITE)
	# velvet drapes all round: plum on the sides, near black behind the stage
	var plum := Color(0.62, 0.16, 0.46)
	_drape(Vector3(-HALL_X, 0, BACK_WALL), Vector3(-HALL_X, 0, STAGE_WALL), CEILING, plum)
	_drape(Vector3(HALL_X, 0, STAGE_WALL), Vector3(HALL_X, 0, BACK_WALL), CEILING, plum)
	_drape(Vector3(-HALL_X, 0, STAGE_WALL + 0.25), Vector3(HALL_X, 0, STAGE_WALL + 0.25), CEILING, Color(0.3, 0.1, 0.36))
	_drape(Vector3(HALL_X, MEZZ_Y, BACK_WALL - 0.2), Vector3(6.5, MEZZ_Y, BACK_WALL - 0.2), CEILING - MEZZ_Y, plum)
	_drape(Vector3(-6.5, MEZZ_Y, BACK_WALL - 0.2), Vector3(-HALL_X, MEZZ_Y, BACK_WALL - 0.2), CEILING - MEZZ_Y, plum)
	# the truss the lights hang from
	var steel := Color(0.22, 0.2, 0.26)
	for z in [-5.0, -12.0]:
		room.box(Vector3(-8.5, 7.55, z - 0.15), Vector3(8.5, 7.85, z + 0.15), steel)
		for x in [-7.0, 0.0, 7.0]:
			room.box(Vector3(x - 0.03, 7.85, z - 0.03), Vector3(x + 0.03, CEILING, z + 0.03), steel)
	for x in [-8.5, 8.5]:
		room.box(Vector3(x - 0.15, 7.55, -12.15), Vector3(x + 0.15, 7.85, -4.85), steel)
	# sconces on the walls, both floors
	for z in [-14.5, -10.5, -6.5, -2.5]:
		for side in [-1.0, 1.0]:
			_sconce(Vector3(side * (HALL_X - 0.25), 2.6, z), Color(1.0, 0.35, 0.6))
	for z in [5.6, 9.2]:
		for side in [-1.0, 1.0]:
			_sconce(Vector3(side * (HALL_X - 0.25), MEZZ_Y + 2.4, z), Color(1.0, 0.5, 0.35))


# A curtain hung along a wall from a to b (its foot), `height` tall, in deep vertical folds, facing into the
# room (to the left of a->b seen from above)
func _drape(a: Vector3, b: Vector3, height: float, col: Color) -> void:
	var along := b - a
	var length := along.length()
	var t := along / length
	var inward := t.cross(Vector3.UP).normalized()
	var step := 0.11
	var count := int(length / step)
	var start := drape.verts.size()
	var fold_len := 0.5 + rng.randf() * 0.1
	var ph := rng.randf() * TAU
	for k in count + 1:
		var s := length * k / count
		var w := sin(s * TAU / fold_len + ph + sin(s * 1.3) * 1.5)
		var dw := cos(s * TAU / fold_len + ph + sin(s * 1.3) * 1.5) * (TAU / fold_len)
		var off := inward * (0.09 + 0.09 * w)
		var n := (inward - t * 0.09 * dw).normalized()
		var p := a + t * s + off
		var shade := Color(col.r, col.g, col.b) * (0.85 + 0.15 * w)
		drape._v(p, n, shade, Vector2(s, 0))
		drape._v(p + Vector3.UP * height, n, shade, Vector2(s, 1))
	for k in count:
		var i := start + k * 2
		drape.tri(i, i + 1, i + 3)
		drape.tri(i, i + 3, i + 2)


func _sconce(at: Vector3, col: Color) -> void:
	var inward := Vector3(-signf(at.x), 0, 0)
	brass.box(at - Vector3(0.04, 0.2, 0.08) + inward * 0.1, at + Vector3(0.04, 0.05, 0.08) + inward * 0.1, Color.WHITE)
	neon.prism(at + inward * 0.18 + Vector3(0, -0.05, 0), at + inward * 0.18 + Vector3(0, 0.3, 0), 0.07, 0.11, 8, Color(col.r, col.g * 0.8, col.b * 0.8))
	halos.append([at + inward * 0.25 + Vector3(0, 0.15, 0), 1.6, col * 0.5, 0.0])


# --- the mezzanine you stand on ---

func _mezzanine() -> void:
	# (alpha 0: the shader lays planks on its top)
	var wood := Color(0.42, 0.22, 0.24, 0.0)
	room.box(Vector3(-HALL_X, MEZZ_Y - 0.3, 0.0), Vector3(HALL_X, MEZZ_Y, BACK_WALL), wood)
	room.box(Vector3(-HALL_X, 0, -0.06), Vector3(HALL_X, MEZZ_Y - 0.3, 0.0), Color(0.2, 0.12, 0.22))
	# a magenta line of light along its edge
	neon.tube(PackedVector3Array([Vector3(-HALL_X, MEZZ_Y - 0.22, -0.08), Vector3(HALL_X, MEZZ_Y - 0.22, -0.08)]), 0.025, 6, Color(1.0, 0.2, 0.7))
	# the rail: brass on posts, a lower rail, smoked glass panels
	var top := MEZZ_Y + 1.05
	brass.tube(PackedVector3Array([Vector3(-HALL_X, top, 0.06), Vector3(HALL_X, top, 0.06)]), 0.035, 8, Color.WHITE)
	brass.tube(PackedVector3Array([Vector3(-HALL_X, MEZZ_Y + 0.12, 0.06), Vector3(HALL_X, MEZZ_Y + 0.12, 0.06)]), 0.02, 6, Color.WHITE)
	var x := -HALL_X + 0.3
	while x < HALL_X:
		brass.prism(Vector3(x, MEZZ_Y, 0.06), Vector3(x, top, 0.06), 0.022, 0.022, 6, Color.WHITE, false)
		x += 1.2
	x = -HALL_X + 0.3
	while x < HALL_X:
		# thin balusters between
		for k in range(1, 6):
			var bx := x + k * 0.2
			if bx < HALL_X:
				brass.prism(Vector3(bx, MEZZ_Y + 0.12, 0.06), Vector3(bx, top, 0.06), 0.009, 0.009, 4, Color(0.7, 0.7, 0.7), false)
		x += 1.2


# --- the stage, the DJ, the speakers ---

func _stage() -> void:
	var s := STAGE
	room.box(Vector3(s.position.x, 0, s.position.y), Vector3(s.end.x, STAGE_Y, s.end.y), Color(0.16, 0.1, 0.2))
	neon.tube(PackedVector3Array([Vector3(s.position.x, STAGE_Y - 0.06, s.end.y + 0.02), Vector3(s.end.x, STAGE_Y - 0.06, s.end.y + 0.02)]), 0.022, 6, Color(0.3, 0.7, 1.0))
	# the DJ's booth: a desk with level meters across its front, two decks and a mixer
	var z0 := s.end.y - 1.2
	var z1 := s.end.y - 0.5
	room.box(Vector3(-1.9, STAGE_Y, z0), Vector3(1.9, STAGE_Y + 1.05, z1), Color(0.12, 0.08, 0.15))
	lacquer.box(Vector3(-2.0, STAGE_Y + 1.05, z0 - 0.05), Vector3(2.0, STAGE_Y + 1.1, z1 + 0.05), Color(0.2, 0.15, 0.25))
	var meters := Geo.new()
	meters.quad(Vector3(-1.75, STAGE_Y + 0.15, z1 + 0.01), Vector3(1.75, STAGE_Y + 0.15, z1 + 0.01), Vector3(1.75, STAGE_Y + 0.95, z1 + 0.01), Vector3(-1.75, STAGE_Y + 0.95, z1 + 0.01), Vector3.BACK, Color.WHITE)
	_mesh(meters, _mat(PANEL, {"mode": 1, "cells": Vector2(24.0, 5.0)}))
	var top := STAGE_Y + 1.1
	for side in [-1.0, 1.0]:
		var c := Vector3(side * 0.75, top, (z0 + z1) * 0.5)
		room.lathe(c, PackedVector2Array([Vector2(0.2, 0.0), Vector2(0.2, 0.05), Vector2(0.0, 0.05)]), 14, Color(0.15, 0.12, 0.18))
		var ring := PackedVector3Array()
		for k in 16:
			var a := TAU * k / 16.0
			ring.append(c + Vector3(cos(a) * 0.17, 0.06, sin(a) * 0.17))
		neon.tube(ring, 0.01, 4, Color(0.2, 0.8, 1.0), 0.0, true)
		halos.append([c + Vector3(0, 0.1, 0), 0.7, Color(0.1, 0.4, 0.8), 0.6])
	room.box(Vector3(-0.3, top, z0 + 0.1), Vector3(0.3, top + 0.07, z1 - 0.1), Color(0.1, 0.08, 0.12))
	halos.append([Vector3(0, top + 0.1, (z0 + z1) * 0.5), 0.5, Color(1.0, 0.3, 0.6), 1.0])
	# speaker stacks either side
	var speaker := Geo.new()
	for side in [-1.0, 1.0]:
		var cx: float = side * 7.4
		var zf := -14.4
		for k in 2:
			var y0 := k * 1.6
			room.box(Vector3(cx - 0.7, y0, zf - 1.0), Vector3(cx + 0.7, y0 + 1.58, zf), Color(0.12, 0.09, 0.14))
			speaker.quad(Vector3(cx - 0.65, y0 + 0.04, zf + 0.01), Vector3(cx + 0.65, y0 + 0.04, zf + 0.01), Vector3(cx + 0.65, y0 + 1.54, zf + 0.01), Vector3(cx - 0.65, y0 + 1.54, zf + 0.01), Vector3.BACK, Color.WHITE)
	_mesh(speaker, _mat(PANEL, {"mode": 2}))


# --- the bar, behind you ---

func _bar() -> void:
	var z0 := 8.4
	var z1 := 9.2
	var hx := 5.5
	var y := MEZZ_Y
	plush.box(Vector3(-hx, y, z0), Vector3(hx, y + 1.05, z1), Color(0.72, 0.12, 0.32))
	lacquer.box(Vector3(-hx - 0.2, y + 1.05, z0 - 0.15), Vector3(hx + 0.2, y + 1.12, z1 + 0.05), Color(0.14, 0.08, 0.14))
	neon.tube(PackedVector3Array([Vector3(-hx - 0.15, y + 1.02, z0 - 0.14), Vector3(hx + 0.15, y + 1.02, z0 - 0.14)]), 0.015, 5, Color(1.0, 0.55, 0.25))
	brass.tube(PackedVector3Array([Vector3(-hx, y + 0.22, z0 - 0.18), Vector3(hx, y + 0.22, z0 - 0.18)]), 0.025, 6, Color.WHITE)
	# the back counter and the lit wall of bottles over it
	var bz := BACK_WALL - 0.05
	room.box(Vector3(-hx, y, bz - 0.75), Vector3(hx, y + 0.95, bz), Color(0.3, 0.14, 0.2))
	lacquer.box(Vector3(-hx, y + 0.95, bz - 0.8), Vector3(hx, y + 1.0, bz), Color(0.14, 0.08, 0.14))
	var panel := Geo.new()
	var py0 := y + 1.05
	var py1 := y + 3.2
	panel.quad(Vector3(hx - 0.2, py0, bz - 0.01), Vector3(-hx + 0.2, py0, bz - 0.01), Vector3(-hx + 0.2, py1, bz - 0.01), Vector3(hx - 0.2, py1, bz - 0.01), Vector3.FORWARD, Color.WHITE)
	_mesh(panel, _mat(PANEL, {"mode": 0}))
	# a frame round it
	lacquer.box(Vector3(-hx, py1, bz - 0.4), Vector3(hx, py1 + 0.12, bz), Color(0.25, 0.12, 0.2))
	lacquer.box(Vector3(-hx, py0, bz - 0.3), Vector3(-hx + 0.2, py1, bz), Color(0.25, 0.12, 0.2))
	lacquer.box(Vector3(hx - 0.2, py0, bz - 0.3), Vector3(hx, py1, bz), Color(0.25, 0.12, 0.2))
	# glass shelves, and the bottles on them
	var bottles: Array = []
	var glass := [Color(0.95, 0.55, 0.15), Color(0.35, 0.75, 0.3), Color(0.85, 0.85, 0.75), Color(0.25, 0.45, 0.95),
		Color(0.85, 0.2, 0.25), Color(0.6, 0.3, 0.12), Color(0.95, 0.8, 0.35)]
	for k in 3:
		var sy := py0 + 0.12 + k * 0.68
		lacquer.box(Vector3(-hx + 0.2, sy - 0.025, bz - 0.32), Vector3(hx - 0.2, sy, bz - 0.01), Color(0.5, 0.4, 0.45))
		var x := -hx + 0.32
		while x < hx - 0.3:
			var h := rng.randf_range(0.8, 1.25) if k < 2 else rng.randf_range(0.9, 1.5)
			var col: Color = glass[rng.randi() % glass.size()]
			bottles.append([Vector3(x, sy, bz - 0.17 + rng.randf_range(-0.05, 0.05)), h, col])
			x += rng.randf_range(0.11, 0.17)
	_bottles(bottles)
	# a low ceiling over the bar, with lamps hanging over the counter
	room.box(Vector3(-7.0, 5.3, 7.0), Vector3(7.0, CEILING, BACK_WALL), Color(0.2, 0.12, 0.2))
	for i in 7:
		var lx := -4.5 + i * 1.5
		var lz := (z0 + z1) * 0.5
		room.prism(Vector3(lx, 5.3, lz), Vector3(lx, 4.65, lz), 0.006, 0.006, 3, Color(0.1, 0.1, 0.1), false)
		brass.prism(Vector3(lx, 4.68, lz), Vector3(lx, 4.45, lz), 0.05, 0.17, 10, Color.WHITE, false)
		neon.sphere(Vector3(lx, 4.47, lz), 0.06, 6, 4, Color(1.0, 0.75, 0.45))
		halos.append([Vector3(lx, 4.4, lz), 1.1, Color(1.0, 0.55, 0.25) * 0.6, 0.0])
	# stools
	for i in 8:
		var sx := -4.6 + i * 1.3
		var sz := z0 - 0.55
		brass.prism(Vector3(sx, y, sz), Vector3(sx, y + 0.72, sz), 0.03, 0.03, 6, Color.WHITE, false)
		brass.lathe(Vector3(sx, y, sz), PackedVector2Array([Vector2(0.2, 0.0), Vector2(0.18, 0.02), Vector2(0.0, 0.03)]), 10, Color.WHITE)
		plush.lathe(Vector3(sx, y + 0.72, sz), PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.2, 0.0), Vector2(0.21, 0.06), Vector2(0.18, 0.1), Vector2(0.0, 0.11)]), 12, Color(0.72, 0.12, 0.32))


func _bottles(list: Array) -> void:
	var g := Geo.new()
	g.lathe(Vector3.ZERO, PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.038, 0.0), Vector2(0.04, 0.02), Vector2(0.04, 0.19),
		Vector2(0.03, 0.23), Vector2(0.014, 0.26), Vector2(0.013, 0.31), Vector2(0.016, 0.32), Vector2(0.0, 0.33)]), 8, Color.WHITE)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = g.commit()
	mm.instance_count = list.size()
	for i in list.size():
		var b: Array = list[i]
		var h: float = b[1]
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(1.0 + (h - 1.0) * 0.3, h, 1.0 + (h - 1.0) * 0.3)), b[0]))
		mm.set_instance_color(i, b[2])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _mat(BOTTLE)
	add_child(mmi)


# --- velvet booths: up on the mezzanine's sides, and down along the floor's walls ---

var _seats: Array = []  # [position, yaw]


func _booths() -> void:
	var crimson := Color(0.72, 0.12, 0.32)
	var violet := Color(0.42, 0.16, 0.72)
	# the mezzanine's sides
	for side in [-1.0, 1.0]:
		for k in 2:
			var z0 := 1.6 + k * 3.4
			_banquette(side, MEZZ_Y, z0, z0 + 3.0, crimson if k == 0 else violet)
	# down by the floor
	for side in [-1.0, 1.0]:
		for k in 3:
			var z0 := -16.4 + k * 4.4
			_banquette(side, 0.0, z0, z0 + 3.6, violet if (k + int(side > 0)) % 2 == 0 else crimson)


# A booth against the side wall (side -1 is the left, -X): a buttoned seat and high back between two
# rounded ends, a table in front with a little lamp
func _banquette(side: float, y: float, z0: float, z1: float, col: Color) -> void:
	var wall := side * (HALL_X - 0.2)
	var inner := side * (HALL_X - 0.95)
	var back := side * (HALL_X - 0.5)
	plush.box(Vector3(minf(back, inner), y, z0), Vector3(maxf(back, inner), y + 0.45, z1), col)
	plush.box(Vector3(minf(wall, back), y, z0), Vector3(maxf(wall, back), y + 1.35, z1), col)
	for z in [z0, z1]:
		plush.prism(Vector3(side * (HALL_X - 0.6), y, z), Vector3(side * (HALL_X - 0.6), y + 0.75, z), 0.38, 0.38, 10, col * 0.9)
	# the table and its lamp
	var tx := side * (HALL_X - 1.85)
	var mid := (z0 + z1) * 0.5
	for tz in [mid - 0.7, mid + 0.7]:
		lacquer.lathe(Vector3(tx, y, tz), PackedVector2Array([Vector2(0.25, 0.0), Vector2(0.05, 0.03), Vector2(0.04, 0.68),
			Vector2(0.38, 0.7), Vector2(0.38, 0.74), Vector2(0.0, 0.75)]), 14, Color(0.2, 0.12, 0.2))
		neon.prism(Vector3(tx, y + 0.75, tz), Vector3(tx, y + 0.9, tz), 0.06, 0.04, 8, Color(1.0, 0.6, 0.35))
		halos.append([Vector3(tx, y + 0.86, tz), 0.9, Color(1.0, 0.45, 0.3) * 0.55, 0.0])
	# who sits there: one or two to a side of each table, facing the room
	for tz in [mid - 1.0, mid - 0.35, mid + 0.4, mid + 1.05]:
		if rng.randf() < 0.75:
			_seats.append([Vector3(side * (HALL_X - 1.15), y, tz), -side * PI * 0.5])


# --- the moth: a great neon sign over the DJ ---

func _moths() -> void:
	_moth(Vector3(0.0, 5.3, STAGE_WALL + 0.45), Vector3.RIGHT, Vector3.BACK, 0.95, 1.0)
	# little ones on the walls of the mezzanine, either side
	for side in [-1.0, 1.0]:
		_moth(Vector3(side * (HALL_X - 0.35), MEZZ_Y + 3.5, 2.4), Vector3(0, 0, side), Vector3(-side, 0, 0), 0.42, 0.45)
		# a line of violet light along each wall, high up
		neon.tube(PackedVector3Array([Vector3(side * (HALL_X - 0.3), 7.7, STAGE_WALL + 0.5), Vector3(side * (HALL_X - 0.3), 7.7, BACK_WALL - 0.4)]), 0.03, 6, Color(0.55, 0.3, 1.0))


## A neon moth on a wall: c its middle, `right` across the wall, `away` off it into the room, s its size.
func _moth(c: Vector3, right: Vector3, away: Vector3, s: float, glow: float) -> void:
	var pink := Color(1.0, 0.25, 0.7)
	var gold := Color(1.0, 0.65, 0.25)
	var blue := Color(0.45, 0.4, 1.0)
	var to3 := func(p: Vector2) -> Vector3: return c + right * (p.x * s) + Vector3.UP * (p.y * s)
	var curve := func(pts: Array, closed: bool, mirror: float) -> PackedVector3Array:
		var out := PackedVector3Array()
		var n := pts.size()
		var segs := n if closed else n - 1
		for i in segs:
			var p0: Vector2 = pts[(i - 1 + n) % n] if closed or i > 0 else pts[0]
			var p1: Vector2 = pts[i]
			var p2: Vector2 = pts[(i + 1) % n]
			var p3: Vector2 = pts[(i + 2) % n] if closed or i + 2 < n else pts[n - 1]
			for k in 6:
				var t := k / 6.0
				var p := 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t)
				out.append(to3.call(Vector2(p.x * mirror, p.y)))
		if not closed:
			var last: Vector2 = pts[n - 1]
			out.append(to3.call(Vector2(last.x * mirror, last.y)))
		return out
	var r := 0.035 * maxf(s, 0.6)
	# the body, the head, and the feelers
	var body := []
	for k in 14:
		var a := TAU * k / 14.0
		body.append(Vector2(cos(a) * 0.24, sin(a) * 1.05 - 0.2))
	neon.tube(curve.call(body, true, 1.0), r, 5, blue, 0.0, true)
	var head := []
	for k in 10:
		var a := TAU * k / 10.0
		head.append(Vector2(cos(a) * 0.2, sin(a) * 0.19 + 1.08))
	neon.tube(curve.call(head, true, 1.0), r, 5, blue, 0.0, true)
	for m in [-1.0, 1.0]:
		neon.tube(curve.call([Vector2(0.08, 1.25), Vector2(0.35, 1.8), Vector2(0.85, 2.15), Vector2(1.15, 2.05), Vector2(1.05, 1.85)], false, m), r * 0.8, 5, gold, 3.0 if m > 0 else 0.0)
		# wings open (group 1) and lifted (group 2), taking turns so the moth beats its wings
		for g in [1.0, 2.0]:
			var lift := 0.0 if g < 1.5 else 1.0
			var up := [Vector2(0.26, 0.55), Vector2(1.1, 1.35 + lift * 0.35), Vector2(2.3, 1.95 + lift * 0.6), Vector2(3.15, 1.75 + lift * 0.75),
				Vector2(3.0, 0.95 + lift * 0.45), Vector2(2.1, 0.25 + lift * 0.1), Vector2(0.3, -0.05)]
			neon.tube(curve.call(up, true, m), r, 5, pink, g, true)
			var low := [Vector2(0.3, -0.15), Vector2(1.5, -0.35 + lift * 0.15), Vector2(2.2, -1.05 + lift * 0.35), Vector2(1.85, -1.85 + lift * 0.45),
				Vector2(1.0, -1.75 + lift * 0.35), Vector2(0.45, -1.05)]
			neon.tube(curve.call(low, true, m), r, 5, pink, g, true)
			# eyes on the wings
			var e1 := []
			var e2 := []
			for k in 10:
				var a := TAU * k / 10.0
				e1.append(Vector2(1.95 + cos(a) * 0.36, 1.2 + lift * 0.4 + sin(a) * 0.3))
				e2.append(Vector2(1.3 + cos(a) * 0.22, -1.0 + lift * 0.3 + sin(a) * 0.2))
			neon.tube(curve.call(e1, true, m), r * 0.8, 5, gold, g, true)
			neon.tube(curve.call(e2, true, m), r * 0.8, 5, gold, g, true)
	# its glow on the drapes
	halos.append([c + Vector3(0, 0.3 * s, 0) + away * 0.2, 8.4 * s, Color(0.55, 0.08, 0.4) * 0.5 * glow, 0.3])
	halos.append([c + away * 0.2, 2.6 * s, Color(0.25, 0.2, 0.7) * 0.6 * glow, 0.0])


# --- the people ---

func _crowd() -> void:
	var stand: Array = [[], [], [], []]
	var dj := Vector3(0, STAGE_Y, STAGE.end.y - 1.5)
	# the floor, packed tightest at the front
	var step := 0.82
	var z := STAGE.end.y + 0.35
	while z < -0.6:
		var x := -9.6
		while x < 9.6:
			var p := Vector3(x + rng.randf_range(-0.3, 0.3), 0.0, z + rng.randf_range(-0.3, 0.3))
			var on_floor := FLOOR_RECT.has_point(Vector2(p.x, p.z))
			var keep := 0.0
			if on_floor:
				keep = lerpf(0.95, 0.6, (p.z - FLOOR_RECT.position.y) / FLOOR_RECT.size.y)
			elif absf(p.x) < 9.6 and p.z > -13.0:
				keep = 0.22
			if absf(p.x) > 6.0 and p.z < -13.0:
				keep = 0.0
			if rng.randf() < keep:
				var to := dj - p
				var yaw := atan2(-to.x, -to.z) + rng.randf_range(-0.5, 0.5)
				if rng.randf() < 0.15:
					yaw += rng.randf_range(1.5, 3.0) * (1.0 if rng.randf() < 0.5 else -1.0)
				var phase := rng.randf_range(-0.08, 0.08)
				var roll := rng.randf()
				if roll < 0.18:
					phase = 0.5
				elif roll < 0.26:
					phase = rng.randf()
				var energy := rng.randf_range(0.55, 1.0) if on_floor else rng.randf_range(0.15, 0.45)
				var style := rng.randf() if on_floor else rng.randf() * 0.3
				stand[rng.randi() % 4].append([p, yaw, rng.randf_range(0.9, 1.08), Color(phase, style, energy, rng.randf())])
			x += step
		z += step
	# up here: at the rail either side of you, at the bar, in little groups
	for x in [-10.4, -9.1, -7.2, -5.9, -4.6, 4.6, 6.3, 8.4, 9.6]:
		if rng.randf() < 0.85:
			_put(stand, Vector3(x + rng.randf_range(-0.2, 0.2), MEZZ_Y, 0.42), rng.randf_range(-0.3, 0.3), 0.1, 0.3)
	for x in [-4.1, -2.5, -1.4, 0.6, 2.9, 4.0]:
		_put(stand, Vector3(x, MEZZ_Y, 7.55 + rng.randf_range(-0.1, 0.15)), PI + rng.randf_range(-0.4, 0.4), 0.08, 0.2)
	_put(stand, Vector3(1.6, MEZZ_Y, 10.05), 0.15, 0.15, 0.35)
	_put(stand, Vector3(-3.0, MEZZ_Y, 10.0), -0.3, 0.05, 0.2)
	for g in [Vector3(-6.0, MEZZ_Y, 4.4), Vector3(6.6, MEZZ_Y, 3.9), Vector3(-2.6, MEZZ_Y, 5.6), Vector3(3.4, MEZZ_Y, 5.8),
			Vector3(-8.2, MEZZ_Y, 1.9), Vector3(8.4, MEZZ_Y, 1.8), Vector3(-4.2, MEZZ_Y, 2.6), Vector3(5.2, MEZZ_Y, 2.4), Vector3(-7.4, MEZZ_Y, 6.9), Vector3(7.6, MEZZ_Y, 6.6)]:
		_high_table(g)
		var n := 2 + rng.randi() % 3
		for i in n:
			var a := TAU * i / n + rng.randf()
			var p: Vector3 = g + Vector3(cos(a), 0, sin(a)) * 0.62
			var to: Vector3 = g - p
			_put(stand, p, atan2(-to.x, -to.z), 0.15, 0.35)
	# the DJ, facing the floor, one hand up now and then
	stand[0].append([dj, PI, 1.0, Color(0.0, 0.5, 0.9, 0.3)])
	var mat := _mat(CROWD, {"shoulder_y": Figures.SHOULDER, "hip_y": Figures.HIP})
	for kind in 4:
		_people(Figures.standing(kind), stand[kind], mat)
	# sat in the booths
	var sat: Array = [[], []]
	for s in _seats:
		sat[rng.randi() % 2].append([s[0], s[1] + rng.randf_range(-0.3, 0.3), rng.randf_range(0.92, 1.05),
			Color(rng.randf(), rng.randf() * 0.3, rng.randf_range(0.3, 0.6), rng.randf())])
	var smat := _mat(CROWD, {"seated": 1.0, "shoulder_y": Figures.SEAT_SHOULDER, "hip_y": Figures.SEAT_HIP})
	for kind in 2:
		_people(Figures.seated(kind * 2), sat[kind], smat)


# A tall round table to stand at, with a little lamp on it
func _high_table(at: Vector3) -> void:
	lacquer.lathe(at, PackedVector2Array([Vector2(0.24, 0.0), Vector2(0.22, 0.03), Vector2(0.03, 0.05), Vector2(0.03, 1.02),
		Vector2(0.3, 1.04), Vector2(0.3, 1.08), Vector2(0.0, 1.09)]), 12, Color(0.2, 0.12, 0.2))
	neon.prism(at + Vector3(0, 1.09, 0), at + Vector3(0, 1.2, 0), 0.045, 0.035, 8, Color(1.0, 0.55, 0.35))
	halos.append([at + Vector3(0, 1.17, 0), 0.8, Color(1.0, 0.45, 0.3) * 0.5, 0.0])


func _put(stand: Array, p: Vector3, yaw: float, style: float, energy: float) -> void:
	stand[rng.randi() % 4].append([p, yaw, rng.randf_range(0.92, 1.06), Color(rng.randf_range(-0.1, 0.1), style * rng.randf(), energy, rng.randf())])


func _people(mesh: ArrayMesh, list: Array, material: ShaderMaterial) -> void:
	if list.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	# (the vertex colours mark the parts; in Compatibility they only reach the shader with instance colours on)
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = list.size()
	for i in list.size():
		var it: Array = list[i]
		var sc: float = it[2]
		mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, it[1]).scaled(Vector3(sc, sc, sc)), it[0]))
		mm.set_instance_custom_data(i, it[3])
		mm.set_instance_color(i, Color.WHITE)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = material
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


# --- the lights: beams through the haze, the mirror ball ---

func _beams() -> void:
	var list: Array = []  # [position, rest basis, colour, length, radius, phase, mode]
	var cols := [Color(1.0, 0.2, 0.7), Color(0.2, 0.6, 1.0), Color(0.6, 0.25, 1.0), Color(1.0, 0.45, 0.8)]
	var i := 0
	for z in [-5.0, -12.0]:
		for x in [-4.5, -1.5, 1.5, 4.5]:
			var at := Vector3(x, 7.45, z)
			room.box(at - Vector3(0.14, 0.2, 0.14), at + Vector3(0.14, 0.1, 0.14), Color(0.1, 0.08, 0.12))
			list.append([at + Vector3(0, -0.12, 0), Basis(), cols[i % 4], 9.5, 0.85, float(i) / 8.0 + rng.randf() * 0.1, 0.0])
			halos.append([at + Vector3(0, -0.15, 0), 0.7, cols[i % 4] * 0.8, 1.0])
			i += 1
	# uplights from the stage's front, crossing over the floor
	for x in [-4.6, -2.6, 2.6, 4.6]:
		var at := Vector3(x, STAGE_Y + 0.08, STAGE.end.y - 0.2)
		var aim := (Vector3(-x * 1.2, 7.5, -4.0) - at).normalized()
		room.box(at - Vector3(0.12, 0.08, 0.12), at + Vector3(0.12, 0.08, 0.12), Color(0.1, 0.08, 0.12))
		var col := Color(1.0, 0.5, 0.2) if absf(x) > 3.0 else Color(0.85, 0.2, 1.0)
		list.append([at, _aim(aim), col, 11.0, 0.7, rng.randf(), 1.0])
		halos.append([at + Vector3(0, 0.05, 0.1), 0.6, col * 0.7, 1.0])
	# the pin spots on the ball
	for x in [-6.0, 6.0]:
		var at := Vector3(x, 7.45, -4.0)
		list.append([at, _aim((BALL - at).normalized()), Color(1.0, 0.9, 0.95), at.distance_to(BALL), 0.3, 0.0, 2.0])
	var g := Geo.new()
	g.prism(Vector3.ZERO, Vector3(0, -1, 0), 0.03, 1.0, 18, Color.WHITE, false)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = g.commit()
	mm.instance_count = list.size()
	for k in list.size():
		var b: Array = list[k]
		mm.set_instance_transform(k, Transform3D(b[1], b[0]))
		mm.set_instance_color(k, b[2])
		mm.set_instance_custom_data(k, Color(b[3], b[4], b[5], b[6]))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _mat(BEAM, {"strength": 0.32})
	mmi.custom_aabb = AABB(Vector3(-HALL_X, -1, STAGE_WALL), Vector3(HALL_X * 2.0, CEILING + 2.0, -STAGE_WALL + 2.0))
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


# A basis whose -Y points along dir (the beam's rest)
func _aim(dir: Vector3) -> Basis:
	var y := -dir
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z)


func _ball() -> void:
	var s := SphereMesh.new()
	s.radius = 0.45
	s.height = 0.9
	s.radial_segments = 28
	s.rings = 14
	var mi := MeshInstance3D.new()
	mi.mesh = s
	mi.position = BALL
	mi.material_override = _mat(BALL_SHADER)
	add_child(mi)
	room.prism(BALL + Vector3(0, 0.4, 0), Vector3(BALL.x, CEILING, BALL.z), 0.012, 0.012, 4, Color(0.3, 0.3, 0.3), false)
	halos.append([BALL, 1.6, Color(0.6, 0.55, 0.7) * 0.5, 0.0])


# The club's name in neon script over the bar, behind you
func _signs() -> void:
	var sign := Label3D.new()
	sign.text = "The Velvet Moth"
	sign.font = ITALIC
	sign.font_size = 86
	sign.pixel_size = 0.0035
	sign.outline_size = 16
	sign.modulate = Color(1.0, 0.55, 0.9)
	sign.outline_modulate = Color(1.0, 0.1, 0.55, 0.55)
	sign.position = Vector3(0.0, 6.55, 6.97)
	sign.rotation = Vector3(0, PI, 0)
	sign.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sign)
	halos.append([Vector3(0, 6.55, 6.9), 6.0, Color(0.7, 0.1, 0.45) * 0.45, 0.0])


# Each material's worth of the room into one mesh, and the halos into one MultiMesh
func _commit() -> void:
	_mesh(room, _mat(ROOM, {"brush": 0.3}))
	_mesh(drape, _mat(ROOM, {"sheen": 1.0, "brush": 0.15}))
	_mesh(plush, _mat(ROOM, {"sheen": 0.7, "tuft": 1.0, "brush": 0.1}))
	_mesh(brass, _mat(ROOM, {"tint": Color(0.95, 0.65, 0.35), "gloss": 1.0, "brush": 0.1, "speck": 0.6}))
	_mesh(lacquer, _mat(ROOM, {"gloss": 0.7, "brush": 0.05}))
	_mesh(neon, _mat(NEON, {"power": 1.0}))
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = quad
	mm.instance_count = halos.size()
	for i in halos.size():
		var h: Array = halos[i]
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * float(h[1])), h[0]))
		mm.set_instance_color(i, h[2])
		mm.set_instance_custom_data(i, Color(h[3], 0, 0, 0))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _mat(HALO)
	mmi.custom_aabb = AABB(Vector3(-HALL_X - 5, -5, STAGE_WALL - 5), Vector3(HALL_X * 2 + 10, CEILING + 10, BACK_WALL - STAGE_WALL + 10))
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
