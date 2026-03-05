## YoutubeFetcher autoload. Fetches YouTube channel data for contacts via the YouTube Data API v3.
## Registers as an autoload in project.godot.
extends Node

const _API_BASE = "https://www.googleapis.com/youtube/v3"
const _API_KEY_SETTING = "youtube_api_key"
const _STALE_DAYS_SETTING = "youtube_stale_days"
const _DEFAULT_STALE_DAYS = 1
const MAX_VIDEOS = 10

signal fetch_completed(contact_id:int, success:bool)


## Fetches YouTube data for a single contact if their data is stale.
## Fire-and-forget: call without await for non-blocking behavior.
func fetch_for_contact(contact:Contact)-> void:
	if contact.id == -1:
		return
	var api_key = Database.get_setting(_API_KEY_SETTING)
	if api_key.is_empty():
		return
	var url = _get_youtube_url(contact)
	if url.is_empty():
		return
	Database.load_contact_youtube(contact)
	if not _is_stale(contact.youtube_last_fetch):
		return
	await _do_fetch(contact, api_key)


## Fetches YouTube data for multiple contacts. More API-efficient for bulk updates
## because channel stats are requested in a single batched channels.list call.
func fetch_for_contacts(contacts:Array)-> void:
	var api_key = Database.get_setting(_API_KEY_SETTING)
	if api_key.is_empty():
		return

	var to_fetch:Array = []
	for contact in contacts:
		var c = contact as Contact
		if c == null or c.id == -1:
			continue
		if _get_youtube_url(c).is_empty():
			continue
		Database.load_contact_youtube(c)
		if _is_stale(c.youtube_last_fetch):
			to_fetch.append(c)

	if to_fetch.is_empty():
		return

	# Resolve channel IDs (one request per contact, only for non-direct IDs)
	var contact_channel_map:Dictionary = {}  # contact_id -> channel_id
	for contact in to_fetch:
		var c = contact as Contact
		var identifier = _parse_channel_identifier(_get_youtube_url(c))
		var channel_id = await _resolve_to_channel_id(identifier, api_key)
		if not channel_id.is_empty():
			contact_channel_map[c.id] = channel_id

	if contact_channel_map.is_empty():
		return

	# Batch fetch all channel stats in a single API call
	var ids_csv = ",".join(contact_channel_map.values())
	var channel_stats = await _fetch_channel_stats_batch(ids_csv, api_key)

	for contact in to_fetch:
		var c = contact as Contact
		var channel_id:String = contact_channel_map.get(c.id, "")
		if channel_id.is_empty():
			continue
		var stats:Dictionary = channel_stats.get(channel_id, {})
		if stats.is_empty():
			continue
		_apply_channel_stats(c, stats)
		var uploads_id:String = stats.get("uploads_playlist_id", "")
		if not uploads_id.is_empty():
			var videos = await _fetch_latest_videos(uploads_id, api_key)
			c.youtube_videos = videos
			if not videos.is_empty():
				c.youtube_last_activity = (videos[0] as YoutubeVideo).datetime
		c.youtube_last_fetch = Time.get_datetime_string_from_system(true)
		Database.save_contact_youtube(c)
		fetch_completed.emit(c.id, true)


#region Private helpers

func _is_stale(last_fetch:String)-> bool:
	if last_fetch.is_empty():
		return true
	var stale_days_str = Database.get_setting(_STALE_DAYS_SETTING)
	var stale_days = int(stale_days_str) if stale_days_str.is_valid_int() else _DEFAULT_STALE_DAYS
	var stored_unix = Time.get_unix_time_from_datetime_string(last_fetch)
	var now_unix = Time.get_unix_time_from_system()
	return (now_unix - stored_unix) > (stale_days * 86400.0)


func _get_youtube_url(contact:Contact)-> String:
	for link in contact.links:
		var l = link as Contact.ContactLink
		if l != null and l.name.to_lower() == "youtube":
			return l.link
	return ""


## Parses a YouTube URL into {type, value} for channel resolution.
func _parse_channel_identifier(url:String)-> Dictionary:
	# Direct channel ID: youtube.com/channel/UCxxxxx
	var re = RegEx.new()
	re.compile("youtube\\.com/channel/([A-Za-z0-9_-]+)")
	var m = re.search(url)
	if m:
		return {type = "id", value = m.get_string(1)}

	# Handle: youtube.com/@handle
	re.compile("youtube\\.com/@([A-Za-z0-9_.-]+)")
	m = re.search(url)
	if m:
		return {type = "handle", value = "@" + m.get_string(1)}

	# Legacy user: youtube.com/user/username
	re.compile("youtube\\.com/user/([A-Za-z0-9_]+)")
	m = re.search(url)
	if m:
		return {type = "username", value = m.get_string(1)}

	# Custom URL: youtube.com/c/name or youtube.com/name
	re.compile("youtube\\.com/(?:c/)?([A-Za-z0-9_]+)")
	m = re.search(url)
	if m and m.get_string(1) not in ["watch", "shorts", "playlist", "feed"]:
		return {type = "handle", value = m.get_string(1)}

	return {}


func _resolve_to_channel_id(identifier:Dictionary, api_key:String)-> String:
	if identifier.is_empty():
		return ""
	if identifier.type == "id":
		return identifier.value
	var param_key = "forHandle" if identifier.type in ["handle", "custom"] else "forUsername"
	var url = "%s/channels?part=id&%s=%s&key=%s" % [
		_API_BASE, param_key, identifier.value, api_key
	]
	var data = await _http_get(url)
	var items = data.get("items", [])
	if items.is_empty():
		return ""
	return items[0].get("id", "")


## Returns dict: channel_id -> {title, description, subscribers, uploads_playlist_id}
func _fetch_channel_stats_batch(channel_ids_csv:String, api_key:String)-> Dictionary:
	var url = "%s/channels?part=snippet,statistics,contentDetails&id=%s&key=%s" % [
		_API_BASE, channel_ids_csv, api_key
	]
	var data = await _http_get(url)
	var result:Dictionary = {}
	for item in data.get("items", []):
		var channel_id:String = item.get("id", "")
		if channel_id.is_empty():
			continue
		var snippet:Dictionary = item.get("snippet", {})
		var statistics:Dictionary = item.get("statistics", {})
		var content_details:Dictionary = item.get("contentDetails", {})
		var subs_str:String = statistics.get("subscriberCount", "0")
		result[channel_id] = {
			title = snippet.get("title", ""),
			description = snippet.get("description", ""),
			subscribers = int(subs_str) if subs_str.is_valid_int() else 0,
			uploads_playlist_id = content_details.get("relatedPlaylists", {}).get("uploads", ""),
		}
	return result


func _apply_channel_stats(contact:Contact, stats:Dictionary)-> void:
	contact.youtube_channel_title = stats.get("title", "")
	contact.youtube_channel_description = stats.get("description", "")
	contact.youtube_subscribers = stats.get("subscribers", 0)


## Fetches latest videos from the channel's uploads playlist.
## Returns an Array of YoutubeVideo, newest first.
func _fetch_latest_videos(uploads_playlist_id:String, api_key:String)-> Array:
	var url = "%s/playlistItems?part=snippet&playlistId=%s&maxResults=%d&key=%s" % [
		_API_BASE, uploads_playlist_id, MAX_VIDEOS, api_key
	]
	var data = await _http_get(url)
	var video_ids:Array[String] = []
	for item in data.get("items", []):
		var vid_id:String = item.get("snippet", {}).get("resourceId", {}).get("videoId", "")
		if not vid_id.is_empty():
			video_ids.append(vid_id)

	if video_ids.is_empty():
		return []

	# Batch fetch video statistics in a single call
	var ids_csv = ",".join(video_ids)
	var stats_url = "%s/videos?part=snippet,statistics&id=%s&key=%s" % [
		_API_BASE, ids_csv, api_key
	]
	var stats_data = await _http_get(stats_url)

	var videos:Array = []
	for item in stats_data.get("items", []):
		var video = YoutubeVideo.new()
		var snippet:Dictionary = item.get("snippet", {})
		var statistics:Dictionary = item.get("statistics", {})
		video.title = snippet.get("title", "")
		video.description = snippet.get("description", "")
		video.datetime = snippet.get("publishedAt", "")
		var views_str:String = statistics.get("viewCount", "0")
		var likes_str:String = statistics.get("likeCount", "0")
		var comments_str:String = statistics.get("commentCount", "0")
		video.views = int(views_str) if views_str.is_valid_int() else 0
		video.likes = int(likes_str) if likes_str.is_valid_int() else 0
		video.comment_count = int(comments_str) if comments_str.is_valid_int() else 0
		videos.append(video)
	return videos


func _do_fetch(contact:Contact, api_key:String)-> void:
	var identifier = _parse_channel_identifier(_get_youtube_url(contact))
	var channel_id = await _resolve_to_channel_id(identifier, api_key)
	if channel_id.is_empty():
		push_warning("YoutubeFetcher: could not resolve channel ID for contact %d" % contact.id)
		fetch_completed.emit(contact.id, false)
		return

	var stats_dict = await _fetch_channel_stats_batch(channel_id, api_key)
	var stats:Dictionary = stats_dict.get(channel_id, {})
	if stats.is_empty():
		fetch_completed.emit(contact.id, false)
		return

	_apply_channel_stats(contact, stats)

	var uploads_id:String = stats.get("uploads_playlist_id", "")
	if not uploads_id.is_empty():
		var videos = await _fetch_latest_videos(uploads_id, api_key)
		contact.youtube_videos = videos
		if not videos.is_empty():
			contact.youtube_last_activity = (videos[0] as YoutubeVideo).datetime

	contact.youtube_last_fetch = Time.get_datetime_string_from_system(true)
	Database.save_contact_youtube(contact)
	fetch_completed.emit(contact.id, true)


## Makes an HTTP GET request. Returns parsed JSON dict, or empty dict on failure.
func _http_get(url:String)-> Dictionary:
	var http = HTTPRequest.new()
	add_child(http)
	var err = http.request(url)
	if err != OK:
		http.queue_free()
		push_warning("YoutubeFetcher: failed to send request to %s" % url)
		return {}
	var response = await http.request_completed
	http.queue_free()
	var result_code:int = response[0]
	var http_code:int = response[1]
	var body:PackedByteArray = response[3]
	if result_code != HTTPRequest.RESULT_SUCCESS or http_code != 200:
		push_warning("YoutubeFetcher: HTTP %d (result %d) for %s" % [http_code, result_code, url])
		return {}
	var json = JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		push_warning("YoutubeFetcher: JSON parse error for %s" % url)
		return {}
	return json.data if json.data is Dictionary else {}

#endregion Private helpers
