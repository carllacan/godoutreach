class_name Task

enum Status { Pending, Waiting }

var status:Status = Status.Pending
var contact_id:int = -1
var contact_name:String = ""
var game_id:int = -1
var game_name:String = ""
var description:String = ""
var last_event:ContactEvent = null
