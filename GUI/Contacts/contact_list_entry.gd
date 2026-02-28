class_name ContactListEntry
extends Button

const SCENE = preload("res://GUI/Contacts/contact_list_entry.tscn")

var contact_id:int = -1

signal contact_selected(id:int)


static func create(contact:Contact)-> Button:
	var entry = SCENE.instantiate()
	entry.contact_id = contact.id
	entry.text = ("[INACTIVE] " if contact.abandoned else "") + contact.name
	if contact.abandoned:
		entry.modulate = Color(1, 1, 1, 0.5)
	return entry


func _ready()-> void:
	pressed.connect(func(): contact_selected.emit(contact_id))
