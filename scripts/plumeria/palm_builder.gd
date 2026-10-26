extends RefCounted
## A coconut palm, built into two MeshKits (trunks, fronds) so a whole grove is two draws: a ringed trunk
## that leans off its foot and curves back up to the light, a crown of fronds arching out and drooping, a
## couple of dead ones hanging brown under it, and a cluster of coconuts. `lite` builds a plainer one for
## far off. What sways and how much is written into UV2 and COLOR.a for palm.gdshader.

const MeshKit := preload("res://scripts/plumeria/mesh_kit.gd")


static func build(trunks: MeshKit, fronds: MeshKit, base: Vector3, height: float, lean_dir: Vector3,
		lean: float, rng: RandomNumberGenerator, lite := false) -> Vector3:
	var phase := rng.randf()
	var rings := 7 if lite else 14
	var sides := 5 if lite else 8
	var pts := PackedVector3Array()
	var radii := PackedFloat32Array()
	var t2s := []
	var flat := Vector3(lean_dir.x, 0.0, lean_dir.z).normalized()
	var wobble := Vector3(-flat.z, 0.0, flat.x) * rng.randf_range(-0.4, 0.4)
	for i in rings + 1:
		var s := float(i) / rings
		var off := flat * lean * (2.0 * s - s * s) + wobble * sin(s * PI)
		pts.append(base + Vector3.UP * height * s + off)
		radii.append(0.19 * (1.0 + 0.7 * exp(-s * 10.0)) * (1.0 - 0.3 * s) * (height / 9.0 * 0.4 + 0.6))
		t2s.append(Vector2(s * s, 0.0))
	var tint := Color(1, 1, 1, phase)
	trunks.tube(pts, radii, sides, tint, t2s)
	var top := pts[pts.size() - 1]
	# the crownshaft and the coconuts
	trunks.blob(Transform3D(Basis(), top + Vector3(0, 0.15, 0)), Vector3(0.24, 0.32, 0.24), Color(0.62, 0.62, 0.42, phase), 4, 6, Vector2(1, 0))
	if not lite:
		for k in rng.randi_range(3, 6):
			var a := rng.randf() * TAU
			var at := top + Vector3(cos(a) * 0.22, -0.05 - rng.randf() * 0.2, sin(a) * 0.22)
			trunks.blob(Transform3D(Basis(), at), Vector3.ONE * 0.11, Color(0.42, 0.36, 0.16, phase), 3, 5, Vector2(1, 0))
	var count := rng.randi_range(9, 12) if not lite else 8
	var start := rng.randf() * TAU
	for i in count:
		var a := start + TAU * i / count + rng.randf_range(-0.2, 0.2)
		var rise := rng.randf_range(-0.15, 0.85)
		var length := rng.randf_range(2.8, 3.8) * (height / 9.0 * 0.3 + 0.7)
		var droop := rng.randf_range(0.55, 0.95)
		var green := Color(rng.randf_range(0.78, 1.0), rng.randf_range(0.85, 1.0), rng.randf_range(0.7, 0.95), phase)
		_frond(fronds, top + Vector3(0, 0.25, 0), a, rise, length, droop, green, lite)
	if not lite:
		# dead ones, hanging
		for k in rng.randi_range(1, 3):
			var a := rng.randf() * TAU
			_frond(fronds, top + Vector3(0, 0.05, 0), a, rng.randf_range(-1.3, -0.9), rng.randf_range(1.8, 2.4), 0.1,
				Color(1.0, 0.62, 0.42, phase), lite)
	return top


static func _frond(kit: MeshKit, from: Vector3, azimuth: float, rise: float, length: float, droop: float, tint: Color, lite: bool) -> void:
	var rows := 6 if lite else 14
	var out := Vector3(cos(azimuth), 0.0, sin(azimuth))
	var across := Vector3(-out.z, 0.0, out.x)
	var prev := []
	var last := from
	for i in rows + 1:
		var s := float(i) / rows
		var p := from + out * length * s * cos(rise) + Vector3.UP * (length * s * sin(rise) - droop * length * s * s)
		var tangent := (p - last).normalized() if i > 0 else (out * cos(rise) + Vector3.UP * sin(rise)).normalized()
		last = p
		# leaflets start a little way out, widest past the middle, to a point at the tip
		var w := 0.6 * length / 3.3 * pow(sin(PI * clampf((s - 0.06) / 0.94, 0.0, 1.0)), 0.6)
		var hang := deg_to_rad(28.0 + 30.0 * s)
		var side := across.slide(tangent).normalized()
		var lift := tangent.cross(side).normalized()
		if lift.y < 0.0:
			lift = -lift
		var l := p + side * w * cos(hang) - lift * w * sin(hang)
		var r := p - side * w * cos(hang) - lift * w * sin(hang)
		var flutter := pow(s, 1.5)
		var nl := (lift * cos(hang) + side * sin(hang)).normalized()
		var nr := (lift * cos(hang) - side * sin(hang)).normalized()
		var row := [
			kit.vert(l, nl, tint, Vector2(s, -1.0), Vector2(1.0, flutter)),
			kit.vert(p + lift * 0.02, lift, tint, Vector2(s, 0.0), Vector2(1.0, flutter)),
			kit.vert(r, nr, tint, Vector2(s, 1.0), Vector2(1.0, flutter)),
		]
		if i > 0:
			kit.quad(prev[0], row[0], row[1], prev[1])
			kit.quad(prev[1], row[1], row[2], prev[2])
		prev = row
