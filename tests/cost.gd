extends SceneTree
## How heavy the place is: start-up time, and triangles and draw calls from the view and round about.
##   godot --path . --audio-driver Dummy --resolution 450x800 -s tests/cost.gd

func _initialize() -> void:
	var t0 := Time.get_ticks_msec()
	# straight into a place (amberwood, or --place=<id>), not the postcards
	load("res://scripts/main.gd").start_place = "amberwood"
	change_scene_to_file("res://scenes/main.tscn")
	_run.call_deferred(t0)


func _run(t0: int) -> void:
	while current_scene == null or not current_scene.is_node_ready() or current_scene.camera == null:
		await process_frame
	print("built in %d ms (with the fade in)" % (Time.get_ticks_msec() - t0))
	await create_timer(3.0).timeout
	var cam = current_scene.camera
	for yaw in [38.0, 120.0, 200.0, -60.0]:
		cam._yaw = yaw
		cam._since_touch = 0.0
		await create_timer(0.5).timeout
		var tris := Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		var draws := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		print("yaw %4d: %6.0fk triangles, %4d draws, %3d fps" % [yaw, tris / 1000.0, draws, Engine.get_frames_per_second()])
	quit()
