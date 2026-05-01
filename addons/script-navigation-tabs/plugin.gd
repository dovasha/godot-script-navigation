@tool
extends EditorPlugin

const SCRIPT_NAVIGATION := preload("res://addons/script-navigation-tabs/script_navigation.tscn")

var script_editor: ScriptEditor = EditorInterface.get_script_editor()
var script_nav_panel: ScriptNavPanel

var side_panel: VSplitContainer
var methods_panel: VBoxContainer


func _enter_tree() -> void:
	script_nav_panel = SCRIPT_NAVIGATION.instantiate()
	
	script_editor.connect(&"editor_script_changed", script_nav_panel._on_script_changed)
	if not script_editor.visible:
		await script_editor.visibility_changed
	
	# Find ScriptEditor's side panel, which is the first 'VSplitContainer'
	side_panel = script_editor.find_children("", "VSplitContainer", true, false)[0]
	methods_panel = side_panel.get_child(1) # Keep a reference to the built-in Methods list
	
	# Add the new panel to the ScriptEditor
	side_panel.remove_child(methods_panel)
	side_panel.add_child(script_nav_panel)
	
	# Reparent Methods list to the new panel
	script_nav_panel.add_child(methods_panel)
	script_nav_panel.move_child(methods_panel, 0)
	
	_on_theme_changed()
	script_editor.connect(&"theme_changed", _on_theme_changed)


func _exit_tree() -> void:
	script_editor.disconnect(&"theme_changed", _on_theme_changed)
	script_editor.disconnect(&"editor_script_changed", script_nav_panel._on_script_changed)
	
	# Restore Original Layout
	script_nav_panel.remove_child(methods_panel)
	script_nav_panel.queue_free()
	side_panel.add_child(methods_panel)
	
	
func _on_theme_changed() -> void:
	await get_tree().process_frame
	# The sidebar uses a custom panel stylebox that differs from the base editor theme 
	# Reuse it so our panel matches the rest of the side panel visually
	var panel_style: StyleBox = methods_panel.find_children("", "ItemList", true, false)[0].get_theme_stylebox(&"panel")
	script_nav_panel.theme.set_stylebox(&"panel", &"ScrollContainer", panel_style)
