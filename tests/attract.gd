extends SceneTree
## Plays the arcade preview: the ticket punched, then a slow look round three spots in the wood.
## Record it with Movie Maker, with an override.cfg setting the window to 960x540 (the project overrides the size):
##   godot --path . --audio-driver Dummy --fixed-fps 30 --write-movie out.avi -s tests/attract.gd


func _initialize() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	_run.call_deferred()


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _pan(cam, from: Vector2, to: Vector2, seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		var k := smoothstep(0.0, 1.0, t / seconds)
		cam._home = from.lerp(to, k)
		cam._yaw = cam._home.x
		cam._pitch = cam._home.y
		t += 1.0 / 30.0
		await process_frame


func _cut(main, spot: int) -> void:
	var tw = main.create_tween()
	tw.tween_property(main.paint, "shader_parameter/fade", 1.0, 0.5)
	await tw.finished
	main.camera.go_to(spot)
	tw = main.create_tween()
	tw.tween_property(main.paint, "shader_parameter/fade", 0.0, 0.6)


func _run() -> void:
	while current_scene == null or not current_scene.is_node_ready():
		await process_frame
	var main = current_scene
	var cam = main.camera
	# paper grain only costs bitrate in a small film
	main.paint.set_shader_parameter("grain", 0.0)
	await _wait(2.5)
	main._board()
	await _wait(0.75)
	main.hud.visible = false
	main.hud.modulate.a = 0.0
	await _wait(0.6)
	main.hud.visible = false
	await _pan(cam, Vector2(-12, 14), Vector2(10, 0), 6.5)
	await _cut(main, 2)
	await _pan(cam, Vector2(75, -10), Vector2(35, -4), 6.0)
	await _cut(main, 3)
	await _pan(cam, Vector2(14, 2), Vector2(-8, 12), 6.5)
	quit()
