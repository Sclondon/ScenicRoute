extends Node
## Scenic Route: scenic places to stand in and look around. It opens on a spread of postcards, one for each
## place (scripts/places.gd); tap one and you are there, and drag to look about. The only thing on screen
## while you are there is a little postcard in the corner, to go back to the postcards.

const Places := preload("res://scripts/places.gd")
const Look := preload("res://scripts/look.gd")
const PAINT := preload("res://shaders/paint.gdshader")
const SERIF := preload("res://fonts/LibreBaskerville.ttf")
const ITALIC := preload("res://fonts/LibreBaskerville-Italic.ttf")

const CREAM := Color(1.0, 0.95, 0.85)
const INK := Color(0.16, 0.1, 0.06)
const PAPER := Color(0.93, 0.87, 0.74)
const GOLD := Color(0.95, 0.78, 0.45)

var place: Node3D
var place_info: Dictionary
var camera: Camera3D
var ambience: Node
var paint: ShaderMaterial
var title: Label
var hint: Label
var picker: Control
var cards: Array[Control] = []
var back_card: Control
var _grid: GridContainer
var _busy := false
var _hinted := false
var _words: Tween
var loading: Control
var _load_holder: Control
var _load_line: Control
var _load_t := 0.0
## How far along the line is drawn, and how far the building has got.
var _shown := 0.0
var _target := 0.0
## A place to open straight into, by id (tests set it before the scene starts).
static var start_place := ""


func _ready() -> void:
	_build_paint()
	_build_words()
	_build_picker()
	_build_back()
	_build_loading()
	get_viewport().size_changed.connect(_lay_out)
	_lay_out()
	# a single place opens straight into it, and a test can ask for one (`start_place`, or --place=<id>)
	var want := start_place
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--place="):
			want = a.substr(8)
	var open := Places.ready_places()
	for p in open:
		if p.id == want:
			go(p)
			return
	if open.size() == 1:
		go(open[0])


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
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _shadowed(l: Label) -> Label:
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_outline_size", 8)
	l.modulate.a = 0.0
	return l


func _build_words() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	title = _shadowed(_label("", ITALIC, 40, CREAM))
	title.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	title.anchor_left = 0.0
	title.anchor_right = 1.0
	title.offset_top = -230
	title.offset_bottom = -170
	layer.add_child(title)
	hint = _shadowed(_label("Drag to look around", ITALIC, 26, Color(CREAM, 0.85)))
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.anchor_left = 0.0
	hint.anchor_right = 1.0
	hint.offset_top = -160
	hint.offset_bottom = -120
	layer.add_child(hint)


# --- the postcards ---

func _build_picker() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 3
	add_child(layer)
	picker = ColorRect.new()
	picker.color = Color(0.09, 0.06, 0.04)
	picker.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(picker)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 24
	column.offset_right = -24
	column.offset_top = 40
	column.offset_bottom = -24
	column.add_theme_constant_override("separation", 18)
	picker.add_child(column)
	column.add_child(_label("S C E N I C   R O U T E", SERIF, 30, GOLD))
	column.add_child(_label("Where to?", ITALIC, 24, Color(CREAM, 0.75)))
	_grid = GridContainer.new()
	_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 18)
	_grid.add_theme_constant_override("v_separation", 18)
	column.add_child(_grid)
	for p in Places.ready_places():
		var card := _postcard(p)
		cards.append(card)
		_grid.add_child(card)


# A postcard: the place's picture with a white border, its name and a line about it on the card below
func _postcard(p: Dictionary) -> Control:
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(10)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 10
	card.add_theme_stylebox_override("panel", sb)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.set_meta("place", p)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(inner)
	var picture := TextureRect.new()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.size_flags_vertical = Control.SIZE_EXPAND_FILL
	picture.custom_minimum_size = Vector2(0, 90)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var path := Places.card_path(p.id)
	if ResourceLoader.exists(path):
		picture.texture = load(path)
	else:
		# no picture yet: the place's own colour
		var g := Gradient.new()
		g.set_color(0, p.tint.darkened(0.5))
		g.set_color(1, p.tint)
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill_to = Vector2(0, 1)
		picture.texture = gt
	inner.add_child(picture)
	inner.add_child(_label(p.name, SERIF, 24, INK))
	inner.add_child(_label(p.line, ITALIC, 17, Color(INK, 0.75)))
	card.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
			go(p))
	return card


func _lay_out() -> void:
	var size := get_viewport().get_visible_rect().size
	_grid.columns = 1 if size.x < size.y else 2
	if _load_holder:
		var w := minf(size.x - 80.0, 480.0)
		var h := minf(w * 0.92, size.y * 0.55)
		_load_holder.custom_minimum_size = Vector2(w, h)
		for card in _load_holder.get_children():
			card.size = Vector2(w, h)
			card.pivot_offset = Vector2(w, h) * 0.5


# --- going and coming back ---

## Go to a place (one of Places.PLACES): its postcard comes up while it is built, then lifts away on its view.
func go(p: Dictionary) -> void:
	if _busy:
		return
	_busy = true
	_open_loading(p)
	var tw := create_tween()
	tw.tween_property(loading, "modulate:a", 1.0, 0.35)
	await tw.finished
	picker.visible = false
	_leave_place()
	place_info = p
	place = load(p.script).new()
	if place.has_signal("progress"):
		place.progress.connect(func(f: float): _target = f)
	add_child(place)
	if "is_built" in place and not place.is_built:
		await place.built
	_target = 1.0
	camera = Look.new()
	place.add_child(camera)
	camera.setup(place.view_position(), place.get_script().VIEW.look)
	camera.make_current()
	# a few frames drawn behind the card (shaders are made the first time they are drawn), and the line run home
	for i in 3:
		await get_tree().process_frame
	while _shown < 0.999:
		await get_tree().process_frame
	if place.has_method("make_ambience"):
		ambience = place.make_ambience()
		add_child(ambience)
		ambience.start()
	back_card.visible = true
	title.text = p.name
	# the card lifts away, the place is named, then how to look about (the first time), then out of the way
	tw = create_tween()
	tw.tween_property(loading, "modulate:a", 0.0, 0.9)
	# free to leave once it is in view; the name comes and goes on its own
	tw.tween_callback(_loaded)
	tw.tween_property(title, "modulate:a", 1.0, 1.0)
	if not _hinted:
		tw.parallel().tween_property(hint, "modulate:a", 1.0, 1.0)
	tw.tween_interval(3.5)
	tw.tween_property(title, "modulate:a", 0.0, 1.8)
	tw.parallel().tween_property(hint, "modulate:a", 0.0, 1.8)
	_hinted = true
	_words = tw


## Back to the postcards.
func back() -> void:
	if _busy or place == null:
		return
	_busy = true
	var tw := create_tween()
	tw.tween_property(paint, "shader_parameter/fade", 1.0, 0.5)
	await tw.finished
	if _words and _words.is_valid():
		_words.kill()
	_leave_place()
	back_card.visible = false
	title.modulate.a = 0.0
	hint.modulate.a = 0.0
	picker.visible = true
	paint.set_shader_parameter("fade", 0.0)
	_busy = false


func _leave_place() -> void:
	if ambience:
		ambience.queue_free()
		ambience = null
	if place:
		place.queue_free()
		place = null
		camera = null


# The little postcard in the corner that takes you back
func _build_back() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	back_card = Control.new()
	back_card.position = Vector2(22, 22)
	back_card.size = Vector2(76, 56)
	back_card.visible = false
	back_card.modulate.a = 0.75
	back_card.draw.connect(func():
		var r := Rect2(Vector2(6, 8), Vector2(60, 40))
		back_card.draw_rect(Rect2(r.position + Vector2(3, 3), r.size), Color(0, 0, 0, 0.35))
		back_card.draw_rect(r, PAPER)
		back_card.draw_rect(Rect2(r.position + Vector2(4, 4), Vector2(30, 32)), Color(0.86, 0.5, 0.18, 0.85))
		back_card.draw_rect(Rect2(r.position + Vector2(44, 5), Vector2(11, 13)), Color(0.55, 0.3, 0.15))
		for k in 3:
			back_card.draw_line(r.position + Vector2(38, 23 + k * 6), r.position + Vector2(56, 23 + k * 6), Color(INK, 0.6), 1.5))
	back_card.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
			back())
	layer.add_child(back_card)


# --- the loading card: the place's postcard, and a line running from one station to the next as it is built ---

func _build_loading() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 4
	add_child(layer)
	loading = ColorRect.new()
	loading.color = Color(0.09, 0.06, 0.04)
	loading.set_anchors_preset(Control.PRESET_FULL_RECT)
	loading.visible = false
	layer.add_child(loading)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 26)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	loading.add_child(column)
	column.add_child(_label("Next stop", ITALIC, 26, Color(CREAM, 0.75)))
	_load_holder = Control.new()
	_load_holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_load_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_load_holder)
	_load_line = Control.new()
	_load_line.custom_minimum_size = Vector2(0, 40)
	_load_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_load_line.draw.connect(_draw_line)
	column.add_child(_load_line)


func _open_loading(p: Dictionary) -> void:
	for c in _load_holder.get_children():
		c.queue_free()
	var card := _postcard(p)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_load_holder.add_child(card)
	_shown = 0.0
	_target = 0.0
	loading.modulate.a = 0.0
	loading.visible = true
	_lay_out()


func _loaded() -> void:
	loading.visible = false
	_busy = false


func _draw_line() -> void:
	var w := minf(_load_line.size.x - 80.0, 420.0)
	var a := Vector2((_load_line.size.x - w) * 0.5, _load_line.size.y * 0.5)
	var b := a + Vector2(w, 0)
	var x := 0.0
	while x < w:
		_load_line.draw_line(a + Vector2(x, 0), a + Vector2(minf(x + 8.0, w), 0), Color(CREAM, 0.25), 2.0)
		x += 16.0
	var head := a.lerp(b, _shown)
	_load_line.draw_line(a, head, GOLD, 3.0)
	_load_line.draw_circle(a, 6.0, GOLD)
	_load_line.draw_circle(b, 6.0, Color(CREAM, 0.35))
	_load_line.draw_circle(head, 9.0, Color(GOLD, 0.3))
	_load_line.draw_circle(head, 5.0, CREAM)


func _process(delta: float) -> void:
	if not loading.visible:
		return
	_load_t += delta
	# building steps can take a while each: ease the line along rather than jump, and never back
	_shown = minf(move_toward(_shown, _target, delta * 1.2), 1.0)
	for card in _load_holder.get_children():
		# held to the holder's size (a new card grows tall until its words have wrapped)
		card.size = _load_holder.custom_minimum_size
		card.pivot_offset = card.size * 0.5
		card.rotation = sin(_load_t * 1.4) * 0.02
		card.position.y = sin(_load_t * 2.1) * 4.0
	_load_line.queue_redraw()


## There, and the loading card gone (for the tests).
func arrived() -> bool:
	return camera != null and not loading.visible
