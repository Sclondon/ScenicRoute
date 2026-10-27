extends SceneTree
## Makes the postcards: each place (scripts/places.gd) from its own view, saved as cards/<id>.jpg.
## Run with a landscape window, one place at a time (each opens on its own):
##   godot --path . --audio-driver Dummy --resolution 720x480 -s tests/cards.gd -- --place=<id>

const Places := preload("res://scripts/places.gd")


func _initialize() -> void:
	var want := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--place="):
			want = a.substr(8)
	load("res://scripts/main.gd").start_place = want
	change_scene_to_file("res://scenes/main.tscn")
	_run.call_deferred(want)


func _run(want: String) -> void:
	while current_scene == null or not current_scene.is_node_ready() or not current_scene.arrived():
		await process_frame
	var main = current_scene
	# no name over it, and the light settled
	await create_timer(3.0).timeout
	main.title.visible = false
	main.hint.visible = false
	main.back_card.visible = false
	main.paint.set_shader_parameter("grain", 0.0)
	await create_timer(5.0).timeout
	var img := root.get_texture().get_image()
	img.resize(600, 400, Image.INTERPOLATE_LANCZOS)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://cards"))
	img.save_jpg(ProjectSettings.globalize_path(Places.card_path(want)), 0.85)
	print("card ", want)
	quit()
