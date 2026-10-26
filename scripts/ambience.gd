extends Node
## The sound of a wood in autumn, all made at start-up (no audio files): wind coming and going in the
## tops, dry leaves hissing when it gusts, a woodpecker far off (the birds are the jays in the oaks: GameCommon's).
##
## The beds are baked once with their gusts in them and loop seamlessly, and are left alone while they
## play: changing a player's volume every frame stutters in the web build.

const RATE := 22050
const BED_SECONDS := 24

var wind: AudioStreamPlayer
var rustle: AudioStreamPlayer
var players: Array[AudioStreamPlayer] = []
var sounds := {}
var _next := 0
var _pecker_in := 25.0


func _ready() -> void:
	var gust := _gust()
	wind = _bed(_wind_loop(gust), -6.0)
	rustle = _bed(_rustle_loop(gust), -14.0)
	sounds["peck"] = _pecks()
	for i in 3:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)


func start() -> void:
	if not wind.playing:
		wind.play()
		rustle.play()


func play(sound: String, volume_db := 0.0, pitch := 1.0) -> void:
	var p := players[_next]
	_next = (_next + 1) % players.size()
	p.stream = sounds[sound]
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


func _process(delta: float) -> void:
	if not wind.playing:
		return
	_pecker_in -= delta
	if _pecker_in <= 0.0:
		_pecker_in = randf_range(30.0, 70.0)
		play("peck", -18.0, randf_range(0.9, 1.1))


func _bed(stream: AudioStreamWAV, volume_db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = volume_db
	add_child(p)
	return p


# How hard the wind blows over the loop, 0..1: slow swells that come round again at the loop's end,
# with a smooth wander on top
func _gust() -> PackedFloat32Array:
	var n := RATE * BED_SECONDS
	var g := PackedFloat32Array()
	g.resize(n)
	var knots := PackedFloat32Array()
	var step := 2.0
	var count := int(BED_SECONDS / step)
	for k in count:
		knots.append(randf())
	for i in n:
		var t := float(i) / RATE
		var u := t / BED_SECONDS
		var slow := 0.5 + 0.3 * sin(TAU * u * 2.0) + 0.2 * sin(TAU * u * 3.0 + 1.3)
		var kf := t / step
		var a := knots[int(kf) % count]
		var b := knots[(int(kf) + 1) % count]
		var f := kf - floorf(kf)
		var wander := lerpf(a, b, f * f * (3.0 - 2.0 * f))
		g[i] = clampf(slow * 0.7 + wander * 0.3, 0.0, 1.0)
	return g


# Wind: brown noise, low-passed again, swelling with the gusts
func _wind_loop(gust: PackedFloat32Array) -> AudioStreamWAV:
	var n := gust.size() + RATE
	var s := PackedFloat32Array()
	s.resize(n)
	var brown := 0.0
	var lp := 0.0
	for i in n:
		brown = brown * 0.998 + randf_range(-1.0, 1.0) * 0.02
		lp += (brown - lp) * 0.06
		s[i] = lp * (0.35 + 0.65 * gust[i % gust.size()])
	return _loop(_normal(s, 0.7))


# Dry leaves: noise kept to the hiss band, rising and falling smoothly with the gusts
func _rustle_loop(gust: PackedFloat32Array) -> AudioStreamWAV:
	var n := gust.size() + RATE
	var s := PackedFloat32Array()
	s.resize(n)
	var prev := 0.0
	var lp := 0.0
	var flutter := 0.0
	var flutter_to := 0.0
	for i in n:
		var w := randf_range(-1.0, 1.0)
		var hp := w - prev
		prev = w
		lp += (hp - lp) * 0.5
		# the leaves catch in little flurries, eased, never switched
		if i % 2205 == 0:
			flutter_to = randf()
		flutter += (flutter_to - flutter) * 0.0004
		var g := gust[i % gust.size()]
		s[i] = lp * g * g * (0.5 + 0.5 * flutter)
	return _loop(_normal(s, 0.6))


# A woodpecker far off: a quick drumroll that slows
func _pecks() -> AudioStreamWAV:
	var s := PackedFloat32Array()
	var gap := 0.045
	for k in 14:
		var n := int(0.02 * RATE)
		for i in n:
			var u := float(i) / n
			s.append((sin(TAU * 900.0 * i / RATE) * 0.5 + randf_range(-0.5, 0.5)) * (1.0 - u) * 0.6)
		for i in int(gap * RATE):
			s.append(0.0)
		gap *= 1.06
	return _wav(s)


func _normal(s: PackedFloat32Array, peak: float) -> PackedFloat32Array:
	var top := 0.0001
	for v in s:
		top = maxf(top, absf(v))
	var k := peak / top
	for i in s.size():
		s[i] *= k
	return s


# The bed is a second longer than the loop: crossfade that second into the start, so the loop has no seam
func _loop(s: PackedFloat32Array) -> AudioStreamWAV:
	var fade := RATE
	var n := s.size() - fade
	var out := s.slice(0, n)
	for i in fade:
		var u := float(i) / fade
		out[i] = s[i] * sqrt(u) + s[n + i] * sqrt(1.0 - u)
	var wav := _wav(out)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = n
	return wav


func _wav(s: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(s.size() * 2)
	for i in s.size():
		data.encode_s16(i * 2, int(clampf(s[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav
