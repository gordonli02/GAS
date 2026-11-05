class_name PackAssets
extends RefCounted
## Loads pack images and audio straight from raw bytes.
## Never uses load()/ResourceLoader, which could pull in scripts embedded in resources.

static var _cache := {}


static func image(path: String) -> Image:
	if _cache.has(path):
		return _cache[path]
	var img := Image.load_from_file(path)
	if img != null:
		_cache[path] = img
	return img


static func texture(path: String) -> ImageTexture:
	var img := image(path)
	return ImageTexture.create_from_image(img) if img != null else null


static func audio(path: String) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	var s: AudioStream = null
	match path.get_extension().to_lower():
		"wav":
			s = AudioStreamWAV.load_from_file(path)
		"ogg":
			s = AudioStreamOggVorbis.load_from_file(path)
		"mp3":
			s = AudioStreamMP3.load_from_file(path)
	if s != null:
		_cache[path] = s
	return s


static func clear_cache() -> void:
	_cache.clear()
