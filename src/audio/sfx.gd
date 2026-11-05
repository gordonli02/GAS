extends Node
## Sound effects (autoload "Sfx"). Owns a small pool of players, the engine's
## recorded and baked sounds, and tear-rip slicing for pack rips.
## Settings: master volume and mute (player menu); per-sound replacement files and
## volumes (developer panel, as the web build's sound bench).

const SOUNDS := {
	"deal": "res://assets/audio/sfx_deal.wav",
	"flip": "res://assets/audio/sfx_flip.wav",
	"toss": "res://assets/audio/sfx_toss.wav",
	"pop": "res://assets/audio/sfx_pop.wav",
	"win_2": "res://assets/audio/sfx_win_2.wav",
	"win_3": "res://assets/audio/sfx_win_3.wav",
	"win_5": "res://assets/audio/sfx_win_5.wav",
	"win_8": "res://assets/audio/sfx_win_8.wav",
	"button": "res://assets/audio/machine_button.wav",
	"bill": "res://assets/audio/bill_insert.wav",
	"dispense_loop": "res://assets/audio/dispense_loop.wav",
	## The loop sped up 1.5x at its own pitch (tools/time_stretch_loop.py).
	"dispense_loop_fast": "res://assets/audio/dispense_loop_fast.wav",
	"dispense_stop": "res://assets/audio/dispense_stop.wav",
}
## Sound slots the developer panel can replace and turn up or down (the web build's list).
## "tear" stands for the recorded rips, "win" for every win jingle, "dispense" for the motor.
const SLOTS := ["tear", "pop", "deal", "flip", "toss", "dispense", "dispense_stop", "bill", "button", "win"]
const AUDIO_EXTS := ["wav", "ogg", "mp3"]
const POOL := 16
const DEFAULT_MASTER := 0.8

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _tweens: Array = []
var _next := 0
var _slices := {}   ## cache: "<path>|<start>|<end>" -> AudioStreamWAV
var _motor := AudioStreamPlayer.new()
var _motor_on := false
var _default_loop: AudioStream
var _override := {}   ## slot -> AudioStream
var _volume := {}     ## slot -> linear gain (0..2)


func _ready() -> void:
	for id in SOUNDS:
		_streams[id] = load(SOUNDS[id])
	for i in POOL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
		_tweens.append(null)
	set_master(DEFAULT_MASTER)
	_default_loop = _looped(_streams["dispense_loop_fast"])
	_motor.stream = _default_loop
	add_child(_motor)


## The dispenser's motor loop while tickets come out: 1.5x speed, original pitch.
func motor(on: bool) -> void:
	if on == _motor_on:
		return
	_motor_on = on
	if on:
		_motor.volume_db = linear_to_db(maxf(volume("dispense"), 0.0001))
		_motor.play()
	else:
		_motor.stop()


func set_master(linear: float) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(linear, 0.0001)))


func set_muted(muted: bool) -> void:
	AudioServer.set_bus_mute(0, muted)


## Master volume, mute and the developer's sound replacements, from the save's settings.
func apply_settings(s: Dictionary) -> void:
	set_master(float(s.get("master", DEFAULT_MASTER)))
	set_muted(bool(s.get("muted", false)))
	_override.clear()
	_volume.clear()
	var sounds: Dictionary = s.get("sounds", {})
	for slot in sounds:
		var d = sounds[slot]
		if not SLOTS.has(slot) or typeof(d) != TYPE_DICTIONARY:
			continue
		_volume[slot] = clampf(float(d.get("volume", 1.0)), 0.0, 2.0)
		var file := str(d.get("file", ""))
		if file != "":
			var st := load_file(file)
			if st != null:
				_override[slot] = st
	_motor.stream = _looped(_override["dispense"]) if _override.has("dispense") else _default_loop


func volume(slot: String) -> float:
	return _volume.get(slot, 1.0)


func is_replaced(slot: String) -> bool:
	return _override.has(slot)


## Reads a sound file from disk (WAV, OGG or MP3), uncached.
static func load_file(path: String) -> AudioStream:
	match path.get_extension().to_lower():
		"wav":
			return AudioStreamWAV.load_from_file(path)
		"ogg":
			return AudioStreamOggVorbis.load_from_file(path)
		"mp3":
			return AudioStreamMP3.load_from_file(path)
	return null


func play(id: String, pitch := 1.0) -> void:
	var slot := slot_of(id)
	var s: AudioStream = _override.get(slot, _streams.get(id))
	if s:
		_play_stream(s, pitch, volume(slot))


## Developer panel "listen": the slot's sound as the game would play it.
func audition(slot: String) -> void:
	match slot:
		"tear":
			if _override.has("tear"):
				_play_stream(_override.tear, 1.0, volume("tear"))
			else:
				var clips := Packs.tear_clips_for(Packs.forms()[0]) if not Packs.forms().is_empty() else []
				if not clips.is_empty():
					var src := PackAssets.audio(clips[randi() % clips.size()].path)
					if src != null:
						_play_stream(src, 1.0, volume("tear"))
		"dispense":
			_play_stream(_motor.stream, 1.0, volume("dispense"))
			var p := _players[(_next - 1 + POOL) % POOL]
			get_tree().create_timer(1.2).timeout.connect(func(): if p.stream == _motor.stream: p.stop())
		"win":
			play("win_8")
		_:
			play(slot)


static func slot_of(id: String) -> String:
	if id.begins_with("win_"):
		return "win"
	if id.begins_with("dispense_loop"):
		return "dispense"
	return id


## Win jingle length follows the prize, as in the web build.
func play_win(prize: int) -> void:
	play("win_8" if prize >= 50 else "win_5" if prize >= 10 else "win_3" if prize >= 5 else "win_2")


## The first break of a flap: silent when recorded rips carry the sound (web build),
## unless the developer replaced the pop.
func play_break(has_rips: bool) -> void:
	if not has_rips or _override.has("pop") or _override.has("tear"):
		play("pop")


## Plays the part of a rip between the crackles that progress just crossed.
## clip: {path, marks} from a pack. A replacement tear file is cut into equal steps.
func play_tear_slice(clip: Dictionary, from_step: int, to_step: int, steps: int) -> void:
	if _override.has("tear"):
		var len: float = _override.tear.get_length()
		_play_span(_override.tear, float(from_step) / steps * len, float(to_step - from_step) / steps * len, volume("tear"))
		return
	var src := PackAssets.audio(clip.path) as AudioStreamWAV
	if src == null:
		return
	var span := TearSlicer.slice(clip.marks, src.get_length(), from_step, to_step, steps)
	if span.x < 0:
		return
	_play_stream(_slice(src, clip.path, span.x, span.y), 1.0, volume("tear"))


## Plays [start, end] seconds of a rip (used for the band snapping).
## With a replacement tear file the band plays the pop instead, as in the web build.
func play_tear_span(clip: Dictionary, start: float, end: float) -> void:
	if _override.has("tear"):
		play("pop")
		return
	var src := PackAssets.audio(clip.path) as AudioStreamWAV
	if src != null and end > start:
		_play_stream(_slice(src, clip.path, start, end), 1.0, volume("tear"))


## A copy of [start, end] with full gain to the end, then a short linear fade.
func _slice(src: AudioStreamWAV, key: String, start: float, end: float) -> AudioStreamWAV:
	var id := "%s|%.4f|%.4f" % [key, start, end]
	if _slices.has(id):
		return _slices[id]
	var bps := 2 * (2 if src.stereo else 1)
	var rate := src.mix_rate
	var total := src.data.size() / bps
	var a := clampi(int(start * rate), 0, total)
	var b := clampi(int(end * rate), a, total)
	var c := clampi(int((end + TearSlicer.FADE) * rate), b, total)
	var bytes := src.data.slice(a * bps, c * bps)
	var fade_frames := c - b
	for i in fade_frames:
		var g := 1.0 - float(i + 1) / fade_frames
		var at := (b - a + i) * bps
		for ch in range(0, bps, 2):
			bytes.encode_s16(at + ch, int(bytes.decode_s16(at + ch) * g))
	var out := AudioStreamWAV.new()
	out.format = src.format
	out.mix_rate = rate
	out.stereo = src.stereo
	out.data = bytes
	_slices[id] = out
	return out


func _play_stream(s: AudioStream, pitch: float, gain := 1.0) -> AudioStreamPlayer:
	var i := _next
	_next = (_next + 1) % POOL
	if _tweens[i] != null:
		_tweens[i].kill()
		_tweens[i] = null
	var p := _players[i]
	p.stream = s
	p.pitch_scale = pitch
	p.volume_db = linear_to_db(maxf(gain, 0.0001))
	p.play()
	return p


## Any stream from `start` for `dur` seconds, then a short fade (replacement files
## may be OGG or MP3, which cannot be cut into a new stream like a WAV).
func _play_span(s: AudioStream, start: float, dur: float, gain: float) -> void:
	if dur <= 0.0:
		return
	var i := _next
	var p := _play_stream(s, 1.0, gain)
	p.seek(start)
	var t := create_tween()
	t.tween_interval(dur)
	t.tween_property(p, "volume_db", -60.0, TearSlicer.FADE)
	t.tween_callback(p.stop)
	_tweens[i] = t


## Frames in a WAV stream, whatever its format.
static func loop_frames(s: AudioStreamWAV) -> int:
	return roundi(s.get_length() * s.mix_rate)


static func _looped(s: AudioStream) -> AudioStream:
	var loop := s.duplicate()
	if loop is AudioStreamWAV:
		loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
		loop.loop_begin = 0
		# The whole sound, in frames. Not from data.size(): the engine's sounds are
		# imported compressed (QOA), so bytes say nothing about length (until M7 the
		# motor looped only its first 0.2 s this way).
		loop.loop_end = loop_frames(loop)
	elif loop is AudioStreamOggVorbis or loop is AudioStreamMP3:
		loop.loop = true
	return loop
