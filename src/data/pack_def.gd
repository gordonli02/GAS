class_name PackDef
extends RefCounted
## A loaded, validated data pack. Holds data only; assets are loaded on demand
## through PackAssets so a pack can never bring code into the game.

var format := 0
var id := ""
var version := ""
var name := {}             ## localized text: {"en": "...", "zh": "..."}
var author := ""
var dir := ""              ## absolute or res:// directory of the pack
var forms: Array = []      ## FormDef
var tear_clips: Array = [] ## {path: String, marks: PackedFloat32Array}


func form(form_id: String) -> FormDef:
	for f in forms:
		if f.id == form_id:
			return f
	return null
