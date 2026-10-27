extends SceneTree
## Saves one picture from anywhere, for checking the layout by eye:
##   godot --path . --audio-driver Dummy --resolution 800x450 -s tests/cam.gd -- <out.png> x y z yaw pitch [wait] [--place=<id>]

func _initialize() -> void:
	# straight into a place (amberwood, or --place=<id>), not the postcards
	load("res://scripts/main.gd").start_place = "amberwood"
	change_scene_to_file("res://scenes/main.tscn")
	_run.call_deferred()


func _run() -> void:
	var a := Array(OS.get_cmdline_user_args()).filter(func(s: String) -> bool: return not s.begins_with("--"))
	while current_scene == null or not current_scene.is_node_ready() or not current_scene.arrived():
		await process_frame
	await create_timer(float(a[6]) if a.size() > 6 else 1.5).timeout
	var cam = current_scene.camera
	cam.set_process(false)
	cam.set_process_input(false)
	cam.position = Vector3(float(a[1]), float(a[2]), float(a[3]))
	cam.rotation = Vector3(deg_to_rad(float(a[5])), deg_to_rad(float(a[4])), 0)
	current_scene.title.visible = false
	current_scene.hint.visible = false
	await process_frame
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(a[0])
	quit()
