extends Node

func get_tasks_for_game(game:UserGame)-> Array[Task]:
	var tasks:Array[Task] = []
	var contacts = Database.get_all_contacts()
	for contact in contacts:
		if contact.abandoned:
			continue
		var task = _get_task_for_contact_game(contact, game)
		if task != null:
			tasks.append(task)
	return tasks


func get_tasks_for_contact(contact:Contact)-> Array[Task]:
	var tasks:Array[Task] = []
	var games = Database.get_all_user_games()
	for game in games:
		if not (game.id in contact.relevant_game_ids):
			continue
		var task = _get_task_for_contact_game(contact, game)
		if task != null:
			tasks.append(task)
	return tasks


func get_all_tasks()-> Array[Task]:
	var tasks:Array[Task] = []
	for game in Database.get_all_user_games():
		tasks.append_array(get_tasks_for_game(game))
	return tasks


func categorize_contacts_for_game(game:UserGame)-> Dictionary:
	var result = {"done": [], "waiting": [], "pending": [], "prospect": [], "discarded": []}
	for contact in Database.get_all_contacts():
		if contact.abandoned:
			result.discarded.append(contact)
			continue
		var last_event = Database.get_latest_event_for_contact_game(contact.id, game.id)
		if last_event == null:
			result.prospect.append(contact)
			continue
		match last_event.kind_name:
			EventKind.DISCARDED, EventKind.REJECTION:
				result.discarded.append(contact)
			EventKind.COVERAGE:
				result.done.append(contact)
			EventKind.MESSAGED, EventKind.ACCEPTANCE:
				result.waiting.append(contact)
			EventKind.REQUEST:
				result.pending.append(contact)
			_:
				result.waiting.append(contact)
	return result


func _get_task_for_contact_game(contact:Contact, game:UserGame)-> Task:
	var task = Task.new()
	task.contact_id = contact.id
	task.contact_name = contact.name
	task.game_id = game.id
	task.game_name = game.name

	var last_event = Database.get_latest_event_for_contact_game(contact.id, game.id)
	task.last_event = last_event

	if last_event == null:
		task.status = Task.Status.Pending
		task.description = "Decide whether to reach out to %s for %s" % [contact.name, game.name]
		return task

	match last_event.kind_name:
		EventKind.DISCARDED, EventKind.REJECTION, EventKind.COVERAGE:
			return null
		EventKind.MESSAGED:
			task.status = Task.Status.Waiting
			task.description = "Waiting for %s to respond about %s" % [contact.name, game.name]
		EventKind.ACCEPTANCE:
			task.status = Task.Status.Waiting
			task.description = "%s accepted to cover %s — waiting for coverage" % [contact.name, game.name]
		EventKind.REQUEST:
			task.status = Task.Status.Pending
			task.description = "%s requested more info about %s" % [contact.name, game.name]
		_:
			task.status = Task.Status.Waiting
			task.description = "Last event with %s for %s: %s" % [contact.name, game.name, last_event.kind_name]

	return task
