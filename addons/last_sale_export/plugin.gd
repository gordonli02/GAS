@tool
extends EditorPlugin
## Editor only. Adds the export step that finishes a build: see LastSaleExport.

var _export := LastSaleExport.new()


func _enter_tree() -> void:
	add_export_plugin(_export)


func _exit_tree() -> void:
	remove_export_plugin(_export)
