tool
extends EditorPlugin

var dock = load("res://addons/docs_checklist/main.tscn").instance()


func _enter_tree():
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, dock)
	dock.plugin = self


func _exit_tree():
	remove_control_from_docks(dock)
	dock.queue_free()
