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
	make()


func set_task(new_value:Task)-> void:
	task = new_value
	make()


func make()-> void:
	if not is_node_ready(): return
	if task == null: return
	var status = "PENDING" if task.status == Task.Status.Pending else "WAITING"
	desc_label.text = "Suggested: [%s] %s" % [status, task.description]
