extends RefCounted
## The people of The Velvet Moth: low figures facing -Z with their feet at the origin, made to be danced
## by shaders/velvet_moth/crowd.gdshader. COLOR.r marks the part (0 legs, 0.25 body, 0.5 head, 0.75 left
## arm, 1 right arm) and COLOR.g how far down the arm (past 0.5, the forearm and hand).

const Geo := preload("res://scripts/velvet_moth/geo.gd")

const SHOULDER := 1.42
const HIP := 0.88
const SEAT_SHOULDER := 1.0
const SEAT_HIP := 0.47


static func _part(p: float, g := 0.0) -> Color:
	return Color(p, g, 0.0)


## A standing figure. kind 0: short hair; 1: hair up in a bun, slimmer; 2: long hair; 3: broad, a cap.
static func standing(kind: int) -> ArrayMesh:
	var g := Geo.new()
	var slim := 0.88 if kind == 1 or kind == 2 else (1.12 if kind == 3 else 1.0)
	for side in [-1.0, 1.0]:
		g.prism(Vector3(side * 0.095, HIP + 0.02, 0.0), Vector3(side * 0.11, 0.06, 0.0), 0.1, 0.065, 6, _part(0.0))
		g.box(Vector3(side * 0.11 - 0.05, 0.0, -0.15), Vector3(side * 0.11 + 0.05, 0.08, 0.05), _part(0.0))
	_top(g, HIP, SHOULDER, slim, kind)
	return g.commit()


## A figure sat down, its seat 0.45 above its origin, thighs forward.
static func seated(kind: int) -> ArrayMesh:
	var g := Geo.new()
	var slim := 0.88 if kind == 1 or kind == 2 else 1.0
	for side in [-1.0, 1.0]:
		g.prism(Vector3(side * 0.1, SEAT_HIP, 0.0), Vector3(side * 0.11, SEAT_HIP + 0.02, -0.42), 0.085, 0.065, 6, _part(0.0))
		g.prism(Vector3(side * 0.11, SEAT_HIP + 0.02, -0.42), Vector3(side * 0.12, 0.06, -0.46), 0.06, 0.05, 6, _part(0.0))
		g.box(Vector3(side * 0.12 - 0.05, 0.0, -0.6), Vector3(side * 0.12 + 0.05, 0.08, -0.4), _part(0.0))
	_top(g, SEAT_HIP - 0.04, SEAT_SHOULDER, slim, kind)
	return g.commit()


# The body from the hips up: body, neck, head (and hair), and the arms hanging from the shoulders
static func _top(g: Geo, hip: float, sh: float, slim: float, kind: int) -> void:
	var body := _part(0.25)
	g.prism(Vector3(0, hip - 0.04, 0), Vector3(0, hip + 0.18, 0), 0.165 * slim, 0.15 * slim, 8, body, true, 0.62)
	g.prism(Vector3(0, hip + 0.18, 0), Vector3(0, sh + 0.02, 0), 0.15 * slim, 0.205 * slim, 8, body, true, 0.6)
	var head := _part(0.5)
	g.prism(Vector3(0, sh, 0), Vector3(0, sh + 0.12, 0), 0.05, 0.045, 5, head)
	var hc := Vector3(0, sh + 0.22, 0)
	g.sphere(hc, 0.12, 8, 6, head, Vector3(0.9, 1.08, 1.0))
	match kind:
		1:
			g.sphere(hc + Vector3(0, 0.08, 0.09), 0.065, 6, 4, head)
		2:
			g.prism(hc + Vector3(0, 0.04, 0.03), hc + Vector3(0, -0.3, 0.07), 0.11, 0.09, 7, head, true, 0.8)
		3:
			g.prism(hc + Vector3(0, 0.05, 0), hc + Vector3(0, 0.12, 0), 0.115, 0.11, 8, head)
			g.box(hc + Vector3(-0.09, 0.05, -0.2), hc + Vector3(0.09, 0.075, -0.05), head)
	for side in [-1.0, 1.0]:
		var p := 0.75 if side < 0.0 else 1.0
		var s := Vector3(side * 0.2 * slim, sh, 0)
		var e := s + Vector3(side * 0.015, -0.29, 0)
		var h := e + Vector3(side * 0.015, -0.27, 0)
		g.sphere(s + Vector3(0, 0.0, 0), 0.075, 6, 4, _part(p, 0.0))
		g.prism(s + Vector3(0, 0.03, 0), e, 0.07, 0.055, 6, _part(p, 0.2))
		g.prism(e + Vector3(0, 0.03, 0), h, 0.058, 0.044, 6, _part(p, 0.9))
		g.sphere(h + Vector3(0, -0.03, 0), 0.052, 5, 3, _part(p, 0.9))
