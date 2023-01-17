tool
extends VBoxContainer

enum {
	STATUS_UNDOC,
	STATUS_HAS_MD_CODEBLOCKS,
	STATUS_UNDOC_UNDERSCORED,
	STATUS_DONE,
	STATUS_MAX,
}

export(Array, String) var legend_labels := []
export(Array, Color) var legend_colors := []

onready var legend_item := $"Legend/Box"
onready var legend_container := $"Legend"
onready var tree := $"Panel/Tree"

var	plugin : EditorPlugin

var folders_to_scan := ["res://addons/wyvernbox/"]
var show_props := []
var show_funcs := []

var script_members := {}
var status_counts := {}


func _ready():
	if get_viewport().get_parent() != null: return
	for i in legend_labels.size():
		var new_node = legend_item.duplicate()
		legend_container.add_child(new_node)

		new_node.get_node("Color").color = legend_colors[i]
		new_node.get_node("Label").text = legend_labels[i]
		new_node.get_node("P").connect("toggled", self, "_on_prop_category_toggled", [i])
		new_node.get_node("F").connect("toggled", self, "_on_func_category_toggled", [i])
		show_props.append(true)
		show_funcs.append(true)

	connect("visibility_changed", self, "_on_visibility_changed")

	if ProjectSettings.has_setting("addons/docs_checklist/base_dir"):
		$"Box/Folder".text = ProjectSettings.get_setting("addons/docs_checklist/base_dir")

	_fill_tree()
	legend_item.hide()


func _exit_tree():
	legend_item.free()


func _fill_tree():
	$"Box/Folder".text = "res://" + $"Box/Folder".text.trim_suffix("/").trim_prefix("res://") + "/"
	ProjectSettings.set_setting("addons/docs_checklist/base_dir", $"Box/Folder".text)

	var dir = Directory.new()
	var folder_queue = []
	var cur_folder = $"Box/Folder".text

	tree.clear()
	tree.create_item()
	status_counts.clear()

	while true:
		dir.open(cur_folder)
		dir.list_dir_begin(true, true)
		while true:
			var cur_item = dir.get_next()
			if cur_item == "":
				break

			if dir.dir_exists(cur_folder + cur_item):
				folder_queue.append(cur_folder + cur_item + "/")

			elif cur_item.ends_with(".gd"):
				var loaded = load(cur_folder + cur_item)
				if loaded is Script:
					_add_script_to_tree(loaded)

		if folder_queue.size() == 0:
			break

		else:
			cur_folder = folder_queue.pop_back()

	var total_members := 0.0
	for k in status_counts:
		total_members += status_counts[k]

	print(status_counts)
	for k in status_counts:
		legend_container.get_child(k + 1).get_node("Label").text = "%s (%.2f%s)" % [
			legend_labels[k],
			status_counts[k] / total_members * 100.0,
			"%",
		]


func _add_script_to_tree(script_to_add):
	var tree_node = tree.create_item()
	tree_node.set_text(0, script_to_add.resource_path.get_file())
	tree_node.set_metadata(0, script_to_add)
	script_members[script_to_add] = []

	if script_to_add is GDScript:
		_scan_script(script_to_add, script_members[script_to_add], tree_node, GDScript)


func _scan_script(scan_script, member_array, tree_node, script_type):
	var script_status := 9999999
	var lines = scan_script.source_code.split('\n')
	var member_status := STATUS_UNDOC

	var x := ""
	var member_name := ""
	var actual_name_start := 0
	for i in lines.size():
		x = lines[i]
		if is_line_comment(x, script_type):
			if member_status == STATUS_UNDOC:
				member_status = STATUS_DONE if !"`" in x else STATUS_HAS_MD_CODEBLOCKS

			elif member_status == STATUS_DONE && "`" in x:
				member_status = STATUS_HAS_MD_CODEBLOCKS

		elif is_line_func(x, script_type):
			actual_name_start = 5
			member_name = x.substr(0, x.find("(", actual_name_start)) + "()"
			if member_status == STATUS_UNDOC && member_name[actual_name_start] == "_":
				member_status = STATUS_UNDOC_UNDERSCORED

			script_status = min(script_status, member_status)
			_add_script_member(member_name, true, scan_script, i, member_status, member_array, tree_node)
			member_status = STATUS_UNDOC

		elif is_line_prop(x, script_type):
			actual_name_start = x.find("var ") + 4
			member_name = x.substr(0, x.find(" ", actual_name_start))
			if member_status == STATUS_UNDOC && member_name[actual_name_start] == "_":
				member_status = STATUS_UNDOC_UNDERSCORED

			script_status = min(script_status, member_status)
			_add_script_member(member_name, false, scan_script, i, member_status, member_array, tree_node)
			member_status = STATUS_UNDOC

		elif !is_line_comment(x, script_type):
			member_status = STATUS_UNDOC

	if script_status < STATUS_MAX:
		tree_node.set_custom_color(0, legend_colors[script_status])


func is_line_comment(line, script_type):
	match script_type:
		GDScript: return line.begins_with("#")


func is_line_func(line, script_type):
	match script_type:
		GDScript: return line.begins_with("func ")


func is_line_prop(line, script_type):
	match script_type:
		GDScript: return line.begins_with("var ") || " var " in line


func _add_script_member(name, is_func, script_res, loc, status, member_array, node_parent):
	status_counts[status] = status_counts.get(status, 0) + 1
	if is_func:
		if !show_funcs[status]: return

	else:
		if !show_props[status]: return

	var tree_node = tree.create_item(node_parent)
	tree_node.set_text(0, name)
	tree_node.set_metadata(0, {"script" : script_res, "loc" : loc + 1})
	tree_node.set_custom_color(0, legend_colors[status])
	member_array.append(tree_node)


func _on_prop_category_toggled(toggled, index):
	show_props[index] = toggled
	_fill_tree()


func _on_func_category_toggled(toggled, index):
	show_funcs[index] = toggled
	_fill_tree()


func _on_visibility_changed():
	if is_visible_in_tree(): _fill_tree()


func _on_Tree_item_activated():
	var meta = tree.get_selected().get_metadata(0)
	plugin.get_editor_interface().edit_script(meta["script"], meta["loc"])


func _on_Refresh_pressed():
	_fill_tree()
