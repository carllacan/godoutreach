extends VBoxContainer
class_name ContactFullView

## Shows all the information in a contact, and provides a GUI to edit it


enum Mode {
	READ,
	EDIT,
}

var mode:Mode = Mode.READ : set = set_mode


func set_mode(new_value:Mode)-> void:
	mode = new_value
	
	update_mode()
	
	
func update_mode()-> void:
	if not is_node_ready(): return
	
	match mode:
		Mode.READ:
			%NameLabel.show()
			%EmailLinkButton.show()
			%CategoryLabel.show()
			%LanguageLabel.show()
			%AbandonedCheck.hide()
			%AbandonedLabel.visible = %AbandonedCheck.button_pressed
			%NotesContainerPanel.show()
			%TagsLabel.show()
			%EditButton.show()
			
			%NameField.hide()
			%EmailField.hide()
			%CategoryField.hide()
			%LanguageField.hide()
			%NotesField.hide()
			%TagsContainer.hide()
			%AddLinkButton.hide()
			%SaveButton.hide()
			%DeleteButton.hide()
			
			for l:ContactLinkEntry in %LinksContainer.get_children():
				assert(l is ContactLinkEntry)
				l.read_only = true
				
		Mode.EDIT:
			%NameLabel.hide()
			%EmailLinkButton.hide()
			%CategoryLabel.hide()
			%LanguageLabel.hide()
			%AbandonedCheck.show()
			%AbandonedLabel.hide()
			%NotesContainerPanel.hide()
			%TagsLabel.hide()
			%EditButton.hide()
			
			%NameField.show()
			%EmailField.show()
			%CategoryField.show()
			%LanguageField.show()
			%NotesField.show()
			%TagsContainer.show()
			%AddLinkButton.show()
			%SaveButton.show()
			%DeleteButton.show()
			
			for l:ContactLinkEntry in %LinksContainer.get_children():
				assert(l is ContactLinkEntry)
				l.read_only = false
