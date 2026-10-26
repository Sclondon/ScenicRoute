extends Node3D
## The creatures about Amberwood, all GameCommon's (installed with its kit.sh, as Warren has them):
## deer that come along the valley now and then, grazing as they go; rabbits and a hare out on the
## slope; a fox trotting the valley, stopping to listen and pounce; blue jays in the old oaks; frogs
## singing round the pond. Nothing here notices you: you are only looking.
##
## Made after the place is built (it reads `height` and the hero oaks' `perches` off its parent).

var land: Node3D
var rng := RandomNumberGenerator.new()

var _herd: Array = []  # [Deer, offset from the leader (along, across)]
var _herd_at := 0.0  # metres along the valley route
var _herd_wait := 0.0
var _herd_graze := 0.0
var _rabbits: Array = []  # [Rabbit, home Vector2, target Vector2, wait]
var _fox: Fox
var _fox_at := 0.0
var _fox_wait := 20.0
var _fox_stop := 0.0


func _ready() -> void:
	land = get_parent()
	rng.seed = 77
	_make_herd()
	_make_rabbits()
	_make_fox()
	_make_jays()
	_make_frogs()


# --- the valley route the deer and the fox follow: along the valley floor, the far side of the pond ---

func _route(at: float, across := 0.0) -> Vector3:
	var z := 40.0 - at
	# out past the pond, and round it
	var x: float = land.path_x(z) - 30.0 + 3.0 * sin(z * 0.05) - 11.0 * exp(-pow((z + 48.0) / 10.0, 2.0)) + across
	return Vector3(x, land.height(x, z), z)


func _place_on_route(n: Node3D, at: float, across: float) -> void:
	var p := _route(at, across)
	var ahead := _route(at + 0.5, across)
	n.position = p
	n.rotation.y = atan2(ahead.x - p.x, ahead.z - p.z)


func _make_herd() -> void:
	# a buck, two does and a fawn
	var who := [[Deer.Variant.BUCK, false, 1.0], [Deer.Variant.DOE, false, 0.95], [Deer.Variant.DOE, false, 0.9], [Deer.Variant.DOE, true, 0.6]]
	for i in who.size():
		var d := Deer.new()
		d.variant = who[i][0]
		d.fawn = who[i][1]
		d.low_poly = true
		d.sound = false
		d.scale = Vector3.ONE * who[i][2]
		add_child(d)
		_herd.append([d, Vector2(-i * 2.6 - rng.randf() * 1.5, rng.randf_range(-1.5, 1.5))])
	# the first lot is already on its way when you arrive
	_herd_at = 72.0


func _make_rabbits() -> void:
	for i in 4:
		var r := Rabbit.new()
		r.variant = Rabbit.Variant.HARE if i == 0 else Rabbit.Variant.RABBIT
		r.low_poly = true
		r.sound = false
		add_child(r)
		# out on the slope below the patch, where you can see them
		var z := rng.randf_range(-48.0, -42.0) if i < 2 else rng.randf_range(-18.0, -8.0)
		var home := Vector2(land.path_x(z) - rng.randf_range(5.0, 14.0), z)
		_rabbits.append([r, home, home, rng.randf_range(0.0, 4.0)])
		r.position = Vector3(home.x, land.height(home.x, home.y), home.y)
		r.rotation.y = rng.randf() * TAU


func _make_fox() -> void:
	_fox = Fox.new()
	_fox.variant = 0
	_fox.scale = Vector3.ONE * 0.72
	_fox.visible = false
	add_child(_fox)


func _make_jays() -> void:
	var perches: PackedVector3Array = land.perches
	if perches.is_empty():
		return
	var jays := BlueJays.new()
	jays.count = 5
	jays.flock_seed = 3
	jays.home = perches[0] - Vector3(0, 6, 0)
	add_child(jays)
	jays.set_perches(perches, PackedVector3Array(), false)
	jays.settle()
	jays.add_child(CorvidVoice.new(jays))


func _make_frogs() -> void:
	var frogs := PondFrogs.new()
	frogs.pool = false
	var pond: Vector2 = land.POND
	var size: Vector2 = land.POND_SIZE
	var level: float = land.pond_level()
	var banks: Array = []
	for i in 12:
		var a := TAU * i / 12.0 + rng.randf_range(-0.15, 0.15)
		var edge := pond + Vector2(cos(a) * size.x, sin(a) * size.y) * 1.02
		var water := pond + Vector2(cos(a) * size.x, sin(a) * size.y) * 0.8
		banks.append([Vector3(edge.x, maxf(land.height(edge.x, edge.y), level) + 0.02, edge.y), Vector3(water.x, level, water.y)])
	frogs.banks = banks
	frogs.count = banks.size()
	frogs.chorus = 0.45
	frogs.volume_db = -16.0
	add_child(frogs)


func _process(delta: float) -> void:
	_drive_herd(delta)
	_drive_rabbits(delta)
	_drive_fox(delta)


# The herd walks the valley, stopping to graze, the others following the leader; at the far end they go
# out of sight and come back along it a while later
func _drive_herd(delta: float) -> void:
	if _herd_wait > 0.0:
		_herd_wait -= delta
		if _herd_wait <= 0.0:
			_herd_at = -10.0
		for h in _herd:
			h[0].visible = false
		return
	if _herd_graze > 0.0:
		_herd_graze -= delta
	else:
		_herd_at += delta * 1.1
		if rng.randf() < delta * 0.05:
			_herd_graze = rng.randf_range(4.0, 10.0)
	var grazing := _herd_graze > 0.0
	for i in _herd.size():
		var d: Deer = _herd[i][0]
		var off: Vector2 = _herd[i][1]
		d.visible = true
		d.grazing = grazing and i != 0
		d.alert = grazing and i == 0
		_place_on_route(d, _herd_at + off.x, off.y)
	if _herd_at > 200.0:
		_herd_wait = rng.randf_range(40.0, 90.0)


# Rabbits sit and nibble, then hop a few metres, never far from home
func _drive_rabbits(delta: float) -> void:
	for r in _rabbits:
		var rabbit: Rabbit = r[0]
		var target: Vector2 = r[2]
		var at := Vector2(rabbit.position.x, rabbit.position.z)
		var to := target - at
		if to.length() > 0.05:
			var step := minf(to.length(), delta * 0.9)
			at += to.normalized() * step
			rabbit.position = Vector3(at.x, land.height(at.x, at.y), at.y)
			rabbit.rotation.y = atan2(to.x, to.y)
			rabbit.grazing = false
		else:
			r[3] -= delta
			rabbit.grazing = r[3] > 1.5
			rabbit.upright = r[3] <= 1.5 and r[3] > 0.0
			if r[3] <= 0.0:
				var home: Vector2 = r[1]
				r[2] = home + Vector2(rng.randf_range(-4, 4), rng.randf_range(-4, 4))
				r[3] = rng.randf_range(3.0, 9.0)


# The fox now and then trots along the valley, stops to listen, and pounces on something in the grass
func _drive_fox(delta: float) -> void:
	if _fox_wait > 0.0:
		_fox_wait -= delta
		_fox.visible = false
		if _fox_wait <= 0.0:
			_fox_at = 0.0
		return
	_fox.visible = true
	if _fox.pouncing():
		_fox.global_position += _fox.pounce_push() * delta
		_fox.position.y = land.height(_fox.position.x, _fox.position.z) + _fox.pounce_lift()
		return
	if _fox_stop > 0.0:
		_fox_stop -= delta
		_fox.listening = true
		if _fox_stop <= 0.0:
			_fox.listening = false
			var ahead := _route(_fox_at + 1.6, -6.0)
			_fox.pounce(ahead)
		return
	_fox_at += delta * 2.2
	_place_on_route(_fox, _fox_at, -6.0)
	if rng.randf() < delta * 0.06:
		_fox_stop = rng.randf_range(2.0, 4.0)
	if _fox_at > 200.0:
		_fox_wait = rng.randf_range(60.0, 140.0)
