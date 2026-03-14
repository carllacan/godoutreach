class_name ContactLinkEntry
extends HBoxContainer

const SCENE = preload("res://GUI/Contacts/contact_link_entry.tscn")

var read_only:bool = true : set = set_read_only

@onready var name_dropdown:OptionButton = %NameDropdown
@onready var url_field:LineEdit = %UrlField
@onready var delete_button:Button = %DeleteButton


func _ready()-> void:
	for n in Contact.ContactLink.DEFAULT_LINK_NAMES:
		name_dropdown.add_item(n)
	delete_button.pressed.connect(queue_free)


func set_read_only(new_value:bool)-> void:
	read_only = new_value
	update_state()
	

func setup(link_name:String, link_url:String)-> void:
	url_field.text = link_url
	var matched = false
	for i in name_dropdown.item_count:
		if name_dropdown.get_item_text(i) == link_name:
			name_dropdown.select(i)
			matched = true
			break
	if not matched and not link_name.is_empty():
		name_dropdown.add_item(link_name)
		name_dropdown.select(name_dropdown.item_count - 1)
		
	%NameLabel.text = link_name
	%UrlLinkButton.text = link_url


func get_link_name()-> String:
	return name_dropdown.get_item_text(name_dropdown.selected)


func get_link_url()-> String:
	return url_field.text.strip_edges()


func update_state()-> void:
	if not is_node_ready(): return
	
	if read_only:
		%NameLabel.show()
		%UrlLinkButton.show()
		
		%NameDropdown.hide()
		%UrlField.hide()
		%DeleteButton.hide()
	else:
		%NameLabel.hide()
		%UrlLinkButton.hide()
		
		%NameDropdown.show()
		%UrlField.show()
		%DeleteButton.show()
