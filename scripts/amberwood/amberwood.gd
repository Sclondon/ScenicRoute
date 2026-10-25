extends Node3D
## Amberwood: an autumn wood at the golden hour, after Over the Garden Wall. A dirt path wanders off
## into a haze of sun between dark trunks; the crowns meet over it in gold and rust; leaves come down.
## Everything is built here from code and seeded, so it is the same wood every visit.
##
## The look comes from painting, not lighting: every material lights itself by hand off `SUN_DIR`
## (the engine's light is only there for the fog's glow), and warm fog does the depth.

const TreeBuilder := preload("res://scripts/amberwood/tree_builder.gd")
const FOLIAGE := preload("res://shaders/foliage.gdshader")
const BARK := preload("res://shaders/bark.gdshader")
const GROUND := preload("res://shaders/ground.gdshader")
const LEAF := preload("res://shaders/leaf.gdshader")
const SHAFT := preload("res://shaders/shaft.gdshader")
const GLOW := preload("res://shaders/glow.gdshader")
const PROP := preload("res://shaders/prop.gdshader")

## Towards the sun: low, ahead down the path and a little to the right.
const SUN_DIR := Vector3(0.18, 0.3, -1.0)
const SUN_COLOR := Color(1.0, 0.85, 0.55)
const FOG := Color(0.8, 0.62, 0.38)

const NEAR_Z := 45.0
const FAR_Z := -110.0
const HALF_WIDTH := 46.0
const GROUND_HALF := 80.0

## The places you can stand, from the way in to where the light is. `look` is (yaw, pitch) in degrees,
## yaw 0 down the path (-Z), positive to the left.
const SPOTS := [
	{"name": "The way in", "z": 10.0, "side": 0.0, "eye": 1.6, "look": Vector2(0.0, 2.0)},
	{"name": "The fallen log", "z": -15.0, "side": 3.2, "eye": 1.4, "look": Vector2(40.0, -4.0)},
	{"name": "The pumpkin fence", "z": -31.0, "side": 0.5, "eye": 1.6, "look": Vector2(60.0, -8.0)},
	{"name": "Where the light gets in", "z": -50.0, "side": 0.3, "eye": 1.6, "look": Vector2(0.0, 6.0)},
]
const LOG_Z := -15.0
const PATCH_Z := Vector2(-26.0, -40.0)

var rng := RandomNumberGenerator.new()
var materials: Array[ShaderMaterial] = []
var _trees: Array = []  # [Transform3D, variant index]
var _foliage: Array = []  # [Vector3 position, Color custom]


static func path_x(z: float) -> float:
	return 2.2 * sin(z * 0.055) + 1.2 * sin(z * 0.13 + 1.0)


## How far a point is from the middle of the path.
static func off_path(x: float, z: float) -> float:
	return absf(x - path_x(z))


static func height(x: float, z: float) -> float:
	var off := off_path(x, z)
	var h := smoothstep(2.0, 14.0, off) * 1.1 + smoothstep(16.0, 34.0, off) * 2.5 + smoothstep(40.0, 80.0, off) * 7.0
	h += sin(x * 0.21 + z * 0.13) * 0.35 * smoothstep(3.0, 10.0, off)
	h += sin(x * 0.07 - z * 0.05 + 2.0) * 0.6 * smoothstep(5.0, 20.0, off)
	h -= 0.08 * (1.0 - smoothstep(1.2, 2.2, off))
	return h


static func ground_point(x: float, z: float) -> Vector3:
	return Vector3(x, height(x, z), z)


## Where you stand at a spot, and which way you face.
static func spot_position(i: int) -> Vector3:
	var s: Dictionary = SPOTS[i]
	var z: float = s.z
	var x := path_x(z) + float(s.side)
	return Vector3(x, height(x, z) + float(s.eye), z)


func _ready() -> void:
	rng.seed = 1031
	_environment()
	_ground()
	_props()
	_trees_and_leaves()
	_undergrowth()
	_ground_leaves()
	_falling_leaves()
	_shafts()
	_glow()


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
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.95, 0.84, 0.6)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.4, 0.3)
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = FOG
	env.fog_density = 0.026
	env.fog_sun_scatter = 0.35
	env.fog_sky_affect = 1.0
	env.fog_height = 0.6
	env.fog_height_density = 0.12
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 0.85
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	# only for the fog's glow towards the sun; nothing here is lit by it
	var sun := DirectionalLight3D.new()
	sun.light_color = SUN_COLOR
	sun.light_energy = 1.0
	sun.shadow_enabled = false
	sun.look_at_from_position(Vector3.ZERO, -SUN_DIR, Vector3.UP)
	add_child(sun)


func _ground() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# finer near the path, where it is seen close up
	var xs: Array[float] = []
	var x := -GROUND_HALF
	while x <= GROUND_HALF:
		xs.append(x)
		x += 0.6 if absf(x) < 9.0 else (2.0 if absf(x) < 30.0 else 4.0)
	var zs: Array[float] = []
	var z := NEAR_Z
	while z >= FAR_Z:
		zs.append(z)
		z -= 0.8 if z > -70.0 else 2.5
	# the grid follows the path, so the path is always well inside the fine part
	for j in zs.size() - 1:
		for i in xs.size() - 1:
			var a := _gp(xs[i], zs[j])
			var b := _gp(xs[i + 1], zs[j])
			var c := _gp(xs[i], zs[j + 1])
			var d := _gp(xs[i + 1], zs[j + 1])
			for p in [a, c, b, b, c, d]:
				var q: Vector3 = p
				st.set_normal(_normal(q.x, q.z))
				st.add_vertex(q)
	var mesh := MeshInstance3D.new()
	mesh.mesh = st.commit()
	mesh.material_override = _mat(GROUND)
	add_child(mesh)


func _gp(x: float, z: float) -> Vector3:
	return ground_point(x + path_x(z), z)


func _normal(x: float, z: float) -> Vector3:
	var e := 0.3
	return Vector3(height(x - e, z) - height(x + e, z), 2.0 * e, height(x, z - e) - height(x, z + e)).normalized()


func _clear_of_props(x: float, z: float, r: float) -> bool:
	var px := path_x(z)
	# the fallen log on the right of the path
	if absf(z - LOG_Z) < 6.0 + r and x > px and x < px + 7.0 + r:
		return false
	# the pumpkin patch on the left
	if z < PATCH_Z.x + r and z > PATCH_Z.y - r and x < px - 1.5 and x > px - 13.0 - r:
		return false
	return true


func _trees_and_leaves() -> void:
	# a handful of shapes, reused turned and scaled
	var builder := TreeBuilder.new()
	var variants: Array = []
	for v in 12:
		var birch := v >= 9
		var h := rng.randf_range(11.0, 17.0) if not birch else rng.randf_range(10.0, 14.0)
		var r := rng.randf_range(0.28, 0.5) if not birch else rng.randf_range(0.16, 0.24)
		var mesh := builder.build(rng, h, r, rng.randf_range(3.5, 5.5), false)
		variants.append({"mesh": mesh, "crowns": builder.crowns.duplicate(), "birch": birch, "transforms": []})
	var bark := _mat(BARK, {"moss": 0.6})
	var birch_bark := _mat(BARK, {"birch": 1.0})
	# trees on a jittered grid, thick at the path's edges, none on it
	var step := 2.7
	var z := NEAR_Z + 4.0
	while z > FAR_Z + 4.0:
		var x := -HALF_WIDTH
		while x < HALF_WIDTH:
			var tx := x + rng.randf_range(-1.1, 1.1)
			var tz := z + rng.randf_range(-1.1, 1.1)
			x += step
			var off := off_path(tx, tz)
			var keep := 0.85 if off < 6.0 else (0.55 if off < 16.0 else (0.35 if off < 30.0 else 0.25))
			if off < 2.4 or rng.randf() > keep or not _clear_of_props(tx, tz, 1.0):
				continue
			var vi := rng.randi_range(0, variants.size() - 1)
			if rng.randf() < 0.8 and vi >= 9:
				vi = rng.randi_range(0, 8)
			var s := rng.randf_range(0.8, 1.25)
			# turn the tree so its branches (+X) reach towards the path
			var to_path := signf(path_x(tz) - tx)
			var yaw := (0.0 if to_path > 0.0 else PI) + rng.randf_range(-0.7, 0.7)
			if off > 12.0:
				yaw = rng.randf_range(0.0, TAU)
			var basis := Basis(Vector3.UP, yaw).scaled(Vector3(s, s, s))
			# lean out over the path a little
			basis = Basis(Vector3(0, 0, 1).rotated(Vector3.UP, yaw), -rng.randf_range(0.0, 0.08) * float(off < 6.0)) * basis
			var tr := Transform3D(basis, ground_point(tx, tz) - Vector3(0, 0.15, 0))
			variants[vi].transforms.append(tr)
			_crown(variants[vi], tr, off)
		z -= step
	for v in variants:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = v.mesh
		mm.instance_count = v.transforms.size()
		for i in v.transforms.size():
			mm.set_instance_transform(i, v.transforms[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = birch_bark if v.birch else bark
		add_child(mmi)
	_foliage_mesh(_foliage, _mat(FOLIAGE), 1.0)


# Leaf clumps for one tree: a few cards round each crown point, the tree's own colour give or take
func _crown(variant: Dictionary, tr: Transform3D, off: float) -> void:
	var hue := 0.12 + rng.randf() * 0.88
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
	for i in cards.size():
		mm.set_instance_transform(i, Transform3D(Basis(), cards[i][0]))
		mm.set_instance_custom_data(i, cards[i][1])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = material
	mmi.custom_aabb = AABB(Vector3(-HALF_WIDTH - 10, -5, FAR_Z - 10), Vector3(HALF_WIDTH * 2 + 20, 40, NEAR_Z - FAR_Z + 20))
	add_child(mmi)
	return mmi


func _undergrowth() -> void:
	var bushes: Array = []
	var grass: Array = []
	var z := NEAR_Z
	while z > FAR_Z + 20.0:
		for k in 6:
			var side := -1.0 if rng.randf() < 0.5 else 1.0
			var off := 1.7 + pow(rng.randf(), 1.6) * 12.0
			var x := path_x(z) + side * off
			var zz := z + rng.randf_range(-0.6, 0.6)
			if not _clear_of_props(x, zz, 0.0):
				continue
			var size := rng.randf_range(0.9, 1.8) * (1.0 + off * 0.03)
			var p := ground_point(x, zz) + Vector3(0, size * 0.3, 0)
			bushes.append([p, Color(size, rng.randf_range(0.35, 1.0), rng.randf_range(0.05, 0.5), rng.randf())])
		for k in 4:
			var side := -1.0 if rng.randf() < 0.5 else 1.0
			var off := rng.randf_range(1.45, 3.2)
			var x := path_x(z) + side * off
			var zz := z + rng.randf_range(-0.6, 0.6)
			var size := rng.randf_range(0.45, 0.95)
			grass.append([ground_point(x, zz) - Vector3(0, 0.05, 0), Color(size, rng.randf_range(0.0, 0.6), rng.randf_range(0.3, 0.9), rng.randf())])
		z -= 1.2
	_foliage_mesh(bushes, _mat(FOLIAGE, {"darkness": 0.25, "leaf_scale": 9.0, "sway": 0.4}))
	_foliage_mesh(grass, _mat(FOLIAGE, {"blades": 1.0, "sway": 0.6,
		"gold": Color(0.62, 0.48, 0.26), "orange": Color(0.48, 0.33, 0.17), "rust": Color(0.32, 0.21, 0.11)}))


func _leaf_cards(count: int, falling: bool) -> Array:
	var out: Array = []
	for i in count:
		var z := rng.randf_range(FAR_Z * 0.6, 20.0)
		var off := (rng.randf() * 2.0 - 1.0) * (7.0 if falling else 5.5)
		# lying leaves gather at the path's edges
		if not falling and rng.randf() < 0.6:
			off = signf(off) * rng.randf_range(1.2, 2.6)
		var x := path_x(z) + off
		var p := ground_point(x, z)
		var size := rng.randf_range(0.14, 0.26)
		var basis := Basis(Vector3.UP, rng.randf() * TAU)
		if falling:
			p.y += rng.randf_range(8.0, 12.0)
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
	mmi.custom_aabb = AABB(Vector3(-HALF_WIDTH, -20, FAR_Z), Vector3(HALF_WIDTH * 2, 40, NEAR_Z - FAR_Z))
	add_child(mmi)


func _ground_leaves() -> void:
	_leaf_mesh(_leaf_cards(3500, false), _mat(LEAF))


func _falling_leaves() -> void:
	_leaf_mesh(_leaf_cards(320, true), _mat(LEAF, {"falling": 1.0}))


# Shafts of sun slanting down onto the path, two crossed cards each
func _shafts() -> void:
	var sun := SUN_DIR.normalized()
	var z := 4.0
	while z > -70.0:
		var x := path_x(z) + rng.randf_range(-2.5, 2.5)
		var foot := ground_point(x, z)
		var length := rng.randf_range(14.0, 20.0)
		var width := rng.randf_range(0.8, 2.2)
		var mid := foot + sun * length * 0.5
		var seed := rng.randf() * 10.0
		for k in 2:
			var quad := QuadMesh.new()
			quad.size = Vector2(width, length)
			var m := MeshInstance3D.new()
			m.mesh = quad
			var y_axis := sun
			var x_axis := y_axis.cross(Vector3.UP).normalized().rotated(y_axis, k * PI * 0.5)
			var z_axis := x_axis.cross(y_axis).normalized()
			m.transform = Transform3D(Basis(x_axis, y_axis, z_axis), mid)
			m.material_override = _mat(SHAFT, {"seed": seed, "strength": rng.randf_range(0.08, 0.16)})
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(m)
		z -= rng.randf_range(5.0, 9.0)


func _glow() -> void:
	var z := FAR_Z + 8.0
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
	_pumpkin_patch()
	_stones()


func _fallen_log() -> void:
	var px := path_x(LOG_Z)
	var builder := TreeBuilder.new()
	var r := RandomNumberGenerator.new()
	r.seed = 7
	# a felled trunk, bare, lying along the path a little skew
	var mesh := builder.build(r, 9.0, 0.45, 1.6, true, false, 0.7)
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = _mat(BARK, {"moss": 1.0})
	var base := ground_point(px + 3.2, LOG_Z + 3.5)
	var basis := Basis(Vector3.UP, 0.25) * Basis(Vector3.RIGHT, -PI * 0.5 + 0.03)
	m.transform = Transform3D(basis, base + Vector3(0, 0.35, 0))
	add_child(m)
	# its stump, snapped off
	var stump := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.5
	cyl.bottom_radius = 0.7
	cyl.height = 1.3
	cyl.radial_segments = 9
	stump.mesh = cyl
	stump.material_override = materials[-1]
	stump.position = ground_point(px + 3.6, LOG_Z + 5.0) + Vector3(0, 0.5, 0)
	add_child(stump)


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
	for i in 26:
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
		var size := rng.randf_range(0.6, 1.2)
		vines.append([ground_point(px, pz) + Vector3(0, 0.15, 0), Color(size, rng.randf(), rng.randf_range(0.2, 0.7), rng.randf())])
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
	for i in 30:
		var z := rng.randf_range(FAR_Z * 0.6, NEAR_Z)
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var x := path_x(z) + side * rng.randf_range(1.6, 6.0)
		if not _clear_of_props(x, z, 0.0):
			continue
		var s := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radial_segments = 7
		sphere.rings = 4
		s.mesh = sphere
		s.material_override = mat
		var size := rng.randf_range(0.2, 0.6)
		s.position = ground_point(x, z)
		s.scale = Vector3(size * rng.randf_range(1.0, 1.6), size * 0.6, size)
		s.rotation.y = rng.randf() * TAU
		add_child(s)
