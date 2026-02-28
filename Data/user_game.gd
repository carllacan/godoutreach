class_name UserGame

class GameLink:
	var id:int = -1
	var name:String = ""
	var link:String = ""

class GameDescription:
	var id:int = -1
	var content:String = ""
	var tag_ids:Array[int] = []

var id:int = -1
var name:String = ""
var tag_ids:Array[int] = []
var links:Array = []
var short_descriptions:Array = []
var descriptions:Array = []
var similar_games:Array[String] = []
