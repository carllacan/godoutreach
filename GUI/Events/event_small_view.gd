class_name EventSmallView
extends PanelContainer

const SCENE = preload("res://GUI/Events/event_small_view.tscn")

var event:ContactEvent : set = set_event

@onready var header_label:Label = %HeaderLabel
@onready var body_label:Label = %BodyLabel
@onready var link_label:Label = %LinkLabel
@onready var delete_button:Button = %DeleteButton


static func create(e:ContactEvent)-> EventSmallView:
	var view = SCENE.instantiate()
	view.event = e
	return view


func _ready()-> void:
	delete_button.pressed.connect(_on_delete_pressed)
	make()


func set_event(new_value:ContactEvent)-> void:
	event = new_value
	make()


func make()-> void:
	if not is_node_ready(): return
	if event == null: return
	header_label.text = "[%s] %s" % [event.kind_name, event.datetime]
	if not event.channel.is_empty():
		header_label.text += " via " + event.channel
	body_label.text = event.content_text
	body_label.visible = not event.content_text.is_empty()
	link_label.text = "Link: " + event.content_link
	link_label.visible = not event.content_link.is_empty()


func _on_delete_pressed()-> void:
	if event == null: return
	Database.delete_contact_event(event.id)
