class_name YoutubeVideoSmallView
extends PanelContainer

const SCENE = preload("res://GUI/Contacts/youtube_video_small_view.tscn")

var video:YoutubeVideo : set = set_video

@onready var title_label:Label = %TitleLabel
@onready var date_label:Label = %DateLabel
@onready var views_label:Label = %ViewsLabel
@onready var likes_label:Label = %LikesLabel
@onready var comments_label:Label = %CommentsLabel


static func create(v:YoutubeVideo)-> YoutubeVideoSmallView:
	var view = SCENE.instantiate() as YoutubeVideoSmallView
	view.video = v
	return view


func set_video(new_value:YoutubeVideo)-> void:
	video = new_value
	make()


func _ready()-> void:
	make()


func make()-> void:
	if not is_node_ready(): return
	if video == null: return
	title_label.text = video.title
	date_label.text = video.datetime.left(10)
	views_label.text = "  %s views" % _fmt(video.views)
	likes_label.text = "  %s likes" % _fmt(video.likes)
	comments_label.text = "  %s comments" % _fmt(video.comment_count)


func _fmt(n:int)-> String:
	if n >= 1_000_000:
		return "%.1fM" % (n / 1_000_000.0)
	elif n >= 1000:
		return "%.1fk" % (n / 1000.0)
	return str(n)
