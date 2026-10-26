extends Node
## Scenic Route: one scenic place you stand in and look around. No buttons, no walking: drag to look.

const Amberwood := preload("res://scripts/amberwood/amberwood.gd")
const Look := preload("res://scripts/look.gd")
const Ambience := preload("res://scripts/ambience.gd")
const PAINT := preload("res://shaders/paint.gdshader")
const ITALIC := preload("res://fonts/LibreBaskerville-Italic.ttf")

const CREAM := Color(1.0, 0.95, 0.85)

var place: Node3D
var camera: Camera3D
var ambience: Node
var paint: ShaderMaterial
var title: Label
var hint: Label


func _ready() -> void:
	place = Amberwood.new()
	add_child(place)
	camera = Look.new()
	place.add_child(camera)
	camera.setup(Amberwood.view_position(), Amberwood.VIEW.look)
	camera.make_current()
	ambience = Ambience.new()
	add_child(ambience)
	_build_paint()
	_build_words()
	ambience.start()
	# come up out of the dark, name the place, then say how to look about and get out of the way
	paint.set_shader_parameter("fade", 1.0)
	var tw := create_tween()
	tw.tween_property(paint, "shader_parameter/fade", 0.0, 2.0)
	tw.tween_property(title, "modulate:a", 1.0, 1.2)
	tw.parallel().tween_property(hint, "modulate:a", 1.0, 1.2)
	tw.tween_interval(4.0)
	tw.tween_property(title, "modulate:a", 0.0, 2.0)
	tw.parallel().tween_property(hint, "modulate:a", 0.0, 2.0)


func _build_paint() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paint = ShaderMaterial.new()
	paint.shader = PAINT
	paint.set_shader_parameter("fade", 0.0)
	rect.material = paint
	layer.add_child(rect)


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", ITALIC)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_outline_size", 8)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.modulate.a = 0.0
	return l


func _build_words() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	title = _label("Amberwood", 40, CREAM)
	title.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	title.anchor_left = 0.0
	title.anchor_right = 1.0
	title.offset_top = -230
	title.offset_bottom = -170
	layer.add_child(title)
	hint = _label("Drag to look around", 26, Color(CREAM, 0.85))
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.anchor_left = 0.0
	hint.anchor_right = 1.0
	hint.offset_top = -160
	hint.offset_bottom = -120
	layer.add_child(hint)
