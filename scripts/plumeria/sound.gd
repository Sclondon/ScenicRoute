extends Node
## The sound of the Plumeria Beach Club, all made at start-up: the surf (a low roar always, and every
## eight seconds a wave that crashes, rolls in as white water, washes up the sand with a hiss and draws
## back fizzing), the palms rustling in the breeze, the torches crackling softly, and now and then a few
## chords on a ukulele somewhere behind you at the bar (plucked strings, Karplus-Strong, soft).
##
## As in scripts/ambience.gd: every bed is baked once with its swells in it, loops seamlessly and is left
## alone while it plays (changing a player's volume every frame stutters on the web). The surf is baked on
## the same 24 s round as the waves drawn on the sea and the sand: `start()` tells their shaders when it
## began, so each crash is heard as it is seen.

const RATE := 16000
const PERIOD := 8.0
const ROUND := 24.0
const SPEED := 4.5
const BREAK_AT := 13.0

## The sea's and the sand's materials, whose `wave_t0` is set when the surf starts.
var surf_materials: Array[ShaderMaterial] = []
var surf: AudioStreamPlayer
var palms: AudioStreamPlayer
var torches: AudioStreamPlayer
var uke: Array[AudioStreamPlayer] = []
var chords := {}
var _phrase: Array = []
var _uke_in := 14.0
var _next := 0
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.seed = 4242
	surf = _bed(_surf_loop(), -2.0)
	palms = _bed(_palm_loop(), -17.0)
	torches = _bed(_torch_loop(), -21.0)
	# ukulele chords, re-entrant tuning G C E A
	chords["C"] = _strum([392.0, 261.63, 329.63, 523.25])
	chords["Am"] = _strum([440.0, 261.63, 329.63, 440.0])
	chords["F"] = _strum([440.0, 349.23, 440.0, 523.25])
	chords["G7"] = _strum([392.0, 293.66, 349.23, 440.0])
	chords["Dm"] = _strum([440.0, 293.66, 349.23, 440.0])
	for i in 3:
		var p := AudioStreamPlayer.new()
		p.volume_db = -15.0
		add_child(p)
		uke.append(p)


func start() -> void:
	if surf.playing:
		return
	var t0 := fmod(Time.get_ticks_msec() / 1000.0, 3600.0)
	for m in surf_materials:
		m.set_shader_parameter("wave_t0", t0)
	surf.play()
	palms.play()
	torches.play()


func _process(delta: float) -> void:
	if not surf.playing:
		return
	if not _phrase.is_empty():
		_phrase[0][1] -= delta
		if _phrase[0][1] <= 0.0:
			var p := uke[_next]
			_next = (_next + 1) % uke.size()
			p.stream = chords[_phrase[0][0]]
			p.pitch_scale = 1.0
			p.play()
			_phrase.pop_front()
		return
	_uke_in -= delta
	if _uke_in <= 0.0:
		_uke_in = rng.randf_range(22.0, 40.0)
		var phrases := [["C", "Am", "F", "G7", "C"], ["F", "C", "G7", "C"], ["C", "Dm", "G7", "C"], ["Am", "F", "C"]]
		var phrase: Array = phrases[rng.randi() % phrases.size()]
		var wait := 0.0
		for name in phrase:
			_phrase.append([name, wait])
			wait = rng.randf_range(1.5, 2.1)


func _bed(stream: AudioStreamWAV, volume_db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = volume_db
	add_child(p)
	return p


static func _wave_size(k: int) -> float:
	var m := posmod(k, 3)
	return 1.0 if m == 0 else (0.72 if m == 1 else 0.86)


# The surf: the whole round of three waves, with a second more for the crossfade
func _surf_loop() -> AudioStreamWAV:
	var n := int(RATE * (ROUND + 1.0))
	var s := PackedFloat32Array()
	s.resize(n)
	# envelopes for each part, from where each wave is in its life
	var brown := 0.0
	var lp_roar := 0.0
	var lp_crash := 0.0
	var lp2_crash := 0.0
	var lp_hiss := 0.0
	var prev := 0.0
	var fizz := 0.0
	# the envelopes, worked out every STEP samples (and eased between)
	const STEP := 64
	var steps := n / STEP + 2
	var env_crash := PackedFloat32Array()
	var env_roll := PackedFloat32Array()
	var env_wash := PackedFloat32Array()
	var env_back := PackedFloat32Array()
	env_crash.resize(steps)
	env_roll.resize(steps)
	env_wash.resize(steps)
	env_back.resize(steps)
	for j in steps:
		var t := float(j * STEP) / RATE
		for k in range(-1, 5):
			var size := _wave_size(k)
			var arrive := k * PERIOD + 0.45 * PERIOD
			var hit := arrive - BREAK_AT * size / SPEED
			var since := t - hit
			if since > 0.0 and since < 4.0:
				env_crash[j] += size * (1.0 - exp(-since * 8.0)) * exp(-since * 1.4)
			if since > 0.0 and t < arrive + 1.0:
				env_roll[j] += size * smoothstep(0.0, 0.6, since) * (1.0 - smoothstep(arrive - 0.5, arrive + 1.0, t))
			var on := t - arrive
			if on > 0.0 and on < 3.2:
				env_wash[j] += size * smoothstep(0.0, 0.5, on) * (1.0 - smoothstep(1.0, 3.2, on))
			if on > 2.2 and on < 7.0:
				env_back[j] += size * smoothstep(2.2, 3.2, on) * (1.0 - smoothstep(3.5, 7.0, on))
	for i in n:
		var t := float(i) / RATE
		var j := i / STEP
		var f := float(i % STEP) / STEP
		var crash := lerpf(env_crash[j], env_crash[j + 1], f)
		var roll := lerpf(env_roll[j], env_roll[j + 1], f)
		var wash := lerpf(env_wash[j], env_wash[j + 1], f)
		var back := lerpf(env_back[j], env_back[j + 1], f)
		var w := randf_range(-1.0, 1.0)
		# the low roar, always
		brown = brown * 0.997 + w * 0.03
		lp_roar += (brown - lp_roar) * 0.04
		var sea := lp_roar * (0.22 + 0.04 * sin(TAU * t / ROUND * 2.0))
		# the crash: a deep thud of noise
		lp_crash += (w - lp_crash) * 0.08
		lp2_crash += (lp_crash - lp2_crash) * 0.12
		sea += lp2_crash * crash * 6.0
		# white water rolling in, and the wash: brighter noise, kept soft
		var hp := w - prev
		prev = w
		lp_hiss += (hp * 0.5 + w * 0.5 - lp_hiss) * 0.35
		sea += lp_hiss * (roll * 0.4 + wash * 0.45)
		# drawing back: a fizz of tiny pops over a fading hiss
		if randf() < 0.02 * back:
			fizz = randf_range(0.3, 1.0)
		fizz *= 0.9
		sea += lp_hiss * back * 0.16 + fizz * w * 0.08
		s[i] = sea
	return _loop(_normal(s, 0.8))


# Palms: a papery rustle that rises and falls with the breeze
func _palm_loop() -> AudioStreamWAV:
	var n := int(RATE * 14.0)
	var s := PackedFloat32Array()
	s.resize(n)
	var prev := 0.0
	var lp := 0.0
	var lp2 := 0.0
	var flutter := 0.0
	var to := 0.0
	for i in n:
		var t := float(i) / RATE
		var u := t / 13.0
		var gust := 0.55 + 0.3 * sin(TAU * u * 2.0) + 0.15 * sin(TAU * u * 3.0 + 1.1)
		var w := randf_range(-1.0, 1.0)
		var hp := w - prev
		prev = w
		lp += (hp - lp) * 0.3
		lp2 += (lp - lp2) * 0.5
		if i % 1800 == 0:
			to = randf()
		flutter += (to - flutter) * 0.0006
		s[i] = lp2 * gust * gust * (0.4 + 0.6 * flutter)
	return _loop(_normal(s, 0.6))


# The torches: a soft breathy roar with little crackles in it
func _torch_loop() -> AudioStreamWAV:
	var n := int(RATE * 8.0)
	var s := PackedFloat32Array()
	s.resize(n)
	var brown := 0.0
	var pop := 0.0
	var lp := 0.0
	for i in n:
		var w := randf_range(-1.0, 1.0)
		brown = brown * 0.995 + w * 0.02
		if randf() < 4.0 / RATE:
			pop = randf_range(0.4, 1.0)
		pop *= 0.996
		lp += (w * pop - lp) * 0.3
		s[i] = brown * 0.5 + lp * 0.8
	return _loop(_normal(s, 0.5))


# A chord strummed down the four strings, each a plucked string (Karplus-Strong), soft and warm
func _strum(freqs: Array) -> AudioStreamWAV:
	var length := int(RATE * 2.2)
	var out := PackedFloat32Array()
	out.resize(length)
	for si in freqs.size():
		var f: float = freqs[si]
		var start := int(RATE * 0.028 * si)
		var period := int(RATE / f)
		var buf := PackedFloat32Array()
		buf.resize(period)
		# a soft pluck: the noise smoothed so the attack is round, not bright
		var sm := 0.0
		for k in period:
			sm += (randf_range(-1.0, 1.0) - sm) * 0.45
			buf[k] = sm
		var idx := 0
		var last := 0.0
		for i in range(start, length):
			var a := buf[idx]
			var b := buf[(idx + 1) % period]
			var y := (a + b) * 0.5 * 0.9965
			buf[idx] = y
			idx = (idx + 1) % period
			last += (a - last) * 0.5
			var age := float(i - start) / RATE
			out[i] += last * (1.0 - smoothstep(1.4, 2.2, age)) * 0.3
	_normal(out, 0.6)
	return _wav(out)


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
