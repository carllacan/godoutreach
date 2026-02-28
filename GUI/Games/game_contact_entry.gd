class_name GameContactEntry
extends Button

const SCENE = preload("res://GUI/Games/game_contact_entry.tscn")

var contact_id:int = -1
var game_id:int = -1

signal contact_game_selected(contact_id:int, game_id:int)


static func create(contact:Contact, gid:int, status_label:String)-> Button:
	var entry = SCENE.instantiate()
	entry.contact_id = contact.id
	entry.game_id = gid
	entry.text = contact.name + "  [" + status_label + "]"
	return entry


func _ready()-> void:
	pressed.connect(func(): contact_game_selected.emit(contact_id, game_id))
