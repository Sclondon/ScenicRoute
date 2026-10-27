extends Node3D
## Caffè del Porto: a terrace table at a cafe on a little harbour of the Italian coast, mid-morning. You sit
## under a striped awning with an espresso, looking out over the moored boats and the breakwater to the
## glittering sea; pastel houses are stacked up the cliffs either side, a bell tower stands over the right
## quay, and behind you are the cafe's door, its menu board and a lane of steps climbing into the town.
## Everything is built here from code and seeded, so it is the same place every visit.
##
## The light is the engine's sun, with its shadows, painted in two tones (shaders/caffe_del_porto/
## light.gdshaderinc): the sun side warm, the shade side the environment's cool blue ambient. The sea is
## see-through where you look across it, and under it are the sky and the boats and houses turned over,
## as their reflections.
##
## The pieces are built by town.gd (the houses, church and cafe), terrace.gd (where you sit) and
## harbour.gd (the sea, boats, breakwater and people), all from the land here (`height`).

const Places := preload("res://scripts/places.gd")

## Made a step at a time (Places.build), so the loading card moves while it is built.
signal progress(done: float)
signal built
var is_built := false

const Geo := preload("res://scripts/caffe_del_porto/geo.gd")
const Town := preload("res://scripts/caffe_del_porto/town.gd")
const Terrace := preload("res://scripts/caffe_del_porto/terrace.gd")
const Harbour := preload("res://scripts/caffe_del_porto/harbour.gd")
const LIT := preload("res://shaders/caffe_del_porto/lit.gdshader")
const HOUSE := preload("res://shaders/caffe_del_porto/house.gdshader")
const LAND := preload("res://shaders/caffe_del_porto/land.gdshader")
const SKY := preload("res://shaders/caffe_del_porto/sky.gdshader")

## Towards the sun: high, ahead and to the right.
const SUN_DIR := Vector3(0.40, 0.76, -0.52)
const SUN_COLOR := Color(1.0, 0.95, 0.84)
## The sea's surface; the quay and the terrace are at 0.
const SEA := -1.0
## The edge of the quay at the head of the harbour, in front of the terrace; the houses' fronts behind it.
const QUAY_Z := -3.4
const FRONT_Z := 4.6
## The lane of steps that climbs into the town beside the cafe (its middle, and half its width).
const LANE_X := 8.4
const LANE_HALF := 1.25

## Where you sit: at a little marble table on the terrace, looking out to sea.
const VIEW := {"eye": 1.2, "look": Vector2(8.0, -4.0)}

var rng := RandomNumberGenerator.new()
var lit: ShaderMaterial
var lit_still: ShaderMaterial
var lit_tree: ShaderMaterial
var house: ShaderMaterial
var harbour: Node3D
var terrace: Node3D
## Small things near you, all in one mesh (the cafe's front, the terrace's tiles, what is on the tables).
var terrace_geo := Geo.new()
## Meshes to show turned over under the sea, as their reflections (house-painted, and lit), and the land's.
var reflect: Array[Mesh] = []
var reflect_lit: Array[Mesh] = []
var land_mesh: Mesh


static func view_position() -> Vector3:
	return Vector3(0.0, float(VIEW.eye), 0.0)


## The left shore of the harbour (land where x is less); it curls in towards the mouth further out.
static func shore_l(z: float) -> float:
	return -22.0 + 12.0 * smoothstep(-40.0, -150.0, z) + 2.0 * sin(z * 0.07)


## The right shore (land where x is more), out to the breakwater.
static func shore_r(z: float) -> float:
	return 24.0 + 5.0 * smoothstep(-5.0, -50.0, z) + 1.5 * sin(z * 0.09 + 1.0)


## How far into the land from each shore (negative in the sea): x left, y right, z the harbour's head.
static func into(x: float, z: float) -> Vector3:
	var dl := shore_l(z) - x - maxf(-170.0 - z, 0.0) * 1.2
	var dr := x - shore_r(z) - maxf(-92.0 - z, 0.0) * 1.3
	var db := z - QUAY_Z
	return Vector3(dl, dr, db)


## Quay widths along each shore there (0 where the cliff comes straight out of the sea).
static func quay_w(z: float) -> Vector3:
	return Vector3(6.5 * (1.0 - smoothstep(-35.0, -50.0, z)), 5.5 * (1.0 - smoothstep(-40.0, -55.0, z)), FRONT_Z - QUAY_Z)


static func _rough(x: float, z: float) -> float:
	return 3.0 * sin(x * 0.11 + z * 0.07) + 2.2 * sin(x * 0.05 - z * 0.13 + 1.0) + 1.2 * sin(x * 0.23 + z * 0.19 + 2.0)


static func _cliff(d: float, qw: float, x: float, z: float) -> float:
	if d < 0.0:
		return SEA - 2.0 + d * 0.3
	var q := clampf(qw / 5.0, 0.0, 1.0)
	var e := d - qw - 2.0 * q
	var base := lerpf(SEA + 0.4, 0.0, q)
	if e <= 0.0:
		return base
	return base + 40.0 * (1.0 - exp(-e / 45.0)) + 0.25 * e + _rough(x, z) * smoothstep(0.0, 18.0, e)


## The height of the land (below the sea, the floor of it).
static func height(x: float, z: float) -> float:
	var d := into(x, z)
	var qw := quay_w(z)
	var h := maxf(_cliff(d.x, qw.x, x, z), _cliff(d.y, qw.y, x, z))
	# behind the quay the town climbs, gently at first, then steeply up to the ridge
	var hb := SEA - 2.0 + d.z * 0.3
	if d.z >= 0.0:
		var e := d.z - qw.z - 2.0
		hb = 0.0
		if e > 0.0:
			var lane := 1.0 - smoothstep(LANE_HALF + 0.5, LANE_HALF + 4.0, absf(x - LANE_X))
			hb = 0.42 * e + 32.0 * smoothstep(25.0, 150.0, e) + _rough(x, z) * smoothstep(10.0, 40.0, e) * (1.0 - lane)
	return maxf(h, hb)


## The steps of the lane: the ground along it.
static func lane_height(z: float) -> float:
	return 0.42 * maxf(z - FRONT_Z, 0.0)


func _ready() -> void:
	rng.seed = 7771
	lit = _mat(LIT)
	lit_still = _mat(LIT, {"sway": 0.0})
	lit_tree = _mat(LIT, {"tree": 1.0})
	house = _mat(HOUSE)
	Places.build(self, [_environment, _land, _town, _terrace, _harbour, func(): put(terrace_geo, lit_still, true)])


func _town() -> void:
	Town.new().build(self)


func _terrace() -> void:
	terrace = Terrace.new()
	add_child(terrace)
	terrace.build(self)


func _harbour() -> void:
	harbour = Harbour.new()
	add_child(harbour)
	harbour.build(self)


func _mat(shader: Shader, params := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader
	for k in params:
		m.set_shader_parameter(k, params[k])
	return m


## Put a Geo's mesh in the place.
func put(g: Geo, material: Material, shadows := true, parent: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = g.mesh()
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent else self).add_child(mi)
	return mi


## Many of one mesh: transforms, and their own colours (INSTANCE_CUSTOM) if given.
func many(mesh: Mesh, xfs: Array, material: Material, customs := [], shadows := true, parent: Node = null) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = not customs.is_empty()
	# (with custom data, colours on too and left white: without them the Compatibility renderer tints
	# the whole mesh by the custom data)
	mm.use_colors = mm.use_custom_data
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
		if mm.use_custom_data:
			mm.set_instance_custom_data(i, customs[i])
			mm.set_instance_color(i, Color.WHITE)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = material
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent else self).add_child(mmi)
	return mmi


func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = SKY
	sky_mat.set_shader_parameter("sun_dir", SUN_DIR.normalized())
	env.sky = Sky.new()
	env.sky.sky_material = sky_mat
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.65, 0.92)
	env.ambient_light_energy = 0.66
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color(0.8, 0.86, 0.9)
	env.fog_density = 0.0022
	env.fog_sun_scatter = 0.04
	env.fog_sky_affect = 0.0
	env.fog_height = 8.0
	env.fog_height_density = 0.0
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = SUN_COLOR
	sun.light_energy = 0.74
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 40.0
	sun.directional_shadow_split_1 = 0.25
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.0
	sun.shadow_blur = 0.6
	sun.look_at_from_position(Vector3.ZERO, -SUN_DIR, Vector3.UP)
	add_child(sun)
	# the sun off the tiles, warming the shade under the awning and the cafe's front
	var bounce := OmniLight3D.new()
	bounce.light_color = Color(1.0, 0.76, 0.52)
	bounce.light_energy = 1.1
	bounce.light_specular = 0.0
	bounce.omni_range = 7.5
	bounce.shadow_enabled = false
	bounce.position = Vector3(0.5, 0.3, 1.2)
	add_child(bounce)


# --- the land ---

# Grid lines bunched up near where you sit and spread out far off
func _spread(n: int, lo: float, hi: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for i in range(n, 0, -1):
		var t := float(i) / n
		out.append(lo * t * t)
	for i in n + 1:
		var t := float(i) / n
		out.append(hi * t * t)
	return out


func _land() -> void:
	var xs := _spread(64, -380.0, 560.0)
	var zs := _spread(64, -640.0, 260.0)
	var hs := PackedFloat32Array()
	hs.resize(xs.size() * zs.size())
	for j in zs.size():
		for i in xs.size():
			hs[j * xs.size() + i] = height(xs[i], zs[j])
	var nx := xs.size()
	var nz := zs.size()
	var pts := PackedVector3Array()
	var nrm := PackedVector3Array()
	pts.resize(nx * nz)
	nrm.resize(nx * nz)
	for j in nz:
		for i in nx:
			var i0 := maxi(i - 1, 0)
			var i1 := mini(i + 1, nx - 1)
			var j0 := maxi(j - 1, 0)
			var j1 := mini(j + 1, nz - 1)
			var sx := (hs[j * nx + i1] - hs[j * nx + i0]) / (xs[i1] - xs[i0])
			var sz := (hs[j1 * nx + i] - hs[j0 * nx + i]) / (zs[j1] - zs[j0])
			pts[j * nx + i] = Vector3(xs[i], maxf(hs[j * nx + i], SEA - 2.5), zs[j])
			nrm[j * nx + i] = Vector3(-sx, 1.0, -sz).normalized()
	var cut := SEA - 0.7
	var idx := PackedInt32Array()
	for j in nz - 1:
		for i in nx - 1:
			var a := j * nx + i
			var b := a + 1
			var c := a + nx
			var d := c + 1
			if maxf(maxf(hs[a], hs[b]), maxf(hs[c], hs[d])) < cut:
				continue
			# clockwise from above (x right, z towards you)
			idx.append_array([a, b, d, a, d, c])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = pts
	arrays[Mesh.ARRAY_NORMAL] = nrm
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	land_mesh = mesh
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m := _mat(LAND, {"sea_level": SEA})
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func make_ambience() -> Node:
	return load("res://scripts/caffe_del_porto/ambience.gd").new()
