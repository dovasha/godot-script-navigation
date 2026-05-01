@tool
class_name ScriptNavPanel extends VSplitContainer

enum Tabs { REGIONS, BOOKMARKS }

const HIDE_REGIONS_TAB := false
const HIDE_BOOKMARKS_TAB := false

const REGIONS_ICON = preload("res://addons/script-navigation-tabs/icons/regions.svg")
const BOOKMARK_ICON = preload("res://addons/script-navigation-tabs/icons/bookmark.svg")

# Child Node References
@export var tab_container: TabContainer
@export var regions_tree: Tree
@export var bookmarks_list: ScriptNavBookmarksList

# Editor References
var script_editor: ScriptEditor = EditorInterface.get_script_editor()
var code_edit: CodeEdit


#region Setup
func _ready() -> void:
	# Configure Regions and Bookmarks tab icons
	var tab_bar: TabBar = tab_container.get_tab_bar()
	tab_bar.set_tab_icon(Tabs.REGIONS, REGIONS_ICON)
	tab_bar.set_tab_icon_max_width(Tabs.REGIONS, 15)
	tab_bar.set_tab_icon(Tabs.BOOKMARKS, BOOKMARK_ICON)
	tab_bar.set_tab_icon_max_width(Tabs.BOOKMARKS, 12)
	
	tab_bar.set_tab_hidden(Tabs.REGIONS, HIDE_REGIONS_TAB)
	tab_bar.set_tab_hidden(Tabs.BOOKMARKS, HIDE_BOOKMARKS_TAB)
	
	# Select the first visible tab
	tab_bar.current_tab = -1
	for tab in tab_bar.get_tab_count():
		if not tab_bar.is_tab_hidden(tab):
			tab_bar.current_tab = tab
			tab_container.deselect_enabled = false
			break
	
	# Lock horizontal scrolling on the bookmarks tab
	var h_scroll: HScrollBar = tab_container.get_tab_control(Tabs.BOOKMARKS).get_h_scroll_bar()
	h_scroll.connect(&"value_changed", func(_value): h_scroll.value = 0)
	
	_on_script_changed()
#endregion


#region Items Logic
func _refresh_bookmarks() -> void:
	if not is_instance_valid(code_edit):
		return
		
	# Item Index -> { Line Number: Line Text }
	var entries: Array[Dictionary]
	
	for line in code_edit.get_bookmarked_lines():
		var text := code_edit.get_line(line).strip_edges(true, false)
		entries.append({ "line": line, "text": text })
	
	if bookmarks_list.count == entries.size() \
	and not range(entries.size()).any(
		func(ix): return bookmarks_list.get_bookmark_line(ix) != entries[ix].line \
					  or bookmarks_list.get_bookmark_text(ix) != entries[ix].text ):
		return # Exit early if no changes were made
	
	# Repopulate the ItemList
	bookmarks_list.clear()
	for index in entries.size():
		var entry: Dictionary = entries[index]
		bookmarks_list.add_bookmark(entry.line, entry.text)
	

func _refresh_regions() -> void:
	if not is_instance_valid(code_edit):
		return
	
	var entries: Array[Region] # New entries
	# Region entry indices which have no matching end tag
	var orphans: Array[int] 
	
	for line in code_edit.get_line_count():
		if code_edit.is_line_code_region_start(line):
			# Strip white space and remove regions tag
			var text := code_edit.get_line(line)\
						.strip_edges(true, false)\
						.trim_prefix('#' + code_edit.get_code_region_start_tag())
						
			# New regions are intrinsically orphans
			orphans.append(entries.size())
			entries.append(Region.new(line, text))
			
		elif code_edit.is_line_code_region_end(line):
			if orphans.is_empty(): continue
			
			var last_orphan := orphans.pop_back()
			entries[last_orphan].end = line
			
			# Nest entries opened after `last_orphan` since they've all closed by now
			while entries.size() > last_orphan + 1:
				entries[last_orphan].sub_regions.append(entries.pop_at(last_orphan + 1))
	
	# Collapse all entries into a root region
	var regions_root := Region.new(INF, '')
	regions_root.sub_regions = entries
	
	var tree_root := regions_tree.get_root()
	if not tree_root or _is_regions_tree_modified_recursive(tree_root, regions_root):
		regions_tree.clear()
		_populate_regions_tree_recursive(null, regions_root)


func _populate_regions_tree_recursive(root: TreeItem, region: Region) -> void:
	var item := regions_tree.create_item(root)
	item.set_text(0, region.text)
	item.set_tooltip_text(0, region.text)
	item.set_metadata(0, region.start)
	
	for sub in region.sub_regions:
		_populate_regions_tree_recursive(item, sub)


func _is_regions_tree_modified_recursive(root: TreeItem, region: Region) -> bool:
	var child := root.get_first_child()
	var subs: Array[Region] = region.sub_regions
	
	var next_sub := 0 # Next sub-regions child counter
	while child or next_sub < subs.size():
		var sub_region: Region = subs[next_sub] if next_sub < subs.size() else null
		
		# Both have entries, check concurrency then recurse
		if child and sub_region:
			if child.get_text(0) != sub_region.text\
			or child.get_metadata(0) != sub_region.start:
				return true
				
			if _is_regions_tree_modified_recursive(child, sub_region):
				return true # Modification found in recurse
		 # Region has extra entries
		elif not child: return true
		 # Tree has extra entries
		else: return true
		
		child = child.get_next() if child else null
		next_sub += 1
		
	return false
#endregion


#region Events
func _on_script_changed(_script: Script = null) -> void:
	var editor = script_editor.get_current_editor()
	code_edit = editor.get_base_editor() if editor else null
	_refresh_bookmarks()
	_refresh_regions()


func _on_bookmark_selected(index: int) -> void:
	var line_number: int = bookmarks_list.get_bookmark_line(index)
	script_editor.goto_line(line_number)
	code_edit.center_viewport_to_caret()
	
	
func _on_region_selected() -> void:
	var item := regions_tree.get_selected()
	var line_number: int = item.get_metadata(0)
	script_editor.goto_line(line_number)
	code_edit.center_viewport_to_caret()
#endregion


class Region:
	var text: String
	var start: int
	var end: int
	
	var sub_regions: Array[Region]
	
	func _init(r_start: int, r_text: String) -> void: 
		start = r_start
		text = r_text
