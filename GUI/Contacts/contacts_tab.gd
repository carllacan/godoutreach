class_name ContactsTab
extends HSplitContainer

var _current_contact:Contact = null
var _subscribers_label:Label

@onready var contact_list_content:VBoxContainer = %ContactListContent
@onready var editor_panel:VBoxContainer = %EditorPanel
@onready var name_field:LineEdit = %NameField
@onready var email_field:LineEdit = %EmailField
@onready var email_link_button:LinkButton = %EmailLinkButton
@onready var category_field:OptionButton = %CategoryField
@onready var language_field:LineEdit = %LanguageField
@onready var abandoned_check:CheckBox = %AbandonedCheck
@onready var tags_container:FlowContainer = %TagsContainer
@onready var notes_field:TextEdit = %NotesField
@onready var delete_button:Button = %DeleteButton
@onready var links_container:VBoxContainer = %LinksContainer
@onready var add_link_button:Button = %AddLinkButton
@onready var tasks_list:VBoxContainer = %TasksList
@onready var no_selection_label:Label = %NoSelectionLabel
@onready var add_contact_button:Button = %AddContactButton
@onready var channel_name_label:Label = %ChannelNameLabel
@onready var channel_description_label:Label = %ChannelDescriptionLabel

@onready var edit_button:Button = %EditButton
@onready var save_button:Button = %SaveButton

@onready var latest_activity_label:Label = %LatestActivityLabel
@onready var youtube_videos:VBoxContainer = %YoutubeVideos


func _ready()-> void:
	add_contact_button.pressed.connect(_on_add_contact_pressed)
	edit_button.pressed.connect(_on_edit_pressed)
	save_button.pressed.connect(_on_save_pressed)
	email_field.text_changed.connect(_on_email_changed)
	email_link_button.pressed.connect(func(): OS.shell_open("mailto:" + email_field.text.strip_edges()))
	delete_button.pressed.connect(_on_delete_pressed)
	add_link_button.pressed.connect(func(): _add_link_row())
	Database.contacts_changed.connect(_rebuild_contact_list)
	Database.settings_changed.connect(_refresh_categories)
	Database.events_changed.connect(_refresh_tasks)
	YoutubeFetcher.fetch_completed.connect(_on_youtube_fetch_completed)
	
	%ImportContactsButton.pressed.connect(_open_import_window)
	
	# SubscribersAmountLabel is not marked unique — navigate from LatestActivityLabel's parent (YoutubeInfo)
	_subscribers_label = %LatestActivityLabel.get_parent().get_parent().get_node(
		"HBoxContainer3/SubscribersAmountLabel"
	) as Label
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
	if _current_contact and _current_contact.id == id: return
	_load_contact(contact)
	_show_editor(true)
	%ContactFullView.mode = ContactFullView.Mode.READ
	

func _load_contact(contact:Contact)-> void:
	_current_contact = contact
	name_field.text = contact.name
	email_field.text = contact.email
	_on_email_changed(contact.email)
	language_field.text = contact.language
	abandoned_check.button_pressed = contact.abandoned
	notes_field.text = contact.notes
	delete_button.disabled = false
	_refresh_categories()
	_refresh_tags()
	_refresh_links()
	_refresh_tasks()
	Database.load_contact_youtube(contact)
	_refresh_youtube()


func _refresh_categories()-> void:
	category_field.clear()
	category_field.add_item("(none)", -1)
	for cat in Database.get_all_contact_categories():
		category_field.add_item(cat.name, cat.id)
	if _current_contact == null: return
	category_field.select(0)
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


func _refresh_links()-> void:
	for child in links_container.get_children():
		child.queue_free()
	if _current_contact == null: return
	for link in _current_contact.links:
		_add_link_row(link.name, link.link)


func _add_link_row(link_name:String = "", link_url:String = "")-> void:
	var entry:ContactLinkEntry = ContactLinkEntry.SCENE.instantiate()
	links_container.add_child(entry)
	entry.setup(link_name, link_url)


func _collect_links()-> Array:
	var result = []
	for entry in links_container.get_children():
		var link_entry = entry as ContactLinkEntry
		if link_entry == null: continue
		var url = link_entry.get_link_url()
		if url.is_empty(): continue
		var link = Contact.ContactLink.new()
		link.name = link_entry.get_link_name()
		link.link = url
		result.append(link)
	return result


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


func _show_editor(shown:bool)-> void:
	editor_panel.visible = shown
	no_selection_label.visible = not shown


func _refresh_youtube()-> void:
	for child in youtube_videos.get_children():
		child.queue_free()
	if _current_contact == null:
		channel_name_label.text = ""
		channel_description_label.text = ""
		if _subscribers_label: _subscribers_label.text = ""
		latest_activity_label.text = ""
		return
	channel_name_label.text = _current_contact.youtube_channel_title
	channel_description_label.text = _current_contact.youtube_channel_description
	if _subscribers_label:
		_subscribers_label.text = _fmt_subscribers(_current_contact.youtube_subscribers)
	latest_activity_label.text = _current_contact.youtube_last_activity.left(10)
	for video in _current_contact.youtube_videos:
		youtube_videos.add_child(YoutubeVideoSmallView.create(video))


func _fmt_subscribers(n:int)-> String:
	if n >= 1_000_000:
		return "%.1fM" % (n / 1_000_000.0)
	elif n >= 1000:
		return "%.1fk" % (n / 1000.0)
	return str(n)


func _on_youtube_fetch_completed(contact_id:int, success:bool)-> void:
	if not success: return
	if _current_contact == null or _current_contact.id != contact_id: return
	Database.load_contact_youtube(_current_contact)
	_refresh_youtube()


func _on_email_changed(text:String)-> void:
	email_link_button.visible = not text.strip_edges().is_empty()


func _on_add_contact_pressed()-> void:
	_current_contact = Contact.new()
	name_field.text = ""
	email_field.text = ""
	_on_email_changed("")
	language_field.text = ""
	abandoned_check.button_pressed = false
	notes_field.text = ""
	delete_button.disabled = true
	_refresh_categories()
	_refresh_tags()
	_refresh_links()
	_refresh_tasks()
	_refresh_youtube()
	_show_editor(true)
	name_field.grab_focus()


func _on_edit_pressed()-> void:
	if _current_contact == null: return
	
	%ContactFullView.mode = ContactFullView.Mode.EDIT
	
	
func _on_save_pressed()-> void:
	if _current_contact == null: return
	var trimmed = name_field.text.strip_edges()
	if trimmed.is_empty(): return
	_current_contact.name = trimmed
	_current_contact.email = email_field.text.strip_edges()
	_current_contact.language = language_field.text.strip_edges()
	_current_contact.abandoned = abandoned_check.button_pressed
	_current_contact.notes = notes_field.text
	_current_contact.category_id = category_field.get_selected_id()
	_current_contact.links = _collect_links()
	Database.save_contact(_current_contact)
	YoutubeFetcher.fetch_for_contact(_current_contact)
	
	%ContactFullView.mode = ContactFullView.Mode.READ


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


func _open_import_window()-> void:
	ImportContactsWindow.open(self)
