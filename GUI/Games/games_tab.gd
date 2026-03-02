class_name GamesTab
extends HSplitContainer

var _current_game:UserGame = null
var _viewing_contact_id:int = -1

@onready var game_list_content:VBoxContainer = %GameListContent
@onready var right_panel:VBoxContainer = %RightPanel
@onready var no_selection_label:Label = %NoSelectionLabel
@onready var game_editor_panel:VBoxContainer = %GameEditorPanel
@onready var game_name_field:LineEdit = %GameNameField
@onready var game_delete_button:Button = %GameDeleteButton
@onready var tags_container:FlowContainer = %GameTagsContainer
@onready var contact_view_panel:VBoxContainer = %ContactViewPanel
@onready var contact_view_title:Label = %ContactViewTitle
@onready var events_list:VBoxContainer = %EventsList
@onready var add_game_button:Button = %AddGameButton
@onready var game_save_button:Button = %GameSaveButton
@onready var back_button:Button = %BackButton


func _ready()-> void:
	add_game_button.pressed.connect(_on_add_game_pressed)
	game_save_button.pressed.connect(_on_game_save_pressed)
	game_delete_button.pressed.connect(_on_game_delete_pressed)
	back_button.pressed.connect(_on_back_pressed)
	Database.games_changed.connect(_rebuild_game_list)
	Database.contacts_changed.connect(_rebuild_game_list)
	Database.events_changed.connect(_on_events_changed)
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
	for c in container.get_children().slice(1):
		container.remove_child(c)

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
	game_editor_panel.visible = true
	contact_view_panel.visible = false
	_show_right_panel(true)
	game_name_field.text = _current_game.name
	game_delete_button.disabled = false
	_refresh_game_tags()


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


func _on_contact_game_selected(contact_id:int, game_id:int)-> void:
	_current_game = Database.get_user_game(game_id)
	_viewing_contact_id = contact_id
	game_editor_panel.visible = false
	contact_view_panel.visible = true
	_show_right_panel(true)
	var contact = Database.get_contact(contact_id)
	if contact == null: return
	contact_view_title.text = "%s — %s" % [contact.name, _current_game.name if _current_game else ""]
	_refresh_events()


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
			var panel = PanelContainer.new()
			var vbox = VBoxContainer.new()
			panel.add_child(vbox)
			var header = Label.new()
			header.text = "[%s] %s" % [event.kind_name, event.datetime]
			if not event.channel.is_empty():
				header.text += " via " + event.channel
			header.modulate = Color.CORNFLOWER_BLUE
			vbox.add_child(header)
			if not event.content_text.is_empty():
				var body = Label.new()
				body.text = event.content_text
				body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				vbox.add_child(body)
			if not event.content_link.is_empty():
				var link_lbl = Label.new()
				link_lbl.text = "Link: " + event.content_link
				link_lbl.modulate = Color(0.6, 0.8, 1.0)
				vbox.add_child(link_lbl)
			var del_btn = Button.new()
			del_btn.text = "Delete event"
			var event_id = event.id
			del_btn.pressed.connect(func(): Database.delete_contact_event(event_id))
			vbox.add_child(del_btn)
			events_list.add_child(panel)

	var contact = Database.get_contact(_viewing_contact_id)
	if contact == null: return
	var task = TasksManager._get_task_for_contact_game(contact, _current_game)
	if task != null:
		events_list.add_child(HSeparator.new())
		var suggestion = Label.new()
		var status = "PENDING" if task.status == Task.Status.Pending else "WAITING"
		suggestion.text = "Suggested: [%s] %s" % [status, task.description]
		suggestion.modulate = Color.YELLOW
		suggestion.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		events_list.add_child(suggestion)


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
	game_editor_panel.visible = true
	contact_view_panel.visible = false
	game_name_field.text = ""
	game_delete_button.disabled = true
	_refresh_game_tags()
	_show_right_panel(true)
	game_name_field.grab_focus()


func _on_game_save_pressed()-> void:
	if _current_game == null: return
	var trimmed = game_name_field.text.strip_edges()
	if trimmed.is_empty(): return
	_current_game.name = trimmed
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
	game_editor_panel.visible = true
	contact_view_panel.visible = false
