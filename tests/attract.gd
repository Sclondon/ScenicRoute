extends SceneTree
## Plays the arcade preview: the wood coming up out of the dark, then a slow look round: the valley, the deer,
## into the wood and back out.
## Record it with Movie Maker, with an override.cfg setting the window to 960x540 (the project overrides the size):
##   godot --path . --audio-driver Dummy --fixed-fps 30 --write-movie out.avi -s tests/attract.gd


func _initialize() -> void:
	# straight into a place (amberwood, or --place=<id>), not the postcards
	load("res://scripts/main.gd").start_place = "amberwood"
	change_scene_to_file("res://scenes/main.tscn")
	_run.call_deferred()


func _pan(cam, from: Vector2, to: Vector2, seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		var k := smoothstep(0.0, 1.0, t / seconds)
		var v := from.lerp(to, k)
		cam._yaw = v.x
		cam._pitch = v.y
		cam._since_touch = 0.0
		t += 1.0 / 30.0
		await process_frame


func _run() -> void:
	while current_scene == null or not current_scene.is_node_ready() or current_scene.camera == null:
		await process_frame
	var main = current_scene
	var cam = main.camera
	# paper grain only costs bitrate in a small film
	main.paint.set_shader_parameter("grain", 0.0)
	await _pan(cam, Vector2(0, 8), Vector2(16, -3), 7.0)
	await _pan(cam, Vector2(16, -3), Vector2(60, -10), 6.0)
	await _pan(cam, Vector2(60, -10), Vector2(-50, 0), 9.0)
	await _pan(cam, Vector2(-50, 0), Vector2(14, -3), 6.0)
	quit()
