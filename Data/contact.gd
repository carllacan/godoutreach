class_name Contact

class ContactLink:
	const DEFAULT_LINK_NAMES:Array[String] = [
		"Youtube",
		"Twitch"
	]
	var id:int = -1
	var name:String = ""
	var link:String = ""
	var notes:String = ""

class ContactSavedContent:
	var id:int = -1
	var link:String = ""
	var name:String = ""
	var notes:String = ""

var id:int = -1
var name:String = ""
var category_id:int = -1
var language:String = ""
var notes:String = ""
var abandoned:bool = false
var tag_ids:Array[int] = []
var links:Array = []
var saved_content:Array = []
var covered_games:Array[String] = []
var relevant_game_ids:Array[int] = []
var youtube_last_fetch:String = ""
var youtube_channel_title:String = ""
var youtube_channel_description:String = ""
var youtube_last_activity:String = ""
var youtube_subscribers:int = 0
var youtube_videos:Array = []
