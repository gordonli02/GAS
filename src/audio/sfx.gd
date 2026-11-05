extends Node
## Sound effects (autoload "Sfx"). Owns a small pool of players, the engine's
## recorded and baked sounds, and tear-rip slicing for pack rips.

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
	"dispense_stop": "res://assets/audio/dispense_stop.wav",
}
const POOL := 16
const DEFAULT_MASTER := 0.8

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _slices := {}   ## cache: "<path>|<start>|<end>" -> AudioStreamWAV


func _ready() -> void:
	for id in SOUNDS:
		_streams[id] = load(SOUNDS[id])
	for i in POOL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	set_master(DEFAULT_MASTER)


func set_master(linear: float) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(linear, 0.0001)))


func play(id: String, pitch := 1.0) -> void:
	var s: AudioStream = _streams.get(id)
	if s:
		_play_stream(s, pitch)


## Win jingle length follows the prize, as in the web build.
func play_win(prize: int) -> void:
	play("win_8" if prize >= 50 else "win_5" if prize >= 10 else "win_3" if prize >= 5 else "win_2")


## Plays the part of a rip between the crackles that progress just crossed.
## clip: {path, marks} from a pack.
func play_tear_slice(clip: Dictionary, from_step: int, to_step: int, steps: int) -> void:
	var src := PackAssets.audio(clip.path) as AudioStreamWAV
	if src == null:
		return
	var span := TearSlicer.slice(clip.marks, src.get_length(), from_step, to_step, steps)
	if span.x < 0:
		return
	_play_stream(_slice(src, clip.path, span.x, span.y), 1.0)


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


func _play_stream(s: AudioStream, pitch: float) -> void:
	var p := _players[_next]
	_next = (_next + 1) % POOL
	p.stream = s
	p.pitch_scale = pitch
	p.play()
