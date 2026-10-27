extends SceneTree
## Plays the arcade preview: the postcards, then each place in turn (a card tapped, the place fading in, a slow
## look round), and back to the postcards. Record it with Movie Maker, with an override.cfg setting the window to
## 960x540 (the project overrides the size):
##   godot --path . --audio-driver Dummy --fixed-fps 30 --write-movie out.avi -s tests/attract.gd

## Each place: the pans (yaw, pitch from and to), seconds each.
const TOUR := [
	["amberwood", [[Vector2(0, 8), Vector2(16, -3)], [Vector2(16, -3), Vector2(55, -6)]]],
	["plumeria", [[Vector2(-20, 6), Vector2(3, -2)], [Vector2(3, -2), Vector2(30, -4)]]],
	["velvet_moth", [[Vector2(-25, -10), Vector2(0, -18)], [Vector2(0, -18), Vector2(30, -12)]]],
	["caffe_del_porto", [[Vector2(-30, -2), Vector2(0, -6)], [Vector2(0, -6), Vector2(35, -4)]]],
]


func _initialize() -> void:
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
	while current_scene == null or not current_scene.is_node_ready():
		await process_frame
	var main = current_scene
	# paper grain only costs bitrate in a small film
	main.paint.set_shader_parameter("grain", 0.0)
	await create_timer(2.0).timeout
	for stop in TOUR:
		var card: Control = null
		for c in main.cards:
			if c.get_meta("place").id == stop[0]:
				card = c
		main.go(card.get_meta("place"))
		while not main.arrived():
			await process_frame
		var cam = main.camera
		cam.set_process_input(false)
		main.back_card.visible = false
		await _pan(cam, stop[1][0][0], stop[1][0][0], 1.4)
		for pan in stop[1]:
			await _pan(cam, pan[0], pan[1], 3.0)
		main.back()
		await create_timer(1.2).timeout
	await create_timer(1.0).timeout
	quit()
