extends Node3D
## Amberwood: the edge of an autumn wood at the golden hour, after Over the Garden Wall. A dirt path
## runs along it; on one side (+X) the wood goes deep, dark trunks and crowns of gold and rust; on the
## other the trees give out past a pumpkin patch onto rolling hills, with a stream winding down to a
## pond, a field of corn and copses on the far rises. Leaves come down; shafts of sun come and go.
## Everything is built here from code and seeded, so it is the same place every visit.
##
## The look comes from painting, not lighting: almost every material lights itself by hand off
## `SUN_DIR` (the engine's light is there for the fog's glow and the grass), and warm fog does the depth.

const TreeBuilder := preload("res://scripts/amberwood/tree_builder.gd")
const BushBuilder := preload("res://scripts/amberwood/bush_builder.gd")
const CornBuilder := preload("res://scripts/amberwood/corn_builder.gd")
const Wildlife := preload("res://scripts/amberwood/wildlife.gd")
const FOLIAGE := preload("res://shaders/foliage.gdshader")
const BARK := preload("res://shaders/bark.gdshader")
const GROUND := preload("res://shaders/ground.gdshader")
const LEAF := preload("res://shaders/leaf.gdshader")
const LEAF3D := preload("res://shaders/leaf3d.gdshader")
const SHAFT := preload("res://shaders/shaft.gdshader")
const GLOW := preload("res://shaders/glow.gdshader")
const PROP := preload("res://shaders/prop.gdshader")
const WATER := preload("res://shaders/water.gdshader")
const CORN := preload("res://shaders/corn.gdshader")
const SKY := preload("res://shaders/sky.gdshader")

## Towards the sun: low, ahead down the path and a little to the right.
const SUN_DIR := Vector3(0.18, 0.3, -1.0)
const SUN_COLOR := Color(1.0, 0.85, 0.55)
const FOG := Color(0.84, 0.7, 0.5)

## The wood's extent along the path, and how far it goes in on the +X side.
const NEAR_Z := 110.0
const FAR_Z := -150.0
const HALF_WIDTH := 46.0
## The ground: how far it goes each way from the path, and along it.
const GROUND_RIGHT := 80.0
const GROUND_LEFT := 420.0
const GROUND_NEAR := 260.0
const GROUND_FAR := -420.0

## Where you stand: on the path at the wood's edge, by the pumpkin patch, looking out over the fence to
## the pond and the hills. `look` is (yaw, pitch) in degrees, yaw 0 down the path (-Z), positive to the left.
const VIEW := {"z": -27.0, "side": 0.6, "eye": 1.6, "look": Vector2(38.0, -4.0)}
## Within this of where you stand, things are built in full (trees with roots, 3D bushes).
const NEAR := 22.0
const LOG_Z := -15.0
const PATCH_Z := Vector2(-26.0, -40.0)
## The pond: its middle (x, z) and its half-widths.
const POND := Vector2(-24.0, -48.0)
const POND_SIZE := Vector2(8.5, 5.5)
## The stream, from where it rises down to the pond.
const STREAM: Array[Vector2] = [Vector2(-9, 14), Vector2(-13, 4), Vector2(-17, -6), Vector2(-21, -16),
	Vector2(-23, -27), Vector2(-24.5, -35), Vector2(-24, -39.5), Vector2(-24, -44)]
## The corn: a field on the rise past the pond (x, z, width, depth).
const CORN_FIELD := Rect2(-74.0, -96.0, 26.0, 36.0)

var rng := RandomNumberGenerator.new()
var materials: Array[ShaderMaterial] = []
var _foliage: Array = []  # [Vector3 position, Color custom]
## Branch ends in the old oaks, for the jays to sit on.
var perches := PackedVector3Array()
var wildlife: Node3D

static var _pond_level := INF
static var _stream_top := INF


static func path_x(z: float) -> float:
	return 2.2 * sin(z * 0.055) + 1.2 * sin(z * 0.13 + 1.0)


## How far a point is from the middle of the path.
static func off_path(x: float, z: float) -> float:
	return absf(x - path_x(z))


## How far out of the wood a point is, 0..1: the -X side opens out past the trees along the path.
static func open_at(x: float, z: float) -> float:
	return smoothstep(5.0, 13.0, path_x(z) - x)


static func view_position() -> Vector3:
	var z: float = VIEW.z
	var x := path_x(z) + float(VIEW.side)
	return Vector3(x, height(x, z) + float(VIEW.eye), z)


# The land before the water is cut into it
static func _raw_height(x: float, z: float) -> float:
	var off := off_path(x, z)
	var h := smoothstep(2.0, 14.0, off) * 1.1
	h += sin(x * 0.21 + z * 0.13) * 0.35 * smoothstep(3.0, 10.0, off)
	h += sin(x * 0.07 - z * 0.05 + 2.0) * 0.6 * smoothstep(5.0, 20.0, off)
	h -= 0.08 * (1.0 - smoothstep(1.2, 2.2, off))
	# a low rise where you stand, to see out over the patch and down to the pond
	var knoll := Vector2(x - path_x(VIEW.z) - 1.5, (z - VIEW.z) * 0.8)
	h += 2.3 * exp(-knoll.length_squared() / 30.0)
	var open := open_at(x, z)
	var wood := smoothstep(16.0, 34.0, off) * 2.5 + smoothstep(40.0, 80.0, off) * 7.0
	# the land falls away from the wood's edge into a broad valley, where the stream and pond lie:
	# steepest at the top, so from the edge you see down into it
	var lo := path_x(z) - x
	h -= (2.0 * smoothstep(3.0, 13.0, lo) + 6.5 * (1.0 - exp(-maxf(lo - 9.0, 0.0) / 6.0))) * (1.0 - smoothstep(50.0, 120.0, lo))
	if open <= 0.0:
		return h + wood
	# rolling hills, growing as they go out, up to a far ridge
	var d := maxf(path_x(z) - x - 5.0, 0.0)
	var hills := (4.5 * sin(x * 0.033 + z * 0.011 + 0.5) + 3.5 * sin(z * 0.041 - x * 0.017 + 1.7)
		+ 1.0 * sin((x + z) * 0.09 + 0.4)) * smoothstep(4.0, 40.0, d)
	hills += (9.0 * sin(z * 0.013 + x * 0.007) + 7.0) * smoothstep(50.0, 180.0, d)
	hills += smoothstep(120.0, 320.0, d) * 32.0
	return h + lerpf(wood, hills, open)


static func _pond_d(x: float, z: float) -> float:
	return Vector2((x - POND.x) / POND_SIZE.x, (z - POND.y) / POND_SIZE.y).length()


## The pond's water level.
static func pond_level() -> float:
	if _pond_level == INF:
		_pond_level = _raw_height(POND.x, POND.y) - 0.25
	return _pond_level


## Nearest point on the stream: Vector3(distance, how far down it 0..1, 0).
static func stream_at(x: float, z: float) -> Vector2:
	var p := Vector2(x, z)
	var best := INF
	var at := 0.0
	var run := 0.0
	var total := 0.0
	for i in STREAM.size() - 1:
		total += STREAM[i].distance_to(STREAM[i + 1])
	for i in STREAM.size() - 1:
		var a := STREAM[i]
		var b := STREAM[i + 1]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var d := p.distance_to(a + ab * t)
		if d < best:
			best = d
			at = (run + ab.length() * t) / total
		run += ab.length()
	return Vector2(best, at)


## The stream's bed (its water a little under it) at `along` 0..1, always running downhill to the pond.
static func stream_bed(along: float) -> float:
	if _stream_top == INF:
		_stream_top = maxf(_raw_height(STREAM[0].x, STREAM[0].y), pond_level() + 1.2)
	return lerpf(_stream_top, pond_level() + 0.05, along)


static func height(x: float, z: float) -> float:
	var h := _raw_height(x, z)
	if x > path_x(z) - 2.0:
		return h
	# the pond: the ground round it laid flat, then dished
	var pd := _pond_d(x, z)
	if pd < 1.7:
		var flat := pond_level() + 0.25
		h = lerpf(h, flat, smoothstep(1.7, 1.15, pd))
		h -= 1.1 * smoothstep(1.05, 0.45, pd)
	# the stream: a little valley of its own, with its channel down the middle
	if x < -2.0 and x > -38.0 and z < 23.0 and z > -60.0:
		var s := stream_at(x, z)
		if s.x < 8.0:
			var bed := stream_bed(s.y) + 0.15
			h = lerpf(h, bed, smoothstep(8.0, 1.2, s.x))
			h -= 0.42 * smoothstep(1.0, 0.25, s.x)
	return h


static func ground_point(x: float, z: float) -> Vector3:
	return Vector3(x, height(x, z), z)


func _ready() -> void:
	rng.seed = 1031
	_environment()
	_ground()
	_water()
	_props()
	_trees_and_leaves()
	_undergrowth()
	_bushes()
	_grass()
	_corn()
	_ground_leaves()
	_falling_leaves()
	_shafts()
	_glow()
	wildlife = Wildlife.new()
	add_child(wildlife)


func _mat(shader: Shader, params := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter("sun_dir", SUN_DIR.normalized())
	m.set_shader_parameter("sun_color", Vector3(SUN_COLOR.r, SUN_COLOR.g, SUN_COLOR.b))
	for k in params:
		m.set_shader_parameter(k, params[k])
	materials.append(m)
	return m


func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = SKY
	sky_mat.set_shader_parameter("sun_dir", SUN_DIR.normalized())
	env.sky = Sky.new()
	env.sky.sky_material = sky_mat
	env.background_color = Color(0.95, 0.84, 0.6)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.45, 0.32)
	env.ambient_light_energy = 0.8
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = FOG
	env.fog_density = 0.0065
	env.fog_sun_scatter = 0.35
	env.fog_sky_affect = 0.45
	env.fog_height = -9.0
	env.fog_height_density = 0.03
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 0.85
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	# for the fog's glow towards the sun, and the grass (the one thing the engine lights)
	var sun := DirectionalLight3D.new()
	sun.light_color = SUN_COLOR
	sun.light_energy = 1.0
	sun.shadow_enabled = false
	sun.look_at_from_position(Vector3.ZERO, -SUN_DIR, Vector3.UP)
	add_child(sun)


# --- the land ---

func _ground() -> void:
	# a grid that follows the path: fine near it and near where you stand, coarse far out on the hills
	var xs: Array[float] = []
	var x := -GROUND_LEFT
	while x <= GROUND_RIGHT:
		xs.append(x)
		var ax := absf(x)
		x += 0.6 if ax < 9.0 else (1.2 if (x < 0.0 and ax < 36.0) else (2.0 if ax < 30.0 else (4.0 if ax < 90.0 else 12.0)))
	var zs: Array[float] = []
	var z := GROUND_NEAR
	while z >= GROUND_FAR:
		zs.append(z)
		var near := absf(z - float(VIEW.z))
		z -= 0.8 if near < 40.0 else (1.6 if near < 90.0 else (4.0 if near < 160.0 else 12.0))
	var w := xs.size()
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	verts.resize(w * zs.size())
	colors.resize(w * zs.size())
	for j in zs.size():
		var px := path_x(zs[j])
		for i in w:
			var gx := xs[i] + px
			var gz := zs[j]
			verts[j * w + i] = Vector3(gx, height(gx, gz), gz)
			# r wet ground by the water, g the corn's soil, b out in the open
			var wet := 0.0
			if gx < -4.0:
				wet = smoothstep(1.6, 1.0, _pond_d(gx, gz))
				if gx > -36.0 and gz < 20.0 and gz > -58.0:
					wet = maxf(wet, smoothstep(1.8, 0.7, stream_at(gx, gz).x))
			var field := 1.0 if CORN_FIELD.grow(1.0).has_point(Vector2(gx, gz)) else 0.0
			colors[j * w + i] = Color(wet, field, open_at(gx, gz))
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	for j in zs.size():
		for i in w:
			var l := verts[j * w + maxi(i - 1, 0)]
			var r := verts[j * w + mini(i + 1, w - 1)]
			var f := verts[maxi(j - 1, 0) * w + i]
			var b := verts[mini(j + 1, zs.size() - 1) * w + i]
			normals[j * w + i] = (b - f).cross(r - l).normalized()
	var idx := PackedInt32Array()
	for j in zs.size() - 1:
		for i in w - 1:
			var a := j * w + i
			var c := a + w
			idx.append_array([a, c, a + 1, a + 1, c, c + 1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(GROUND, {"corn_rect": Vector4(CORN_FIELD.position.x, CORN_FIELD.position.y, CORN_FIELD.end.x, CORN_FIELD.end.y)})
	add_child(mi)


func _water() -> void:
	# the pond: a disc a little bigger than its hollow, so its edge is under the bank
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var y := pond_level()
	var n := 40
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var c := Vector3(POND.x, y, POND.y)
		var p0 := c + Vector3(cos(a0) * POND_SIZE.x, 0, sin(a0) * POND_SIZE.y) * 1.1
		var p1 := c + Vector3(cos(a1) * POND_SIZE.x, 0, sin(a1) * POND_SIZE.y) * 1.1
		for p in [c, p1, p0]:
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(p.x, p.z))
			st.add_vertex(p)
	var pond := MeshInstance3D.new()
	pond.mesh = st.commit()
	pond.material_override = _mat(WATER, {"flow": 0.0, "pond": POND, "pond_size": POND_SIZE})
	add_child(pond)
	# the stream: a ribbon down its channel, UV.y metres along it
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array[Vector3] = []
	var steps := 90
	var total := 0.0
	for i in STREAM.size() - 1:
		total += STREAM[i].distance_to(STREAM[i + 1])
	for k in steps + 1:
		var along := float(k) / steps
		var want := along * total
		var p2 := STREAM[-1]
		var run := 0.0
		for i in STREAM.size() - 1:
			var seg := STREAM[i].distance_to(STREAM[i + 1])
			if want <= run + seg:
				p2 = STREAM[i].lerp(STREAM[i + 1], (want - run) / seg)
				break
			run += seg
		pts.append(Vector3(p2.x, stream_bed(along) - 0.08, p2.y))
	var half := 0.85
	for k in steps:
		var a := pts[k]
		var b := pts[k + 1]
		var side := (b - a).cross(Vector3.UP).normalized() * half
		var va := total * k / steps
		var vb := total * (k + 1) / steps
		var quad := [[a - side, Vector2(0, va)], [a + side, Vector2(1, va)], [b - side, Vector2(0, vb)], [b + side, Vector2(1, vb)]]
		for q in [quad[0], quad[2], quad[1], quad[1], quad[2], quad[3]]:
			st.set_normal(Vector3.UP)
			st.set_uv(q[1])
			st.add_vertex(q[0])
	var stream := MeshInstance3D.new()
	stream.mesh = st.commit()
	stream.material_override = _mat(WATER, {"flow": 1.0})
	add_child(stream)


func _clear_of_props(x: float, z: float, r: float) -> bool:
	var px := path_x(z)
	# the fallen log on the right of the path
	if absf(z - LOG_Z) < 6.0 + r and x > px and x < px + 7.0 + r:
		return false
	# the pumpkin patch on the left
	if z < PATCH_Z.x + r and z > PATCH_Z.y - r and x < px - 1.5 and x > px - 13.0 - r:
		return false
	if x < px - 3.0:
		if _pond_d(x, z) < 1.3 + r / POND_SIZE.y:
			return false
		if x > -38.0 and z < 22.0 and z > -60.0 and stream_at(x, z).x < 1.6 + r:
			return false
		if CORN_FIELD.grow(r).has_point(Vector2(x, z)):
			return false
	return true


# --- trees ---

## The kinds of tree: how often each comes, and its shape's ranges.
const KINDS := {
	"oak": {"height": [8.5, 12.5], "radius": [0.55, 0.95], "reach": [5.5, 8.0], "lean": [0.0, 0.18],
		"twist": [0.04, 0.12], "flute": [0.1, 0.16], "flare": [0.7, 1.1], "roots": [5, 8], "branches": [5, 7], "curl": [0.8, 1.3]},
	"tall": {"height": [12.0, 17.0], "radius": [0.24, 0.42], "reach": [3.5, 5.0], "lean": [0.0, 0.1],
		"twist": [0.0, 0.04], "flute": [0.03, 0.06], "flare": [0.4, 0.6], "roots": [2, 4], "branches": [4, 7], "curl": [0.2, 0.5]},
	"leaner": {"height": [10.0, 14.0], "radius": [0.3, 0.5], "reach": [4.0, 6.0], "lean": [0.3, 0.6],
		"twist": [0.02, 0.08], "flute": [0.05, 0.1], "flare": [0.6, 0.9], "roots": [3, 5], "branches": [4, 6], "curl": [0.5, 0.9]},
	"aspen": {"height": [10.0, 15.0], "radius": [0.14, 0.26], "reach": [2.5, 3.8], "lean": [0.0, 0.12],
		"twist": [0.0, 0.0], "flute": [0.0, 0.0], "flare": [0.25, 0.4], "roots": [0, 2], "branches": [4, 6], "curl": [0.1, 0.3], "tip": 0.25},
	"snag": {"height": [6.0, 10.0], "radius": [0.25, 0.45], "reach": [2.5, 4.0], "lean": [0.0, 0.25],
		"twist": [0.03, 0.1], "flute": [0.08, 0.12], "flare": [0.6, 0.9], "roots": [3, 5], "branches": [2, 4], "curl": [0.8, 1.2], "bare": true},
}
const VARIANTS := {"oak": 4, "tall": 4, "leaner": 3, "aspen": 4, "snag": 2}


func _shape(kind: String, r: RandomNumberGenerator, lite: bool) -> Dictionary:
	var k: Dictionary = KINDS[kind]
	var out := {"lite": lite, "bare": k.get("bare", false), "tip": k.get("tip", 0.18)}
	for key in ["height", "radius", "reach", "lean", "twist", "flute", "flare", "curl"]:
		out[key] = r.randf_range(k[key][0], k[key][1])
	out["roots"] = r.randi_range(k.roots[0], k.roots[1])
	out["branches"] = r.randi_range(k.branches[0], k.branches[1])
	return out


## A tree made twice from one seed: in full near, plainer far; the leaves are where both put them.
func _variant(kind: String, seed: int, shape_override := {}) -> Dictionary:
	var builder := TreeBuilder.new()
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var shape := _shape(kind, r, false)
	shape.merge(shape_override, true)
	var full := builder.build(r, shape)
	var crowns := builder.crowns.duplicate()
	r.seed = seed
	shape = _shape(kind, r, true)
	shape.merge(shape_override, true)
	shape.lite = true
	var lite := builder.build(r, shape)
	return {"kind": kind, "full": full, "lite": lite, "crowns": crowns, "near": [], "far": [], "bare": shape.bare}


func _trees_and_leaves() -> void:
	var variants: Array = []
	var by_kind := {}
	var seed := 500
	for kind in VARIANTS:
		by_kind[kind] = []
		for v in VARIANTS[kind]:
			seed += 1
			by_kind[kind].append(variants.size())
			variants.append(_variant(kind, seed))
	var bark := _mat(BARK, {"moss": 0.6})
	var birch_bark := _mat(BARK, {"birch": 1.0})
	var view := view_position()
	# trees on a jittered grid, thick at the path's edges, none on it; on the open side only a row
	# along the path, and the odd one out on the hills
	var step := 2.7
	var z := NEAR_Z
	while z > FAR_Z:
		var x := -HALF_WIDTH
		while x < HALF_WIDTH:
			var tx := x + rng.randf_range(-1.1, 1.1)
			var tz := z + rng.randf_range(-1.1, 1.1)
			x += step
			var off := off_path(tx, tz)
			var keep := 0.85 if off < 6.0 else (0.55 if off < 16.0 else (0.35 if off < 30.0 else 0.25))
			var open := open_at(tx, tz)
			keep *= 1.0 - open * 0.97
			var far := Vector2(tx - view.x, tz - view.z).length()
			if far > 70.0:
				keep *= 0.75
			if off < 2.4 or rng.randf() > keep or not _clear_of_props(tx, tz, 1.0):
				continue
			# keep the view out over the valley open (the old oaks frame it)
			var bearing := rad_to_deg(atan2(view.x - tx, view.z - tz))
			if far < 6.0 or (path_x(tz) - tx > 2.0 and far < 40.0 and bearing > 12.0 and bearing < 100.0):
				continue
			_plant(variants, by_kind, _kind_at(tx, tz, off), tx, tz, off, far)
		z -= step
	# copses on the far rises
	for c in 14:
		var d := rng.randf_range(50.0, 300.0)
		var cz := view.z + rng.randf_range(-260.0, 140.0)
		var cx := path_x(cz) - 8.0 - d
		for t in rng.randi_range(4, 11):
			var tx := cx + rng.randf_range(-9.0, 9.0)
			var tz := cz + rng.randf_range(-9.0, 9.0)
			if not _clear_of_props(tx, tz, 2.0):
				continue
			_plant(variants, by_kind, "oak" if rng.randf() < 0.6 else "tall", tx, tz, 40.0, 999.0)
	_hero_oaks(variants)
	for v in variants:
		for lod in ["near", "far"]:
			# in squares, so the trees off screen are not drawn
			for square in _squares(v[lod], func(t: Transform3D) -> Vector3: return t.origin).values():
				var mm := MultiMesh.new()
				mm.transform_format = MultiMesh.TRANSFORM_3D
				mm.mesh = v.full if lod == "near" else v.lite
				mm.instance_count = square.size()
				for i in square.size():
					mm.set_instance_transform(i, square[i])
				var mmi := MultiMeshInstance3D.new()
				mmi.multimesh = mm
				mmi.material_override = birch_bark if v.kind == "aspen" else bark
				add_child(mmi)
	var leaves := _mat(FOLIAGE)
	for square in _squares(_foliage, func(c: Array) -> Vector3: return c[0]).values():
		_foliage_mesh(square, leaves, 1.0)


## Things grouped by the square of `size` metres they stand in (`where` says where each is).
func _squares(things: Array, where: Callable, size := 40.0) -> Dictionary:
	var out := {}
	for t in things:
		var p: Vector3 = where.call(t)
		var key := Vector2i(floori(p.x / size), floori(p.z / size))
		if not out.has(key):
			out[key] = []
		out[key].append(t)
	return out


# Aspens stand together in groves; leaning trees and old oaks near the path's edge
func _kind_at(x: float, z: float, off: float) -> String:
	var grove := sin(x * 0.11 + 1.3) * sin(z * 0.09 - 0.4)
	if grove > 0.45 and rng.randf() < 0.8:
		return "aspen"
	var roll := rng.randf()
	if off < 7.0:
		return "oak" if roll < 0.35 else ("leaner" if roll < 0.6 else ("snag" if roll < 0.66 else "tall"))
	return "oak" if roll < 0.2 else ("leaner" if roll < 0.32 else ("snag" if roll < 0.38 else "tall"))


func _plant(variants: Array, by_kind: Dictionary, kind: String, tx: float, tz: float, off: float, far: float) -> void:
	var choices: Array = by_kind[kind]
	var vi: int = choices[rng.randi_range(0, choices.size() - 1)]
	var v: Dictionary = variants[vi]
	var s := rng.randf_range(0.75, 1.3)
	# turn the tree so its branches (+X) reach towards the path
	var to_path := signf(path_x(tz) - tx)
	var yaw := (0.0 if to_path > 0.0 else PI) + rng.randf_range(-0.7, 0.7)
	if off > 12.0:
		yaw = rng.randf() * TAU
	var basis := Basis(Vector3.UP, yaw).scaled(Vector3(s, s, s))
	var tr := Transform3D(basis, ground_point(tx, tz) - Vector3(0, 0.12, 0))
	v["near" if far < NEAR else "far"].append(tr)
	if not v.bare:
		_crown(v, tr, off if far < 999.0 else 40.0)


# Two great old oaks at the wood's edge, framing the way out to the hills
func _hero_oaks(variants: Array) -> void:
	var spots := [[-5.2, -20.5, -2.2], [-4.6, -45.0, -0.6], [5.5, -36.0, 2.6]]
	for k in spots.size():
		var v := _variant("oak", 900 + k, {"height": 12.5, "radius": 0.95 - k * 0.1, "reach": 9.0, "roots": 9,
			"branches": 7, "curl": 1.4, "twist": 0.1, "flute": 0.14, "flare": 0.55, "lean": 0.12})
		var tz: float = spots[k][1]
		var tx: float = spots[k][0] + path_x(tz)
		var tr := Transform3D(Basis(Vector3.UP, spots[k][2]), ground_point(tx, tz) - Vector3(0, 0.15, 0))
		v.near.append(tr)
		variants.append(v)
		_crown(v, tr, 0.0)
		# the outer leaf clumps, low enough to see a bird on, are perches
		for c in v.crowns:
			if c.y < 9.0 and Vector2(c.x, c.z).length() > 3.0:
				perches.append(tr * Vector3(c.x, c.y + 0.2, c.z))


# Leaf clumps for one tree: a few cards round each crown point, the tree's own colour give or take
func _crown(variant: Dictionary, tr: Transform3D, off: float) -> void:
	var hue := 0.12 + rng.randf() * 0.88
	if variant.kind == "aspen":
		hue = rng.randf_range(0.0, 0.25)
	var cards := 4 if off < 10.0 else (3 if off < 20.0 else (2 if off < 30.0 else 1))
	var top := 0.0
	for c in variant.crowns:
		top = maxf(top, c.y)
	for c in variant.crowns:
		var centre := tr * Vector3(c.x, c.y, c.z)
		var scale := tr.basis.get_scale().x
		var size: float = c.w * scale
		for k in cards:
			var p := centre + Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.6, 0.8), rng.randf_range(-1, 1)) * size * 0.8
			var lit := clampf(0.25 + 0.6 * (c.y / top) + (p.y - centre.y) / size * 0.3 + rng.randf_range(-0.15, 0.15), 0.0, 1.0)
			var h := clampf(hue + rng.randf_range(-0.18, 0.18), 0.0, 1.0)
			_foliage.append([p, Color(size * rng.randf_range(1.3, 1.9), h, lit, rng.randf())])


func _foliage_mesh(cards: Array, material: ShaderMaterial, quad := 1.0) -> MultiMeshInstance3D:
	var quad_mesh := QuadMesh.new()
	quad_mesh.size = Vector2(quad, quad)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = quad_mesh
	mm.instance_count = cards.size()
	var lo := Vector3.INF
	var hi := -Vector3.INF
	for i in cards.size():
		var p: Vector3 = cards[i][0]
		mm.set_instance_transform(i, Transform3D(Basis(), p))
		mm.set_instance_custom_data(i, cards[i][1])
		lo = lo.min(p)
		hi = hi.max(p)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = material
	if not cards.is_empty():
		mmi.custom_aabb = AABB(lo - Vector3.ONE * 6.0, hi - lo + Vector3.ONE * 12.0)
	add_child(mmi)
	return mmi


# --- low growth ---

func _undergrowth() -> void:
	var bushes: Array = []
	var grass: Array = []
	var view := view_position()
	var z := NEAR_Z
	while z > FAR_Z + 20.0:
		for k in 6:
			var side := -1.0 if rng.randf() < 0.5 else 1.0
			var off := 1.7 + pow(rng.randf(), 1.6) * 12.0
			var x := path_x(z) + side * off
			var zz := z + rng.randf_range(-0.6, 0.6)
			# near where you stand the bushes are real ones (_bushes)
			if not _clear_of_props(x, zz, 0.0) or Vector2(x - view.x, zz - view.z).length() < 16.0:
				continue
			if open_at(x, zz) > 0.6 and rng.randf() < 0.85:
				continue
			var size := rng.randf_range(0.9, 1.8) * (1.0 + off * 0.03)
			var p := ground_point(x, zz) + Vector3(0, size * 0.3, 0)
			bushes.append([p, Color(size, rng.randf_range(0.35, 1.0), rng.randf_range(0.05, 0.5), rng.randf())])
		for k in 3:
			var side := -1.0 if rng.randf() < 0.5 else 1.0
			var off := rng.randf_range(1.45, 3.2)
			var x := path_x(z) + side * off
			var zz := z + rng.randf_range(-0.6, 0.6)
			if Vector2(x - view.x, zz - view.z).length() < 9.0:
				continue
			var size := rng.randf_range(0.45, 0.95)
			grass.append([ground_point(x, zz) - Vector3(0, 0.05, 0), Color(size, rng.randf_range(0.0, 0.6), rng.randf_range(0.3, 0.9), rng.randf())])
		z -= 1.2
	_foliage_mesh(bushes, _mat(FOLIAGE, {"darkness": 0.25, "leaf_scale": 9.0, "sway": 0.4}))
	_foliage_mesh(grass, _mat(FOLIAGE, {"blades": 1.0, "sway": 0.6,
		"gold": Color(0.62, 0.48, 0.26), "orange": Color(0.48, 0.33, 0.17), "rust": Color(0.32, 0.21, 0.11)}))


## The 3D bushes round where you stand, of every kind, with their leaves one by one.
func _bushes() -> void:
	var view := view_position()
	var kinds := BushBuilder.KINDS.keys()
	var placed := {}
	for kind in kinds:
		placed[kind] = []
	var tries := 0
	var count := 0
	while count < 46 and tries < 600:
		tries += 1
		var a := rng.randf() * TAU
		var d := rng.randf_range(3.0, 18.0)
		var x := view.x + cos(a) * d
		var z := view.z + sin(a) * d
		var off := off_path(x, z)
		if off < 1.9 or not _clear_of_props(x, z, 0.3):
			continue
		# fewer out in the open, and none right in front of the view to the pond
		var open := open_at(x, z)
		if open > 0.5 and rng.randf() < 0.75:
			continue
		var to := Vector2(x - view.x, z - view.z)
		var look_dir := Vector2(-sin(deg_to_rad(VIEW.look.x)), -cos(deg_to_rad(VIEW.look.x)))
		if to.normalized().dot(look_dir) > 0.93 and d < 12.0:
			continue
		var kind: String = kinds[rng.randi_range(0, kinds.size() - 1)]
		if open > 0.3 and rng.randf() < 0.6:
			kind = "bracken"
		var s := rng.randf_range(0.7, 1.35)
		placed[kind].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.15), s)), ground_point(x, z) - Vector3(0, 0.08, 0)))
		count += 1
	var builder := BushBuilder.new()
	for kind in kinds:
		if placed[kind].is_empty():
			continue
		var r := RandomNumberGenerator.new()
		r.seed = hash(kind)
		var info: Dictionary = BushBuilder.KINDS[kind]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = builder.build(r, kind)
		mm.instance_count = placed[kind].size()
		for i in placed[kind].size():
			mm.set_instance_transform(i, placed[kind][i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		var params: Dictionary = info.colors.duplicate()
		params["shape"] = info.shape
		mmi.material_override = _mat(LEAF3D, params)
		add_child(mmi)


func _grass() -> void:
	var view := view_position()
	var rect := Rect2(view.x - 85.0, view.z - 80.0, 92.0, 140.0)
	Grass.field(self, rect, 0.65, {
		"mask": func(p: Vector2) -> float:
			var open := open_at(p.x, p.y)
			var off := off_path(p.x, p.y)
			if off < 1.8 or not _clear_of_props(p.x, p.y, 0.2):
				return 0.0
			# a little along the path's edge in the wood, all over the open ground
			return maxf(open, 0.35 * (1.0 - smoothstep(2.2, 4.0, off))),
		"height": func(p: Vector2) -> float: return height(p.x, p.y),
		"ground": Color(0.36, 0.3, 0.15),
		"body": Color(0.5, 0.44, 0.2),
		"tip": Color(0.82, 0.68, 0.36),
		"dry": Color(0.78, 0.6, 0.3),
		"dryness": 0.6,
		"flowers": 0.0,
		"blade_height": 0.42,
		"banded": 0.0,
		"wrap": 0.6,
		"translucency": 0.6,
		"wind": 0.35,
		"seed": 7,
	})


func _corn() -> void:
	var stalk := CornBuilder.stalk(false)
	var plain := CornBuilder.stalk(true)
	var view := view_position()
	var near: Array = []
	var far: Array = []
	var x := CORN_FIELD.position.x + 0.5
	while x < CORN_FIELD.end.x:
		var z := CORN_FIELD.position.y + 0.3
		while z < CORN_FIELD.end.y:
			var px := x + rng.randf_range(-0.12, 0.12)
			var pz := z + rng.randf_range(-0.15, 0.15)
			z += CornBuilder.STEP
			# a ragged edge, and a few gaps
			var edge := minf(minf(px - CORN_FIELD.position.x, CORN_FIELD.end.x - px), minf(pz - CORN_FIELD.position.y, CORN_FIELD.end.y - pz))
			if rng.randf() < 0.08 or (edge < 1.5 and rng.randf() < 0.4):
				continue
			var s := rng.randf_range(0.88, 1.12)
			var tr := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), ground_point(px, pz) - Vector3(0, 0.05, 0))
			(near if Vector2(px - view.x, pz - view.z).length() < 34.0 else far).append(tr)
		x += CornBuilder.ROW
	var mat := _mat(CORN)
	for set in [[near, stalk], [far, plain]]:
		if set[0].is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = set[1]
		mm.instance_count = set[0].size()
		for i in set[0].size():
			mm.set_instance_transform(i, set[0][i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = mat
		add_child(mmi)


func _leaf_cards(count: int, falling: bool, around := Vector3.INF, radius := 0.0) -> Array:
	var out: Array = []
	for i in count:
		var z := rng.randf_range(-90.0, 30.0)
		var off := (rng.randf() * 2.0 - 1.0) * (7.0 if falling else 5.5)
		# lying leaves gather at the path's edges
		if not falling and rng.randf() < 0.6:
			off = signf(off) * rng.randf_range(1.2, 2.6)
		var x := path_x(z) + off
		if around != Vector3.INF:
			var a := rng.randf() * TAU
			var d := sqrt(rng.randf()) * radius
			x = around.x + cos(a) * d
			z = around.z + sin(a) * d
		var p := ground_point(x, z)
		var size := rng.randf_range(0.14, 0.26)
		var basis := Basis(Vector3.UP, rng.randf() * TAU)
		if falling:
			p.y += rng.randf_range(7.0, 12.0)
		else:
			p.y += 0.02 + rng.randf() * 0.02
			basis = Basis(Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized(), rng.randf_range(0.0, 0.3)) * basis
		var custom := Color(rng.randf(), rng.randf(), rng.randf_range(0.5, 1.0) if falling else rng.randf_range(0.3, 0.85), rng.randf())
		out.append([Transform3D(basis.scaled(Vector3(size, size, size)), p), custom])
	return out


func _leaf_mesh(cards: Array, material: ShaderMaterial) -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(1, 1)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = plane
	mm.instance_count = cards.size()
	for i in cards.size():
		mm.set_instance_transform(i, cards[i][0])
		mm.set_instance_custom_data(i, cards[i][1])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = material
	mmi.custom_aabb = AABB(Vector3(-60, -20, -160), Vector3(120, 50, 220))
	add_child(mmi)


func _ground_leaves() -> void:
	_leaf_mesh(_leaf_cards(3500, false), _mat(LEAF))


func _falling_leaves() -> void:
	var view := view_position()
	var cards := _leaf_cards(260, true)
	# and plenty coming down round where you stand, under the oaks
	cards.append_array(_leaf_cards(260, true, view, 14.0))
	_leaf_mesh(cards, _mat(LEAF, {"falling": 1.0}))


# Shafts of sun slanting down through the trees, two crossed cards each, each coming and going
func _shafts() -> void:
	var sun := SUN_DIR.normalized()
	var view := view_position()
	var feet: Array[Vector3] = []
	var z := 10.0
	while z > -80.0:
		feet.append(ground_point(path_x(z) + rng.randf_range(-2.5, 2.5), z))
		z -= rng.randf_range(5.0, 9.0)
	# more round where you stand: in the wood's edge, over the patch and the path
	for i in 14:
		var a := rng.randf() * TAU
		var d := rng.randf_range(4.0, 22.0)
		var x := view.x + cos(a) * d
		var zz := view.z + sin(a) * d
		if open_at(x, zz) > 0.7:
			continue
		feet.append(ground_point(x, zz))
	for foot in feet:
		var length := rng.randf_range(14.0, 22.0)
		var width := rng.randf_range(0.8, 2.6)
		var mid: Vector3 = foot + sun * length * 0.5
		var seed := rng.randf() * 10.0
		var strength := rng.randf_range(0.1, 0.2)
		for k in 2:
			var quad := QuadMesh.new()
			quad.size = Vector2(width, length)
			var m := MeshInstance3D.new()
			m.mesh = quad
			var y_axis := sun
			var x_axis := y_axis.cross(Vector3.UP).normalized().rotated(y_axis, k * PI * 0.5)
			var z_axis := x_axis.cross(y_axis).normalized()
			m.transform = Transform3D(Basis(x_axis, y_axis, z_axis), mid)
			m.material_override = _mat(SHAFT, {"seed": seed, "strength": strength})
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(m)


func _glow() -> void:
	var z := -118.0
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	var m := MeshInstance3D.new()
	m.mesh = quad
	m.material_override = _mat(GLOW, {"strength": 0.4})
	m.position = Vector3(path_x(z) + 6.0, 9.0, z)
	m.scale = Vector3(70, 70, 1)
	add_child(m)


# --- things in the wood ---

func _props() -> void:
	_fallen_log()
	_fallen_trees()
	_pumpkin_patch()
	_stones()


func _fallen_log() -> void:
	var px := path_x(LOG_Z)
	var builder := TreeBuilder.new()
	var r := RandomNumberGenerator.new()
	r.seed = 7
	# a felled trunk, bare, lying along the path a little skew
	var mesh := builder.build(r, {"height": 9.0, "radius": 0.45, "reach": 1.6, "bare": true, "branches": 0, "tip": 0.7, "flute": 0.05})
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = _mat(BARK, {"moss": 1.0})
	var base := ground_point(px + 3.2, LOG_Z + 3.5)
	var basis := Basis(Vector3.UP, 0.25) * Basis(Vector3.RIGHT, -PI * 0.5 + 0.03)
	m.transform = Transform3D(basis, base + Vector3(0, 0.35, 0))
	add_child(m)
	# its stump, snapped off
	var stump := MeshInstance3D.new()
	stump.mesh = builder.build(r, {"height": 1.2, "radius": 0.55, "branches": 0, "bare": true, "tip": 0.85, "roots": 5, "flute": 0.1, "flare": 0.8})
	stump.material_override = materials[-1]
	stump.position = ground_point(px + 3.6, LOG_Z + 5.0) - Vector3(0, 0.1, 0)
	add_child(stump)


# Great trees blown down, their roots torn up in a plate of earth standing on end
func _fallen_trees() -> void:
	var mat := _mat(BARK, {"moss": 1.0})
	var soil := _mat(PROP, {"color": Color(0.24, 0.17, 0.11), "shadow_color": Color(0.07, 0.05, 0.04), "brush": 0.7})
	# [x off the path, z, which way it lies, foot radius]
	var lying := [[7.5, -33.0, 0.5, 0.75], [-6.5, -4.0, 2.6, 0.6], [14.0, -58.0, -0.4, 0.9]]
	for k in lying.size():
		var r := RandomNumberGenerator.new()
		r.seed = 70 + k
		var radius: float = lying[k][3]
		var builder := TreeBuilder.new()
		var mesh := builder.build(r, {"height": 13.0, "radius": radius, "reach": 4.0, "bare": true, "branches": 4,
			"roots": 9, "curl": 1.0, "twist": 0.06, "flute": 0.1, "flare": 1.0})
		var tz: float = lying[k][1]
		var tx: float = path_x(tz) + lying[k][0]
		var yaw: float = lying[k][2]
		# laid over: the trunk's up (+Y) along the ground, the yaw way
		var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, -PI * 0.5 + 0.06)
		var foot := ground_point(tx, tz) + Vector3(0, radius * 0.75, 0)
		var m := MeshInstance3D.new()
		m.mesh = mesh
		m.material_override = mat
		m.transform = Transform3D(basis, foot)
		add_child(m)
		# the plate of earth the roots tore up
		var plate := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radial_segments = 12
		sphere.rings = 6
		plate.mesh = sphere
		plate.material_override = soil
		plate.transform = Transform3D(basis * Basis().scaled(Vector3(radius * 3.4, 0.35, radius * 3.4)), foot - basis.y * 0.2)
		add_child(plate)


func _pumpkin_patch() -> void:
	var fence_mat := _mat(PROP, {"color": Color(0.36, 0.27, 0.19), "shadow_color": Color(0.08, 0.06, 0.05), "brush": 0.5})
	# a split-rail fence, zig-zagging along the left of the path
	var z := PATCH_Z.x + 2.0
	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3(0.14, 1.3, 0.14)
	var zig := 0
	var prev := Vector3.ZERO
	while z > PATCH_Z.y - 2.0:
		var x := path_x(z) - 2.3 - 0.45 * float(zig % 2)
		var p := ground_point(x, z)
		var post := MeshInstance3D.new()
		post.mesh = post_mesh
		post.material_override = fence_mat
		post.position = p + Vector3(0, 0.55, 0)
		post.rotation = Vector3(rng.randf_range(-0.08, 0.08), rng.randf(), rng.randf_range(-0.12, 0.12))
		add_child(post)
		if zig > 0:
			for h in [0.45, 0.9]:
				# one rail broken and fallen now and then
				if h > 0.6 and rng.randf() < 0.25:
					continue
				_rail(prev + Vector3(0, h, 0), p + Vector3(0, h + rng.randf_range(-0.06, 0.06), 0), fence_mat)
		prev = p
		zig += 1
		z -= 2.6
	# pumpkins in the patch behind it, in their vines
	var pumpkin_mats := [
		_mat(PROP, {"color": Color(0.92, 0.48, 0.12), "shadow_color": Color(0.38, 0.12, 0.04), "gloss": 0.25}),
		_mat(PROP, {"color": Color(0.85, 0.38, 0.1), "shadow_color": Color(0.32, 0.09, 0.03), "gloss": 0.2}),
		_mat(PROP, {"color": Color(0.94, 0.62, 0.22), "shadow_color": Color(0.4, 0.18, 0.06), "gloss": 0.2}),
	]
	var stem_mat := _mat(PROP, {"color": Color(0.42, 0.4, 0.2), "shadow_color": Color(0.12, 0.1, 0.05)})
	var meshes := [_pumpkin_mesh(1.0, 10), _pumpkin_mesh(0.8, 8), _pumpkin_mesh(1.25, 12)]
	for i in 30:
		var pz := rng.randf_range(PATCH_Z.y + 1.0, PATCH_Z.x - 1.0)
		var px := path_x(pz) - rng.randf_range(3.2, 11.5)
		var size := rng.randf_range(0.16, 0.36)
		if i < 3:
			# a few right by the fence, where they can be seen
			px = path_x(pz) - rng.randf_range(2.9, 4.0)
		var p := ground_point(px, pz)
		var pm := MeshInstance3D.new()
		pm.mesh = meshes[i % meshes.size()]
		pm.material_override = pumpkin_mats[rng.randi_range(0, 2)]
		pm.position = p + Vector3(0, size * 0.32, 0)
		pm.rotation = Vector3(rng.randf_range(-0.2, 0.2), rng.randf() * TAU, rng.randf_range(-0.2, 0.2))
		pm.scale = Vector3(size, size * rng.randf_range(0.75, 0.95), size)
		add_child(pm)
		var stem := MeshInstance3D.new()
		var sc := CylinderMesh.new()
		sc.top_radius = 0.05
		sc.bottom_radius = 0.09
		sc.height = 0.3
		sc.radial_segments = 6
		stem.mesh = sc
		stem.material_override = stem_mat
		stem.position = Vector3(0.0, 0.5, 0.0)
		stem.rotation = Vector3(0.4, 0, 0.2)
		pm.add_child(stem)
	# broad leaves and vines among them: low dark-green-going-brown clumps
	var vines: Array = []
	for i in 140:
		var pz := rng.randf_range(PATCH_Z.y, PATCH_Z.x)
		var px := path_x(pz) - rng.randf_range(2.6, 12.5)
		var size := rng.randf_range(0.45, 0.85)
		vines.append([ground_point(px, pz) + Vector3(0, 0.05, 0), Color(size, rng.randf(), rng.randf_range(0.2, 0.7), rng.randf())])
	_foliage_mesh(vines, _mat(FOLIAGE, {"gold": Color(0.55, 0.52, 0.22), "orange": Color(0.45, 0.4, 0.16), "rust": Color(0.42, 0.3, 0.14), "leaf_scale": 4.0, "sway": 0.3, "darkness": 0.1}))


func _rail(a: Vector3, b: Vector3, mat: ShaderMaterial) -> void:
	var rail := MeshInstance3D.new()
	var box := BoxMesh.new()
	var length := a.distance_to(b) + 0.4
	box.size = Vector3(0.12, 0.1, length)
	rail.mesh = box
	rail.material_override = mat
	add_child(rail)
	rail.look_at_from_position((a + b) * 0.5, b, Vector3.UP)
	rail.rotate_object_local(Vector3.FORWARD, rng.randf_range(-0.3, 0.3))


# A pumpkin: a squashed sphere with deep ribs, `ribs` of them
func _pumpkin_mesh(squash: float, ribs: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 10
	var segs := ribs * 4
	var verts: Array = []
	for j in rings + 1:
		var v := float(j) / rings
		var theta := v * PI
		var row: Array = []
		for i in segs + 1:
			var u := float(i) / segs
			var phi := u * TAU
			var rib := 1.0 - 0.09 * pow(absf(sin(phi * ribs * 0.5)), 0.6) * sin(theta)
			var r := sin(theta) * rib
			var y := cos(theta) * 0.8 * squash
			row.append(Vector3(cos(phi) * r, y * (1.0 - 0.25 * pow(absf(cos(theta)), 8.0)), sin(phi) * r))
		verts.append(row)
	for j in rings:
		for i in segs:
			var a: Vector3 = verts[j][i]
			var b: Vector3 = verts[j][i + 1]
			var c: Vector3 = verts[j + 1][i]
			var d: Vector3 = verts[j + 1][i + 1]
			for p in [a, c, b, b, c, d]:
				st.add_vertex(p)
	st.generate_normals()
	return st.commit()


func _stones() -> void:
	var mat := _mat(PROP, {"color": Color(0.5, 0.46, 0.38), "shadow_color": Color(0.14, 0.12, 0.1), "brush": 0.5})
	var spots: Array[Vector2] = []
	for i in 30:
		var z := rng.randf_range(-90.0, 40.0)
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		spots.append(Vector2(path_x(z) + side * rng.randf_range(1.6, 6.0), z))
	# and along the stream and round the pond
	for i in 26:
		var t := rng.randf()
		var k := mini(int(t * (STREAM.size() - 1)), STREAM.size() - 2)
		var p := STREAM[k].lerp(STREAM[k + 1], fmod(t * (STREAM.size() - 1), 1.0))
		spots.append(p + Vector2(rng.randf_range(-1.6, 1.6), rng.randf_range(-1.6, 1.6)))
	for i in 12:
		var a := rng.randf() * TAU
		spots.append(POND + Vector2(cos(a) * POND_SIZE.x, sin(a) * POND_SIZE.y) * rng.randf_range(0.95, 1.15))
	for p in spots:
		if absf(p.x - path_x(p.y)) < 1.5:
			continue
		var s := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radial_segments = 7
		sphere.rings = 4
		s.mesh = sphere
		s.material_override = mat
		var size := rng.randf_range(0.2, 0.6)
		s.position = ground_point(p.x, p.y)
		s.scale = Vector3(size * rng.randf_range(1.0, 1.6), size * 0.6, size)
		s.rotation.y = rng.randf() * TAU
		add_child(s)
