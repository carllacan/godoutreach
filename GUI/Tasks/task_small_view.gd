class_name TaskSmallView
extends PanelContainer

const SCENE = preload("res://GUI/Tasks/task_small_view.tscn")

var task:Task : set = set_task

@onready var desc_label:Label = %DescLabel


static func create(t:Task)-> TaskSmallView:
	var view = SCENE.instantiate()
	view.task = t
	return view


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
	var status = "PENDING" if task.status == Task.Status.Pending else "WAITING"
	desc_label.modulate = Color.ORANGE if task.status == Task.Status.Pending else Color.CORNFLOWER_BLUE
	var prefix = "%s: " % task.game_name if not task.game_name.is_empty() else ""
	desc_label.text = "[%s] %s%s" % [status, prefix, task.description]
