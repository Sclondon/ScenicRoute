extends SceneTree
## Plays it with simulated touches, as a phone would: you are in the wood at once, with no buttons,
## and a drag looks about. Ends PASSED or FAILED.
##   godot --path . --audio-driver Dummy --resolution 450x800 -s tests/smoke.gd

var failures: Array[String] = []


func _initialize() -> void:
	# straight into a place (amberwood, or --place=<id>), not the postcards
	load("res://scripts/main.gd").start_place = "amberwood"
	change_scene_to_file("res://scenes/main.tscn")
	_run.call_deferred()


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		failures.append(what)


# touches arrive in window pixels: map from the game's view first
func _window(p: Vector2) -> Vector2:
	return root.get_final_transform() * p


func _touch(p: Vector2, pressed: bool, index := 0) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = _window(p)
	e.pressed = pressed
	Input.parse_input_event(e)


func _drag(from: Vector2, by: Vector2, index := 0, with_press := true) -> void:
	if with_press:
		_touch(from, true, index)
	var steps := 10
	for i in steps:
		var e := InputEventScreenDrag.new()
		e.index = index
		e.position = _window(from + by * float(i + 1) / steps)
		e.relative = root.get_final_transform().basis_xform(by / steps)
		Input.parse_input_event(e)
		await process_frame
	_touch(from + by, false, index)
	await process_frame


func _run() -> void:
	await _wait(0.5)
	var main = current_scene
	_check(main.loading.visible, "the postcard shows while the place is built")
	while not main.arrived():
		await process_frame
	var cam = main.camera
	_check(main.find_children("*", "BaseButton", true, false).is_empty(), "there are no buttons")
	var at: Vector3 = cam.position
	var yaw: float = cam._yaw
	await _drag(Vector2(360, 600), Vector2(-200, 0))
	_check(absf(cam._yaw - yaw) > 10.0, "a drag turns the view (%.1f -> %.1f)" % [yaw, cam._yaw])
	# a phone that loses the finger going down: the drag alone must still turn it
	yaw = cam._yaw
	await _drag(Vector2(360, 600), Vector2(200, 0), 77, false)
	_check(absf(cam._yaw - yaw) > 10.0, "a drag with no press still turns the view")
	# all the way round
	for i in 6:
		await _drag(Vector2(400, 400), Vector2(-300, 0))
	_check(cam.position == at, "you stay where you stand")
	print("PASSED" if failures.is_empty() else "FAILED: %s" % ", ".join(failures))
	quit(0 if failures.is_empty() else 1)
