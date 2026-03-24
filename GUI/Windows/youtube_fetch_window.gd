extends PanelContainer


@onready var abort_button = %AbortButton
@onready var close_button = %CloseButton

func _ready()-> void:
	YoutubeFetcher.started_fetching.connect(_on_started_fetching)
	YoutubeFetcher.completed_fetching.connect(_on_finished_fetching)
	YoutubeFetcher.progress_changed.connect(_on_progress_changed)
	
	%AbortButton.pressed.connect(_on_abort_button_pressed)
	%CloseButton.pressed.connect(hide)
	
	hide()
	
	
func _on_started_fetching()-> void:
	abort_button.show()
	close_button.hide()
	%WaitLabel.show()
	%ResultLabel.hide()
	show()
	
	
func _on_progress_changed(new_progress:float)-> void:
	%ProgressBar.value = new_progress
	
	
func _on_finished_fetching()-> void:
	abort_button.hide()
	close_button.show()
	%WaitLabel.hide()
	%ResultLabel.show()
	%ResultLabel.text = YoutubeFetcher.last_fetch_result


func _on_abort_button_pressed()-> void:
	YoutubeFetcher.abort_requested = true
