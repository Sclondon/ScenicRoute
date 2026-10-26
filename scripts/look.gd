extends Camera3D
## Your eyes in the place: you stand in one spot and drag to look about (or the arrow keys).
## While nobody touches it, the view drifts back to the place's own view and breathes a little.
##
## `home` is (yaw, pitch) in degrees: yaw 0 is -Z, left is positive.

const DRAG_SPEED := 0.22

var home := Vector2.ZERO

var _yaw := 0.0
var _pitch := 0.0
var _since_touch := 10.0
var _dragging := -1
var _time := 0.0


func setup(at: Vector3, look: Vector2) -> void:
	fov = 62.0
	near = 0.08
	far = 700.0
	position = at
	home = look
	_yaw = look.x
	_pitch = look.y
	_apply()


# In _input, so no Control takes the touch first. Some phones never send the finger going down,
# so a drag from a finger we have not seen takes up that finger.
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _dragging < 0:
			_dragging = event.index
		elif not event.pressed and event.index == _dragging:
			_dragging = -1
	elif event is InputEventScreenDrag:
		if _dragging < 0:
			_dragging = event.index
		if event.index != _dragging:
			return
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
	if _since_touch > 8.0:
		# drift back to the place's own view, slowly, the short way round
		var k := 1.0 - exp(-delta * 0.25)
		_yaw = lerpf(_yaw, _yaw + wrapf(home.x - _yaw, -180.0, 180.0), k)
		_pitch = lerpf(_pitch, home.y, k)
	_yaw = wrapf(_yaw, -180.0, 180.0)
	_pitch = clampf(_pitch, -30.0, 40.0)
	_apply()


func _apply() -> void:
	var breathe := sin(_time * 0.9) * 0.25
	rotation = Vector3(deg_to_rad(_pitch + breathe * 0.4), deg_to_rad(_yaw), 0.0)
