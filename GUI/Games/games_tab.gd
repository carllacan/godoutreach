class_name GamesTab
extends HSplitContainer

var _current_game:UserGame = null
var _viewing_contact_id:int = -1

@onready var game_list_content:VBoxContainer = %GameListContent
@onready var right_panel:VBoxContainer = %RightPanel
@onready var no_selection_label:Label = %NoSelectionLabel

@onready var add_game_button:Button = %AddGameButton
@onready var game_save_button:Button = %GameSaveButton

@onready var back_button:Button = %BackButton

@onready var editor_scroll:ScrollContainer = %EditorScroll
@onready var game_editor_panel:VBoxContainer = %GameEditorPanel
@onready var game_name_field:LineEdit = %GameNameField
@onready var game_delete_button:Button = %GameDeleteButton
@onready var tags_container:FlowContainer = %GameTagsContainer
@onready var contact_view_panel:VBoxContainer = %ContactViewPanel
@onready var contact_view_title:Label = %ContactViewTitle
@onready var events_list:VBoxContainer = %EventsList
@onready var tasks_list:VBoxContainer = %TasksList


@onready var add_game_tag_field:LineEdit = %AddGameTagField
@onready var add_game_tag_button:Button = %AddGameTagButton

@onready var game_links_container:VBoxContainer = %GameLinksContainer
@onready var add_link_button:Button = %AddLinkButton

@onready var short_descs_container:VBoxContainer = %ShortDescsContainer
@onready var add_short_desc_button:Button = %AddShortDescButton
@onready var long_descs_container:VBoxContainer = %LongDescsContainer
@onready var add_long_desc_button:Button = %AddLongDescButton

@onready var event_panel = %CreateEventPanel


func _ready()-> void:
	add_game_button.pressed.connect(_on_add_game_pressed)
	game_save_button.pressed.connect(_on_game_save_pressed)
	game_delete_button.pressed.connect(_on_game_delete_pressed)
	back_button.pressed.connect(_on_back_pressed)
	add_game_tag_button.pressed.connect(_on_add_game_tag_pressed)
	add_game_tag_field.text_submitted.connect(func(_t:String): _on_add_game_tag_pressed())
	add_link_button.pressed.connect(func(): _add_game_link_row())
	add_short_desc_button.pressed.connect(func(): _add_short_desc_row())
	add_long_desc_button.pressed.connect(func(): _add_long_desc_row())
	Database.games_changed.connect(_rebuild_game_list)
	Database.contacts_changed.connect(_rebuild_game_list)
	Database.events_changed.connect(_on_events_changed)
	Database.settings_changed.connect(_on_settings_changed)
	_rebuild_game_list()
	_show_right_panel(false)


func _rebuild_game_list()-> void:
	for child in game_list_content.get_children():
		child.queue_free()
	for game in Database.get_all_user_games():
		_add_game_to_list(game)
	if _current_game != null:
		var refreshed = Database.get_user_game(_current_game.id)
		if refreshed != null:
			_current_game = refreshed
		else:
			_current_game = null
			_show_right_panel(false)


func _add_game_to_list(game:UserGame)-> void:
	var vbox = VBoxContainer.new()
	vbox.name = "Game_%d" % game.id
	game_list_content.add_child(vbox)

	var header_btn = Button.new()
	header_btn.text = game.name
	header_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var game_id = game.id
	header_btn.pressed.connect(func(): _on_game_header_pressed(game_id, vbox))
	vbox.add_child(header_btn)

	var sublists_container = VBoxContainer.new()
	sublists_container.name = "Sublists"
	sublists_container.visible = false
	vbox.add_child(sublists_container)

	var settings_btn = Button.new()
	settings_btn.text = "  SETTINGS"
	settings_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	settings_btn.flat = true
	settings_btn.pressed.connect(func(): _show_game_editor(game_id))
	sublists_container.add_child(settings_btn)

	_populate_contact_sublists(sublists_container, game)


func _populate_contact_sublists(container:VBoxContainer, game:UserGame)-> void:
	for i in range(container.get_child_count() - 1, 0, -1):
		container.get_child(i).free()

	var categorized = TasksManager.categorize_contacts_for_game(game)
	var sections = [
		["Pending", categorized.pending, "Pending"],
		["Prospect", categorized.prospect, "Prospect"],
		["Waiting", categorized.waiting, "Waiting"],
		["Done", categorized.done, "Done"],
		["Discarded", categorized.discarded, "Discarded"],
	]

	for section_data in sections:
		var contacts:Array = section_data[1]
		if contacts.is_empty(): continue
		var section_name:String = section_data[0]
		var status_label:String = section_data[2]

		var section_vbox = VBoxContainer.new()
		container.add_child(section_vbox)

		var entries_vbox = VBoxContainer.new()
		var section_header = Button.new()
		section_header.text = "  — %s (%d)" % [section_name, contacts.size()]
		section_header.alignment = HORIZONTAL_ALIGNMENT_LEFT
		section_header.flat = true
		section_header.pressed.connect(func(): entries_vbox.visible = not entries_vbox.visible)
		section_vbox.add_child(section_header)
		section_vbox.add_child(entries_vbox)

		for contact in contacts:
			var entry = GameContactEntry.create(contact, game.id, status_label)
			entry.contact_game_selected.connect(_on_contact_game_selected)
			entries_vbox.add_child(entry)


func _on_game_header_pressed(game_id:int, vbox:VBoxContainer)-> void:
	var sublists = vbox.get_node("Sublists")
	sublists.visible = not sublists.visible
	if sublists.visible:
		var game = Database.get_user_game(game_id)
		if game != null:
			_populate_contact_sublists(sublists, game)


func _show_game_editor(game_id:int)-> void:
	_current_game = Database.get_user_game(game_id)
	if _current_game == null: return
	_viewing_contact_id = -1
	editor_scroll.visible = true
	contact_view_panel.visible = false
	_show_right_panel(true)
	game_name_field.text = _current_game.name
	game_delete_button.disabled = false
	_refresh_game_tags()
	_refresh_game_links()
	_refresh_short_descs()
	_refresh_long_descs()


func _refresh_game_tags()-> void:
	for child in tags_container.get_children():
		child.queue_free()
	if _current_game == null: return
	for tag in Database.get_all_tags():
		var cb = CheckBox.new()
		cb.text = tag.name
		cb.button_pressed = tag.id in _current_game.tag_ids
		var tag_id = tag.id
		cb.toggled.connect(func(pressed:bool): _on_game_tag_toggled(tag_id, pressed))
		tags_container.add_child(cb)


func _on_game_tag_toggled(tag_id:int, pressed:bool)-> void:
	if _current_game == null: return
	if pressed and not (tag_id in _current_game.tag_ids):
		_current_game.tag_ids.append(tag_id)
	elif not pressed:
		_current_game.tag_ids.erase(tag_id)


func _on_add_game_tag_pressed()-> void:
	var name = add_game_tag_field.text.strip_edges()
	if name.is_empty(): return
	Database.create_tag(name)
	add_game_tag_field.text = ""


func _on_settings_changed()-> void:
	if _current_game != null and editor_scroll.visible:
		_refresh_game_tags()


func _refresh_game_links()-> void:
	for child in game_links_container.get_children():
		child.queue_free()
	if _current_game == null: return
	for link in _current_game.links:
		_add_game_link_row(link.name, link.link)


func _add_game_link_row(link_name:String = "", link_url:String = "")-> void:
	var row = HBoxContainer.new()
	var name_field = LineEdit.new()
	name_field.placeholder_text = "Label"
	name_field.text = link_name
	name_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var url_field = LineEdit.new()
	url_field.placeholder_text = "URL"
	url_field.text = link_url
	url_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var del_btn = Button.new()
	del_btn.text = "X"
	del_btn.pressed.connect(func(): row.queue_free())
	row.add_child(name_field)
	row.add_child(url_field)
	row.add_child(del_btn)
	game_links_container.add_child(row)


func _collect_game_links()-> Array:
	var result = []
	for row in game_links_container.get_children():
		var fields = row.get_children()
		if fields.size() < 2: continue
		var link = UserGame.GameLink.new()
		link.name = (fields[0] as LineEdit).text.strip_edges()
		link.link = (fields[1] as LineEdit).text.strip_edges()
		if link.name.is_empty() and link.link.is_empty(): continue
		result.append(link)
	return result


func _refresh_short_descs()-> void:
	for child in short_descs_container.get_children():
		child.queue_free()
	if _current_game == null: return
	for desc in _current_game.short_descriptions:
		_add_short_desc_row(desc.content)


func _add_short_desc_row(content:String = "")-> void:
	var row = HBoxContainer.new()
	var text_edit = TextEdit.new()
	text_edit.text = content
	text_edit.custom_minimum_size = Vector2(0, 60)
	text_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	var del_btn = Button.new()
	del_btn.text = "X"
	del_btn.pressed.connect(func(): row.queue_free())
	row.add_child(text_edit)
	row.add_child(del_btn)
	short_descs_container.add_child(row)


func _collect_short_descs()-> Array:
	var result = []
	for row in short_descs_container.get_children():
		var children = row.get_children()
		if children.is_empty(): continue
		var desc = UserGame.GameDescription.new()
		desc.content = (children[0] as TextEdit).text.strip_edges()
		if desc.content.is_empty(): continue
		result.append(desc)
	return result


func _refresh_long_descs()-> void:
	for child in long_descs_container.get_children():
		child.queue_free()
	if _current_game == null: return
	for desc in _current_game.descriptions:
		_add_long_desc_row(desc.content)


func _add_long_desc_row(content:String = "")-> void:
	var row = HBoxContainer.new()
	var text_edit = TextEdit.new()
	text_edit.text = content
	text_edit.custom_minimum_size = Vector2(0, 100)
	text_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	var del_btn = Button.new()
	del_btn.text = "X"
	del_btn.pressed.connect(func(): row.queue_free())
	row.add_child(text_edit)
	row.add_child(del_btn)
	long_descs_container.add_child(row)


func _collect_long_descs()-> Array:
	var result = []
	for row in long_descs_container.get_children():
		var children = row.get_children()
		if children.is_empty(): continue
		var desc = UserGame.GameDescription.new()
		desc.content = (children[0] as TextEdit).text.strip_edges()
		if desc.content.is_empty(): continue
		result.append(desc)
	return result


func _on_contact_game_selected(contact_id:int, game_id:int)-> void:
	_current_game = Database.get_user_game(game_id)
	_viewing_contact_id = contact_id
	editor_scroll.visible = false
	contact_view_panel.visible = true
	_show_right_panel(true)
	var contact = Database.get_contact(contact_id)
	if contact == null: return
	contact_view_title.text = "%s — %s" % [contact.name, _current_game.name if _current_game else ""]
	_refresh_events()
	
	event_panel.contact = contact_id
	event_panel.game = _current_game


func _refresh_events()-> void:
	for child in events_list.get_children():
		child.queue_free()
	if _current_game == null or _viewing_contact_id == -1: return

	var events = Database.get_events_for_contact_game(_viewing_contact_id, _current_game.id)
	if events.is_empty():
		var lbl = Label.new()
		lbl.text = "No events yet."
		lbl.modulate = Color(1, 1, 1, 0.5)
		events_list.add_child(lbl)
	else:
		for event in events:
			events_list.add_child(EventSmallView.create(event))

	for child in tasks_list.get_children():
		child.queue_free()
	var contact = Database.get_contact(_viewing_contact_id)
	if contact == null: return
	var task = TasksManager._get_task_for_contact_game(contact, _current_game)
	if task != null:
		tasks_list.add_child(TaskSmallView.create(task))


func _on_events_changed()-> void:
	if _viewing_contact_id != -1:
		_refresh_events()
	_rebuild_game_list()


func _show_right_panel(show:bool)-> void:
	right_panel.visible = show
	no_selection_label.visible = not show


func _on_add_game_pressed()-> void:
	_current_game = UserGame.new()
	_viewing_contact_id = -1
	editor_scroll.visible = true
	contact_view_panel.visible = false
	game_name_field.text = ""
	game_delete_button.disabled = true
	_refresh_game_tags()
	_refresh_game_links()
	_refresh_short_descs()
	_refresh_long_descs()
	_show_right_panel(true)
	game_name_field.grab_focus()


func _on_game_save_pressed()-> void:
	if _current_game == null: return
	var trimmed = game_name_field.text.strip_edges()
	if trimmed.is_empty(): return
	_current_game.name = trimmed
	_current_game.links = _collect_game_links()
	_current_game.short_descriptions = _collect_short_descs()
	_current_game.descriptions = _collect_long_descs()
	Database.save_user_game(_current_game)


func _on_game_delete_pressed()-> void:
	if _current_game == null or _current_game.id == -1: return
	var dialog = ConfirmationDialog.new()
	dialog.dialog_text = "Delete game '%s'? This will delete all its events." % _current_game.name
	dialog.confirmed.connect(func():
		Database.delete_user_game(_current_game.id)
		_current_game = null
		_show_right_panel(false)
	)
	add_child(dialog)
	dialog.popup_centered()


func _on_back_pressed()-> void:
	editor_scroll.visible = true
	contact_view_panel.visible = false
