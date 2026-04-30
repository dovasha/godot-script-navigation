@tool
extends VSplitContainer

const REGIONS_ICON = preload("res://addons/script-navigation-tabs/icons/regions.svg")
const BOOKMARK_ICON = preload("res://addons/script-navigation-tabs/icons/bookmark.svg")

@export var tab_container: TabContainer
@export var regions_list: ItemList
@export var bookmarks_list: ItemList

# Editor References
var script_editor: ScriptEditor
var side_panel: VSplitContainer
var methods_panel: VBoxContainer
var code_edit: CodeEdit


#region Setup
func enter() -> void:
	var tab_bar: TabBar = tab_container.get_tab_bar()
	tab_bar.set_tab_icon(0, REGIONS_ICON); tab_bar.set_tab_icon_max_width(0, 15)
	tab_bar.set_tab_icon(1, BOOKMARK_ICON); tab_bar.set_tab_icon_max_width(1, 12)
	
	script_editor = EditorInterface.get_script_editor()
	script_editor.connect(&"editor_script_changed", _on_script_changed)
	await script_editor.visible

	# Find ScriptEditor's side panel, which is the first 'VSplitContainer'
	side_panel = script_editor.find_children("", "VSplitContainer", true, false)[0]
	
	# Keep a reference to the built-in Methods list
	methods_panel = side_panel.get_child(1)
	side_panel.remove_child(methods_panel)
	add_child(methods_panel)
	move_child(methods_panel, 0)
	
	_on_script_changed()
	side_panel.add_child(self)

func exit() -> void:
	script_editor.disconnect(&"editor_script_changed", _on_script_changed)
	
	# Restore original layout
	methods_panel.get_parent().remove_child(methods_panel)
	side_panel.add_child(methods_panel)
	self.queue_free()
#endregion


#region Items logic
func _refresh_list(items: Array, type: StringName) -> void:
	## Refresh the ItemList of the given type, either &"regions" or &"bookmark"
	
	# Item Index -> { Line Number: Line Text }
	var entries: Array[Dictionary] # New entries
	var list: ItemList = get(&"%s_list" % type)
	
	for index in items.size():
		var line: int = items[index]
		var text: String = code_edit.get_line(line)
	
		match type:
			&"regions":	  text = "%d. %s" % [index + 1, text.trim_prefix('#' + code_edit.get_code_region_start_tag())]
			&"bookmarks": text = "%d - %s" % [line + 1, text]
		
		entries.append({ "line": line, "text": text })
	
	
	if list.item_count == entries.size() \
	and not range(entries.size()).any(
		func(ix): return list.get_item_metadata(ix) != entries[ix].line \
					 or list.get_item_text(ix) != entries[ix].text ):
		return # Exit early if no changes were made
				
	# Repopulate the ItemList
	list.clear()
	for index in entries.size():
		var entry: Dictionary = entries[index]
		list.add_item(entry.text)
		list.set_item_tooltip(index, entry.text)
		list.set_item_metadata(index, entry.line)


func _refresh_bookmarks() -> void:
	if not is_instance_valid(code_edit):
		return
	
	var bookmark_lines := code_edit.get_bookmarked_lines()
	_refresh_list( bookmark_lines, &"bookmarks" )
	_set_current_selection(bookmarks_list)


func _refresh_regions() -> void:
	if not is_instance_valid(code_edit):
		return
	
	var region_lines: Array = []
	for line in code_edit.get_line_count():
		if code_edit.is_line_code_region_start(line):
			region_lines.append(line)
	
	_refresh_list( region_lines, &"regions" )
	_set_current_selection(regions_list)


func _set_current_selection(list: ItemList):
	for ix in list.item_count:
		if list.get_item_metadata(ix) == code_edit.get_caret_line():
			list.select(ix); return # Select item if caret is on its line
	list.deselect_all()
#endregion


#region Events
func _on_script_changed(_script: Script = null) -> void:
	var editor = script_editor.get_current_editor()
	code_edit = editor.get_base_editor() if editor else null
	_refresh_bookmarks()
	_refresh_regions()


func _on_bookmark_selected(index: int) -> void:
	var line_number: int = bookmarks_list.get_item_metadata(index)
	script_editor.goto_line(line_number)
	code_edit.center_viewport_to_caret()
	
	
func _on_region_selected(index: int) -> void:
	var line_number: int = regions_list.get_item_metadata(index)
	script_editor.goto_line(line_number)
	code_edit.center_viewport_to_caret()
#endregion
