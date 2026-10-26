extends SceneTree
## The postcards, and going to each place and back by tapping (simulated touches). Ends PASSED or FAILED.
##   godot --path . --audio-driver Dummy --resolution 450x800 -s tests/picker.gd -- [--out=<folder>]

var failures: Array[String] = []
var out := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	change_scene_to_file("res://scenes/main.tscn")
	_run.call_deferred()


func _tap(c: Control) -> void:
	var p := root.get_final_transform() * c.get_global_rect().get_center()
	for pressed in [true, false]:
		var e := InputEventScreenTouch.new()
		e.position = p
		e.pressed = pressed
		Input.parse_input_event(e)
		await process_frame


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		failures.append(what)


func _run() -> void:
	await create_timer(1.0).timeout
	var main = current_scene
	_check(main.picker.visible and main.cards.size() == 4, "four postcards to choose from")
	if out != "":
		root.get_texture().get_image().save_png(out + "/picker.png")
	for i in main.cards.size():
		var id: String = main.cards[i].get_meta("place").id
		await _tap(main.cards[i])
		await create_timer(4.0).timeout
		_check(main.place != null and main.place_info.id == id and not main.picker.visible, "tapping a card goes to " + id)
		await _tap(main.back_card)
		await create_timer(1.5).timeout
		_check(main.picker.visible and main.place == null, "the corner postcard comes back from " + id)
	print("PASSED" if failures.is_empty() else "FAILED: %s" % ", ".join(failures))
	quit(0 if failures.is_empty() else 1)
