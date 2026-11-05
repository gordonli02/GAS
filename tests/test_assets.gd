extends "res://tests/test_case.gd"
## Fonts and audio import and load.

const FONTS := {
	"res://assets/fonts/alfa-slab-one-latin-400-normal.woff2": "Alfa Slab One",
	"res://assets/fonts/oswald-latin-400-normal.woff2": "Oswald",
	"res://assets/fonts/oswald-latin-600-normal.woff2": "Oswald SemiBold",
	"res://assets/fonts/vt323-latin-400-normal.woff2": "VT323",
}
const MACHINE_AUDIO := ["bill_insert", "dispense_loop", "dispense_stop", "machine_button"]


func test_fonts_import() -> void:
	for path in FONTS:
		var f = load(path)
		if not check(f is FontFile, path + " did not import as a font"):
			continue
		eq(f.get_font_name(), FONTS[path], path + " family")
		for ch in "AZ09$©.":
			check(f.has_char(ch.unicode_at(0)), "%s missing glyph '%s'" % [path, ch])
	var oswald600: FontFile = load("res://assets/fonts/oswald-latin-600-normal.woff2")
	if oswald600:
		eq(oswald600.get_font_weight(), 600, "Oswald 600 weight")


func test_machine_audio_imports() -> void:
	for id in MACHINE_AUDIO:
		var s = load("res://assets/audio/%s.wav" % id)
		if check(s is AudioStreamWAV, id + " did not import"):
			check(s.get_length() > 0.05, id + " is empty")
			note("%s: %.2f s, %d Hz, %s" % [id, s.get_length(), s.mix_rate, "stereo" if s.stereo else "mono"])


func test_pack_tear_clips_load_at_runtime() -> void:
	var pack := core_pack()
	if pack == null:
		return
	for c in pack.tear_clips:
		var s := PackAssets.audio(c.path)
		if check(s is AudioStreamWAV, c.path + " failed to load"):
			var last: float = c.marks[c.marks.size() - 1]
			check(s.get_length() > last, "%s: %.3f s but last crackle at %.3f" % [c.path.get_file(), s.get_length(), last])


## The dispenser motor loops the whole recording (until M7 it looped only the first 0.2 s:
## the loop end was taken from the byte count of a QOA-compressed import).
func test_motor_loops_whole_recording() -> void:
	var raw := FileAccess.get_file_as_bytes("res://assets/audio/dispense_loop_fast.wav")
	var frames := 0
	var i := 12
	while i + 8 <= raw.size():
		var id := raw.slice(i, i + 4).get_string_from_ascii()
		var n := raw.decode_u32(i + 4)
		if id == "data":
			frames = n / 2   # 16-bit mono, as recorded
			break
		i += 8 + n + (n % 2)
	check(frames > 40000, "read the recording's length (%d frames)" % frames)
	var loop: AudioStreamWAV = Sfx._motor.stream
	eq(loop.loop_mode, AudioStreamWAV.LOOP_FORWARD, "motor stream loops")
	eq(loop.loop_begin, 0, "from the start")
	check(absi(loop.loop_end - frames) <= 2, "to the end: loop_end %d, recording %d frames" % [loop.loop_end, frames])
	# A developer's 16-bit replacement: the same rule gives the same answer as its bytes.
	var pcm := AudioStreamWAV.new()
	pcm.format = AudioStreamWAV.FORMAT_16_BITS
	pcm.mix_rate = 22050
	var data := PackedByteArray()
	data.resize(22050 * 2)
	pcm.data = data
	eq(Sfx.loop_frames(pcm), 22050, "a 1 s PCM file loops over 22050 frames")
