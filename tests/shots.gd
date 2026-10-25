extends SceneTree
## Saves pictures of Amberwood to check the look by eye:
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
	await _wait(1.0)
	var main = current_scene
	await _shot("00_booth")
	main._board()
	await _wait(3.0)
	await _shot("01_way_in")
	for i in range(1, 4):
		main.camera.go_to(i)
		await _wait(1.0)
		await _shot("%02d_spot" % (i + 1))
	main.camera.go_to(0)
	main.camera._yaw = 150.0
	main.camera._home = Vector2(150, 0)
	await _wait(1.0)
	await _shot("05_behind")
	main.camera.go_to(0)
	main.camera.stroll(1)
	await _wait(5.0)
	await _shot("06_walking")
	await _wait(30.0)
	print("arrived at ", main.camera.index, " walking ", main.camera.walking)
	await _shot("07_arrived")
	quit()
