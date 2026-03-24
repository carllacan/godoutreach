extends ColorRect


@export var windows:Array[Control] = []


func _ready()-> void:
	for w in windows:
		w.visibility_changed.connect(_on_windows_visibility_changed)
		
		
func _on_windows_visibility_changed()-> void:
	visible = windows.any(func(w): return w.visible)
