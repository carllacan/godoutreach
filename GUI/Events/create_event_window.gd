class_name CreateEventWindow
extends Window

var contact_id:int = -1
var game_id:int = -1

@onready var create_event_panel = %CreateEventPanel


func _ready()-> void:
	close_requested.connect(queue_free)
	Database.events_changed.connect(queue_free)
	create_event_panel.contact = contact_id
	create_event_panel.game = Database.get_user_game(game_id)
