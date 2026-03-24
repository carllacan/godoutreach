extends PanelContainer


@onready var abort_button = %AbortButton
@onready var close_button = %CloseButton

func _ready()-> void:
	YoutubeFetcher.started_fetching.connect(_on_started_fetching)
	YoutubeFetcher.completed_fetching.connect(_on_started_fetching)
	YoutubeFetcher.progress_changed.connect(_on_progress_changed)
	hide()
	
	
func _on_started_fetching()-> void:
	abort_button.show()
	close_button.hide()
	show()
	
	
func _on_progress_changed(new_progress:float)-> void:
	%ProgressBar.value = new_progress
	
	
func _on_finished_fetching()-> void:
	abort_button.hide()
	close_button.show()
	hide()
