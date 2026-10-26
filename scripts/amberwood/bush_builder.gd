extends RefCounted
## Builds a bush as real leaves, one small card each, for close up (far off, foliage.gdshader's painted
## clumps stand in). Leaves fill an upright ellipsoid, thickest at its skin, each facing out from the
## middle so the bush shades as one round thing; bracken is fronds arching out from its foot instead.
## leaf3d.gdshader cuts each card to the kind's leaf shape and lights it.
##
## Each card has UV across (x) and along (y) the leaf, NORMAL out from the bush's middle, and COLOR:
## r its own shade between the kind's two colours, g how far out in the bush it is (0 middle, 1 skin).

## The kinds: leaf shape (leaf3d.gdshader's `shape`), how many leaves and how long, the bush's half
## size (across, up), and its colours.
const KINDS := {
	"bronze": {"shape": 0.0, "leaves": 320, "leaf": 0.13, "size": Vector2(0.9, 0.7),
		"colors": {"color_a": Color(0.36, 0.33, 0.13), "color_b": Color(0.6, 0.34, 0.1), "color_dark": Color(0.12, 0.1, 0.05)}},
	"ember": {"shape": 3.0, "leaves": 280, "leaf": 0.11, "size": Vector2(0.7, 0.85),
		"colors": {"color_a": Color(0.88, 0.36, 0.1), "color_b": Color(0.62, 0.15, 0.06), "color_dark": Color(0.2, 0.06, 0.03)}},
	"bracken": {"shape": 2.0, "leaves": 16, "leaf": 0.95, "size": Vector2(0.6, 0.5),
		"colors": {"color_a": Color(0.74, 0.52, 0.22), "color_b": Color(0.56, 0.33, 0.12), "color_dark": Color(0.2, 0.12, 0.06)}},
	"shadow": {"shape": 1.0, "leaves": 150, "leaf": 0.24, "size": Vector2(1.0, 0.9),
		"colors": {"color_a": Color(0.2, 0.2, 0.1), "color_b": Color(0.15, 0.12, 0.06), "color_dark": Color(0.04, 0.04, 0.03)}},
	"holly": {"shape": 0.0, "leaves": 380, "leaf": 0.08, "size": Vector2(0.6, 0.5),
		"colors": {"color_a": Color(0.3, 0.36, 0.14), "color_b": Color(0.46, 0.42, 0.16), "color_dark": Color(0.08, 0.1, 0.04)}},
}

var st: SurfaceTool


func build(rng: RandomNumberGenerator, kind: String) -> ArrayMesh:
	var info: Dictionary = KINDS[kind]
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var size: Vector2 = info.size
	var middle := Vector3(0.0, size.y * 0.8, 0.0)
	var length: float = info.leaf
	if kind == "bracken":
		for f in info.leaves:
			_frond(rng, f * TAU / info.leaves + rng.randf_range(-0.2, 0.2), length * rng.randf_range(0.7, 1.15))
		return st.commit()
	for i in info.leaves:
		# a point in the ellipsoid, mostly near its skin, not under the ground
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.6, 1), rng.randf_range(-1, 1)).normalized()
		var out := pow(rng.randf(), 0.35)
		var p := middle + Vector3(dir.x * size.x, dir.y * size.y, dir.z * size.x) * out
		p.y = maxf(p.y, 0.05)
		var n := (dir + Vector3(rng.randf_range(-0.4, 0.4), rng.randf_range(-0.2, 0.5), rng.randf_range(-0.4, 0.4))).normalized()
		# the leaf lies across its normal, hanging a little
		var along := n.cross(Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1))).normalized()
		along = (along + Vector3.DOWN * 0.3).normalized()
		var across := n.cross(along).normalized()
		var l := length * rng.randf_range(0.75, 1.25)
		var w := l * (0.75 if info.shape != 1.0 else 0.85)
		var foot := p - along * l * 0.5
		var c := Color(rng.randf(), out, 0.0)
		_card(foot, along * l, across * w, n, dir, c)
	return st.commit()


# A frond of bracken: a strip arching up and out from the foot and drooping at its tip
func _frond(rng: RandomNumberGenerator, a: float, length: float) -> void:
	var out := Vector3(cos(a), 0.0, sin(a))
	var side := out.cross(Vector3.UP).normalized()
	var rise := rng.randf_range(0.7, 1.2)
	var pieces := 5
	var prev := Vector3.ZERO
	var w := 0.32 * length
	var shade := rng.randf()
	for k in pieces:
		var t0 := float(k) / pieces
		var t1 := float(k + 1) / pieces
		var p0 := _frond_at(out, length, rise, t0)
		var p1 := _frond_at(out, length, rise, t1)
		var n := (p1 - p0).cross(side).normalized()
		if n.y < 0.0:
			n = -n
		var corners := [p0 - side * w * 0.5, p0 + side * w * 0.5, p1 + side * w * 0.5, p1 - side * w * 0.5]
		var uvs := [Vector2(0, t0), Vector2(1, t0), Vector2(1, t1), Vector2(0, t1)]
		for i in [0, 1, 2, 0, 2, 3]:
			st.set_color(Color(shade, 0.6 + 0.4 * (uvs[i].y), 0.0))
			st.set_normal((n + out * 0.5).normalized())
			st.set_uv(uvs[i])
			st.add_vertex(corners[i])
		prev = p1


func _frond_at(out: Vector3, length: float, rise: float, t: float) -> Vector3:
	return out * length * t + Vector3.UP * length * (rise * t - rise * 1.1 * t * t + 0.05)


func _card(foot: Vector3, along: Vector3, across: Vector3, n: Vector3, out_dir: Vector3, c: Color) -> void:
	var corners := [foot - across * 0.5, foot + across * 0.5, foot + across * 0.5 + along, foot - across * 0.5 + along]
	var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	# shade it as the bush, round, not as a flat leaf
	var shade_n := (out_dir * 0.7 + n * 0.3).normalized()
	for i in [0, 1, 2, 0, 2, 3]:
		st.set_color(c)
		st.set_normal(shade_n)
		st.set_uv(uvs[i])
		st.add_vertex(corners[i])
