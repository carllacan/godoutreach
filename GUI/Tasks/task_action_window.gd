class_name TaskActionWindow
extends Window

const SCENE = preload("res://GUI/Tasks/task_action_window.tscn")
const CREATE_EVENT_WINDOW_SCENE = preload("res://GUI/Events/create_event_window.tscn")

var task:Task

@onready var context_label:Label = %ContextLabel
@onready var question_label:Label = %QuestionLabel
@onready var yes_button:Button = %YesButton
@onready var no_button:Button = %NoButton
@onready var give_up_button:Button = %GiveUpButton


static func open_for_task(t:Task, parent:Node)-> void:
	var window = SCENE.instantiate()
	window.task = t
	parent.add_child(window)
	window.popup_centered()


func _ready()-> void:
	close_requested.connect(queue_free)
	yes_button.pressed.connect(_on_yes_pressed)
	no_button.pressed.connect(queue_free)
	give_up_button.pressed.connect(_on_give_up_pressed)
	_setup_for_task()


func _setup_for_task()-> void:
	if task == null: return
	if task.status == Task.Status.Waiting:
		var dt = task.last_event.datetime if task.last_event != null else "unknown date"
		context_label.text = "You contacted %s on %s" % [task.contact_name, dt]
		question_label.text = "Has %s responded?" % task.contact_name
		yes_button.text = "Yes, they responded"
		no_button.text = "No, keep waiting"
		give_up_button.text = "No, give up on them"
	else:
		context_label.text = "You should do this:\n%s" % task.description
		question_label.text = "Have you done this?"
		yes_button.text = "Yes, I did it"
		no_button.text = "No"
		give_up_button.text = "No, give up on this contact"


func _on_yes_pressed()-> void:
	var win = CREATE_EVENT_WINDOW_SCENE.instantiate()
	win.contact_id = task.contact_id
	win.game_id = task.game_id
	get_parent().add_child(win)
	win.popup_centered()
	queue_free()


func _on_give_up_pressed()-> void:
	var event = ContactEvent.new()
	event.contact_id = task.contact_id
	event.game_id = task.game_id
	for kind in Database.get_all_event_kinds():
		if kind.name == EventKind.DISCARDED:
			event.kind_id = kind.id
			break
	if event.kind_id == -1:
		push_error("TaskActionWindow: Discarded event kind not found")
		queue_free()
		return
	event.datetime = Time.get_datetime_string_from_system()
	event.content_text = "Discarded after contact" if task.last_event != null else "Discarded without contact"
	Database.save_contact_event(event)
	queue_free()
