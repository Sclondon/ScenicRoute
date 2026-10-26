extends SceneTree
## Saves pictures of Amberwood to check the look by eye: the view, then round to each side and behind.
##   godot --path . --audio-driver Dummy --resolution 450x800 -s tests/shots.gd -- --out=<folder>

var out := "user://shots"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	change_scene_to_file("res://scenes/main.tscn")
	_run.call_deferred()


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _shot(name: String) -> void:
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("shot ", name)


func _run() -> void:
	await _wait(3.5)
	var cam = current_scene.camera
	await _shot("00_view")
	var names := ["01_left", "02_behind", "03_right"]
	for i in 3:
		cam._yaw = 90.0 * (i + 1)
		cam._pitch = 0.0
		cam._since_touch = 0.0
		await _wait(0.5)
		await _shot(names[i])
	quit()
