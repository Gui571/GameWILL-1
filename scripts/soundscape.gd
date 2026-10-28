class_name Soundscape
extends Node
## Small original synthesizer; all sounds are generated locally, with no external assets.
## This node does not alter the global audio bus or require any online service.

const SAMPLE_RATE := 16000
const LOOP_SECONDS := 16.0
const TAU_F := PI * 2.0

var muted := false
var music_volume_db := -12.0
var sfx_volume_db := -6.0
var _battle := false
var _battle_mix := 0.0
var _ambient: AudioStreamPlayer
var _pulse: AudioStreamPlayer
var _voices: Array[AudioStreamPlayer] = []
var _sounds: Dictionary = {}
var _voice_index := 0
var _playback_enabled := true

func _ready() -> void:
	# The headless Dummy audio driver has no audible output and does not reliably
	# release looping WAV playbacks on immediate shutdown. Still synthesize assets
	# for tests, but reserve actual playback for graphical game sessions.
	_playback_enabled = DisplayServer.get_name() != "headless"
	_ambient = AudioStreamPlayer.new()
	_ambient.name = "Atmosphere"
	add_child(_ambient)
	_pulse = AudioStreamPlayer.new()
	_pulse.name = "BattlePulse"
	add_child(_pulse)
	for index in range(6):
		var voice := AudioStreamPlayer.new()
		voice.name = "Effect%d" % index
		add_child(voice)
		_voices.append(voice)
	# Defer synthesis until the first frame can render the menu.
	call_deferred("_prepare_audio")

func _prepare_audio() -> void:
	_ambient.stream = _make_music(false)
	_pulse.stream = _make_music(true)
	for kind in ["click", "hit", "skill", "ultimate", "break", "heal", "win", "lose"]:
		_sounds[kind] = _make_effect(kind)
	_apply_volume()
	if _playback_enabled:
		_ambient.play()
		_pulse.play()

func _process(delta: float) -> void:
	_battle_mix = move_toward(_battle_mix, 1.0 if _battle else 0.0, delta * 0.65)
	_apply_volume()

func _apply_volume() -> void:
	if not is_instance_valid(_ambient):
		return
	_ambient.volume_db = -80.0 if muted else music_volume_db
	_pulse.volume_db = -80.0 if muted or _battle_mix < 0.002 else music_volume_db - 3.0 + linear_to_db(_battle_mix)

func set_battle(value: bool) -> void:
	_battle = value

func _exit_tree() -> void:
	# Explicitly release looping playback before the audio server shuts down.
	for player in [_ambient, _pulse] + _voices:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
	_sounds.clear()

func set_muted(value: bool) -> void:
	muted = value
	_apply_volume()
	for voice in _voices:
		voice.volume_db = -80.0 if muted else sfx_volume_db

func play_sfx(kind: String) -> void:
	if not _playback_enabled or muted or not _sounds.has(kind) or _voices.is_empty():
		return
	var voice := _voices[_voice_index]
	_voice_index = (_voice_index + 1) % _voices.size()
	voice.stream = _sounds[kind]
	voice.volume_db = sfx_volume_db
	voice.play()

func _make_wav(samples: PackedByteArray, looping: bool = false) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = samples
	if looping:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size() / 2
	return wav

func _make_music(pulse: bool) -> AudioStreamWAV:
	var count := int(SAMPLE_RATE * LOOP_SECONDS)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	# D minor, B-flat, F, C; a restrained motif with room for dialogue.
	var roots := [146.8324, 116.5409, 174.6141, 130.8128]
	var thirds := [1.189207, 1.259921, 1.259921, 1.259921]
	var melody := [293.6648, 349.2282, 440.0, 349.2282, 523.2511, 440.0, 391.9954, 261.6256]
	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var chord := int(t / 4.0) % 4
		var local := fmod(t, 4.0)
		var value := 0.0
		if pulse:
			var beat := fmod(t, 0.5)
			var bass: float = roots[chord] / 2.0
			var envelope := minf(beat / 0.012, 1.0) * exp(-beat * 9.0)
			value = sin(TAU_F * bass * t) * envelope * 0.30
			# A low, soft drum with a descending pitch, avoiding harsh noise.
			var kick := fmod(t, 1.0)
			value += sin(TAU_F * (48.0 * kick + 10.0 * (1.0 - exp(-kick * 12.0)))) * exp(-kick * 15.0) * 0.16
		else:
			var pad_env := minf(local / 0.35, 1.0) * minf((4.0 - local) / 0.45, 1.0)
			var root: float = roots[chord]
			value = (sin(TAU_F * root * t) + sin(TAU_F * root * thirds[chord] * t) * 0.45 + sin(TAU_F * root * 1.498307 * t) * 0.55) * pad_env * 0.12
			var note_time := fmod(t, 2.0)
			var note: float = melody[int(t / 2.0) % 8]
			var note_env := minf(note_time / 0.025, 1.0) * exp(-note_time * 2.0)
			value += (sin(TAU_F * note * t) + sin(TAU_F * note * 2.0 * t) * 0.16) * note_env * 0.23
			# Quiet octave shimmer gives the loop an airy, railway-at-night texture.
			value += sin(TAU_F * note * 0.5 * t) * note_env * 0.035
		# Short boundary taper prevents loop seams and first-frame clicks.
		value *= minf(t / 0.02, 1.0) * minf((LOOP_SECONDS - t) / 0.02, 1.0)
		bytes.encode_s16(i * 2, int(clampf(value, -0.95, 0.95) * 32767.0))
	return _make_wav(bytes, true)

func _make_effect(kind: String) -> AudioStreamWAV:
	var duration := 0.30
	match kind:
		"click": duration = 0.075
		"hit": duration = 0.20
		"skill": duration = 0.40
		"ultimate": duration = 1.25
		"break": duration = 0.65
		"heal": duration = 0.85
		"win": duration = 1.65
		"lose": duration = 1.40
	var count := int(duration * SAMPLE_RATE)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var p := t / duration
		var value := 0.0
		var env := minf(t / 0.008, 1.0) * pow(1.0 - p, 2.0)
		match kind:
			"click":
				value = sin(TAU_F * 660.0 * t) * env * 0.15
			"hit":
				value = (sin(TAU_F * (150.0 * t - 160.0 * t * t)) * 0.46 + sin(TAU_F * 1297.0 * t) * sin(TAU_F * 1771.0 * t) * 0.15) * env
			"skill":
				value = (sin(TAU_F * (240.0 * t + 650.0 * t * t)) * 0.30 + sin(TAU_F * 880.0 * t) * 0.10) * env
			"ultimate":
				var swell := sin(PI * p) * (0.6 + 0.4 * p)
				value = (sin(TAU_F * (73.4162 * t + 25.0 * t * t)) * 0.22 + sin(TAU_F * 293.6648 * t) * 0.15 + sin(TAU_F * 440.0 * t) * 0.13) * swell
			"break":
				value = (sin(TAU_F * 783.99 * t) * 0.19 + sin(TAU_F * 1174.66 * t) * 0.17 + sin(TAU_F * 1567.98 * t) * 0.10) * env
			"heal":
				var note := [523.2511, 659.2551, 783.9909][mini(int(t / 0.16), 2)] as float
				value = (sin(TAU_F * note * t) + sin(TAU_F * note * 2.0 * t) * 0.12) * env * 0.28
			"win":
				var notes := [293.6648, 349.2282, 440.0, 587.3295]
				var step := mini(int(t / 0.22), 3)
				var note: float = notes[step]
				var strike := fmod(t, 0.22) if step < 3 else t - 0.66
				value = sin(TAU_F * note * t) * minf(strike / 0.01, 1.0) * exp(-strike * 2.8) * env * 0.42
			"lose":
				value = (sin(TAU_F * 146.8324 * t) + sin(TAU_F * 155.5635 * t) * 0.5) * env * 0.20
		bytes.encode_s16(i * 2, int(clampf(value, -0.95, 0.95) * 32767.0))
	return _make_wav(bytes)
