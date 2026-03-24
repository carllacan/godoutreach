class_name DeletableButton
extends PanelContainer

const SCENE = preload("res://GUI/Settings/deletable_button.tscn")

signal deletion_requested

var text:String = "" : set = set_text

@onready var label:Label = %Label
@onready var delete_button:Button = %DeleteButton


static func create(t:String) -> DeletableButton:
	var btn = SCENE.instantiate() as DeletableButton
	btn.text = t
	return btn


func set_text(new_value:String) -> void:
	text = new_value
	if is_node_ready():
		label.text = text


func _ready() -> void:
	label.text = text
	delete_button.pressed.connect(func(): deletion_requested.emit())
