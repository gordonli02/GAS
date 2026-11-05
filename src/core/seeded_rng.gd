class_name SeededRng
extends RefCounted
## Seeded generator ported bit for bit from the web build:
## a string hash (cyrb128-style) seeds sfc32, then 12 warm-up draws.
## All state is kept as unsigned 32-bit values inside 64-bit ints.

const MASK := 0xFFFFFFFF

var _a := 0
var _b := 0
var _c := 0
var _d := 0


func _init(seed_text: String) -> void:
	var h := _Hasher.new(seed_text)
	_a = h.next()
	_b = h.next()
	_c = h.next()
	_d = h.next()
	for i in 12:
		next_float()


## Uniform float in [0, 1), same sequence as the JS `r()`.
func next_float() -> float:
	var t := (((_a + _b) & MASK) + _d) & MASK
	_d = (_d + 1) & MASK
	_a = _b ^ (_b >> 9)
	_b = (_c + ((_c << 3) & MASK)) & MASK
	_c = ((_c << 21) & MASK) | (_c >> 11)
	_c = (_c + t) & MASK
	return float(t) / 4294967296.0


## Integer in [0, n), same as the JS `int(r, n)`.
func next_int(n: int) -> int:
	return int(floor(next_float() * n))


## In-place Fisher-Yates, same draw order as the JS `shuffle`.
func shuffle(list: Array) -> Array:
	var i := list.size() - 1
	while i > 0:
		var j := next_int(i + 1)
		var tmp = list[i]
		list[i] = list[j]
		list[j] = tmp
		i -= 1
	return list


## 32-bit multiply keeping the low 32 bits, like Math.imul (unsigned result).
static func imul(a: int, b: int) -> int:
	a &= MASK
	b &= MASK
	var lo := (a * (b & 0xFFFF)) & MASK
	var hi := ((a * (b >> 16)) & 0xFFFF) << 16
	return (lo + hi) & MASK


class _Hasher:
	var h := 0

	func _init(text: String) -> void:
		# JS hashes UTF-16 code units, so do the same.
		var units := text.to_utf16_buffer()
		var count := units.size() / 2
		h = 1779033703 ^ count
		for i in count:
			var cu := units[i * 2] | (units[i * 2 + 1] << 8)
			h = SeededRng.imul(h ^ cu, 3432918353)
			h = ((h << 13) & SeededRng.MASK) | (h >> 19)

	func next() -> int:
		h = SeededRng.imul(h ^ (h >> 16), 2869860233)
		h = SeededRng.imul(h ^ (h >> 13), 3266489909)
		h = h ^ (h >> 16)
		return h & SeededRng.MASK
