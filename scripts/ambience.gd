extends Node
## The sound of a wood in autumn, all made at start-up (no audio files): wind coming and going in the
## tops, dry leaves hissing when it gusts, small birds now and then, a woodpecker far off, and leaves
## crunching underfoot as you walk. Looped beds are baked once and crossfaded so their loops don't show.

const RATE := 22050

var wind: AudioStreamPlayer
var rustle: AudioStreamPlayer
var players: Array[AudioStreamPlayer] = []
var sounds := {}
var _next := 0
var _bird_in := 3.0
var _pecker_in := 25.0
var _time := 0.0


func _ready() -> void:
	wind = _bed(_wind_loop(), -8.0)
	rustle = _bed(_rustle_loop(), -16.0)
	for i in 3:
		sounds["bird%d" % i] = _birdsong(i)
	sounds["peck"] = _pecks()
	for i in 4:
		sounds["crunch%d" % i] = _crunch()
	for i in 5:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)


func start() -> void:
	if not wind.playing:
		wind.play()
		rustle.play()


func stop() -> void:
	wind.stop()
	rustle.stop()


func play(sound: String, volume_db := 0.0, pitch := 1.0) -> void:
	var p := players[_next]
	_next = (_next + 1) % players.size()
	p.stream = sounds[sound]
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


func step() -> void:
	play("crunch%d" % randi_range(0, 3), -10.0, randf_range(0.85, 1.15))


func _process(delta: float) -> void:
	if not wind.playing:
		return
	_time += delta
	# gusts: the leaves hiss louder as the wind swells
	var gust := 0.5 + 0.5 * sin(_time * 0.21) * sin(_time * 0.13 + 1.0)
	rustle.volume_db = lerpf(-24.0, -12.0, gust)
	_bird_in -= delta
	if _bird_in <= 0.0:
		_bird_in = randf_range(5.0, 16.0)
		play("bird%d" % randi_range(0, 2), randf_range(-20.0, -12.0), randf_range(0.9, 1.15))
	_pecker_in -= delta
	if _pecker_in <= 0.0:
		_pecker_in = randf_range(30.0, 70.0)
		play("peck", -17.0, randf_range(0.9, 1.1))


func _bed(stream: AudioStreamWAV, volume_db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = volume_db
	add_child(p)
	return p


# Wind: brown noise, low-passed again, swelling slowly; 16 s that loops
func _wind_loop() -> AudioStreamWAV:
	var n := RATE * 16
	var s := PackedFloat32Array()
	s.resize(n)
	var brown := 0.0
	var lp := 0.0
	for i in n:
		brown = clampf(brown + randf_range(-1.0, 1.0) * 0.04, -1.0, 1.0) * 0.998
		lp += (brown - lp) * 0.08
		var t := float(i) / RATE
		var swell := 0.55 + 0.45 * sin(TAU * t / 16.0 * 2.0) * sin(TAU * t / 16.0 + 0.6)
		s[i] = lp * swell * 2.2
	return _loop(s)


# Dry leaves: high noise in fluttering bursts; 9 s that loops
func _rustle_loop() -> AudioStreamWAV:
	var n := RATE * 9
	var s := PackedFloat32Array()
	s.resize(n)
	var prev := 0.0
	var flutter := 0.0
	for i in n:
		var w := randf_range(-1.0, 1.0)
		var hp := w - prev
		prev = w
		if i % 400 == 0:
			flutter = clampf(flutter + randf_range(-0.35, 0.35), 0.0, 1.0)
		s[i] = hp * 0.25 * (0.3 + flutter)
	return _loop(s)


# A small bird: a few quick chirps sliding up or down
func _birdsong(kind: int) -> AudioStreamWAV:
	var notes: Array = [[3200.0, 4200.0], [4100.0, 2900.0], [3600.0, 3900.0]][kind]
	var count: int = [3, 2, 5][kind]
	var s := PackedFloat32Array()
	var phase := 0.0
	for c in count:
		var dur := 0.09 if kind != 2 else 0.05
		var n := int(dur * RATE)
		for i in n:
			var u := float(i) / n
			var f := lerpf(notes[0], notes[1], u) * (1.0 + 0.04 * sin(u * 40.0))
			phase += TAU * f / RATE
			var env := sin(u * PI)
			s.append(sin(phase) * env * 0.5)
		for i in int(0.06 * RATE):
			s.append(0.0)
	return _wav(s)


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


# A footstep in dry leaves: a crackle of short clicks over a soft hush
func _crunch() -> AudioStreamWAV:
	var n := int(0.22 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var prev := 0.0
	for i in n:
		var u := float(i) / n
		var w := randf_range(-1.0, 1.0)
		var hp := w - prev * 0.6
		prev = w
		var crackle := 1.0 if randf() < 0.04 * (1.0 - u) else 0.25
		var env := minf(u / 0.05, 1.0) * pow(1.0 - u, 2.0)
		s[i] = hp * crackle * env * 0.55
	return _wav(s)


# Crossfade the last second into the first, so the loop has no seam
func _loop(s: PackedFloat32Array) -> AudioStreamWAV:
	var fade := RATE
	var n := s.size() - fade
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = s[i]
	for i in fade:
		var u := float(i) / fade
		out[i] = s[i] * u + s[n + i] * (1.0 - u)
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
