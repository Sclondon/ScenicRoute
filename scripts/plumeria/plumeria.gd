extends Node3D
## The Plumeria Beach Club: a Hawaiian beach club as the sun goes down. You sit at the rail of its
## open-air deck, a drink and a lei on the ledge in front of you, looking down a path of tiki torches to
## the beach and the sea, the sun about to touch it and its road of glitter coming across the water to you.
## Long swells roll in, glow green-gold through their faces, break and run up the wet sand. Palms lean
## out over the beach and sway; string lights sag between poles over you and back to the thatched tiki bar
## behind (its bottles, glass-float lanterns, a carved tiki). Loungers and closed umbrellas, an outrigger
## canoe pulled up on the sand, surfboards on a rack, plumeria trees and hibiscus in planters; a couple
## walking the water's edge, someone standing in the shallows, a boy chasing the wash, a barman and two at the
## bar, a catamaran out under the sun, big birds soaring off the palm tops; green fluted mountains inland and a
## headland across the bay, both in the evening haze.
##
## Everything is built here from code and seeded. The look is painted, not lit: this place's own materials light
## themselves off `SUN_DIR` (shaders/plumeria/common.gdshaderinc holds the same sun, the sky's colours and the
## haze), and things far off fade into the sky's own colour that way. GameCommon's parts are used where one fits
## (see README): the sand of the beach, the people, the birds, the hibiscus bushes, the torches' flames.

const Places := preload("res://scripts/places.gd")

## Made a step at a time (Places.build), so the loading card moves while it is built.
signal progress(done: float)
signal built
var is_built := false

const MeshKit := preload("res://scripts/plumeria/mesh_kit.gd")
const PalmBuilder := preload("res://scripts/plumeria/palm_builder.gd")
const Sound := preload("res://scripts/plumeria/sound.gd")
const SKY := preload("res://shaders/plumeria/sky.gdshader")
const SEA := preload("res://shaders/plumeria/sea.gdshader")
const LAND := preload("res://shaders/plumeria/land.gdshader")
const LIT := preload("res://shaders/plumeria/lit.gdshader")
const THATCH := preload("res://shaders/plumeria/thatch.gdshader")
const PALM := preload("res://shaders/plumeria/palm.gdshader")
const GLOW := preload("res://shaders/plumeria/glow.gdshader")
const BLOOM := preload("res://shaders/plumeria/bloom.gdshader")
const SHADOW := preload("res://shaders/plumeria/shadow.gdshader")
const FireScript := preload("res://scripts/fire.gd")
const ITALIC := preload("res://fonts/LibreBaskerville-Italic.ttf")

## Towards the sun, just over the sea ahead and a touch to the left (common.gdshaderinc's SUN must match).
const SUN_DIR := Vector3(-0.1, 0.045, -1.0)
const SUN_COLOR := Color(1.0, 0.74, 0.42)
const SEA_Y := -0.45
## The deck's floor, above the sand.
const DECK := 2.1
## The front of the tiki bar behind you.
const BAR_Z := 7.6
## Where the beach is GameCommon's sand (x, z, width, depth).
const SAND_RECT := Rect2(-140.0, -38.0, 280.0, 58.0)
## A hibiscus, as a kind of painted-woodland bush: broad glossy leaves (the beech's outline), deep green.
const HIBISCUS := {"shape": 0.0, "leaves": 260, "leaf": 0.12, "size": Vector2(0.5, 0.42),
	"colors": {"color_a": Color(0.2, 0.4, 0.14), "color_b": Color(0.12, 0.3, 0.12), "color_dark": Color(0.04, 0.09, 0.04)}}
## Where you face on arriving: out to sea, the sun a little left of the middle.
const VIEW := {"look": Vector2(3.0, -2.0)}

const BAMBOO := Color(0.72, 0.6, 0.36)
const KOA := Color(0.42, 0.24, 0.12)
const DARK_WOOD := Color(0.3, 0.2, 0.13)
const WIRE := Color(0.08, 0.06, 0.05)
const BULB := Color(1.0, 0.72, 0.38)

var rng := RandomNumberGenerator.new()
var props := MeshKit.new()
var deck := MeshKit.new()
var thatch := MeshKit.new()
var woven := MeshKit.new()
var blooms := MeshKit.new()
var shadows := MeshKit.new()
var glows: Array = [] # [position, Color with size in a]
var surf_materials: Array[ShaderMaterial] = []
var walkers: Array = []
## Where no palm may grow (the cottages).
var clear_spots: Array[Vector2] = []
var sand: SandGround
var boy: DrivenBoy
var birds: CorvidFlock
var palm_tops: Array[Vector3] = []
var _birds_up := 20.0
## Where the hibiscus bushes stand (painted-woodland's bushes, in leaves of their own).
var bushes: Array = []


static func view_position() -> Vector3:
	return Vector3(0.0, DECK + 1.25, 0.0)


## The still waterline on the sand, as z for an x.
static func shore_z(x: float) -> float:
	return -19.0 - 0.0005 * x * x - 3.0 * sin(x * 0.015 + 0.5)


## The ground: sea floor, the beach rising from the water to a berm, low dunes, grass going back gently,
## then the mountains (which sink away again before the far edge of what can be seen).
static func height(x: float, z: float) -> float:
	var d := z - shore_z(x)
	var h: float
	if d < 0.0:
		h = SEA_Y + maxf(d * 0.06, -6.0)
	elif d < 14.0:
		h = SEA_Y + d * 0.04
	else:
		h = SEA_Y + 0.56
	# the berm the club stands on, rising behind the loungers
	h += 0.95 * smoothstep(10.0, 20.0, d)
	h += 0.14 * sin(x * 0.3 + z * 0.2) * sin(x * 0.11 - z * 0.17) * smoothstep(26.0, 34.0, d)
	h += maxf(d - 50.0, 0.0) * 0.03
	h += mountain(x, z)
	return h


static func mountain(x: float, z: float) -> float:
	var d := z - shore_z(x)
	var ridge := 0.62 + 0.22 * sin(x * 0.009 + 1.0) + 0.12 * sin(x * 0.031 + 2.0) - 0.3 * pow(absf(sin(x * 0.017 + 0.4)), 8.0)
	# knife-edged ridges running down to the coast between deep valleys, as the old volcanoes wear
	var spurs := 1.0 - absf(sin(x * 0.035 + sin(z * 0.012) * 1.6))
	var spurs2 := 1.0 - absf(sin(x * 0.083 + z * 0.01 + 1.0))
	var m := smoothstep(110.0, 360.0, d) * 230.0 * ridge * (0.62 + 0.28 * spurs + 0.1 * spurs2)
	return m * (1.0 - smoothstep(540.0, 680.0, Vector2(x, z).length()))


func _ready() -> void:
	rng.seed = 808
	Places.build(self, [_environment, _land, _sand, _sea, _deck, _bar, _front, _string_lights, _torches, _beach,
		_planters, _palms, _distant, _people, _commit])


func _mat(shader: Shader, params := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader
	for k in params:
		m.set_shader_parameter(k, params[k])
	return m


func _add(mesh: Mesh, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	env.sky.sky_material = _mat(SKY)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.74, 0.55, 0.52)
	env.ambient_light_energy = 1.2
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 0.9
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	# only the torches' smoke is lit by the engine
	var sun := DirectionalLight3D.new()
	sun.light_color = SUN_COLOR
	sun.light_energy = 0.8
	sun.shadow_enabled = false
	sun.look_at_from_position(Vector3.ZERO, -SUN_DIR, Vector3.UP)
	add_child(sun)


# --- land and sea ---

# Columns across the coast: fine in front of you, coarse far off
static func _columns() -> Array[float]:
	var xs: Array[float] = []
	var x := -900.0
	while x <= 900.0:
		xs.append(x)
		var ax := absf(x)
		x += 1.0 if ax < 30.0 else (2.0 if ax < 80.0 else (5.0 if ax < 200.0 else (15.0 if ax < 450.0 else 40.0)))
	return xs


# A grid laid along the shore: x across, d out from the waterline (`sign` -1 out to sea, +1 inland)
func _shore_grid(ds: Array[float], sign: float, at: Callable, color: Callable) -> ArrayMesh:
	var xs := _columns()
	var w := xs.size()
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	verts.resize(w * ds.size())
	colors.resize(w * ds.size())
	for j in ds.size():
		for i in w:
			var x := xs[i]
			var z := shore_z(x) + ds[j] * sign
			verts[j * w + i] = Vector3(x, at.call(x, z), z)
			colors[j * w + i] = color.call(x, z)
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	for j in ds.size():
		for i in w:
			var l := verts[j * w + maxi(i - 1, 0)]
			var r := verts[j * w + mini(i + 1, w - 1)]
			var f := verts[maxi(j - 1, 0) * w + i]
			var b := verts[mini(j + 1, ds.size() - 1) * w + i]
			var nn := (r - l).cross(b - f).normalized()
			normals[j * w + i] = nn if nn.y >= 0.0 else -nn
	var idx := PackedInt32Array()
	for j in ds.size() - 1:
		for i in w - 1:
			var a := j * w + i
			var c := a + w
			idx.append_array([a, a + 1, c, a + 1, c + 1, c])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _land() -> void:
	var ds: Array[float] = []
	var d := -8.0
	while d <= 660.0:
		ds.append(d)
		d += 1.0 if d < 34.0 else (2.5 if d < 80.0 else (8.0 if d < 200.0 else 20.0))
	var mesh := _shore_grid(ds, 1.0, height, func(x: float, z: float) -> Color:
		var dd := z - shore_z(x)
		var m := mountain(x, z)
		var hill := smoothstep(3.0, 30.0, m)
		return Color(smoothstep(30.0, 42.0, dd) * (1.0 - hill), hill, 0.0))
	var mat := _mat(LAND, {"sand_rect": Vector4(SAND_RECT.position.x, SAND_RECT.position.y, SAND_RECT.end.x, SAND_RECT.end.y)})
	surf_materials.append(mat)
	var mi := _add(mesh, mat)
	mi.custom_aabb = AABB(Vector3(-900, -10, -700), Vector3(1800, 300, 1400))


# The beach in front of the club is GameCommon's sand (it takes the prints of the people walking on it); the
# land mesh draws the wet sand and the wash over it, the grass behind it, and the beach beyond it either way,
# raised a little over it and fading into it with ragged edges (land.gdshader's `sand_rect`)
func _sand() -> void:
	# The sand is lit by the engine: the low sun hardly reaches level ground, so the dusky violet ambient light
	# lights it, as it is at sundown. (Sand.sky is left black: on this renderer the ambient light is not taken
	# off where it is set, and the two together burnt the sand white.) Statics: set before any sand is made.
	Sand.quality = 1
	Sand.sky = Color.BLACK
	Sand.sun_gain = 1.5
	var ground := SandGround.new()
	var mid := SAND_RECT.get_center()
	ground.position = Vector3(mid.x, 0.0, mid.y)
	ground.half = SAND_RECT.size * 0.5
	ground.cell = 2.0
	ground.colour = Color(0.96, 0.8, 0.62)
	ground.ripples = 0
	ground.dent_cell = 0.1
	ground.casts_shadow = false
	ground.auto_quality = false
	ground.clip = true
	ground.beyond = 0.0
	ground.height = func(x: float, z: float) -> float: return height(x + mid.x, z + mid.y)
	add_child(ground)
	# damp sand down by the water, where the people walk
	for i in 41:
		var x := lerpf(SAND_RECT.position.x, SAND_RECT.end.x, i / 40.0)
		ground.paint(Sand.Kind.DAMP, Vector2(x, shore_z(x) + 2.0), 6.0, 1.0, 3.0)
	var m := ground.material()
	m.set_shader_parameter(&"haze", Color(0.98, 0.7, 0.58, 0.004))
	m.set_shader_parameter(&"sparkle", 1.2)
	m.set_shader_parameter(&"glint", Color(1.0, 0.8, 0.55))
	# the prints are kept round the water's edge in front of the deck, where the people walk
	var focus := Node3D.new()
	focus.position = Vector3(-6.0, 0.0, shore_z(-6.0) + 3.0)
	add_child(focus)
	ground.focus = focus
	sand = ground



func _sea() -> void:
	var ds: Array[float] = []
	var d := -8.0
	while d <= 760.0:
		ds.append(d)
		d += 0.6 if d < 50.0 else (3.0 if d < 150.0 else 25.0)
	var mesh := _shore_grid(ds, -1.0, func(_x: float, _z: float) -> float: return SEA_Y,
		func(_x: float, _z: float) -> Color: return Color.WHITE)
	var mat := _mat(SEA)
	surf_materials.append(mat)
	var mi := _add(mesh, mat)
	mi.custom_aabb = AABB(Vector3(-900, -10, -1200), Vector3(1800, 20, 1300))


# --- the club ---

func _deck() -> void:
	# the floor, on posts over the sand
	deck.box(Transform3D(Basis(), Vector3(0, DECK - 0.1, 6.4)), Vector3(15.0, 0.2, 17.2), Color(0.62, 0.45, 0.3))
	var floor_y := DECK - 0.2
	for x in [-7.4, -3.7, 0.0, 3.7, 7.4]:
		for z in [-2.1, 2.5, 7.0, 11.3, 14.9]:
			var g := height(x, z)
			props.cylinder(Vector3(x, g - 0.2, z), Vector3(x, floor_y, z), 0.12, 0.12, 6, DARK_WOOD)
	# a facing board round the front edge, and the steps down to the sand in the middle
	props.box(Transform3D(Basis(), Vector3(0, DECK - 0.22, -2.2)), Vector3(15.1, 0.3, 0.06), DARK_WOOD)
	var steps := 6
	var sand := height(0.0, -2.35 - steps * 0.3)
	for i in steps:
		var top := lerpf(DECK, sand, float(i + 1) / (steps + 1))
		var z := -2.35 - i * 0.3
		deck.box(Transform3D(Basis(), Vector3(0, top - 0.04, z)), Vector3(2.0, 0.08, 0.32), Color(0.6, 0.44, 0.3))
		props.box(Transform3D(Basis(), Vector3(0, (top + sand) * 0.5 - 0.05, z + 0.02)), Vector3(1.9, top - sand, 0.3), DARK_WOOD * 0.8)
	# the rail along the front, open over the steps: bamboo posts, a top rail, crossed bamboo below
	for s in [-1.0, 1.0]:
		var x0: float = 1.1 * s
		var x1: float = 7.4 * s
		var posts := 5
		for i in posts:
			var x := lerpf(x0, x1, float(i) / (posts - 1))
			props.cylinder(Vector3(x, DECK, -2.12), Vector3(x, DECK + 1.0, -2.12), 0.055, 0.05, 6, BAMBOO)
		props.cylinder(Vector3(x0, DECK + 1.0, -2.12), Vector3(x1, DECK + 1.0, -2.12), 0.05, 0.05, 6, BAMBOO * 0.95)
		props.cylinder(Vector3(x0, DECK + 0.5, -2.12), Vector3(x1, DECK + 0.5, -2.12), 0.035, 0.035, 5, BAMBOO * 0.9)
		# along the sides, back to the bar
		props.cylinder(Vector3(x1, DECK + 1.0, -2.12), Vector3(x1, DECK + 1.0, 7.0), 0.05, 0.05, 6, BAMBOO * 0.95)
		for z in [0.0, 2.3, 4.6, 7.0]:
			props.cylinder(Vector3(x1, DECK, z), Vector3(x1, DECK + 1.0, z), 0.055, 0.05, 6, BAMBOO)
	# the ledge you sit at, the stools along it, and the tables either side
	deck.box(Transform3D(Basis(), Vector3(0, DECK + 0.9, -0.58)), Vector3(6.4, 0.07, 0.5), KOA * 1.25)
	for x in [-3.0, -1.2, 1.2, 3.0]:
		props.cylinder(Vector3(x, DECK, -0.62), Vector3(x, DECK + 0.87, -0.62), 0.05, 0.05, 6, BAMBOO)
	props.cylinder(Vector3(-3.1, DECK + 0.22, -0.45), Vector3(3.1, DECK + 0.22, -0.45), 0.025, 0.025, 6, Color(0.6, 0.5, 0.3))
	for x in [-2.4, -1.25, 1.25, 2.4]:
		_stool(Vector3(x, DECK, 0.15))
	for p in [Vector3(-5.2, DECK, -0.6), Vector3(5.2, DECK, -0.6), Vector3(-5.0, DECK, 2.2), Vector3(5.0, DECK, 2.2)]:
		_table(p)
	_drinks()


func _stool(at: Vector3) -> void:
	props.cylinder(at, at + Vector3(0, 0.74, 0), 0.04, 0.04, 6, DARK_WOOD)
	for k in 3:
		var a := TAU * k / 3.0
		props.cylinder(at + Vector3(cos(a) * 0.22, 0, sin(a) * 0.22), at + Vector3(0, 0.5, 0), 0.02, 0.025, 4, DARK_WOOD)
	props.lathe(Transform3D(Basis(), at + Vector3(0, 0.74, 0)), [Vector2(0.0, 0.0), Vector2(0.2, 0.0), Vector2(0.21, 0.06), Vector2(0.0, 0.08)], 10, KOA)


func _table(at: Vector3) -> void:
	props.cylinder(at, at + Vector3(0, 0.72, 0), 0.05, 0.05, 6, DARK_WOOD)
	props.lathe(Transform3D(Basis(), at + Vector3(0, 0.72, 0)), [Vector2(0.0, 0.0), Vector2(0.45, 0.0), Vector2(0.45, 0.05), Vector2(0.0, 0.05)], 14, KOA)
	for k in 2:
		var a := rng.randf() * TAU + PI * k
		var c := at + Vector3(cos(a) * 0.7, 0, sin(a) * 0.7)
		var face := (at - c).normalized()
		var side := face.cross(Vector3.UP)
		props.box(Transform3D(Basis(side, Vector3.UP, -face), c + Vector3(0, 0.45, 0)), Vector3(0.44, 0.05, 0.42), BAMBOO * 0.75)
		for sl in 5:
			var o2 := side * (-0.18 + sl * 0.09) - face * 0.2
			props.cylinder(c + o2 + Vector3(0, 0.47, 0), c + o2 - face * 0.04 + Vector3(0, 0.95, 0), 0.016, 0.016, 4, BAMBOO * 0.8)
		props.cylinder(c - side * 0.22 - face * 0.24 + Vector3(0, 0.95, 0), c + side * 0.22 - face * 0.24 + Vector3(0, 0.95, 0), 0.022, 0.022, 5, BAMBOO * 0.7)
		for l in 4:
			var o := side * (0.19 if l % 2 == 0 else -0.19) + face * (0.18 if l < 2 else -0.18)
			props.cylinder(c + o, c + o + Vector3(0, 0.45, 0), 0.02, 0.02, 4, BAMBOO * 0.85)
	# a candle in a glass on it
	glows.append([at + Vector3(0, 0.82, 0), Color(1.0, 0.6, 0.25, 0.25)])
	props.lathe(Transform3D(Basis(), at + Vector3(0, 0.77, 0)), [Vector2(0.0, 0.0), Vector2(0.05, 0.0), Vector2(0.055, 0.1), Vector2(0.0, 0.1)], 8, Color(1.0, 0.6, 0.3), Vector2(0.6, 0))


# The drink in front of you (a mai tai, an umbrella and a flower in it) and a lei of plumeria on the ledge
func _drinks() -> void:
	var top := DECK + 0.935
	var glass := Vector3(0.19, top, -0.92)
	var drink := Color(0.95, 0.42, 0.18)
	props.lathe(Transform3D(Basis(), glass), [Vector2(0.0, 0.0), Vector2(0.04, 0.0), Vector2(0.04, 0.012), Vector2(0.012, 0.02),
		Vector2(0.012, 0.06), Vector2(0.045, 0.09), Vector2(0.05, 0.16), Vector2(0.0, 0.16)], 12, drink, Vector2(0.12, 0))
	props.lathe(Transform3D(Basis(), glass + Vector3(0, 0.16, 0)), [Vector2(0.0, 0.0), Vector2(0.05, 0.0), Vector2(0.052, 0.025), Vector2(0.0, 0.025)], 12, Color(0.9, 0.86, 0.75), Vector2(0.15, 0))
	# the paper umbrella, open, tipped over the rim
	var stick_a := glass + Vector3(-0.02, 0.1, 0.0)
	var stick_b := glass + Vector3(-0.07, 0.3, 0.03)
	props.cylinder(stick_a, stick_b, 0.003, 0.003, 4, Color(0.85, 0.75, 0.5))
	var up := (stick_b - stick_a).normalized()
	var basis := Basis(up.cross(Vector3.FORWARD).normalized(), up, up.cross(Vector3.FORWARD).normalized().cross(up))
	props.lathe(Transform3D(basis, stick_b - up * 0.03), [Vector2(0.06, 0.0), Vector2(0.032, 0.016), Vector2(0.0, 0.028)], 10, Color(0.95, 0.45, 0.5))
	_flower(glass + Vector3(0.045, 0.19, 0.0), Vector3(0.4, 1.0, -0.3), 0.045, 2.0, Color.WHITE)
	# a second glass along the ledge, nearly finished
	var g2 := Vector3(-1.05, top, -0.55)
	props.lathe(Transform3D(Basis(), g2), [Vector2(0.0, 0.0), Vector2(0.035, 0.0), Vector2(0.04, 0.12), Vector2(0.0, 0.12)], 10, Color(0.75, 0.82, 0.8), Vector2(0.1, 0))
	props.lathe(Transform3D(Basis(), g2), [Vector2(0.0, 0.0), Vector2(0.035, 0.0), Vector2(0.036, 0.03), Vector2(0.0, 0.03)], 10, Color(0.95, 0.6, 0.25), Vector2(0.3, 0))
	# the lei, lying in a loose loop
	var centre := Vector3(-0.36, top + 0.02, -0.68)
	for i in 30:
		var a := TAU * i / 30.0
		var p := centre + Vector3(cos(a) * 0.2 + sin(a * 2.0) * 0.03, rng.randf() * 0.01, sin(a) * 0.1)
		var face := Vector3(rng.randf_range(-0.4, 0.4), 1.0, rng.randf_range(-0.4, 0.4))
		var tint := Color(1.0, 0.92, 0.95) if i % 5 != 0 else Color(1.0, 0.75, 0.82)
		_flower(p, face, 0.042, 2.0, tint)


## A flower card at `at`, facing `face`, of radius `r` (`kind` 2 plumeria, 3 hibiscus).
func _flower(at: Vector3, face: Vector3, r: float, kind: float, tint: Color) -> void:
	var f := face.normalized()
	var right := f.cross(Vector3(0.3, 0.1, 1.0).normalized()).normalized()
	var spin := rng.randf() * TAU
	right = right.rotated(f, spin)
	var up := f.cross(right)
	blooms.card(at, right * r, up * r, tint, Vector2(kind, 0))


func _bar() -> void:
	var front := BAR_Z
	var back := BAR_Z + 6.4
	# the four carved posts and the beams
	for x in [-5.0, 5.0]:
		for z in [front, back - 0.4]:
			props.cylinder(Vector3(x, DECK, z), Vector3(x, DECK + 2.5, z), 0.16, 0.14, 8, DARK_WOOD)
			for k in 4:
				props.lathe(Transform3D(Basis(), Vector3(x, DECK + 0.4 + k * 0.5, z)), [Vector2(0.15, 0.0), Vector2(0.18, 0.06), Vector2(0.15, 0.12)], 8, KOA * 0.8)
		props.beam(Vector3(x, DECK + 2.5, front - 0.5), Vector3(x, DECK + 2.5, back), 0.18, 0.2, DARK_WOOD)
	props.beam(Vector3(-5.3, DECK + 2.5, front), Vector3(5.3, DECK + 2.5, front), 0.18, 0.2, DARK_WOOD)
	# the roof: an A-frame, the ridge running back from the sea, swept up and out over the front
	var ridge_y := DECK + 5.3
	var eave_y := DECK + 2.35
	var half := 6.0
	var slope := Vector2(half, ridge_y - eave_y).length()
	var ridge_line := []
	for s in [-1.0, 1.0]:
		var rows := 16
		var cols := 10
		var grid := []
		for i in rows + 1:
			var u := float(i) / rows
			var row := []
			for j in cols + 1:
				var k := float(j) / cols * (slope + 0.4) / slope
				var sweep := pow(1.0 - u, 3.0) * maxf(1.0 - k, 0.0)
				var z := lerpf(front - 0.8 - 1.0 * maxf(1.0 - k, 0.0) * maxf(1.0 - k, 0.0), back + 0.5, u)
				var p := Vector3(s * half * k, ridge_y - (ridge_y - eave_y) * k + sweep * 0.9, z)
				row.append(p)
			grid.append(row)
			if s > 0.0:
				ridge_line.append(row[0])
		var ids := []
		for i in rows + 1:
			var r := []
			for j in cols + 1:
				var p: Vector3 = grid[i][j]
				var along: Vector3 = grid[mini(i + 1, rows)][j] - grid[maxi(i - 1, 0)][j]
				var down: Vector3 = grid[i][mini(j + 1, cols)] - grid[i][maxi(j - 1, 0)]
				var nn := along.cross(down).normalized()
				if nn.y < 0.0:
					nn = -nn
				r.append(thatch.vert(p, nn, Color.WHITE, Vector2(p.z * 1.0, float(j) / cols * (slope + 0.4)), Vector2(slope, 0)))
			ids.append(r)
		for i in rows:
			for j in cols:
				thatch.quad(ids[i][j], ids[i][j + 1], ids[i + 1][j + 1], ids[i + 1][j])
		# rafters under the thatch, poles from the ridge down to the eave
		for i in range(2, rows + 1, 2):
			var top: Vector3 = grid[i][0] + Vector3(0, -0.12, 0)
			var foot: Vector3 = grid[i][cols - 1] + Vector3(0, -0.12, 0)
			props.cylinder(top, foot, 0.05, 0.05, 5, BAMBOO * 0.75, Vector2.ZERO, false)
	# the ridge pole, and a carved finial at its swept-up front
	var rp := PackedVector3Array()
	var rr := PackedFloat32Array()
	for p in ridge_line:
		rp.append(p + Vector3(0, 0.06, 0))
		rr.append(0.11)
	props.tube(rp, rr, 6, DARK_WOOD)
	var tip: Vector3 = ridge_line[0]
	props.lathe(Transform3D(Basis(), tip + Vector3(0, 0.05, 0)), [Vector2(0.12, 0.0), Vector2(0.16, 0.2), Vector2(0.1, 0.4), Vector2(0.14, 0.55), Vector2(0.0, 0.9)], 8, KOA)
	# a tie beam and king post across the open gable, and the club's name on a board on the tie beam
	var gz := front - 0.2
	props.beam(Vector3(-5.6, DECK + 2.62, gz), Vector3(5.6, DECK + 2.62, gz), 0.16, 0.18, DARK_WOOD)
	props.beam(Vector3(0, DECK + 2.62, gz), Vector3(0, ridge_y - 0.2, gz - 0.4), 0.12, 0.12, DARK_WOOD)
	for s in [-1.0, 1.0]:
		props.beam(Vector3(0, DECK + 2.7, gz), Vector3(s * 2.6, DECK + 3.9, gz - 0.2), 0.1, 0.1, DARK_WOOD)
	props.box(Transform3D(Basis(), Vector3(0, DECK + 2.95, gz - 0.12)), Vector3(3.7, 0.52, 0.06), Color(0.3, 0.17, 0.1))
	var sign := Label3D.new()
	sign.text = "The Plumeria Beach Club"
	sign.font = ITALIC
	sign.font_size = 64
	sign.pixel_size = 0.0034
	sign.modulate = Color(1.0, 0.86, 0.6)
	sign.outline_size = 0
	sign.shaded = false
	sign.double_sided = false
	sign.position = Vector3(0, DECK + 2.95, gz - 0.16)
	sign.rotation.y = PI
	add_child(sign)
	# the bar itself: a koa top on a front of bamboo poles
	var bz := front + 1.8
	for k in 76:
		var x := -3.8 + k * 0.1
		props.cylinder(Vector3(x, DECK, bz), Vector3(x, DECK + 1.04, bz), 0.048, 0.048, 5, BAMBOO * (0.9 + 0.2 * rng.randf()), Vector2.ZERO, false)
	props.box(Transform3D(Basis(), Vector3(0, DECK + 1.08, bz + 0.2)), Vector3(7.9, 0.08, 0.75), KOA)
	props.box(Transform3D(Basis(), Vector3(0, DECK + 0.5, bz + 0.45)), Vector3(7.5, 1.0, 0.5), DARK_WOOD * 0.7)
	for x in [-3.0, -1.5, 0.0, 1.5, 3.0]:
		_stool(Vector3(x, DECK, bz - 0.6))
	# glasses and a pineapple on the bar
	for k in 5:
		var x := rng.randf_range(-3.3, 3.3)
		props.lathe(Transform3D(Basis(), Vector3(x, DECK + 1.12, bz + 0.2)), [Vector2(0.0, 0.0), Vector2(0.035, 0.0), Vector2(0.04, 0.13), Vector2(0.0, 0.13)], 8,
			[Color(0.95, 0.45, 0.2), Color(0.3, 0.75, 0.85), Color(0.98, 0.85, 0.4)][k % 3], Vector2(0.15, 0))
	props.blob(Transform3D(Basis(), Vector3(2.4, DECK + 1.25, bz + 0.25)), Vector3(0.08, 0.12, 0.08), Color(0.8, 0.55, 0.15), 5, 8)
	for k in 6:
		var a2 := TAU * k / 6.0
		props.beam(Vector3(2.4, DECK + 1.35, bz + 0.25), Vector3(2.4 + cos(a2) * 0.08, DECK + 1.55, bz + 0.25 + sin(a2) * 0.08), 0.03, 0.01, Color(0.3, 0.5, 0.2))
	# the back bar: shelves of bottles, lit from beneath, against woven matting
	var wall_z := back - 0.3
	woven.box(Transform3D(Basis(), Vector3(0, DECK + 1.6, wall_z)), Vector3(10.0, 3.2, 0.08), Color(0.66, 0.52, 0.34))
	props.box(Transform3D(Basis(), Vector3(0, DECK + 0.45, wall_z - 0.3)), Vector3(7.2, 0.9, 0.5), DARK_WOOD)
	for level in 3:
		var y := DECK + 1.05 + level * 0.45
		props.box(Transform3D(Basis(), Vector3(0, y, wall_z - 0.15)), Vector3(6.4, 0.04, 0.26), KOA)
		var x := -3.0
		while x < 3.0:
			var tall := rng.randf_range(0.22, 0.36)
			var col: Color = [Color(0.55, 0.3, 0.1), Color(0.3, 0.55, 0.2), Color(0.85, 0.6, 0.2), Color(0.85, 0.85, 0.75),
				Color(0.2, 0.35, 0.5), Color(0.6, 0.15, 0.12)][rng.randi() % 6]
			var neck := rng.randf_range(0.012, 0.018)
			var body := rng.randf_range(0.03, 0.045)
			props.lathe(Transform3D(Basis(), Vector3(x, y + 0.02, wall_z - 0.15)), [Vector2(0.0, 0.0), Vector2(body, 0.0), Vector2(body, tall * 0.62),
				Vector2(neck, tall * 0.8), Vector2(neck, tall), Vector2(0.0, tall)], 7, col, Vector2(0.3, 0))
			x += body * 2.0 + rng.randf_range(0.01, 0.06)
		glows.append([Vector3(-1.5, y + 0.05, wall_z - 0.05), Color(1.0, 0.6, 0.3, 0.6)])
		glows.append([Vector3(1.5, y + 0.05, wall_z - 0.05), Color(1.0, 0.6, 0.3, 0.6)])
	# glass fishing floats in rope nets hung from the beams, glowing
	for p in [Vector3(-2.6, DECK + 2.2, front + 0.4), Vector3(0.0, DECK + 2.4, front + 1.0), Vector3(2.6, DECK + 2.2, front + 0.4),
			Vector3(-2.2, DECK + 2.3, front + 4.0), Vector3(2.2, DECK + 2.3, front + 4.0)]:
		var col2: Color = [Color(0.4, 0.8, 0.7), Color(0.95, 0.7, 0.35), Color(0.5, 0.75, 0.9)][rng.randi() % 3]
		props.cylinder(p + Vector3(0, 0.15, 0), Vector3(p.x, DECK + 3.3, p.z), 0.006, 0.006, 3, WIRE)
		props.blob(Transform3D(Basis(), p), Vector3.ONE * 0.15, col2, 6, 8, Vector2(0.9, 0))
		for k in 3:
			props.cylinder(p + Vector3(cos(k * 2.1) * 0.15, 0, sin(k * 2.1) * 0.15), p + Vector3(0, 0.16, 0), 0.005, 0.005, 3, WIRE)
		glows.append([p, Color(col2.r, col2.g, col2.b, 0.7)])
	# carved tikis standing guard by the bar's corners
	_tiki(Vector3(-5.9, DECK, front - 0.3))
	_tiki(Vector3(5.9, DECK, front - 0.3))


func _tiki(at: Vector3) -> void:
	var wood := Color(0.36, 0.24, 0.15)
	var dark := Color(0.12, 0.08, 0.06)
	props.cylinder(at, at + Vector3(0, 1.1, 0), 0.22, 0.2, 8, wood)
	props.lathe(Transform3D(Basis(), at + Vector3(0, 1.1, 0)), [Vector2(0.21, 0.0), Vector2(0.27, 0.15), Vector2(0.27, 0.6), Vector2(0.23, 0.75), Vector2(0.0, 0.78)], 10, wood)
	# brow, eyes, a wide mouth with teeth, arms folded over the belly
	props.box(Transform3D(Basis(), at + Vector3(0, 1.6, -0.25)), Vector3(0.44, 0.07, 0.08), wood * 1.1)
	for s in [-1.0, 1.0]:
		props.blob(Transform3D(Basis(), at + Vector3(s * 0.1, 1.5, -0.25)), Vector3(0.07, 0.06, 0.03), dark, 3, 6)
		props.beam(at + Vector3(s * 0.19, 0.85, -0.12), at + Vector3(s * 0.02, 0.72, -0.2), 0.08, 0.08, wood * 1.1)
	props.box(Transform3D(Basis(), at + Vector3(0, 1.28, -0.26)), Vector3(0.36, 0.14, 0.04), dark)
	props.box(Transform3D(Basis(), at + Vector3(0, 1.3, -0.275)), Vector3(0.3, 0.04, 0.02), Color(0.85, 0.75, 0.55))
	props.blob(Transform3D(Basis(), at + Vector3(0, 1.4, -0.27)), Vector3(0.06, 0.05, 0.05), wood * 1.15, 3, 6)
	shadows_for(at, 1.9, 0.5)


# Planters along the front of the deck, the poles for the lights, the surfboard rack
func _front() -> void:
	for x in [-6.6, 6.6]:
		_hibiscus(Vector3(x, DECK, -1.6), 0.7)
	_plumeria_tree(Vector3(-7.0, DECK, 2.6), 1.0)
	_plumeria_tree(Vector3(7.0, DECK, 2.8), 0.9)
	_hibiscus(Vector3(-2.2, height(-2.2, -3.0), -3.0), 0.55)
	_hibiscus(Vector3(2.2, height(2.2, -3.0), -3.0), 0.55)
	# a rack of surfboards beside the deck
	var rack := Vector3(9.3, height(9.3, -1.0), -1.0)
	props.beam(rack + Vector3(0, 1.3, -1.0), rack + Vector3(0, 1.3, 1.0), 0.08, 0.08, DARK_WOOD)
	for z in [-1.0, 1.0]:
		props.cylinder(rack + Vector3(0, 0, z), rack + Vector3(0, 1.4, z), 0.05, 0.05, 6, DARK_WOOD)
	var boards := [Color(0.95, 0.85, 0.6), Color(0.3, 0.7, 0.75), Color(0.95, 0.45, 0.35), Color(0.98, 0.95, 0.88)]
	for k in 4:
		var z: float = -0.75 + k * 0.5
		var lean := Basis(Vector3(1, 0, 0), deg_to_rad(-12.0 + rng.randf() * 6.0))
		var len := rng.randf_range(2.2, 2.7)
		props.blob(Transform3D(lean, rack + Vector3(-0.25, len * 0.5, z)), Vector3(0.04, len * 0.5, 0.26), boards[k], 6, 8, Vector2.ZERO)
		shadows_for(rack + Vector3(-0.25, 0, z), len, 0.4)


func _planter(at: Vector3, size: float) -> void:
	props.box(Transform3D(Basis(), at + Vector3(0, size * 0.32, 0)), Vector3(size, size * 0.64, size), Color(0.45, 0.3, 0.2))
	props.box(Transform3D(Basis(), at + Vector3(0, size * 0.65, 0)), Vector3(size * 1.06, 0.05, size * 1.06), DARK_WOOD)
	props.box(Transform3D(Basis(), at + Vector3(0, size * 0.63, 0)), Vector3(size * 0.95, 0.02, size * 0.95), Color(0.2, 0.13, 0.08))


func _hibiscus(at: Vector3, size: float) -> void:
	_planter(at, size)
	var c := at + Vector3(0, size * 0.64 + 0.45 * size * 1.2, 0)
	bushes.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * size * 1.2), at + Vector3(0, size * 0.64, 0)))
	for k in 9:
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.1, 1), rng.randf_range(-1, 1)).normalized()
		_flower(c + dir * Vector3(0.42, 0.36, 0.42) * size * 1.2, dir + Vector3(0, 0.3, 0), 0.09, 3.0, Color.WHITE)


# A plumeria: a grey candelabra of thick forked branches with a rosette of long leaves at each tip and
# clusters of white and yellow flowers in them
func _plumeria_tree(at: Vector3, size: float) -> void:
	_planter(at, 0.9)
	var bark := Color(0.42, 0.38, 0.34)
	var base := at + Vector3(0, 0.6, 0)
	var tips := []
	var stack := [[base, Vector3.UP, 1.0 * size, 0]]
	while not stack.is_empty():
		var it: Array = stack.pop_back()
		var from: Vector3 = it[0]
		var dir: Vector3 = it[1]
		var len: float = it[2]
		var depth: int = it[3]
		var to: Vector3 = from + dir * len
		props.cylinder(from, to, 0.1 - depth * 0.02, 0.085 - depth * 0.02, 6, bark, Vector2.ZERO, false)
		if depth >= 3:
			tips.append([to, dir])
			continue
		var forks := 3 if depth == 0 else 2
		var spin := rng.randf() * TAU
		for k in forks:
			var a := spin + TAU * k / forks
			var nd := (Vector3.UP * 1.3 + Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.6, 0.9)).normalized()
			stack.append([to, nd, len * rng.randf_range(0.55, 0.75), depth + 1])
	for t in tips:
		var tip: Vector3 = t[0]
		var dir: Vector3 = t[1]
		for k in 13:
			var a := TAU * k / 13.0 + rng.randf() * 0.4
			var out := (Vector3(cos(a), 0, sin(a)) + dir * 0.6 + Vector3.UP * 0.4).normalized()
			var side := out.cross(Vector3.UP).normalized()
			var lean := out.slide(side).normalized()
			blooms.card(tip + lean * 0.26, side * 0.085, lean * 0.27, Color(1, 1, 1), Vector2(0, 0))
		for k in rng.randi_range(6, 10):
			var p := tip + Vector3(rng.randf_range(-0.14, 0.14), 0.08 + rng.randf() * 0.1, rng.randf_range(-0.14, 0.14))
			var tint := Color(1, 1, 1) if rng.randf() < 0.7 else Color(1.0, 0.75, 0.82)
			_flower(p, Vector3(rng.randf_range(-0.6, 0.6), 1.0, rng.randf_range(-0.6, 0.6)), 0.06, 2.0, tint)


# --- lights ---

# A string of lights from a to b sagging `sag` in the middle: the wire, and a bulb every half metre
func _string(a: Vector3, b: Vector3, sag: float) -> void:
	var span := a.distance_to(b)
	var segs := maxi(int(span / 0.6), 4)
	var pts := PackedVector3Array()
	for i in segs + 1:
		var u := float(i) / segs
		pts.append(a.lerp(b, u) + Vector3.DOWN * sag * 4.0 * u * (1.0 - u))
	for i in segs:
		props.beam(pts[i], pts[i + 1], 0.012, 0.012, WIRE)
	var count := int(span / 0.55)
	for k in count:
		var u := (k + 0.5) / count
		var p := a.lerp(b, u) + Vector3.DOWN * (sag * 4.0 * u * (1.0 - u) + 0.07)
		glows.append([p, Color(BULB.r, BULB.g, BULB.b, 0.16)])
		props.blob(Transform3D(Basis(), p), Vector3(0.028, 0.04, 0.028), Color(1.0, 0.85, 0.6), 3, 5, Vector2(1.2, 0))


func _string_lights() -> void:
	var poles := [Vector3(-6.4, 0, -6.6), Vector3(6.4, 0, -6.6)]
	var tops := []
	for p in poles:
		var g := height(p.x, p.z)
		var top := Vector3(p.x, g + 4.3, p.z)
		props.cylinder(Vector3(p.x, g - 0.3, p.z), top, 0.07, 0.055, 6, BAMBOO * 0.9)
		tops.append(top + Vector3(0, -0.1, 0))
		shadows_for(Vector3(p.x, g, p.z), 4.3, 0.14)
	var ridge := Vector3(0, DECK + 5.7, BAR_Z - 1.6)
	var eaves := [Vector3(-5.6, DECK + 2.45, BAR_Z - 0.6), Vector3(5.6, DECK + 2.45, BAR_Z - 0.6)]
	_string(tops[0], tops[1], 0.75)
	_string(tops[0], ridge, 0.55)
	_string(tops[1], ridge, 0.55)
	_string(tops[0], eaves[0], 0.35)
	_string(tops[1], eaves[1], 0.35)
	# along the bar's eaves, and across under the roof
	_string(eaves[0], Vector3(-5.6, DECK + 2.45, BAR_Z + 6.2), 0.25)
	_string(eaves[1], Vector3(5.6, DECK + 2.45, BAR_Z + 6.2), 0.25)
	_string(Vector3(-5.0, DECK + 2.6, BAR_Z + 0.1), Vector3(5.0, DECK + 2.6, BAR_Z + 0.1), 0.3)


func _torches() -> void:
	var spots := [Vector3(-1.6, 0, -3.8), Vector3(1.6, 0, -3.8), Vector3(-1.5, 0, -8.6), Vector3(1.5, 0, -8.8),
		Vector3(-1.3, 0, -13.2), Vector3(1.4, 0, -13.5)]
	for s in spots:
		var g := height(s.x, s.z)
		_torch(Vector3(s.x, g, s.z), 1.7)
	_torch(Vector3(-6.4, DECK, BAR_Z - 0.6), 1.5)
	_torch(Vector3(6.4, DECK, BAR_Z - 0.6), 1.5)


func _torch(foot: Vector3, tall: float) -> void:
	props.cylinder(foot + Vector3(0, -0.3, 0), foot + Vector3(0, tall, 0), 0.04, 0.035, 6, BAMBOO * 0.85)
	for k in 3:
		props.lathe(Transform3D(Basis(), foot + Vector3(0, 0.4 + k * 0.45, 0)), [Vector2(0.04, 0.0), Vector2(0.048, 0.02), Vector2(0.04, 0.04)], 6, BAMBOO * 0.7)
	# the woven cup and the can in it
	props.lathe(Transform3D(Basis(), foot + Vector3(0, tall - 0.05, 0)), [Vector2(0.04, 0.0), Vector2(0.11, 0.18), Vector2(0.12, 0.26), Vector2(0.06, 0.27)], 8, Color(0.58, 0.45, 0.28))
	props.cylinder(foot + Vector3(0, tall + 0.2, 0), foot + Vector3(0, tall + 0.3, 0), 0.05, 0.03, 6, Color(0.2, 0.18, 0.16))
	var fire: Node3D = FireScript.torch()
	fire.set("light", false)
	fire.position = foot + Vector3(0, tall + 0.3, 0)
	add_child(fire)
	glows.append([foot + Vector3(0, tall + 0.55, 0), Color(1.0, 0.55, 0.2, 1.1)])
	shadows_for(foot, tall, 0.14)


# --- the beach ---

func _beach() -> void:
	# loungers in pairs with a furled umbrella between, facing the sea
	for pair in [[-10.4, -8.7], [-6.0, -4.3], [4.3, 6.0], [8.7, 10.4]]:
		var z := -9.6 + rng.randf_range(-0.4, 0.4)
		for x in pair:
			_lounger(Vector3(x, height(x, z), z), rng.randf_range(-0.08, 0.08))
		var ux: float = (pair[0] + pair[1]) * 0.5
		_umbrella(Vector3(ux, height(ux, z + 0.6), z + 0.6), [Color(0.95, 0.42, 0.38), Color(0.25, 0.62, 0.65), Color(0.98, 0.85, 0.55)][rng.randi() % 3])
	# a towel left on one
	props.box(Transform3D(Basis(Vector3.UP, 0.05), Vector3(-8.7, height(-8.7, -9.6) + 0.42, -9.9)), Vector3(0.6, 0.02, 1.1), Color(0.95, 0.75, 0.3))
	_canoe(Vector3(-15.5, 0, -12.0), deg_to_rad(28.0))
	# a few more umbrellas and loungers further along each way, and a lifeguard tower
	for x in [-24.0, -30.0, 19.0, 26.0]:
		var z := shore_z(x) + 13.0
		_lounger(Vector3(x, height(x, z), z), rng.randf_range(-0.3, 0.3))
		_umbrella(Vector3(x + 1.0, height(x + 1.0, z + 0.6), z + 0.6), Color(0.95, 0.45, 0.4))
	_tower(Vector3(34.0, 0, shore_z(34.0) + 12.0))
	# the club's cottages back among the palms
	for h in [[-24.0, 34.0, 0.4], [21.0, 38.0, -0.3], [-44.0, 52.0, 0.9], [40.0, 56.0, -0.8], [-12.0, 62.0, 0.1]]:
		_hut(Vector3(h[0], height(h[0], h[1]), h[1]), h[2])


# A cottage of the club's back among the palms: woven walls on a low platform, a steep thatched roof, a
# lamp lit in the doorway
func _hut(at: Vector3, yaw: float) -> void:
	clear_spots.append(Vector2(at.x, at.z))
	var b := Basis(Vector3.UP, yaw)
	var xf := Transform3D(b, at)
	props.box(xf * Transform3D(Basis(), Vector3(0, 0.25, 0)), Vector3(5.6, 0.5, 4.6), DARK_WOOD)
	woven.box(xf * Transform3D(Basis(), Vector3(0, 1.6, 0)), Vector3(4.6, 2.2, 3.6), Color(0.66, 0.52, 0.34))
	# the door and a window, warm inside, facing the sea
	props.box(xf * Transform3D(Basis(), Vector3(0.6, 1.4, -1.82)), Vector3(0.9, 1.8, 0.06), Color(1.0, 0.62, 0.3), Vector2(0.55, 0))
	props.box(xf * Transform3D(Basis(), Vector3(-1.3, 1.7, -1.82)), Vector3(0.8, 0.6, 0.06), Color(1.0, 0.65, 0.35), Vector2(0.45, 0))
	glows.append([xf * Vector3(0.6, 1.9, -2.0), Color(1.0, 0.6, 0.3, 0.9)])
	_roof(xf * Transform3D(Basis(), Vector3(0, 2.6, 0)), 3.3, 2.9, 2.6)


# A plain thatched A-frame roof at `xf` (its ridge along local z, `half` out each side, `long` front to
# back half-length, `rise` from eave to ridge)
func _roof(xf: Transform3D, half: float, long: float, rise: float) -> void:
	var slope := Vector2(half, rise).length()
	for s in [-1.0, 1.0]:
		var rows := 4
		var cols := 5
		var ids := []
		for i in rows + 1:
			var z := lerpf(-long, long, float(i) / rows)
			var row := []
			for j in cols + 1:
				var k := float(j) / cols * (slope + 0.4) / slope
				var p := Vector3(s * half * k, rise * (1.0 - k), z)
				var nn := (xf.basis * Vector3(s * rise, half, 0.0)).normalized()
				row.append(thatch.vert(xf * p, nn, Color.WHITE, Vector2(z, float(j) / cols * (slope + 0.4)), Vector2(slope, 0)))
			ids.append(row)
		for i in rows:
			for j in cols:
				thatch.quad(ids[i][j], ids[i][j + 1], ids[i + 1][j + 1], ids[i + 1][j])


func _lounger(at: Vector3, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	var white := Color(0.88, 0.85, 0.78)
	var cushion := Color(0.3, 0.6, 0.62) if rng.randf() < 0.5 else Color(0.92, 0.5, 0.42)
	var xf := Transform3D(b, at)
	# the frame: legs, the flat seat towards the sea, the back raised towards the deck
	for sx in [-0.3, 0.3]:
		for sz in [-0.9, 0.7]:
			props.box(xf * Transform3D(Basis(), Vector3(sx, 0.17, sz)), Vector3(0.05, 0.34, 0.05), white)
	props.box(xf * Transform3D(Basis(), Vector3(0, 0.36, -0.3)), Vector3(0.68, 0.06, 1.4), white)
	props.box(xf * Transform3D(Basis(), Vector3(0, 0.41, -0.3)), Vector3(0.6, 0.05, 1.36), cushion)
	var back := Basis(Vector3.RIGHT, deg_to_rad(-50.0))
	props.box(xf * Transform3D(back, Vector3(0, 0.62, 0.62)), Vector3(0.68, 0.06, 0.7), white)
	props.box(xf * Transform3D(back, Vector3(0, 0.65, 0.6)), Vector3(0.6, 0.05, 0.66), cushion)
	shadows_for(at, 0.6, 0.75)


func _umbrella(at: Vector3, col: Color) -> void:
	props.cylinder(at + Vector3(0, -0.3, 0), at + Vector3(0, 2.5, 0), 0.025, 0.025, 5, Color(0.9, 0.88, 0.8))
	# furled: the cloth wrapped tight round the ribs, a tie round it, the finial
	props.lathe(Transform3D(Basis(), at + Vector3(0, 1.3, 0)), [Vector2(0.02, 0.0), Vector2(0.1, 0.25), Vector2(0.13, 0.6), Vector2(0.09, 1.0), Vector2(0.03, 1.2)], 8, col)
	props.lathe(Transform3D(Basis(), at + Vector3(0, 1.95, 0)), [Vector2(0.125, 0.0), Vector2(0.135, 0.03), Vector2(0.125, 0.06)], 8, Color(0.95, 0.92, 0.85))
	props.blob(Transform3D(Basis(), at + Vector3(0, 2.55, 0)), Vector3.ONE * 0.035, Color(0.9, 0.88, 0.8), 3, 5)
	shadows_for(at, 2.5, 0.3)


func _canoe(at: Vector3, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	var g := height(at.x, at.z) + 0.05
	var xf := Transform3D(b, Vector3(at.x, g, at.z))
	var hull := Color(0.42, 0.2, 0.12)
	var trim := Color(0.92, 0.86, 0.7)
	# the hull: a lofted shape, pointed and rising at both ends
	var rows := 14
	var sides := 7
	var ids := []
	for i in rows + 1:
		var u := float(i) / rows * 2.0 - 1.0
		var z := u * 3.4
		var w := 0.32 * sqrt(maxf(1.0 - u * u, 0.0)) + 0.01
		var rise := 0.25 * pow(absf(u), 4.0)
		var row := []
		for s in sides + 1:
			var a := PI * float(s) / sides
			var p := Vector3(cos(a) * w, -sin(a) * 0.32 * (w / 0.33) + 0.32 + rise, z)
			var nn := Vector3(cos(a), -sin(a), 0.0)
			row.append(props.vert(xf * p, b * nn, hull if s > 0 and s < sides else trim))
		ids.append(row)
	for i in rows:
		for s in sides:
			props.quad(ids[i][s], ids[i][s + 1], ids[i + 1][s + 1], ids[i + 1][s])
	# the float (ama) out on one side and the two booms (iako) to it
	props.tube(PackedVector3Array([xf * Vector3(1.7, 0.1, -1.8), xf * Vector3(1.7, 0.12, 0.0), xf * Vector3(1.7, 0.1, 1.8)]),
		PackedFloat32Array([0.02, 0.1, 0.02]), 6, Color(0.5, 0.36, 0.22))
	for z in [-0.9, 0.9]:
		props.tube(PackedVector3Array([xf * Vector3(-0.3, 0.6, z), xf * Vector3(0.9, 0.72, z), xf * Vector3(1.7, 0.22, z)]),
			PackedFloat32Array([0.035, 0.035, 0.03]), 5, Color(0.55, 0.4, 0.25))
	# a paddle on the sand by it
	props.beam(xf * Vector3(-0.7, 0.03, -1.0), xf * Vector3(-0.9, 0.03, 0.5), 0.04, 0.03, Color(0.55, 0.38, 0.22))
	props.blob(xf * Transform3D(Basis(), Vector3(-0.66, 0.03, -1.3)), Vector3(0.11, 0.02, 0.28), Color(0.55, 0.38, 0.22), 3, 6)
	shadows_for(Vector3(at.x, g, at.z), 0.5, 1.6)


func _tower(at: Vector3) -> void:
	var g := height(at.x, at.z)
	var foot := Vector3(at.x, g, at.z)
	var white := Color(0.9, 0.88, 0.82)
	for sx in [-0.8, 0.8]:
		for sz in [-0.8, 0.8]:
			props.beam(foot + Vector3(sx * 1.2, -0.3, sz * 1.2), foot + Vector3(sx, 2.0, sz), 0.12, 0.12, white)
	props.box(Transform3D(Basis(), foot + Vector3(0, 2.1, 0)), Vector3(2.2, 0.15, 2.2), Color(0.2, 0.55, 0.6))
	props.box(Transform3D(Basis(), foot + Vector3(0, 2.6, 0.9)), Vector3(2.0, 0.9, 0.1), white)
	props.box(Transform3D(Basis(), foot + Vector3(0, 3.5, 0)), Vector3(2.5, 0.12, 2.5), Color(0.92, 0.45, 0.38))
	for sx in [-1.0, 1.0]:
		props.beam(foot + Vector3(sx, 2.1, -1.0), foot + Vector3(sx, 3.45, -1.0), 0.08, 0.08, white)
	shadows_for(foot, 3.5, 2.2)


# A long soft shadow on the sand from `foot`, as long as a thing `tall` throws it (capped), `wide` across
func shadows_for(foot: Vector3, tall: float, wide: float) -> void:
	var dir := Vector3(-SUN_DIR.x, 0.0, -SUN_DIR.z).normalized()
	var side := Vector3(dir.z, 0.0, -dir.x)
	var len := minf(tall * 5.0, 12.0)
	var on_deck := foot.y > DECK - 0.1
	var segs := 8
	var prev := []
	for i in segs + 1:
		var u := float(i) / segs
		var p := foot + dir * len * u
		p.y = (DECK if on_deck else height(p.x, p.z)) + 0.07
		var row := [
			shadows.vert(p - side * wide * 0.5, Vector3.UP, Color(1, 1, 1, 0.3), Vector2(0, u)),
			shadows.vert(p + side * wide * 0.5, Vector3.UP, Color(1, 1, 1, 0.3), Vector2(1, u)),
		]
		if i > 0:
			shadows.quad(prev[0], prev[1], row[1], row[0])
		prev = row


func _planters() -> void:
	# beds of hibiscus and ti along the sand in front of the deck
	for x in [-5.2, -3.6, 3.6, 5.2]:
		var z := -2.9 - rng.randf() * 0.4
		var c := Vector3(x, height(x, z) + 0.45, z)
		bushes.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(1.4, 1.0, 1.1)), Vector3(x, height(x, z) + 0.02, z)))
		for k in 5:
			var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.1, 1), rng.randf_range(-1, 1)).normalized()
			_flower(c + dir * Vector3(0.6, 0.36, 0.46), dir, 0.09, 3.0, Color.WHITE)


# --- palms ---

func _palms() -> void:
	var trunks := MeshKit.new()
	var fronds := MeshKit.new()
	var far_trunks := MeshKit.new()
	var far_fronds := MeshKit.new()
	# the ones that frame the view: one leaning out over the beach from the left, others either side
	var heroes := [
		[Vector3(-6.0, 0, -7.0), 8.6, Vector3(0.5, 0, -1), 4.2],
		[Vector3(9.5, 0, -5.0), 10.5, Vector3(0.4, 0, -1), 2.6],
		[Vector3(13.0, 0, -9.0), 8.0, Vector3(1, 0, -0.6), 3.0],
		[Vector3(-11.5, 0, -3.0), 11.0, Vector3(-0.3, 0, -1), 2.0],
		[Vector3(-9.5, 0, 6.0), 9.5, Vector3(-1, 0, 0.2), 2.4],
		[Vector3(10.0, 0, 7.0), 12.0, Vector3(1, 0, 0.3), 1.8],
		[Vector3(-9.0, 0, 17.0), 11.5, Vector3(-0.4, 0, 1), 2.0],
		[Vector3(9.0, 0, 17.5), 9.0, Vector3(0.6, 0, 1), 2.6],
		[Vector3(1.5, 0, 20.0), 12.5, Vector3(0.2, 0, 1), 1.5],
		[Vector3(-4.0, 0, 19.5), 8.5, Vector3(-1, 0, 0.5), 2.2],
	]
	for h in heroes:
		var base: Vector3 = h[0]
		base.y = height(base.x, base.z) - 0.1
		palm_tops.append(PalmBuilder.build(trunks, fronds, base, h[1], (h[2] as Vector3).normalized(), h[3], rng))
		shadows_for(base, 6.0, 0.5)
	# along the beach either way, and the groves behind
	var placed := 0
	var tries := 0
	while placed < 260 and tries < 3000:
		tries += 1
		var x := rng.randf_range(-260.0, 260.0)
		var d := rng.randf_range(24.0, 70.0) if rng.randf() < 0.7 else rng.randf_range(70.0, 200.0)
		var z := shore_z(x) + d
		if absf(x) < 16.0 and z < 24.0:
			continue
		if clear_spots.any(func(c: Vector2) -> bool: return c.distance_to(Vector2(x, z)) < 5.5):
			continue
		# leave the view out of the bar's back clear enough to see the mountains
		if absf(x) < 30.0 and z > 15.0 and z < 40.0 and rng.randf() < 0.5:
			continue
		var base := Vector3(x, height(x, z) - 0.1, z)
		var lean_dir := Vector3(rng.randf_range(-1, 1), 0, -1.0 - rng.randf())
		var tall := rng.randf_range(7.0, 13.0)
		var dist := Vector2(x, z).length()
		if dist < 45.0:
			PalmBuilder.build(trunks, fronds, base, tall, lean_dir.normalized(), rng.randf_range(0.5, 3.0), rng)
			shadows_for(base, 6.0, 0.4)
		else:
			PalmBuilder.build(far_trunks, far_fronds, base, tall, lean_dir.normalized(), rng.randf_range(0.5, 3.0), rng, true)
		placed += 1
	var trunk_mat := _mat(PALM, {"frond": 0.0})
	var frond_mat := _mat(PALM, {"frond": 1.0})
	_add(trunks.mesh(), trunk_mat)
	_add(fronds.mesh(), frond_mat)
	# the far ones, plainer
	_add(far_trunks.mesh(), trunk_mat)
	_add(far_fronds.mesh(), frond_mat)


# --- far off ---

func _distant() -> void:
	# the headland across the bay: an old crater, its rim broken towards the sea
	var head := MeshKit.new()
	var centre := Vector3(360.0, SEA_Y - 4.0, -430.0)
	var rings := 12
	var segs := 36
	var ids := []
	for i in rings + 1:
		var r := float(i) / rings
		var row := []
		for s in segs + 1:
			var a := TAU * s / segs
			var rim := exp(-pow((r - 0.45) / 0.22, 2.0))
			var bowl := smoothstep(0.45, 0.0, r) * 0.55
			var flank := pow(maxf(1.0 - r, 0.0), 1.3)
			var h := 95.0 * (0.62 * flank + 0.5 * rim - bowl * 0.4) * (1.0 + 0.12 * sin(a * 3.0 + 1.0) + 0.06 * sin(a * 7.0))
			# the side to the sea worn down lower and steeper
			h *= 1.0 - 0.3 * smoothstep(0.3, 1.0, -sin(a))
			var p := centre + Vector3(cos(a) * 190.0 * r, maxf(h, 0.0) * (1.0 - smoothstep(0.9, 1.0, r)), sin(a) * 120.0 * r)
			row.append(p)
		ids.append(row)
	var vid := []
	for i in rings + 1:
		var row := []
		for s in segs + 1:
			var p: Vector3 = ids[i][s]
			var l: Vector3 = ids[i][(s + segs - 1) % segs]
			var rr: Vector3 = ids[i][(s + 1) % segs]
			var inn: Vector3 = ids[maxi(i - 1, 0)][s]
			var out: Vector3 = ids[mini(i + 1, rings)][s]
			var nn := (rr - l).cross(out - inn).normalized()
			if nn.y < 0.0:
				nn = -nn
			row.append(head.vert(p, nn, Color(0, 1, 0)))
		vid.append(row)
	for i in rings:
		for s in segs:
			head.quad(vid[i][s], vid[i][s + 1], vid[i + 1][s + 1], vid[i + 1][s])
	var land_mat: ShaderMaterial = surf_materials[0]
	_add(head.mesh(), land_mat)
	# a catamaran out under the sun, its sail dark against the glow
	var boat := MeshKit.new()
	var at := Vector3(-62.0, SEA_Y, -430.0)
	var dark := Color(0.12, 0.09, 0.12)
	for s in [-1.4, 1.4]:
		boat.blob(Transform3D(Basis(), at + Vector3(s, 0.3, 0)), Vector3(0.4, 0.35, 4.5), dark, 3, 6)
	boat.box(Transform3D(Basis(), at + Vector3(0, 0.75, 0)), Vector3(3.2, 0.2, 3.5), dark)
	boat.cylinder(at + Vector3(0, 0.8, -0.5), at + Vector3(0, 11.0, -0.5), 0.08, 0.06, 4, dark)
	var a := boat.vert(at + Vector3(0, 11.0, -0.4), Vector3.RIGHT, dark)
	var b := boat.vert(at + Vector3(0, 1.3, -0.4), Vector3.RIGHT, dark)
	var c := boat.vert(at + Vector3(0.3, 1.4, 3.6), Vector3.RIGHT, dark)
	boat.tri(a, b, c)
	var a2 := boat.vert(at + Vector3(0, 10.0, -0.7), Vector3.RIGHT, dark)
	var b2 := boat.vert(at + Vector3(0, 1.4, -0.7), Vector3.RIGHT, dark)
	var c2 := boat.vert(at + Vector3(0.2, 1.4, -4.0), Vector3.RIGHT, dark)
	boat.tri(a2, b2, c2)
	var boat_node := _add(boat.mesh(), _mat(LIT, {"haze_density": 0.0011}))
	walkers.append({"node": boat_node, "boat": true, "base": Vector3.ZERO})


# --- people ---
# GameCommon's figures (the character controller's rig, turned out by CharacterLook): a couple strolling the
# water's edge, someone standing in the shallows, a barman and two at the bar; and a boy (DrivenBoy) running
# in and out of the wash. On the sand their feet leave prints.

## Someone of the boy's model, grown to `size`, in `outfit` with `colours` over a made-up look.
func _figure(seed: int, sex: int, outfit: String, colours: Dictionary, size: float, at: Vector3, yaw: float) -> Figure:
	var look := CharacterLook.random(seed, sex)
	look["outfit"] = outfit
	look["cap"] = false
	var c: Dictionary = look["colours"]
	c.merge(colours, true)
	var f := Figure.new()
	f.size = size
	f.walk_speed = 0.85
	f.dusty = false
	f.position = at
	# (the plainer model: they are seen from some way off)
	var was := Settings.low_poly
	Settings.low_poly = true
	add_child(f)
	Settings.low_poly = was
	CharacterLook.apply(f.rig, look)
	f.rig.scale = Vector3(size * float(look["build"]), size, size * float(look["build"]))
	f.place(at, yaw)
	return f


func _people() -> void:
	# something to stand on up on the deck (the sand is its own floor)
	var floor_body := StaticBody3D.new()
	var box := CollisionShape3D.new()
	box.shape = BoxShape3D.new()
	(box.shape as BoxShape3D).size = Vector3(15.0, 0.4, 17.2)
	box.position = Vector3(0, DECK - 0.2, 6.4)
	floor_body.add_child(box)
	add_child(floor_body)
	var F := CharacterLook.Sex.FEMALE
	var M := CharacterLook.Sex.MALE
	# the couple, walking the edge of the wash, there and back
	var path := PackedVector3Array()
	for i in 9:
		var x := lerpf(-38.0, 26.0, i / 8.0)
		path.append(Vector3(x, 0.0, shore_z(x) + 3.0))
	var her := _figure(11, F, "dress", {"overalls": Color(0.95, 0.55, 0.5)}, 1.36, _on_sand(path[0] + Vector3(0, 0, 0.6)), PI * 0.5)
	var him := _figure(23, M, "trousers", {"shirt": Color(0.95, 0.93, 0.86), "overalls": Color(0.3, 0.36, 0.48)}, 1.44, _on_sand(path[0] + Vector3(-0.2, 0, -0.1)), PI * 0.5)
	walkers.append({"figure": her, "path": path, "at": 0, "step": 1, "offset": Vector3(0, 0, 0.6)})
	walkers.append({"figure": him, "path": path, "at": 0, "step": 1, "offset": Vector3(0, 0, -0.1)})
	# someone standing in the shallows, looking at the sun
	var sx := 11.0
	var still := _figure(37, M, "trousers", {"shirt": Color(0.25, 0.6, 0.62), "overalls": Color(0.85, 0.82, 0.74)}, 1.4,
		_on_sand(Vector3(sx, 0, shore_z(sx) - 2.2)), PI)
	still.face(still.position + SUN_DIR * 10.0)
	# behind the bar, the barman in a flowered shirt, going up and down it
	var bar_z := BAR_Z + 3.0
	var barman := _figure(51, M, "trousers", {"shirt": Color(0.92, 0.42, 0.3), "overalls": Color(0.85, 0.8, 0.68)}, 1.4,
		Vector3(-1.5, DECK, bar_z), PI)
	walkers.append({"figure": barman, "path": PackedVector3Array([Vector3(-2.6, DECK, bar_z), Vector3(0.4, DECK, bar_z),
		Vector3(2.4, DECK, bar_z), Vector3(-0.6, DECK, bar_z)]), "at": 0, "step": 1, "offset": Vector3.ZERO,
		"pause": 0.0, "face": Vector3(0, DECK, BAR_Z)})
	# two at the bar, standing at it
	var front := BAR_Z + 1.8 - 0.55
	var a := _figure(63, F, "skirt", {"shirt": Color(0.98, 0.95, 0.9), "overalls": Color(0.2, 0.45, 0.55)}, 1.32, Vector3(-2.3, DECK, front), 0.0)
	var b := _figure(77, M, "suit", {"jacket": Color(0.9, 0.86, 0.75), "overalls": Color(0.9, 0.86, 0.75)}, 1.42, Vector3(-1.6, DECK, front - 0.1), 0.0)
	a.face(Vector3(-1.6, DECK, front))
	b.face(Vector3(-2.3, DECK, front + 0.6))
	# and a boy chasing the wash up and down the sand
	boy = DrivenBoy.make()
	boy.position = _on_sand(Vector3(-4.0, 0, shore_z(-4.0) + 4.0))
	(boy.get_node(^"Rig") as CharacterRig).low_poly = true
	add_child(boy)
	CharacterLook.apply(boy.get_node(^"Rig") as CharacterRig, CharacterLook.dressed({"face": "sculpt", "hair": "curls",
		"outfit": "breeches", "cap": false, "colours": {"shirt": Color(0.95, 0.85, 0.4), "overalls": Color(0.3, 0.5, 0.75),
		"skin": CharacterLook.SKINS[4], "hair": CharacterLook.HAIR_COLOURS[1]}}))
	_birds()


func _on_sand(p: Vector3) -> Vector3:
	return Vector3(p.x, height(p.x, p.z) + 0.1, p.z)


# Birds wheeling high over the beach: GameCommon's ravens, grown to the size of frigatebirds, perched on the
# tops of the palms and going up now and then to soar in circles over the sand
func _birds() -> void:
	birds = CorvidFlock.new()
	birds.kind = CorvidBody.Kind.RAVEN
	birds.count = 5
	birds.flock_seed = 8
	birds.size = 2.0
	birds.circle_radius = 24.0
	birds.circle_height = 30.0
	birds.flight_speed = 9.0
	birds.call_every = 9999.0
	birds.cast_shadows = false
	birds.low_poly = true
	birds.view_range = 400.0
	add_child(birds)
	var perches := PackedVector3Array()
	var faces := PackedVector3Array()
	for top in palm_tops.slice(0, 6):
		perches.append(top + Vector3(0, 0.45, 0))
		faces.append(Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized())
	birds.set_perches(perches, faces, false)
	birds.settle()


func _physics_process(_delta: float) -> void:
	if boy == null or not is_built:
		return
	# the boy runs down after the wash as it draws back, and up away from it as it comes in
	# (on the surf's own clock, as the shaders have it: see common.gdshaderinc's swash)
	var t0 = surf_materials[0].get_shader_parameter(&"wave_t0")
	if t0 == null:
		return  # the surf's clock starts with its sound
	var t := fmod(Time.get_ticks_msec() / 1000.0, 3600.0) - float(t0)
	var s := fposmod(t - 0.45 * 8.0, 8.0) / 8.0
	var wander := -4.0 + sin(t * 0.05) * 9.0
	var down := s > 0.45 and s < 0.95
	var target := Vector3(wander, 0, shore_z(wander) + (0.8 if down else 7.5))
	boy.steer(_on_sand(target), DrivenBoy.Pace.JOG if down else DrivenBoy.Pace.RUN)


func _process(delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	if birds and not birds.circling() and t > _birds_up:
		birds.circle_over(Vector3(rng.randf_range(-20, 20), 0, rng.randf_range(-45, -25)), rng.randf_range(25.0, 45.0))
		_birds_up = t + rng.randf_range(40.0, 70.0)
	for w in walkers:
		if w.has("figure"):
			var f: Figure = w.figure
			if f.is_going():
				continue
			if w.has("pause"):
				# the barman stops a while at each place, facing the bar
				if w.pause <= 0.0:
					w.pause = rng.randf_range(3.0, 8.0)
					f.face(Vector3(f.position.x, DECK, w.face.z))
				w.pause -= delta
				if w.pause > 0.0:
					continue
			var path: PackedVector3Array = w.path
			var next: int = w.at + w.step
			if next < 0 or next >= path.size():
				w.step = -w.step
				next = w.at + w.step
			w.at = next
			var goal: Vector3 = path[next] + w.offset
			f.go_to(goal)
			continue
		var node: Node3D = w.node
		if w.has("boat"):
			node.position = Vector3(sin(t * 0.03) * 6.0, sin(t * 0.9) * 0.15, 0.0)


# --- putting it together ---

func _commit() -> void:
	_add(props.mesh(), _mat(LIT, {"gloss": 0.25}))
	_add(deck.mesh(), _mat(LIT, {"planks": 1.0, "gloss": 0.1, "brush": 0.08}))
	_add(thatch.mesh(), _mat(THATCH))
	_add(woven.mesh(), _mat(LIT, {"weave": 1.0}))
	_add(blooms.mesh(), _mat(BLOOM))
	Woodland.add_bushes(self, {"hibiscus": bushes}, SUN_DIR.normalized(), SUN_COLOR, {"hibiscus": HIBISCUS})
	_add(shadows.mesh(), _mat(SHADOW))
	# all the little lights at once
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	mm.mesh = quad
	mm.instance_count = glows.size()
	for i in glows.size():
		mm.set_instance_transform(i, Transform3D(Basis(), glows[i][0]))
		mm.set_instance_custom_data(i, glows[i][1])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _mat(GLOW)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


func make_ambience() -> Node:
	var s: Node = Sound.new()
	s.surf_materials = surf_materials
	return s
