extends Node
## The sound of The Velvet Moth, all made at start-up (no audio files): a house groove at 122 BPM
## (four-on-the-floor kick, offbeat hats, a clap on two and four, a rolling bassline and a soft chord
## stab over Am7 - Fmaj7 - Cmaj7 - G), heard muffled from the mezzanine, through the room and the crowd;
## and under it the crowd talking.
##
## Both are baked once into loops that come round without a seam, and are left alone while they play
## (changing a player's volume every frame stutters in the web build). The place reads `beat()` to keep
## its lights on the music.

const RATE := 22050
const BPM := 122.0
const BARS := 8
const BEATS := BARS * 4
const MURMUR_SECONDS := 12

var music: AudioStreamPlayer
var murmur: AudioStreamPlayer
var loop_samples := 0
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.seed = 4417
	music = _bed(_groove(), -9.0)
	murmur = _bed(_crowd(), -15.0)


func start() -> void:
	if not music.playing:
		music.play()
		murmur.play()


## Where the music is now, in beats from the start of its loop (0..BEATS), or -1 if it is not playing.
func beat() -> float:
	if music == null or not music.playing:
		return -1.0
	var t := music.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()
	return fposmod(t * BPM / 60.0, float(BEATS))


func _bed(stream: AudioStreamWAV, volume_db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = volume_db
	add_child(p)
	return p


# --- the groove ---

func _groove() -> AudioStreamWAV:
	var beat_len := 60.0 / BPM * RATE
	loop_samples = int(round(beat_len * BEATS))
	var n := loop_samples
	var s := PackedFloat32Array()
	s.resize(n)
	var kick := _kick()
	var hat := _hat(0.045, 0.16)
	var open_hat := _hat(0.16, 0.1)
	var clap := _clap()
	# Am7, Fmaj7, Cmaj7, G6 (two bars each), and the bass's roots under them
	var chords := [[220.0, 261.63, 329.63, 392.0], [174.61, 220.0, 261.63, 329.63],
		[246.94, 261.63, 329.63, 392.0], [196.0, 246.94, 293.66, 329.63]]
	var roots := [55.0, 43.65, 65.41, 49.0]
	var stabs := []
	var basses := []
	for c in 4:
		stabs.append(_stab(chords[c]))
		basses.append([_bass(roots[c], 0.2), _bass(roots[c] * 2.0, 0.14)])
	for b in BEATS:
		var at := int(b * beat_len)
		var off := int((b + 0.5) * beat_len)
		var chord: int = (b / 8) % 4
		_add(s, kick, at, 1.0)
		_add(s, open_hat if b % 4 == 3 else hat, off, 1.0)
		if b % 2 == 1:
			_add(s, clap, at, 1.0)
		# 16ths of closed hat, very soft, for the shuffle
		_add(s, hat, int((b + 0.25) * beat_len), 0.25)
		_add(s, hat, int((b + 0.75) * beat_len), 0.35)
		# the bass on the offbeats, jumping the octave at the end of each bar
		var bass: Array = basses[chord]
		_add(s, bass[1] if b % 4 == 3 else bass[0], off, 1.0)
		if b % 4 == 1:
			_add(s, bass[0], int((b + 0.75) * beat_len), 0.7)
		# the stab on the and of two and the and of four, and pushed into the next bar now and then
		if b % 4 == 1 or b % 4 == 3:
			_add(s, stabs[chord], off, 1.0 if b % 8 != 7 else 0.8)
	return _loop_wav(_muffle(s))


# Add a sound into the loop at a sample, wrapping round its end so the loop has no seam
func _add(s: PackedFloat32Array, sound: PackedFloat32Array, at: int, gain: float) -> void:
	var n := s.size()
	for i in sound.size():
		var j := (at + i) % n
		s[j] += sound[i] * gain


func _kick() -> PackedFloat32Array:
	var len := int(0.32 * RATE)
	var out := PackedFloat32Array()
	out.resize(len)
	var phase := 0.0
	for i in len:
		var t := float(i) / RATE
		var f := 46.0 + 85.0 * exp(-t * 28.0)
		phase += TAU * f / RATE
		var amp := exp(-t * 9.0) * minf(t * 600.0, 1.0)
		out[i] = sin(phase) * amp * 0.95
	return out


func _hat(seconds: float, gain: float) -> PackedFloat32Array:
	var len := int(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(len)
	var prev := 0.0
	for i in len:
		var w := rng.randf_range(-1.0, 1.0)
		var hp := w - prev
		prev = w
		var t := float(i) / len
		out[i] = hp * pow(1.0 - t, 3.0) * gain
	return out


func _clap() -> PackedFloat32Array:
	var len := int(0.18 * RATE)
	var out := PackedFloat32Array()
	out.resize(len)
	var lp := 0.0
	var bp := 0.0
	for i in len:
		var t := float(i) / RATE
		var w := rng.randf_range(-1.0, 1.0)
		lp += (w - lp) * 0.35
		bp += (lp - bp) * 0.08
		var band := lp - bp
		# three quick claps and the tail
		var env := exp(-fmod(t, 0.011) * 300.0) if t < 0.033 else exp(-(t - 0.033) * 22.0)
		out[i] = band * env * 0.35
	return out


# A round, plucked bass note: a few harmonics, the top ones dying first
func _bass(freq: float, seconds: float) -> PackedFloat32Array:
	var len := int(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(len)
	for i in len:
		var t := float(i) / RATE
		var x := TAU * freq * t
		var bright := exp(-t * 18.0)
		var v := sin(x) + (0.5 * sin(2.0 * x) + 0.25 * sin(3.0 * x)) * (0.3 + 0.7 * bright)
		var env := minf(t * 300.0, 1.0) * (1.0 - smoothstep(seconds * 0.6, seconds, t))
		out[i] = v * env * 0.32
	return out


# A soft chord stab, like an electric piano: each note a sine with a little second harmonic, dying away
func _stab(freqs: Array) -> PackedFloat32Array:
	var seconds := 0.42
	var len := int(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(len)
	for f: float in freqs:
		var detune := 1.0 + rng.randf_range(-0.002, 0.002)
		for i in len:
			var t := float(i) / RATE
			var x := TAU * f * detune * t
			var env := minf(t * 200.0, 1.0) * exp(-t * 7.0)
			out[i] += (sin(x) + 0.18 * sin(2.0 * x) * exp(-t * 14.0)) * env * 0.075
	return out


# Heard from up on the mezzanine: the top taken off (twice over), and a little of the room coming back
func _muffle(s: PackedFloat32Array) -> PackedFloat32Array:
	var n := s.size()
	var out := PackedFloat32Array()
	out.resize(n)
	var a := 1.0 - exp(-TAU * 1400.0 / RATE)
	var lp1 := 0.0
	var lp2 := 0.0
	var d1 := int(0.071 * RATE)
	var d2 := int(0.123 * RATE)
	# run the filters through the end of the loop first, so they come into the start already going
	for i in range(n - 2000, n):
		lp1 += (s[i] - lp1) * a
		lp2 += (lp1 - lp2) * a
	for i in n:
		var x: float = s[i] + s[(i - d1 + n) % n] * 0.22 + s[(i - d2 + n) % n] * 0.12
		lp1 += (x - lp1) * a
		lp2 += (lp1 - lp2) * a
		out[i] = lp2
	return _normal(out, 0.75)


# --- the crowd ---

# Many people talking at once: noise kept to the voice's band, coming and going in syllables and
# swells, in three registers that each wander on their own
func _crowd() -> AudioStreamWAV:
	var n := RATE * MURMUR_SECONDS + RATE
	var s := PackedFloat32Array()
	s.resize(n)
	var h1 := 0.0
	var l1 := 0.0
	var e1 := 0.0
	var t1 := 0.0
	var h2 := 0.0
	var l2 := 0.0
	var e2 := 0.0
	var t2 := 0.0
	var h3 := 0.0
	var l3 := 0.0
	var e3 := 0.0
	var t3 := 0.0
	var swell := TAU * 2.0 / (RATE * MURMUR_SECONDS)
	for i in n:
		var w := rng.randf() * 2.0 - 1.0
		# low voices, middle, and a few higher ones, each a band of the noise
		h1 += (w - h1) * 0.06
		l1 += (h1 - l1) * 0.012
		h2 += (w - h2) * 0.13
		l2 += (h2 - l2) * 0.03
		h3 += (w - h3) * 0.22
		l3 += (h3 - l3) * 0.07
		# syllables: each register goes to a new loudness every so often, eased there
		if i % 1323 == 0:
			t1 = rng.randf() * rng.randf()
		elif i % 1323 == 441:
			t2 = rng.randf() * rng.randf()
		elif i % 1323 == 882:
			t3 = rng.randf() * rng.randf()
		e1 += (t1 - e1) * 0.0012
		e2 += (t2 - e2) * 0.0015
		e3 += (t3 - e3) * 0.0018
		var v := (h1 - l1) * e1 + (h2 - l2) * e2 * 0.7 + (h3 - l3) * e3 * 0.3
		s[i] = v * (0.75 + 0.25 * sin(swell * i + 0.6))
	return _crossfade_loop(_normal(s, 0.6))


func _normal(s: PackedFloat32Array, peak: float) -> PackedFloat32Array:
	var top := 0.0001
	for v in s:
		top = maxf(top, absf(v))
	var k := peak / top
	for i in s.size():
		s[i] *= k
	return s


# A loop made to wrap round already: just mark it as looping
func _loop_wav(s: PackedFloat32Array) -> AudioStreamWAV:
	var wav := _wav(s)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = s.size()
	return wav


# The bed is a second longer than the loop: crossfade that second into the start, so the loop has no seam
func _crossfade_loop(s: PackedFloat32Array) -> AudioStreamWAV:
	var fade := RATE
	var n := s.size() - fade
	var out := s.slice(0, n)
	for i in fade:
		var u := float(i) / fade
		out[i] = s[i] * sqrt(u) + s[n + i] * sqrt(1.0 - u)
	return _loop_wav(out)


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
