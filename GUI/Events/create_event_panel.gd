extends VBoxContainer


var game
var contact

@onready var event_kind_field:OptionButton = %EventKindField
@onready var event_channel_field:LineEdit = %EventChannelField
@onready var event_content_field:TextEdit = %EventContentField
@onready var event_link_field:LineEdit = %EventLinkField
@onready var log_event_button:Button = %LogEventButton


func _ready() -> void:
	log_event_button.pressed.connect(_on_log_event_pressed)
	_refresh_event_kinds()
	

func _on_log_event_pressed()-> void:
	if game == null or contact == -1: return
	if event_kind_field.item_count == 0: return
	var event = ContactEvent.new()
	event.contact_id = contact
	event.game_id = game.id
	event.kind_id = event_kind_field.get_selected_id()
	event.datetime = Time.get_datetime_string_from_system()
	event.channel = event_channel_field.text.strip_edges()
	event.content_text = event_content_field.text
	event.content_link = event_link_field.text.strip_edges()
	Database.save_contact_event(event)
	event_channel_field.text = ""
	event_content_field.text = ""
	event_link_field.text = ""


func _refresh_event_kinds()-> void:
	event_kind_field.clear()
	for kind in Database.get_all_event_kinds():
		event_kind_field.add_item(kind.name, kind.id)
