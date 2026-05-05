@tool
class_name ScriptNavBookmarksList extends VBoxContainer
const BOOKMARK_ITEM := preload("res://addons/script-navigation-tabs/bookmark_item.tscn")

signal item_clicked(index: int)

var count:
	get: return get_child_count()

# Editor's ScriptEditor font, JetBrains Mono
var code_font := EditorInterface.get_editor_theme().get_font(&"source", &"EditorFonts")


func clear() -> void:
	for child in get_children():
		child.queue_free()
	

func add_bookmark(line: int, text: String) -> void:
	var item: ScriptNavBookmarkItem = BOOKMARK_ITEM.instantiate()
	
	# Apply ScripEditor font to new entries
	# Uses runtime font overrides so the font isn't baked into the theme resource 
	# Which is necessary to avoid it being 6MB+ and slowing projects
	item.line_label.add_theme_font_override(&"font", code_font)
	item.text_label.add_theme_font_override(&"font", code_font)
	
	item.line = line; item.text = text
	item.connect(&"clicked", _on_item_clicked)
	connect(&"theme_changed", item._on_theme_changed)
	
	add_child(item)


func get_bookmark_line(index: int) -> int:
	return get_child(index).line
	
func get_bookmark_text(index: int) -> String:
	return get_child(index).text


func _on_item_clicked(index: int):
	item_clicked.emit(index)
	
