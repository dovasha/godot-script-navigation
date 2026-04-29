@tool
extends EditorPlugin

const SCRIPT_NAVIGATION := preload("res://addons/script-navigation-tabs/script_navigation.tscn")
var script_nav_panel: Control

func _enter_tree() -> void:
	script_nav_panel = SCRIPT_NAVIGATION.instantiate()
	script_nav_panel.enter()
	
func _exit_tree() -> void:
	script_nav_panel.exit()
	script_nav_panel = null
