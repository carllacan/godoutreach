class_name ContactsTab
extends HSplitContainer

var _current_contact:Contact = null

@onready var contact_list_content:VBoxContainer = %ContactListContent
@onready var editor_panel:VBoxContainer = %EditorPanel
@onready var name_field:LineEdit = %NameField
@onready var category_field:OptionButton = %CategoryField
@onready var language_field:LineEdit = %LanguageField
@onready var abandoned_check:CheckBox = %AbandonedCheck
@onready var tags_container:FlowContainer = %TagsContainer
@onready var notes_field:TextEdit = %NotesField
@onready var delete_button:Button = %DeleteButton
@onready var tasks_list:VBoxContainer = %TasksList
@onready var no_selection_label:Label = %NoSelectionLabel
@onready var add_contact_button:Button = %AddContactButton
@onready var save_button:Button = %SaveButton


func _ready()-> void:
	add_contact_button.pressed.connect(_on_add_contact_pressed)
	save_button.pressed.connect(_on_save_pressed)
	delete_button.pressed.connect(_on_delete_pressed)
	Database.contacts_changed.connect(_rebuild_contact_list)
	Database.settings_changed.connect(_refresh_categories)
	Database.events_changed.connect(_refresh_tasks)
	_rebuild_contact_list()
	_refresh_categories()
	_show_editor(false)


func _rebuild_contact_list()-> void:
	for child in contact_list_content.get_children():
		child.queue_free()

	for contact in Database.get_all_contacts():
		var entry = ContactListEntry.create(contact)
		entry.contact_selected.connect(_on_contact_selected)
		contact_list_content.add_child(entry)

	if _current_contact != null:
		var refreshed = Database.get_contact(_current_contact.id)
		if refreshed != null:
			_load_contact(refreshed)
		else:
			_current_contact = null
			_show_editor(false)


func _on_contact_selected(id:int)-> void:
	var contact = Database.get_contact(id)
	if contact == null: return
	_load_contact(contact)
	_show_editor(true)


func _load_contact(contact:Contact)-> void:
	_current_contact = contact
	name_field.text = contact.name
	language_field.text = contact.language
	abandoned_check.button_pressed = contact.abandoned
	notes_field.text = contact.notes
	delete_button.disabled = false
	_refresh_categories()
	_refresh_tags()
	_refresh_tasks()


func _refresh_categories()-> void:
	category_field.clear()
	category_field.add_item("(none)", -1)
	for cat in Database.get_all_contact_categories():
		category_field.add_item(cat.name, cat.id)
	if _current_contact == null: return
	for i in category_field.item_count:
		if category_field.get_item_id(i) == _current_contact.category_id:
			category_field.select(i)
			break


func _refresh_tags()-> void:
	for child in tags_container.get_children():
		child.queue_free()
	if _current_contact == null: return
	for tag in Database.get_all_tags():
		var cb = CheckBox.new()
		cb.text = tag.name
		cb.button_pressed = tag.id in _current_contact.tag_ids
		var tag_id = tag.id
		cb.toggled.connect(func(pressed:bool): _on_tag_toggled(tag_id, pressed))
		tags_container.add_child(cb)


func _on_tag_toggled(tag_id:int, pressed:bool)-> void:
	if _current_contact == null: return
	if pressed and not (tag_id in _current_contact.tag_ids):
		_current_contact.tag_ids.append(tag_id)
	elif not pressed:
		_current_contact.tag_ids.erase(tag_id)


func _refresh_tasks()-> void:
	for child in tasks_list.get_children():
		child.queue_free()
	if _current_contact == null: return
	var tasks = TasksManager.get_tasks_for_contact(_current_contact)
	if tasks.is_empty():
		var lbl = Label.new()
		lbl.text = "No pending tasks."
		lbl.modulate = Color(1, 1, 1, 0.5)
		tasks_list.add_child(lbl)
		return
	for task in tasks:
		tasks_list.add_child(TaskSmallView.create(task))


func _show_editor(show:bool)-> void:
	editor_panel.visible = show
	no_selection_label.visible = not show


func _on_add_contact_pressed()-> void:
	_current_contact = Contact.new()
	name_field.text = ""
	language_field.text = ""
	abandoned_check.button_pressed = false
	notes_field.text = ""
	delete_button.disabled = true
	_refresh_categories()
	_refresh_tags()
	_refresh_tasks()
	_show_editor(true)
	name_field.grab_focus()


func _on_save_pressed()-> void:
	if _current_contact == null: return
	var trimmed = name_field.text.strip_edges()
	if trimmed.is_empty(): return
	_current_contact.name = trimmed
	_current_contact.language = language_field.text.strip_edges()
	_current_contact.abandoned = abandoned_check.button_pressed
	_current_contact.notes = notes_field.text
	_current_contact.category_id = category_field.get_selected_id()
	Database.save_contact(_current_contact)


func _on_delete_pressed()-> void:
	if _current_contact == null or _current_contact.id == -1: return
	var dialog = ConfirmationDialog.new()
	dialog.dialog_text = "Delete contact '%s'? This will also delete all their events." % _current_contact.name
	dialog.confirmed.connect(func():
		Database.delete_contact(_current_contact.id)
		_current_contact = null
		_show_editor(false)
	)
	add_child(dialog)
	dialog.popup_centered()
