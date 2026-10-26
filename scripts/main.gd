extends Node
## Scenic Route: the lounge car's ticket window, and the place it takes you.
## The place is always there behind the window, drifting, so you see where you are buying a ticket to;
## punch a ticket and the window lifts and you are standing in it.

const Amberwood := preload("res://scripts/amberwood/amberwood.gd")
const Stroll := preload("res://scripts/stroll.gd")
const Ambience := preload("res://scripts/ambience.gd")
const PAINT := preload("res://shaders/paint.gdshader")
const SERIF := preload("res://fonts/LibreBaskerville.ttf")
const ITALIC := preload("res://fonts/LibreBaskerville-Italic.ttf")

const PLACE := {"id": "amberwood", "name": "Amberwood", "fare": 10,
	"blurb": "An autumn wood at the golden hour. Leaves coming down, sun through the trees, a path to wander. Stay as long as you like."}

const INK := Color(0.16, 0.1, 0.06)
const PAPER := Color(0.93, 0.87, 0.74)
const GOLD := Color(0.95, 0.78, 0.45)
const CREAM := Color(1.0, 0.95, 0.85)

var place: Node3D
var camera: Camera3D
var ambience: Node
var paint: ShaderMaterial
var booth: Control
var ticket: Control
var punch_hole: Control
var hud: Control
var title: Label
var hint: Label
var back_button: Button
var on_button: Button
var go_button: Button
var leave_button: Button
var visiting := false


func _ready() -> void:
	place = Amberwood.new()
	add_child(place)
	camera = Stroll.new()
	place.add_child(camera)
	var spots: Array[Vector3] = []
	var looks: Array[Vector2] = []
	for i in Amberwood.SPOTS.size():
		spots.append(Amberwood.spot_position(i))
		looks.append(Amberwood.SPOTS[i].look)
	camera.setup(spots, looks, _routes(spots))
	camera.make_current()
	camera.idle_drift = true
	camera.arrived.connect(_arrived)
	camera.left_spot.connect(func(_i): _show_title(""))
	ambience = Ambience.new()
	add_child(ambience)
	camera.step_taken.connect(ambience.step)
	_build_paint()
	_build_hud()
	_build_booth()


# Between two spots the walk keeps to the middle of the path
func _routes(spots: Array[Vector3]) -> Array:
	var out: Array = []
	for i in spots.size() - 1:
		var pts: Array[Vector3] = []
		var a := spots[i]
		var b := spots[i + 1]
		var n := int(absf(b.z - a.z) / 2.0)
		for k in range(1, n):
			var z := lerpf(a.z, b.z, float(k) / n)
			var x := Amberwood.path_x(z)
			pts.append(Vector3(x, Amberwood.height(x, z) + 1.6, z))
		out.append(pts)
	return out


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


func _label(text: String, font: Font, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _button(text: String, size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", SERIF)
	b.add_theme_font_size_override("font_size", size)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.1, 0.06, 0.03, 0.55 if state != "pressed" else 0.75)
		sb.border_color = Color(GOLD, 0.6)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(40)
		sb.content_margin_left = 26
		sb.content_margin_right = 26
		if state == "focus":
			sb.draw_center = false
		b.add_theme_stylebox_override(state, sb)
	b.add_theme_color_override("font_color", CREAM)
	b.add_theme_color_override("font_hover_color", CREAM)
	b.add_theme_color_override("font_pressed_color", GOLD)
	b.add_theme_color_override("font_disabled_color", Color(CREAM, 0.3))
	b.custom_minimum_size = Vector2(0, 88)
	b.focus_mode = Control.FOCUS_NONE
	return b


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.modulate.a = 0.0
	hud.visible = false
	layer.add_child(hud)

	var leave := _button("Leave", 26)
	leave_button = leave
	leave.custom_minimum_size = Vector2(0, 70)
	leave.position = Vector2(24, 24)
	leave.pressed.connect(_leave)
	hud.add_child(leave)

	title = _label("", ITALIC, 34, CREAM)
	title.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	title.anchor_left = 0.0
	title.anchor_right = 1.0
	title.offset_top = -230
	title.offset_bottom = -170
	title.modulate.a = 0.0
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	title.add_theme_constant_override("shadow_offset_y", 2)
	title.add_theme_constant_override("shadow_outline_size", 8)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(title)

	hint = _label("Drag to look around", ITALIC, 26, Color(CREAM, 0.85))
	hint.set_anchors_preset(Control.PRESET_CENTER)
	hint.anchor_left = 0.0
	hint.anchor_right = 1.0
	hint.offset_top = -160
	hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	hint.add_theme_constant_override("shadow_outline_size", 8)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(hint)

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	row.offset_top = -136
	row.offset_bottom = -36
	row.offset_left = 24
	row.offset_right = -24
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(row)
	back_button = _button("‹  Back", 30)
	back_button.pressed.connect(func(): camera.stroll(-1); _refresh_buttons())
	row.add_child(back_button)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(gap)
	on_button = _button("On  ›", 30)
	on_button.pressed.connect(func(): camera.stroll(1); _refresh_buttons())
	row.add_child(on_button)


func _build_booth() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 3
	add_child(layer)
	booth = Control.new()
	booth.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(booth)
	var dim := ColorRect.new()
	dim.color = Color(0.06, 0.035, 0.015, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	booth.add_child(dim)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.custom_minimum_size = Vector2(600, 0)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.add_theme_constant_override("separation", 22)
	booth.add_child(column)

	var head := _label("S C E N I C   R O U T E", SERIF, 30, GOLD)
	column.add_child(head)
	column.add_child(_label("Lounges along the line from Wayside Station", ITALIC, 22, Color(CREAM, 0.8)))

	# the ticket itself: cream card stock, a name, the fare
	ticket = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER
	sb.set_corner_radius_all(10)
	sb.border_color = Color(0.55, 0.36, 0.18)
	sb.set_border_width_all(3)
	sb.content_margin_left = 34
	sb.content_margin_right = 34
	sb.content_margin_top = 26
	sb.content_margin_bottom = 30
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 18
	ticket.add_theme_stylebox_override("panel", sb)
	column.add_child(ticket)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 12)
	ticket.add_child(inner)
	inner.add_child(_label("ADMIT ONE", SERIF, 18, Color(0.55, 0.3, 0.12)))
	inner.add_child(_label(PLACE.name, SERIF, 54, INK))
	var blurb := _label(PLACE.blurb, ITALIC, 22, Color(INK, 0.85))
	inner.add_child(blurb)
	var rule := ColorRect.new()
	rule.color = Color(0.55, 0.36, 0.18, 0.5)
	rule.custom_minimum_size = Vector2(0, 2)
	inner.add_child(rule)
	inner.add_child(_label("Fare  %d tickets" % PLACE.fare, SERIF, 26, INK))
	punch_hole = Control.new()
	punch_hole.custom_minimum_size = Vector2(0, 0)
	punch_hole.draw.connect(func():
		punch_hole.draw_circle(Vector2.ZERO, 16.0, Color(0.06, 0.035, 0.015)))
	punch_hole.visible = false
	booth.add_child(punch_hole)

	var go := _button("Punch ticket", 32)
	go_button = go
	go.pressed.connect(_board)
	column.add_child(go)
	if Tickets.preview:
		column.add_child(_label("Rides are free while the line is being built.", ITALIC, 20, Color(CREAM, 0.6)))
	column.add_child(_label("More stops coming down the line.", ITALIC, 20, Color(CREAM, 0.45)))


func _board() -> void:
	if visiting or not Tickets.admit(PLACE.id, PLACE.fare):
		return
	visiting = true
	ambience.play("crunch0", -4.0, 2.2)
	# punch a hole in the corner of the ticket
	punch_hole.visible = true
	punch_hole.position = ticket.global_position + Vector2(ticket.size.x - 46, 46)
	punch_hole.queue_redraw()
	var tw := create_tween()
	tw.tween_interval(0.5)
	tw.tween_property(paint, "shader_parameter/fade", 1.0, 0.7)
	tw.tween_callback(func():
		booth.visible = false
		camera.idle_drift = false
		camera.go_to(0)
		ambience.start()
		hud.visible = true
		hint.modulate.a = 1.0
		_refresh_buttons())
	tw.tween_property(paint, "shader_parameter/fade", 0.0, 1.2)
	tw.parallel().tween_property(hud, "modulate:a", 1.0, 1.2)
	tw.tween_callback(func(): _show_title(Amberwood.SPOTS[0].name))
	tw.tween_interval(4.0)
	tw.tween_property(hint, "modulate:a", 0.0, 1.5)


func _leave() -> void:
	if not visiting:
		return
	var tw := create_tween()
	tw.tween_property(paint, "shader_parameter/fade", 1.0, 0.7)
	tw.parallel().tween_property(hud, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func():
		visiting = false
		hud.visible = false
		ambience.stop()
		punch_hole.visible = false
		camera.go_to(0)
		camera.idle_drift = true
		booth.visible = true)
	tw.tween_property(paint, "shader_parameter/fade", 0.0, 0.8)


func _arrived(i: int) -> void:
	_show_title(Amberwood.SPOTS[i].name)
	_refresh_buttons()


func _refresh_buttons() -> void:
	back_button.disabled = not camera.can_go(-1)
	on_button.disabled = not camera.can_go(1)
	back_button.modulate.a = 0.0 if camera.index == 0 and not camera.walking else 1.0
	on_button.modulate.a = 0.0 if camera.index == Amberwood.SPOTS.size() - 1 and not camera.walking else 1.0


func _show_title(text: String) -> void:
	var tw := create_tween()
	if text == "":
		tw.tween_property(title, "modulate:a", 0.0, 0.6)
		return
	title.text = text
	tw.tween_property(title, "modulate:a", 1.0, 1.2)
	tw.tween_interval(3.5)
	tw.tween_property(title, "modulate:a", 0.0, 2.0)
