extends SceneTree
## Plays it with simulated touches, as a phone would: punch the ticket, drag to look about, stroll on,
## and leave. Ends PASSED or FAILED.
##   godot --path . --audio-driver Dummy --resolution 450x800 -s tests/smoke.gd

var failures: Array[String] = []


func _initialize() -> void:
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


func _tap(control: Control) -> void:
	var p := control.get_global_rect().get_center()
	_touch(p, true)
	await process_frame
	_touch(p, false)
	await process_frame


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
	await _wait(0.8)
	var main = current_scene
	var cam = main.camera
	_check(main.booth.visible, "starts at the ticket window")
	await _tap(main.go_button)
	await _wait(2.5)
	_check(main.visiting and not main.booth.visible, "punching the ticket lets you in")
	var yaw: float = cam._yaw
	await _drag(Vector2(360, 600), Vector2(-200, 0))
	_check(absf(cam._yaw - yaw) > 10.0, "a drag turns the view (%.1f -> %.1f)" % [yaw, cam._yaw])
	# a phone that loses the finger going down: the drag alone must still turn it
	yaw = cam._yaw
	await _drag(Vector2(360, 600), Vector2(200, 0), 77, false)
	_check(absf(cam._yaw - yaw) > 10.0, "a drag with no press still turns the view")
	await _tap(main.on_button)
	await _wait(0.5)
	_check(cam.walking, "On strolls along the path")
	var t := 0.0
	while cam.walking and t < 40.0:
		await _wait(0.5)
		t += 0.5
	_check(cam.index == 1, "arrives at the fallen log")
	await _tap(main.leave_button)
	await _wait(2.0)
	_check(main.booth.visible and not main.visiting, "Leave goes back to the window")
	print("PASSED" if failures.is_empty() else "FAILED: %s" % ", ".join(failures))
	quit(0 if failures.is_empty() else 1)
