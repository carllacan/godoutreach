class_name TaskCard
extends PanelContainer

const SCENE = preload("res://GUI/Tasks/task_card.tscn")

var task:Task : set = set_task

@onready var game_label:Label = %GameLabel
@onready var contact_label:Label = %ContactLabel
@onready var description_label:Label = %DescriptionLabel
@onready var status_label:Label = %StatusLabel
@onready var days_label:Label = %DaysLabel


static func create(t:Task)-> PanelContainer:
	var card = SCENE.instantiate()
	card.task = t
	return card


func _ready()-> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	gui_input.connect(_on_gui_input)
	make()


func _on_gui_input(event:InputEvent)-> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if task != null:
			TaskActionWindow.open_for_task(task, get_tree().root)


func set_task(new_value:Task)-> void:
	task = new_value
	make()


func make()-> void:
	if not is_node_ready(): return
	if task == null: return

	game_label.text = task.game_name
	contact_label.text = task.contact_name
	description_label.text = task.description
	status_label.text = "PENDING" if task.status == Task.Status.Pending else "WAITING"
	status_label.modulate = Color.ORANGE if task.status == Task.Status.Pending else Color.CORNFLOWER_BLUE

	if task.last_event != null and not task.last_event.datetime.is_empty():
		var event_time = Time.get_datetime_dict_from_datetime_string(task.last_event.datetime, false)
		var event_unix = Time.get_unix_time_from_datetime_dict(event_time)
		var now_unix = Time.get_unix_time_from_system()
		var days = int((now_unix - event_unix) / 86400.0)
		days_label.text = "%d days ago" % days
		days_label.visible = true
	else:
		days_label.visible = false
