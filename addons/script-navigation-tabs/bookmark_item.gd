@tool
class_name ScriptNavBookmarkItem extends HBoxContainer

const HOVERED_OFFSET := 3.0
signal clicked(index: int)

@export var line_label_container: CenterContainer
@export var line_label: RichTextLabel
@export var text_label: TextEdit

var hover_color: Color = Color.BLACK

var line: int:
	set(value):
		line = value
		line_label.text = str(line + 1)
		
var text: String:
	set(value):
		text = value
		text_label.text = text


#region Built-ins
func _ready() -> void:
	set_process(false)
	_on_theme_changed()
	
	# Use the GDScript syntax highlighter in version 4.4 and above
	if ClassDB.can_instantiate("GDScriptSyntaxHighlighter"):
		text_label.syntax_highlighter = ClassDB.instantiate("GDScriptSyntaxHighlighter")
	
func _process(_delta: float) -> void:
	# Fix for when user scroll while hovering. Keeps the item anchored to the layout
	text_label.global_position = global_position + Vector2(line_label_container.size.x + HOVERED_OFFSET, 0)
	
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_MOUSE_ENTER: _on_hover(true)
		NOTIFICATION_MOUSE_EXIT:  _on_hover(false)
#endregion	


#region Events
func _on_hover(hovering: bool) -> void:
	custom_minimum_size = size if hovering else Vector2.ZERO
	text_label.top_level = hovering
	set_process(hovering)
	
	if hovering:
		text_label.add_theme_color_override(&"background_color", hover_color)
	else:
		# Force a layout update to reposition nodes
		text_label.get_parent().queue_sort()
		text_label.remove_theme_color_override(&"background_color")
			

func _on_gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton
	and event.button_index == MOUSE_BUTTON_LEFT
	and event.pressed):
		clicked.emit(get_index())


func _on_theme_changed() -> void:
	# Manually fit width to content, since TextEdit's "scroll_fit_content_width"
	# was only added in Godot 4.4 and isn't available in 4.3 or below
	var font := text_label.get_theme_font("font")
	var font_size := text_label.get_theme_font_size("font_size")
	var stylebox := text_label.get_theme_stylebox("normal")
	text_label.custom_minimum_size.x = ceil(
			font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x 
			+ stylebox.content_margin_left
			+ stylebox.content_margin_right )
			
	# Set hover color to the normal panel's colour, and make it full opacity and darker
	var sb := get_theme_stylebox(&"normal", &"TextEdit")
	if sb is StyleBoxFlat:
		hover_color = Color((sb as StyleBoxFlat).bg_color, 1.0).darkened(0.25)
#endregion
