class_name TasksTab
extends VBoxContainer

@onready var game_filter:OptionButton = %GameFilter
@onready var pending_cards:HFlowContainer = %PendingCards
@onready var waiting_cards:HFlowContainer = %WaitingCards
@onready var pending_section:VBoxContainer = %PendingSection
@onready var waiting_section:VBoxContainer = %WaitingSection
@onready var empty_label:Label = %EmptyLabel


func _ready()-> void:
	game_filter.item_selected.connect(_on_game_filter_item_selected)
	Database.events_changed.connect(rebuild)
	Database.contacts_changed.connect(_refresh_filter)
	Database.games_changed.connect(_refresh_filter)
	_refresh_filter()
	rebuild()


func _refresh_filter()-> void:
	game_filter.clear()
	game_filter.add_item("All games", -1)
	for game in Database.get_all_user_games():
		game_filter.add_item(game.name, game.id)
	rebuild()


func rebuild()-> void:
	for child in pending_cards.get_children():
		child.queue_free()
	for child in waiting_cards.get_children():
		child.queue_free()

	var selected_game_id = game_filter.get_selected_id() if game_filter.item_count > 0 else -1
	var tasks:Array[Task] = []

	if selected_game_id == -1:
		tasks = TasksManager.get_all_tasks()
	else:
		var game = Database.get_user_game(selected_game_id)
		if game != null:
			tasks = TasksManager.get_tasks_for_game(game)

	var pending_count = 0
	var waiting_count = 0

	for task in tasks:
		var card = TaskCard.create(task)
		if task.status == Task.Status.Pending:
			pending_cards.add_child(card)
			pending_count += 1
		else:
			waiting_cards.add_child(card)
			waiting_count += 1

	pending_section.visible = pending_count > 0
	waiting_section.visible = waiting_count > 0
	empty_label.visible = tasks.is_empty()


func _on_game_filter_item_selected(_index:int)-> void:
	rebuild()
