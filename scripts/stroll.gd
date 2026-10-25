extends Camera3D
## Your eyes in a place: stand at one of its spots, drag to look about (or the arrow keys / a stick),
## and stroll on to the next spot or back. You never steer; the path takes you.
##
## The place gives `spots` (positions) and `looks` (yaw, pitch in degrees: yaw 0 is -Z, left is
## positive). While nobody touches it, the view drifts back to the spot's own look and breathes a little.

signal arrived(index: int)
signal left_spot(index: int)
signal step_taken

const DRAG_SPEED := 0.22
const YAW_RANGE := 80.0

var spots: Array[Vector3] = []
var looks: Array[Vector2] = []
## Points between spots to walk through (so a stroll follows the path), from spot i to i+1.
var routes: Array = []
var index := 0
var walking := false
var idle_drift := false

var _yaw := 0.0
var _pitch := 0.0
var _home := Vector2.ZERO
var _since_touch := 10.0
var _dragging := -1
var _walk_t := 0.0
var _walk_from := 0
var _walk_to := 0
var _walk_points: Array[Vector3] = []
var _walk_length := 1.0
var _step_at := 0.0
var _time := 0.0


func setup(spot_list: Array[Vector3], look_list: Array[Vector2], route_list: Array) -> void:
	spots = spot_list
	looks = look_list
	routes = route_list
	fov = 62.0
	near = 0.08
	far = 160.0
	go_to(0)


func go_to(i: int) -> void:
	index = i
	_home = looks[i]
	_yaw = _home.x
	_pitch = _home.y
	position = spots[i]
	_apply()


func can_go(step: int) -> bool:
	return not walking and index + step >= 0 and index + step < spots.size()


func stroll(step: int) -> void:
	if not can_go(step):
		return
	_walk_from = index
	_walk_to = index + step
	_walk_points = [spots[_walk_from]]
	var route: Array = routes[mini(_walk_from, _walk_to)]
	if step < 0:
		route = route.duplicate()
		route.reverse()
	for p in route:
		_walk_points.append(p)
	_walk_points.append(spots[_walk_to])
	_walk_length = 0.0
	for k in _walk_points.size() - 1:
		_walk_length += _walk_points[k].distance_to(_walk_points[k + 1])
	_walk_t = 0.0
	_step_at = 0.0
	walking = true
	left_spot.emit(_walk_from)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _dragging < 0:
			_dragging = event.index
		elif not event.pressed and event.index == _dragging:
			_dragging = -1
	elif event is InputEventScreenDrag and event.index == _dragging:
		var scale := 450.0 / maxf(get_viewport().get_visible_rect().size.x, 1.0)
		_yaw += event.relative.x * DRAG_SPEED * scale
		_pitch += event.relative.y * DRAG_SPEED * scale
		_since_touch = 0.0


func _process(delta: float) -> void:
	_time += delta
	_since_touch += delta
	var keys := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if keys != Vector2.ZERO:
		_yaw -= keys.x * 70.0 * delta
		_pitch -= keys.y * 50.0 * delta
		_since_touch = 0.0
	if walking:
		_walk(delta)
	elif _since_touch > 6.0:
		# drift back to the spot's own view, slowly
		var k := 1.0 - exp(-delta * 0.25)
		_yaw = lerpf(_yaw, _home.x, k)
		_pitch = lerpf(_pitch, _home.y, k)
	_yaw = clampf(_yaw, _home.x - YAW_RANGE, _home.x + YAW_RANGE) if not idle_drift else _yaw
	_pitch = clampf(_pitch, -30.0, 40.0)
	if idle_drift:
		_yaw = _home.x + sin(_time * 0.07) * 14.0
		_pitch = _home.y + sin(_time * 0.05) * 3.0
	_apply()


func _walk(delta: float) -> void:
	var speed := 1.25
	_walk_t += delta * speed / _walk_length
	var t := clampf(_walk_t, 0.0, 1.0)
	# ease in and out of the walk, along the route
	var e := t * t * (3.0 - 2.0 * t)
	var dist := e * _walk_length
	var at := _walk_points[0]
	var ahead := _walk_points[-1]
	var run := 0.0
	for k in _walk_points.size() - 1:
		var seg := _walk_points[k].distance_to(_walk_points[k + 1])
		if dist <= run + seg or k == _walk_points.size() - 2:
			var f := clampf((dist - run) / maxf(seg, 0.001), 0.0, 1.0)
			at = _walk_points[k].lerp(_walk_points[k + 1], f)
			ahead = _walk_points[mini(k + 2, _walk_points.size() - 1)] if f > 0.7 else _walk_points[k + 1]
			break
		run += seg
	# a gentle step in it
	var pace := dist / 0.75
	var bob := sin(pace * PI) * 0.035 * sin(t * PI)
	position = at + Vector3(0, absf(bob), 0)
	if floor(pace) > _step_at:
		_step_at = floor(pace)
		step_taken.emit()
	# look where you are going, then come round to the new spot's view at the end
	var dir := ahead - at
	var walk_yaw := rad_to_deg(atan2(-dir.x, -dir.z)) if dir.length() > 0.01 else _yaw
	var target: Vector2 = looks[_walk_to]
	var turn := smoothstep(0.6, 1.0, t)
	var k := 1.0 - exp(-delta * 3.0)
	_yaw = lerpf(_yaw, lerpf(_closest(walk_yaw, _yaw), _closest(target.x, _yaw), turn), k)
	_pitch = lerpf(_pitch, lerpf(-4.0, target.y, turn), k)
	if t >= 1.0:
		walking = false
		index = _walk_to
		_home = target
		_since_touch = 10.0
		arrived.emit(index)


func _closest(angle: float, to: float) -> float:
	return to + wrapf(angle - to, -180.0, 180.0)


func _apply() -> void:
	var breathe := sin(_time * 0.9) * 0.25 if not walking else 0.0
	rotation = Vector3(deg_to_rad(_pitch + breathe * 0.4), deg_to_rad(_yaw), 0.0)
