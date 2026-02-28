class_name Contact

class ContactLink:
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
