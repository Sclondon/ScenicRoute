extends Node
## The sound of the Caffè del Porto, all made in code (no audio files), after scripts/ambience.gd: the sea
## lapping at the quay, a soft breeze, people talking at the tables (a murmur, never words), and now and
## then a cup set down on its saucer, the church bell tolling over the harbour, a boat's engine puttering
## by far off.
##
## The beds are baked with their swells and laps in them and loop seamlessly, and are left alone while
## they play (changing a player's volume every frame stutters in the web build). Baking takes a few
## seconds of work, so it is done a slice each frame (the web build has no threads), the sea first.

const RATE := 22050
const LOW_RATE := 11025
const BED_SECONDS := 20
## How long to bake for each frame, in microseconds.
const SLICE_USEC := 4000

var beds: Array[AudioStreamPlayer] = []
var players: Array[AudioStreamPlayer] = []
var sounds := {}
var _next := 0
var _started := false
var _ready_shots := false
var _clink_in := 6.0
var _bell_in := 22.0
var _tolls := 0
var _toll_in := 0.0
var _motor_in := 50.0
var _work := 0
var _slice_start := 0
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.seed = 2718
	for i in 5:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)


func start() -> void:
	if _started:
		return
	_started = true
	_slice_start = Time.get_ticks_usec()
	_bake()


## Whether this frame's slice of baking is used up (looked at every 256 steps).
func _yield_now() -> bool:
	_work += 1
	if _work & 255 != 0:
		return false
	return Time.get_ticks_usec() - _slice_start > SLICE_USEC


func _pause() -> void:
	await get_tree().process_frame
	_slice_start = Time.get_ticks_usec()


func _bake() -> void:
	_bed(await _sea(), -7.0)
	_bed(await _breeze(), -17.0)
	_bed(await _chatter(), -21.0)
	sounds["clink"] = await _clink(false)
	sounds["clink2"] = await _clink(true)
	sounds["bell"] = await _bell()
	sounds["motor"] = await _motor()
	_ready_shots = true


func _bed(stream: AudioStreamWAV, volume_db: float) -> void:
	if not is_inside_tree():
		return
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = volume_db
	add_child(p)
	p.play()
	beds.append(p)


func play(sound: String, volume_db := 0.0, pitch := 1.0) -> void:
	var p := players[_next]
	_next = (_next + 1) % players.size()
	p.stream = sounds[sound]
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


func _process(delta: float) -> void:
	if not _ready_shots:
		return
	_clink_in -= delta
	if _clink_in <= 0.0:
		_clink_in = rng.randf_range(5.0, 16.0)
		play("clink2" if rng.randf() < 0.4 else "clink", rng.randf_range(-27.0, -22.0), rng.randf_range(0.9, 1.1))
	# the bell: a few strokes, some way apart, now and then
	_bell_in -= delta
	if _bell_in <= 0.0:
		_bell_in = rng.randf_range(110.0, 190.0)
		_tolls = rng.randi_range(3, 6)
		_toll_in = 0.0
	if _tolls > 0:
		_toll_in -= delta
		if _toll_in <= 0.0:
			_toll_in = 2.6
			_tolls -= 1
			play("bell", -13.0, 1.0)
	_motor_in -= delta
	if _motor_in <= 0.0:
		_motor_in = rng.randf_range(80.0, 150.0)
		play("motor", -19.0, rng.randf_range(0.92, 1.08))


# --- the beds ---

# The sea at the quay's foot: a soft wash rising and falling with the swell, and laps against the
# stones, each a slap of water softly filtered and a gurgle as it drains back
func _sea() -> AudioStreamWAV:
	var n := RATE * BED_SECONDS + RATE
	var s := PackedFloat32Array()
	s.resize(n)
	# when the laps come: every couple of seconds, more in each swell
	var laps: Array = []
	var t := 0.3
	while t < BED_SECONDS + 1.0:
		laps.append([t, rng.randf_range(0.4, 1.0), rng.randf_range(0.35, 0.9)])
		t += rng.randf_range(1.4, 3.6)
	var lp1 := 0.0
	var lp2 := 0.0
	var lp3 := 0.0
	var hp := 0.0
	var brown := 0.0
	var env := PackedFloat32Array()
	env.resize(n)
	var gurgle := PackedFloat32Array()
	gurgle.resize(n)
	for lap in laps:
		var i0 := int(lap[0] * RATE)
		var amp: float = lap[1]
		var len: float = lap[2]
		for k in int(RATE * 2.2):
			var i := i0 + k
			if i >= n:
				break
			var u := float(k) / RATE
			env[i] += amp * (1.0 - exp(-u / 0.06)) * exp(-u / (0.25 * len))
			gurgle[i] += amp * smoothstep(0.15, 0.5, u) * exp(-(u - 0.3) / (0.6 * len)) * 0.7
			if _yield_now():
				await _pause()
	for i in n:
		var w := rng.randf_range(-1.0, 1.0)
		brown = brown * 0.996 + w * 0.04
		var u := float(i) / RATE
		var swell := 0.55 + 0.25 * sin(TAU * u / 10.0) + 0.2 * sin(TAU * u / 6.6667 + 1.0)
		# the wash: low and soft
		lp1 += (brown - lp1) * 0.05
		# the slap: brighter noise, but rounded off well below hiss
		lp2 += (w - lp2) * 0.22
		hp += (lp2 - hp) * 0.03
		var slap := (lp2 - hp) * env[i]
		# the gurgle: low noise wobbling
		lp3 += (w - lp3) * 0.025
		var g := lp3 * gurgle[i] * (0.6 + 0.4 * sin(u * 40.0 + sin(u * 7.0) * 3.0))
		s[i] = lp1 * swell * 0.8 + slap * 0.9 + g * 2.5
		if _yield_now():
			await _pause()
	return _loop(_normal(s, 0.7), RATE)


# A soft breeze off the sea: low noise with slow swells
func _breeze() -> AudioStreamWAV:
	var n := LOW_RATE * BED_SECONDS + LOW_RATE
	var s := PackedFloat32Array()
	s.resize(n)
	var brown := 0.0
	var lp := 0.0
	for i in n:
		var u := float(i) / LOW_RATE
		var gust := 0.55 + 0.3 * sin(TAU * u / 10.0 + 0.5) + 0.15 * sin(TAU * u / 4.0 + 2.0)
		brown = brown * 0.997 + rng.randf_range(-1.0, 1.0) * 0.03
		lp += (brown - lp) * 0.12
		s[i] = lp * gust
		if _yield_now():
			await _pause()
	return _loop(_normal(s, 0.6), LOW_RATE)


# People talking at the tables and on the quay: a few voices, each a buzz shaped by two moving formants
# into vowels, in syllables and phrases with pauses, and all of it muffled as if heard from a little way
# off, so it reads as a murmur and never as words
func _chatter() -> AudioStreamWAV:
	var n := LOW_RATE * BED_SECONDS + LOW_RATE
	var s := PackedFloat32Array()
	s.resize(n)
	var vowels := [Vector2(750, 1150), Vector2(500, 1500), Vector2(320, 1600), Vector2(500, 900), Vector2(360, 800)]
	for v in 5:
		var f0_base := rng.randf_range(105.0, 135.0) if v % 2 == 0 else rng.randf_range(190.0, 235.0)
		var gain := rng.randf_range(0.5, 1.0) * (0.6 if v == 4 else 1.0)
		# lay out the syllables: [start, length, vowel, pitch]
		var syl: Array = []
		var t := rng.randf_range(0.0, 2.5)
		while t < BED_SECONDS + 1.0:
			var count := rng.randi_range(4, 12)
			var pitch := rng.randf_range(0.95, 1.12)
			for k in count:
				var l := rng.randf_range(0.11, 0.24)
				syl.append([t, l, vowels[rng.randi() % vowels.size()], pitch * (1.0 - 0.15 * float(k) / count) * rng.randf_range(0.96, 1.05)])
				t += l + rng.randf_range(0.02, 0.07)
			t += rng.randf_range(0.6, 2.8)
		var phase := 0.0
		var low1 := 0.0
		var band1 := 0.0
		var low2 := 0.0
		var band2 := 0.0
		var si := 0
		var f1 := 500.0
		var f2 := 1200.0
		var f0 := f0_base
		for i in n:
			var u := float(i) / LOW_RATE
			while si < syl.size() - 1 and u > syl[si][0] + syl[si][1]:
				si += 1
			var sy: Array = syl[si]
			var into := u - float(sy[0])
			var amp := 0.0
			if into >= 0.0 and into <= float(sy[1]):
				amp = smoothstep(0.0, 0.03, into) * smoothstep(float(sy[1]), float(sy[1]) - 0.05, into)
			var target: Vector2 = sy[2]
			f1 += (target.x - f1) * 0.004
			f2 += (target.y - f2) * 0.004
			f0 += (f0_base * float(sy[3]) - f0) * 0.002
			phase = fmod(phase + f0 / LOW_RATE, 1.0)
			var src := (phase * 2.0 - 1.0) * amp + rng.randf_range(-0.08, 0.08) * amp
			var k1 := 2.0 * sin(PI * f1 / LOW_RATE)
			var k2 := 2.0 * sin(PI * f2 / LOW_RATE)
			low1 += k1 * band1
			band1 += k1 * (src - low1 - 0.25 * band1)
			low2 += k2 * band2
			band2 += k2 * (src - low2 - 0.3 * band2)
			s[i] += (band1 + band2 * 0.5) * gain
			if _yield_now():
				await _pause()
	# muffle it all
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		lp += (s[i] - lp) * 0.3
		lp2 += (lp - lp2) * 0.3
		s[i] = lp2
	return _loop(_normal(s, 0.6), LOW_RATE)


# --- the one-shots ---

# A cup set down on its saucer: a dull china knock (twice, for a cup and a spoon), kept low and soft
func _clink(twice: bool) -> AudioStreamWAV:
	var n := int(RATE * 0.5)
	var s := PackedFloat32Array()
	s.resize(n)
	var hits := [0.0, 0.11] if twice else [0.0]
	var parts := [[1180.0, 0.05, 1.0], [1960.0, 0.035, 0.5], [2870.0, 0.02, 0.25], [640.0, 0.03, 0.4]]
	for h in hits:
		var i0 := int(h * RATE)
		var amp := 1.0 if h == 0.0 else 0.55
		for k in n - i0:
			var u := float(k) / RATE
			var v := 0.0
			for p in parts:
				v += sin(TAU * p[0] * u) * exp(-u / p[1]) * p[2]
			v += rng.randf_range(-1.0, 1.0) * exp(-u / 0.004) * 0.6
			s[i0 + k] += v * amp
			if _yield_now():
				await _pause()
	var lp := 0.0
	for i in n:
		lp += (s[i] - lp) * 0.45
		s[i] = lp
	return _wav(_normal(s, 0.6), RATE)


# The church bell, heard across the water: a hum, the strike note, its minor third, fifth and octave,
# each dying away at its own pace, softened by the distance, with an echo off the cliffs
func _bell() -> AudioStreamWAV:
	var n := RATE * 7
	var s := PackedFloat32Array()
	s.resize(n)
	var f := 233.0
	var parts := [[0.5, 4.5, 0.8], [1.0, 3.0, 1.0], [1.2, 2.2, 0.6], [1.5, 1.6, 0.35], [2.0, 1.4, 0.5], [2.5, 0.8, 0.18], [3.0, 0.6, 0.12]]
	var c := PackedFloat32Array()
	var sn := PackedFloat32Array()
	var cr := PackedFloat32Array()
	var sr := PackedFloat32Array()
	var dec := PackedFloat32Array()
	var amp := PackedFloat32Array()
	for p in parts:
		var w := TAU * f * float(p[0]) / RATE
		c.append(1.0)
		sn.append(0.0)
		cr.append(cos(w))
		sr.append(sin(w))
		dec.append(exp(-1.0 / (float(p[1]) * RATE)))
		amp.append(p[2])
	for i in n:
		var v := 0.0
		for k in parts.size():
			var nc := c[k] * cr[k] - sn[k] * sr[k]
			sn[k] = c[k] * sr[k] + sn[k] * cr[k]
			c[k] = nc
			amp[k] *= dec[k]
			v += sn[k] * amp[k]
		if i < 400:
			v += rng.randf_range(-1.0, 1.0) * (1.0 - i / 400.0) * 0.4
		s[i] = v
		if _yield_now():
			await _pause()
	# far off: soften it, and let the cliffs answer
	var lp := 0.0
	var out := PackedFloat32Array()
	out.resize(n)
	var d1 := int(0.13 * RATE)
	var d2 := int(0.29 * RATE)
	for i in n:
		lp += (s[i] - lp) * 0.35
		var e := lp
		if i >= d1:
			e += out[i - d1] * 0.22
		if i >= d2:
			e += out[i - d2] * 0.12
		out[i] = e
	return _wav(_normal(out, 0.7), RATE)


# A fishing boat's engine going by far out: a low putt-putt-putt coming up and dying away
func _motor() -> AudioStreamWAV:
	var n := LOW_RATE * 18
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	var lp2 := 0.0
	var ph := 0.0
	var thump := 0.0
	for i in n:
		var u := float(i) / LOW_RATE
		var rate := 8.5 + sin(u * 0.4) * 0.6
		ph += rate / LOW_RATE
		if ph >= 1.0:
			ph -= 1.0
			thump = 1.0
		thump *= 0.9965
		var w := rng.randf_range(-1.0, 1.0)
		lp += (w - lp) * 0.08
		var v := lp * thump * 2.0 + sin(TAU * 62.0 * u) * thump * 0.5
		lp2 += (v - lp2) * 0.2
		var env := smoothstep(0.0, 6.0, u) * smoothstep(18.0, 11.0, u)
		s[i] = lp2 * env
		if _yield_now():
			await _pause()
	return _wav(_normal(s, 0.6), LOW_RATE)


# --- making streams ---

func _normal(s: PackedFloat32Array, peak: float) -> PackedFloat32Array:
	var top := 0.0001
	for v in s:
		top = maxf(top, absf(v))
	var k := peak / top
	for i in s.size():
		s[i] *= k
	return s


# The bed is a second longer than the loop: crossfade that second into the start, so the loop has no seam
func _loop(s: PackedFloat32Array, rate: int) -> AudioStreamWAV:
	var fade := rate
	var n := s.size() - fade
	var out := s.slice(0, n)
	for i in fade:
		var u := float(i) / fade
		out[i] = s[i] * sqrt(u) + s[n + i] * sqrt(1.0 - u)
	var wav := _wav(out, rate)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = n
	return wav


func _wav(s: PackedFloat32Array, rate: int) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(s.size() * 2)
	for i in s.size():
		data.encode_s16(i * 2, int(clampf(s[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav
