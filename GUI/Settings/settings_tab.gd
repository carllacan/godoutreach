class_name SettingsTab
extends ScrollContainer

const YOUTUBE_API_KEY = "youtube_api_key"
const YOUTUBE_STALE_DAYS = "youtube_stale_days"
const YOUTUBE_MAX_VIDEOS = "max_youtube_videos_fetched"

@onready var tags_list:Control = %TagsList
@onready var add_tag_field:LineEdit = %AddTagField
@onready var add_tag_button:Button = %AddTagButton
@onready var cats_list:Control = %CatsList
@onready var add_cat_field:LineEdit = %AddCatField
@onready var add_cat_button:Button = %AddCatButton
@onready var youtube_key_field:LineEdit = %YoutubeKeyField
@onready var save_key_button:Button = %SaveKeyButton
@onready var youtube_stale_days_field:SpinBox = %YoutubeStaleDaysField
@onready var save_stale_days_button:Button = %SaveStaleDaysButton
@onready var youtube_max_videos_field:SpinBox = %YoutubeMaxVideosField
@onready var save_max_videos_button:Button = %SaveMaxVideosButton
@onready var refresh_youtube_button:Button = %RefreshYoutubeButton


func _ready()-> void:
	add_tag_button.pressed.connect(_on_add_tag_pressed)
	add_tag_field.text_submitted.connect(func(_t:String): _on_add_tag_pressed())
	add_cat_button.pressed.connect(_on_add_cat_pressed)
	add_cat_field.text_submitted.connect(func(_t:String): _on_add_cat_pressed())
	save_key_button.pressed.connect(_on_save_key_pressed)
	save_stale_days_button.pressed.connect(_on_save_stale_days_pressed)
	save_max_videos_button.pressed.connect(_on_save_max_videos_pressed)
	refresh_youtube_button.pressed.connect(_on_refresh_youtube_pressed)
	Database.settings_changed.connect(_on_settings_changed)
	_rebuild_tags()
	_rebuild_categories()
	youtube_key_field.text = Database.get_setting(YOUTUBE_API_KEY)
	var stale_days_str = Database.get_setting(YOUTUBE_STALE_DAYS)
	youtube_stale_days_field.value = int(stale_days_str) if stale_days_str.is_valid_int() else 1
	var max_videos_str = Database.get_setting(YOUTUBE_MAX_VIDEOS)
	youtube_max_videos_field.value = int(max_videos_str) if max_videos_str.is_valid_int() else 10


func _on_settings_changed()-> void:
	_rebuild_tags()
	_rebuild_categories()


func _rebuild_tags()-> void:
	for child in tags_list.get_children():
		if child is DeletableButton:
			child.queue_free()
	for tag in Database.get_all_tags():
		var tag_id = tag.id
		var btn = DeletableButton.create(tag.name)
		btn.deletion_requested.connect(func(): Database.delete_tag(tag_id))
		tags_list.add_child(btn)
		move_child(btn, -1)


func _rebuild_categories()-> void:
	for child in cats_list.get_children():
		child.queue_free()
	for cat in Database.get_all_contact_categories():
		var btn = DeletableButton.create(cat.name)
		if cat.is_builtin:
			btn.modulate = Color(1, 1, 1, 0.5)
			btn.get_node("%DeleteButton").visible = false
		else:
			var cat_id = cat.id
			btn.deletion_requested.connect(func(): Database.delete_contact_category(cat_id))
		cats_list.add_child(btn)


func _on_add_tag_pressed()-> void:
	var tag_name = add_tag_field.text.strip_edges()
	if tag_name.is_empty(): return
	Database.create_tag(tag_name)
	add_tag_field.text = ""


func _on_add_cat_pressed()-> void:
	var cat_name = add_cat_field.text.strip_edges()
	if cat_name.is_empty(): return
	Database.create_contact_category(cat_name)
	add_cat_field.text = ""


func _on_save_key_pressed()-> void:
	Database.set_setting(YOUTUBE_API_KEY, youtube_key_field.text.strip_edges())


func _on_save_stale_days_pressed()-> void:
	Database.set_setting(YOUTUBE_STALE_DAYS, str(int(youtube_stale_days_field.value)))


func _on_save_max_videos_pressed()-> void:
	Database.set_setting(YOUTUBE_MAX_VIDEOS, str(int(youtube_max_videos_field.value)))


func _on_refresh_youtube_pressed()-> void:
	refresh_youtube_button.disabled = true
	refresh_youtube_button.text = "Refreshing..."
	var contacts = Database.get_all_contacts()
	await YoutubeFetcher.fetch_for_contacts(contacts, true)
	refresh_youtube_button.disabled = false
	refresh_youtube_button.text = "Refresh YouTube Data"
