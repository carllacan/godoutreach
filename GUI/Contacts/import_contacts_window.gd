class_name ImportContactsWindow
extends Window

@onready var file_dialog:FileDialog = %FileDialog
@onready var errors_container:VBoxContainer = %ErrorsContainer
@onready var new_contacts_container:VBoxContainer = %NewContactsContainer
@onready var existing_contacts_container:VBoxContainer = %ExistingContactsContainer
@onready var import_button:Button = %ImportButton
@onready var new_contacts_section:VBoxContainer = %NewContactsSection
@onready var existing_contacts_section:VBoxContainer = %ExistingContactsSection
@onready var errors_section:VBoxContainer = %ErrorsSection

var _contacts_to_import:Array[Contact] = []


func _ready()-> void:
	close_requested.connect(queue_free)
	%OpenFileButton.pressed.connect(_on_open_file_pressed)
	file_dialog.file_selected.connect(_on_file_selected)
	import_button.pressed.connect(_on_import_pressed)
	import_button.disabled = true
	_show_results(false)


func _on_open_file_pressed()-> void:
	file_dialog.popup_centered_ratio(0.7)


func _on_file_selected(path:String)-> void:
	var result = ContactsImporter.import_csv(path)
	_display_result(result)


func _display_result(result:ContactsImportResult)-> void:
	_clear_lists()
	import_button.disabled = true
	_contacts_to_import = []

	if not result.errors.is_empty():
		_show_errors(result.errors)
		_show_results(true)
		return

	var existing_youtube_links:Array[String] = []
	for contact in Database.get_all_contacts():
		for link in contact.links:
			if (link as Contact.ContactLink).name == "Youtube":
				var url = (link as Contact.ContactLink).link.strip_edges()
				if not url.is_empty():
					existing_youtube_links.append(url)

	var new_contacts:Array[Contact] = []
	var existing_contacts:Array[Contact] = []

	for contact in result.contacts:
		var youtube_url = _get_youtube_link(contact)
		if not youtube_url.is_empty() and youtube_url in existing_youtube_links:
			existing_contacts.append(contact)
		else:
			new_contacts.append(contact)

	_contacts_to_import = new_contacts

	for contact in new_contacts:
		var lbl = Label.new()
		lbl.text = contact.name
		new_contacts_container.add_child(lbl)

	for contact in existing_contacts:
		var lbl = Label.new()
		lbl.text = contact.name
		lbl.modulate = Color(1, 1, 1, 0.5)
		existing_contacts_container.add_child(lbl)

	errors_section.visible = false
	new_contacts_section.visible = true
	existing_contacts_section.visible = true
	import_button.disabled = new_contacts.is_empty()
	_show_results(true)


func _show_errors(errors:Array[String])-> void:
	for error in errors:
		var lbl = Label.new()
		lbl.text = error
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.modulate = Color(1, 0.4, 0.4)
		errors_container.add_child(lbl)
	errors_section.visible = true
	new_contacts_section.visible = false
	existing_contacts_section.visible = false


func _show_results(shown:bool)-> void:
	%ResultsSection.visible = shown


func _clear_lists()-> void:
	for child in errors_container.get_children():
		child.queue_free()
	for child in new_contacts_container.get_children():
		child.queue_free()
	for child in existing_contacts_container.get_children():
		child.queue_free()


func _get_youtube_link(contact:Contact)-> String:
	for link in contact.links:
		if (link as Contact.ContactLink).name == "Youtube":
			return (link as Contact.ContactLink).link.strip_edges()
	return ""


func _on_import_pressed()-> void:
	for contact in _contacts_to_import:
		Database.save_contact(contact)
	queue_free()


static func open(parent:Node)-> void:
	var scene = preload("res://GUI/Contacts/import_contacts_window.tscn")
	var window = scene.instantiate() as ImportContactsWindow
	parent.add_child(window)
	window.popup_centered(Vector2i(600, 500))
