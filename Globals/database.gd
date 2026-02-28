## Database singleton. Requires the gd-sqlite plugin by 2shady4u.
## Install from the AssetLib: search "SQLite" and install the one by 2shady4u.
extends Node

const DB_PATH = "user://godoutreach.db"

var _db:SQLite

signal contacts_changed
signal games_changed
signal events_changed
signal settings_changed


func _ready()-> void:
	_db = SQLite.new()
	_db.path = DB_PATH
	_db.verbosity_level = SQLite.QUIET
	if not _db.open_db():
		push_error("Database: failed to open db at " + DB_PATH)
		return
	_db.query("PRAGMA foreign_keys = ON")
	_create_tables()
	_insert_defaults()


func _create_tables()-> void:
	var statements = [
		"""CREATE TABLE IF NOT EXISTS tags (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			name TEXT NOT NULL UNIQUE
		)""",
		"""CREATE TABLE IF NOT EXISTS contact_categories (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			name TEXT NOT NULL UNIQUE,
			is_builtin INTEGER DEFAULT 0
		)""",
		"""CREATE TABLE IF NOT EXISTS event_kinds (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			name TEXT NOT NULL UNIQUE,
			is_builtin INTEGER DEFAULT 0
		)""",
		"""CREATE TABLE IF NOT EXISTS contacts (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			name TEXT NOT NULL,
			category_id INTEGER REFERENCES contact_categories(id),
			language TEXT DEFAULT '',
			notes TEXT DEFAULT '',
			abandoned INTEGER DEFAULT 0
		)""",
		"""CREATE TABLE IF NOT EXISTS contact_links (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			contact_id INTEGER NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,
			name TEXT NOT NULL DEFAULT '',
			link TEXT NOT NULL DEFAULT '',
			notes TEXT DEFAULT ''
		)""",
		"""CREATE TABLE IF NOT EXISTS contact_saved_content (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			contact_id INTEGER NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,
			link TEXT NOT NULL DEFAULT '',
			name TEXT DEFAULT '',
			notes TEXT DEFAULT ''
		)""",
		"""CREATE TABLE IF NOT EXISTS contact_tags (
			contact_id INTEGER NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,
			tag_id INTEGER NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
			PRIMARY KEY (contact_id, tag_id)
		)""",
		"""CREATE TABLE IF NOT EXISTS contact_covered_games (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			contact_id INTEGER NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,
			name TEXT NOT NULL DEFAULT ''
		)""",
		"""CREATE TABLE IF NOT EXISTS user_games (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			name TEXT NOT NULL
		)""",
		"""CREATE TABLE IF NOT EXISTS user_game_links (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			game_id INTEGER NOT NULL REFERENCES user_games(id) ON DELETE CASCADE,
			name TEXT NOT NULL DEFAULT '',
			link TEXT NOT NULL DEFAULT ''
		)""",
		"""CREATE TABLE IF NOT EXISTS user_game_tags (
			game_id INTEGER NOT NULL REFERENCES user_games(id) ON DELETE CASCADE,
			tag_id INTEGER NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
			PRIMARY KEY (game_id, tag_id)
		)""",
		"""CREATE TABLE IF NOT EXISTS user_game_short_descriptions (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			game_id INTEGER NOT NULL REFERENCES user_games(id) ON DELETE CASCADE,
			content TEXT NOT NULL DEFAULT ''
		)""",
		"""CREATE TABLE IF NOT EXISTS short_description_tags (
			description_id INTEGER NOT NULL REFERENCES user_game_short_descriptions(id) ON DELETE CASCADE,
			tag_id INTEGER NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
			PRIMARY KEY (description_id, tag_id)
		)""",
		"""CREATE TABLE IF NOT EXISTS user_game_descriptions (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			game_id INTEGER NOT NULL REFERENCES user_games(id) ON DELETE CASCADE,
			content TEXT NOT NULL DEFAULT ''
		)""",
		"""CREATE TABLE IF NOT EXISTS description_tags (
			description_id INTEGER NOT NULL REFERENCES user_game_descriptions(id) ON DELETE CASCADE,
			tag_id INTEGER NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
			PRIMARY KEY (description_id, tag_id)
		)""",
		"""CREATE TABLE IF NOT EXISTS similar_games (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			game_id INTEGER NOT NULL REFERENCES user_games(id) ON DELETE CASCADE,
			name TEXT NOT NULL DEFAULT ''
		)""",
		"""CREATE TABLE IF NOT EXISTS contact_game_relevance (
			contact_id INTEGER NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,
			game_id INTEGER NOT NULL REFERENCES user_games(id) ON DELETE CASCADE,
			PRIMARY KEY (contact_id, game_id)
		)""",
		"""CREATE TABLE IF NOT EXISTS contact_events (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			contact_id INTEGER NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,
			game_id INTEGER NOT NULL REFERENCES user_games(id) ON DELETE CASCADE,
			kind_id INTEGER NOT NULL REFERENCES event_kinds(id),
			datetime TEXT NOT NULL,
			channel TEXT DEFAULT '',
			content_text TEXT DEFAULT '',
			content_link TEXT DEFAULT ''
		)""",
	]
	for stmt in statements:
		if not _db.query(stmt):
			push_error("Database: failed to create table")


func _insert_defaults()-> void:
	_db.query("SELECT COUNT(*) as count FROM contact_categories")
	if _db.query_result[0].get("count", 0) == 0:
		for cat in ["Streamer", "YouTuber", "Press", "Podcaster", "Blogger"]:
			_db.query_with_bindings(
				"INSERT OR IGNORE INTO contact_categories (name, is_builtin) VALUES (?, 1)", [cat]
			)

	_db.query("SELECT COUNT(*) as count FROM event_kinds")
	if _db.query_result[0].get("count", 0) == 0:
		for kind in [EventKind.MESSAGED, EventKind.ACCEPTANCE, EventKind.REJECTION,
				EventKind.REQUEST, EventKind.COVERAGE, EventKind.DISCARDED]:
			_db.query_with_bindings(
				"INSERT OR IGNORE INTO event_kinds (name, is_builtin) VALUES (?, 1)", [kind]
			)

	_db.query("SELECT COUNT(*) as count FROM tags")
	if _db.query_result[0].get("count", 0) == 0:
		for tag in ["RPG", "Action", "Puzzle", "Strategy", "Roguelike", "Deckbuilder",
				"Platformer", "Horror", "Simulation", "Adventure", "Indie",
				"Retro", "Pixel Art", "Multiplayer", "Co-op"]:
			_db.query_with_bindings("INSERT OR IGNORE INTO tags (name) VALUES (?)", [tag])


#region Tags

func get_all_tags()-> Array[Tag]:
	_db.query("SELECT * FROM tags ORDER BY name")
	var result:Array[Tag] = []
	for row in _db.query_result:
		var t = Tag.new()
		t.id = row.id
		t.name = row.name
		result.append(t)
	return result


func create_tag(name:String)-> Tag:
	_db.query_with_bindings("INSERT INTO tags (name) VALUES (?)", [name])
	var t = Tag.new()
	t.id = _db.last_insert_rowid
	t.name = name
	settings_changed.emit()
	return t


func delete_tag(id:int)-> void:
	_db.query_with_bindings("DELETE FROM tags WHERE id = ?", [id])
	settings_changed.emit()

#endregion Tags


#region Contact Categories

func get_all_contact_categories()-> Array[ContactCategory]:
	_db.query("SELECT * FROM contact_categories ORDER BY name")
	var result:Array[ContactCategory] = []
	for row in _db.query_result:
		var cat = ContactCategory.new()
		cat.id = row.id
		cat.name = row.name
		cat.is_builtin = bool(row.get("is_builtin", 0))
		result.append(cat)
	return result


func create_contact_category(name:String)-> ContactCategory:
	_db.query_with_bindings(
		"INSERT INTO contact_categories (name, is_builtin) VALUES (?, 0)", [name]
	)
	var cat = ContactCategory.new()
	cat.id = _db.last_insert_rowid
	cat.name = name
	settings_changed.emit()
	return cat


func delete_contact_category(id:int)-> void:
	_db.query_with_bindings(
		"DELETE FROM contact_categories WHERE id = ? AND is_builtin = 0", [id]
	)
	settings_changed.emit()

#endregion Contact Categories


#region Event Kinds

func get_all_event_kinds()-> Array[EventKind]:
	_db.query("SELECT * FROM event_kinds ORDER BY name")
	var result:Array[EventKind] = []
	for row in _db.query_result:
		var kind = EventKind.new()
		kind.id = row.id
		kind.name = row.name
		kind.is_builtin = bool(row.get("is_builtin", 0))
		result.append(kind)
	return result


func create_event_kind(name:String)-> EventKind:
	_db.query_with_bindings("INSERT INTO event_kinds (name, is_builtin) VALUES (?, 0)", [name])
	var kind = EventKind.new()
	kind.id = _db.last_insert_rowid
	kind.name = name
	settings_changed.emit()
	return kind

#endregion Event Kinds


#region Contacts

func get_all_contacts()-> Array[Contact]:
	_db.query("SELECT * FROM contacts ORDER BY name")
	var result:Array[Contact] = []
	for row in _db.query_result:
		result.append(_contact_from_row(row))
	return result


func get_contact(id:int)-> Contact:
	_db.query_with_bindings("SELECT * FROM contacts WHERE id = ?", [id])
	if _db.query_result.is_empty():
		return null
	return _contact_from_row(_db.query_result[0])


func _contact_from_row(row:Dictionary)-> Contact:
	var contact = Contact.new()
	contact.id = row.id
	contact.name = row.name
	var cat_id = row.get("category_id")
	contact.category_id = cat_id if cat_id != null else -1
	contact.language = row.get("language", "")
	contact.notes = row.get("notes", "")
	contact.abandoned = bool(row.get("abandoned", 0))

	_db.query_with_bindings(
		"SELECT tag_id FROM contact_tags WHERE contact_id = ?", [contact.id]
	)
	for r in _db.query_result:
		contact.tag_ids.append(r.tag_id)

	_db.query_with_bindings(
		"SELECT * FROM contact_links WHERE contact_id = ? ORDER BY id", [contact.id]
	)
	for r in _db.query_result:
		var link = Contact.ContactLink.new()
		link.id = r.id
		link.name = r.name
		link.link = r.link
		link.notes = r.get("notes", "")
		contact.links.append(link)

	_db.query_with_bindings(
		"SELECT * FROM contact_saved_content WHERE contact_id = ? ORDER BY id", [contact.id]
	)
	for r in _db.query_result:
		var sc = Contact.ContactSavedContent.new()
		sc.id = r.id
		sc.link = r.link
		sc.name = r.get("name", "")
		sc.notes = r.get("notes", "")
		contact.saved_content.append(sc)

	_db.query_with_bindings(
		"SELECT name FROM contact_covered_games WHERE contact_id = ? ORDER BY id", [contact.id]
	)
	for r in _db.query_result:
		contact.covered_games.append(r.name)

	_db.query_with_bindings(
		"SELECT game_id FROM contact_game_relevance WHERE contact_id = ?", [contact.id]
	)
	for r in _db.query_result:
		contact.relevant_game_ids.append(r.game_id)

	return contact


func save_contact(contact:Contact)-> void:
	var cat_id = contact.category_id if contact.category_id != -1 else null
	if contact.id == -1:
		_db.query_with_bindings(
			"INSERT INTO contacts (name, category_id, language, notes, abandoned) VALUES (?, ?, ?, ?, ?)",
			[contact.name, cat_id, contact.language, contact.notes, int(contact.abandoned)]
		)
		contact.id = _db.last_insert_rowid
	else:
		_db.query_with_bindings(
			"UPDATE contacts SET name=?, category_id=?, language=?, notes=?, abandoned=? WHERE id=?",
			[contact.name, cat_id, contact.language, contact.notes, int(contact.abandoned), contact.id]
		)

	_db.query_with_bindings("DELETE FROM contact_tags WHERE contact_id = ?", [contact.id])
	for tag_id in contact.tag_ids:
		_db.query_with_bindings(
			"INSERT INTO contact_tags (contact_id, tag_id) VALUES (?, ?)", [contact.id, tag_id]
		)

	_db.query_with_bindings("DELETE FROM contact_links WHERE contact_id = ?", [contact.id])
	for link in contact.links:
		_db.query_with_bindings(
			"INSERT INTO contact_links (contact_id, name, link, notes) VALUES (?, ?, ?, ?)",
			[contact.id, link.name, link.link, link.notes]
		)

	_db.query_with_bindings(
		"DELETE FROM contact_saved_content WHERE contact_id = ?", [contact.id]
	)
	for sc in contact.saved_content:
		_db.query_with_bindings(
			"INSERT INTO contact_saved_content (contact_id, link, name, notes) VALUES (?, ?, ?, ?)",
			[contact.id, sc.link, sc.name, sc.notes]
		)

	_db.query_with_bindings(
		"DELETE FROM contact_covered_games WHERE contact_id = ?", [contact.id]
	)
	for game_name in contact.covered_games:
		_db.query_with_bindings(
			"INSERT INTO contact_covered_games (contact_id, name) VALUES (?, ?)",
			[contact.id, game_name]
		)

	_db.query_with_bindings(
		"DELETE FROM contact_game_relevance WHERE contact_id = ?", [contact.id]
	)
	for game_id in contact.relevant_game_ids:
		_db.query_with_bindings(
			"INSERT INTO contact_game_relevance (contact_id, game_id) VALUES (?, ?)",
			[contact.id, game_id]
		)

	contacts_changed.emit()


func delete_contact(id:int)-> void:
	_db.query_with_bindings("DELETE FROM contacts WHERE id = ?", [id])
	contacts_changed.emit()
	events_changed.emit()

#endregion Contacts


#region User Games

func get_all_user_games()-> Array[UserGame]:
	_db.query("SELECT * FROM user_games ORDER BY name")
	var result:Array[UserGame] = []
	for row in _db.query_result:
		result.append(_user_game_from_row(row))
	return result


func get_user_game(id:int)-> UserGame:
	_db.query_with_bindings("SELECT * FROM user_games WHERE id = ?", [id])
	if _db.query_result.is_empty():
		return null
	return _user_game_from_row(_db.query_result[0])


func _user_game_from_row(row:Dictionary)-> UserGame:
	var game = UserGame.new()
	game.id = row.id
	game.name = row.name

	_db.query_with_bindings(
		"SELECT tag_id FROM user_game_tags WHERE game_id = ?", [game.id]
	)
	for r in _db.query_result:
		game.tag_ids.append(r.tag_id)

	_db.query_with_bindings(
		"SELECT * FROM user_game_links WHERE game_id = ? ORDER BY id", [game.id]
	)
	for r in _db.query_result:
		var link = UserGame.GameLink.new()
		link.id = r.id
		link.name = r.name
		link.link = r.link
		game.links.append(link)

	_db.query_with_bindings(
		"SELECT * FROM user_game_short_descriptions WHERE game_id = ? ORDER BY id", [game.id]
	)
	for r in _db.query_result:
		var desc = UserGame.GameDescription.new()
		desc.id = r.id
		desc.content = r.content
		_db.query_with_bindings(
			"SELECT tag_id FROM short_description_tags WHERE description_id = ?", [desc.id]
		)
		for tr in _db.query_result:
			desc.tag_ids.append(tr.tag_id)
		game.short_descriptions.append(desc)

	_db.query_with_bindings(
		"SELECT * FROM user_game_descriptions WHERE game_id = ? ORDER BY id", [game.id]
	)
	for r in _db.query_result:
		var desc = UserGame.GameDescription.new()
		desc.id = r.id
		desc.content = r.content
		_db.query_with_bindings(
			"SELECT tag_id FROM description_tags WHERE description_id = ?", [desc.id]
		)
		for tr in _db.query_result:
			desc.tag_ids.append(tr.tag_id)
		game.descriptions.append(desc)

	_db.query_with_bindings(
		"SELECT name FROM similar_games WHERE game_id = ? ORDER BY id", [game.id]
	)
	for r in _db.query_result:
		game.similar_games.append(r.name)

	return game


func save_user_game(game:UserGame)-> void:
	if game.id == -1:
		_db.query_with_bindings("INSERT INTO user_games (name) VALUES (?)", [game.name])
		game.id = _db.last_insert_rowid
	else:
		_db.query_with_bindings("UPDATE user_games SET name=? WHERE id=?", [game.name, game.id])

	_db.query_with_bindings("DELETE FROM user_game_tags WHERE game_id = ?", [game.id])
	for tag_id in game.tag_ids:
		_db.query_with_bindings(
			"INSERT INTO user_game_tags (game_id, tag_id) VALUES (?, ?)", [game.id, tag_id]
		)

	_db.query_with_bindings("DELETE FROM user_game_links WHERE game_id = ?", [game.id])
	for link in game.links:
		_db.query_with_bindings(
			"INSERT INTO user_game_links (game_id, name, link) VALUES (?, ?, ?)",
			[game.id, link.name, link.link]
		)

	_db.query_with_bindings(
		"DELETE FROM user_game_short_descriptions WHERE game_id = ?", [game.id]
	)
	for desc in game.short_descriptions:
		_db.query_with_bindings(
			"INSERT INTO user_game_short_descriptions (game_id, content) VALUES (?, ?)",
			[game.id, desc.content]
		)
		var new_id = _db.last_insert_rowid
		for tag_id in desc.tag_ids:
			_db.query_with_bindings(
				"INSERT INTO short_description_tags (description_id, tag_id) VALUES (?, ?)",
				[new_id, tag_id]
			)

	_db.query_with_bindings("DELETE FROM user_game_descriptions WHERE game_id = ?", [game.id])
	for desc in game.descriptions:
		_db.query_with_bindings(
			"INSERT INTO user_game_descriptions (game_id, content) VALUES (?, ?)",
			[game.id, desc.content]
		)
		var new_id = _db.last_insert_rowid
		for tag_id in desc.tag_ids:
			_db.query_with_bindings(
				"INSERT INTO description_tags (description_id, tag_id) VALUES (?, ?)",
				[new_id, tag_id]
			)

	_db.query_with_bindings("DELETE FROM similar_games WHERE game_id = ?", [game.id])
	for sg in game.similar_games:
		_db.query_with_bindings(
			"INSERT INTO similar_games (game_id, name) VALUES (?, ?)", [game.id, sg]
		)

	games_changed.emit()


func delete_user_game(id:int)-> void:
	_db.query_with_bindings("DELETE FROM user_games WHERE id = ?", [id])
	games_changed.emit()
	events_changed.emit()

#endregion User Games


#region Contact Events

func get_events_for_contact_game(contact_id:int, game_id:int)-> Array[ContactEvent]:
	_db.query_with_bindings(
		"""SELECT ce.*, ek.name as kind_name
		   FROM contact_events ce
		   JOIN event_kinds ek ON ce.kind_id = ek.id
		   WHERE ce.contact_id = ? AND ce.game_id = ?
		   ORDER BY ce.datetime DESC""",
		[contact_id, game_id]
	)
	var result:Array[ContactEvent] = []
	for row in _db.query_result:
		result.append(_event_from_row(row))
	return result


func get_all_events_for_contact(contact_id:int)-> Array[ContactEvent]:
	_db.query_with_bindings(
		"""SELECT ce.*, ek.name as kind_name
		   FROM contact_events ce
		   JOIN event_kinds ek ON ce.kind_id = ek.id
		   WHERE ce.contact_id = ?
		   ORDER BY ce.datetime DESC""",
		[contact_id]
	)
	var result:Array[ContactEvent] = []
	for row in _db.query_result:
		result.append(_event_from_row(row))
	return result


func get_latest_event_for_contact_game(contact_id:int, game_id:int)-> ContactEvent:
	_db.query_with_bindings(
		"""SELECT ce.*, ek.name as kind_name
		   FROM contact_events ce
		   JOIN event_kinds ek ON ce.kind_id = ek.id
		   WHERE ce.contact_id = ? AND ce.game_id = ?
		   ORDER BY ce.datetime DESC LIMIT 1""",
		[contact_id, game_id]
	)
	if _db.query_result.is_empty():
		return null
	return _event_from_row(_db.query_result[0])


func _event_from_row(row:Dictionary)-> ContactEvent:
	var event = ContactEvent.new()
	event.id = row.id
	event.contact_id = row.contact_id
	event.game_id = row.game_id
	event.kind_id = row.kind_id
	event.kind_name = row.get("kind_name", "")
	event.datetime = row.get("datetime", "")
	event.channel = row.get("channel", "")
	event.content_text = row.get("content_text", "")
	event.content_link = row.get("content_link", "")
	return event


func save_contact_event(event:ContactEvent)-> void:
	if event.id == -1:
		_db.query_with_bindings(
			"""INSERT INTO contact_events
			   (contact_id, game_id, kind_id, datetime, channel, content_text, content_link)
			   VALUES (?, ?, ?, ?, ?, ?, ?)""",
			[event.contact_id, event.game_id, event.kind_id,
			 event.datetime, event.channel, event.content_text, event.content_link]
		)
		event.id = _db.last_insert_rowid
	else:
		_db.query_with_bindings(
			"""UPDATE contact_events
			   SET contact_id=?, game_id=?, kind_id=?, datetime=?,
			       channel=?, content_text=?, content_link=?
			   WHERE id=?""",
			[event.contact_id, event.game_id, event.kind_id,
			 event.datetime, event.channel, event.content_text, event.content_link, event.id]
		)
	events_changed.emit()


func delete_contact_event(id:int)-> void:
	_db.query_with_bindings("DELETE FROM contact_events WHERE id = ?", [id])
	events_changed.emit()

#endregion Contact Events


#region Relevance

func set_contact_game_relevance(contact_id:int, game_id:int, relevant:bool)-> void:
	if relevant:
		_db.query_with_bindings(
			"INSERT OR IGNORE INTO contact_game_relevance (contact_id, game_id) VALUES (?, ?)",
			[contact_id, game_id]
		)
	else:
		_db.query_with_bindings(
			"DELETE FROM contact_game_relevance WHERE contact_id = ? AND game_id = ?",
			[contact_id, game_id]
		)

#endregion Relevance
