extends Node
## Player language (autoload "Lang"). English and Chinese; player text goes through
## tr() with keys in English (locale/ui.csv). Printed ticket copy is pack data and
## is not translated.
##
## The engine's Latin fonts fall back to bundled CJK fonts for Chinese: a pixel font
## next to the LCD faces, a brush-pen hand next to Patrick Hand. All are cut down to
## the characters used by tools/subset_cjk_fonts.py.
##
## Pixel Chinese (G, M6 review): everywhere it is as tall as the capitals of the Latin
## font around it and sits on the same baseline, at the same font size as the English
## (a cut per Latin font: VT323's capitals are 0.56 em, Oswald's 0.81). The menu keeps
## the larger look: the pixel font at 3/4 of full size, text at least size 24
## (LcdStyle.menu_look), through font variations with their own fallback.

const LANGUAGES := ["en", "zh"]
## Shown on the language keys in their own language.
const NAMES := {"en": "ENGLISH", "zh": "中文"}
## Synthetic bold for menu Chinese that asks for it (继续), in em fractions.
const MENU_BOLD := 0.6
const CJK_PIXEL := "res://assets/fonts/cjk-pixel.woff2"
const CJK_PIXEL_LCD := "res://assets/fonts/cjk-pixel-lcd.woff2"
const CJK_PIXEL_COND := "res://assets/fonts/cjk-pixel-cond.woff2"
const CJK_HAND := "res://assets/fonts/cjk-hand.woff2"
const VT323 := "res://assets/fonts/vt323-latin-400-normal.woff2"
const CONDENSED := [
	"res://assets/fonts/oswald-latin-400-normal.woff2",
	"res://assets/fonts/oswald-latin-600-normal.woff2",
	"res://assets/fonts/alfa-slab-one-latin-400-normal.woff2",
]
const HAND := "res://assets/fonts/patrick-hand-latin-400-normal.woff2"

var current := "en"
var _keep := {}   ## path -> Font: holds the fonts so their fallbacks stay set
var _menu_fonts := {}   ## "<latin path>|<bold>" -> FontVariation


func _ready() -> void:
	_apply_fallbacks()


## "" follows the system language; anything else not supported falls back to English.
func set_language(code: String) -> void:
	current = resolve(code, OS.get_locale_language())
	TranslationServer.set_locale(current)
	_resize_texts()


## `latin` with the menu's Chinese as its fallback (see LcdStyle.menu_look).
func menu_font(latin: Font, bold := false) -> Font:
	var key := "%s|%s" % [latin.resource_path, bold]
	if not _menu_fonts.has(key):
		var cjk: Font = _font(CJK_PIXEL)
		if bold:
			var v := FontVariation.new()
			v.base_font = cjk
			v.variation_embolden = MENU_BOLD
			cjk = v
		var f := FontVariation.new()
		f.base_font = latin
		f.fallbacks = [cjk]
		_menu_fonts[key] = f
	return _menu_fonts[key]


static func resolve(code: String, system: String) -> String:
	if LANGUAGES.has(code):
		return code
	return "zh" if system == "zh" else "en"


func _resize_texts() -> void:
	for c in get_tree().get_nodes_in_group(LcdStyle.TEXT_GROUP):
		LcdStyle.resize(c)


func _apply_fallbacks() -> void:
	_fallback(VT323, CJK_PIXEL_LCD)
	for p in CONDENSED:
		_fallback(p, CJK_PIXEL_COND)
	_fallback(HAND, CJK_HAND)


## Sets `latin`'s CJK fallback to `cjk` (replacing any other bundled one).
func _fallback(latin: String, cjk: String) -> void:
	var f := _font(latin)
	var c := _font(cjk)
	if f == null or c == null:
		return
	var ours := [CJK_PIXEL, CJK_PIXEL_LCD, CJK_PIXEL_COND, CJK_HAND]
	var list: Array[Font] = []
	for fb in f.fallbacks:
		if not ours.has(fb.resource_path):
			list.append(fb)
	list.append(c)
	f.fallbacks = list


func _font(path: String) -> Font:
	if not _keep.has(path):
		if not ResourceLoader.exists(path):
			return null
		_keep[path] = load(path)
	return _keep[path]
