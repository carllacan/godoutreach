class_name ContactsImporter

const ImportResult = preload("res://Data/contacts_import_result.gd")
const DELIMITER = ";"

static func import_csv(path:String) -> ImportResult:
	var result = ImportResult.new()

	if not FileAccess.file_exists(path):
		result.errors.append("File not found: %s" % path)
		return result

	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		result.errors.append("Could not open file: %s" % path)
		return result

	# Check for BOM
	var bom = file.get_buffer(3)
	if bom[0] == 0xFF or bom[0] == 0xFE:
		result.errors.append(
			"File appears to be UTF-16 encoded. Please re-save it as UTF-8 CSV from your spreadsheet app (e.g. in Excel: Save As → CSV UTF-8)."
		)
		file.close()
		return result

	# Rewind: if UTF-8 BOM skip 3 bytes, otherwise go back to start
	if bom[0] == 0xEF and bom[1] == 0xBB and bom[2] == 0xBF:
		file.seek(3)
	else:
		file.seek(0)

	var lines:Array[String] = []
	while not file.eof_reached():
		var line = file.get_line()
		if not line.strip_edges().is_empty():
			lines.append(line)
	file.close()

	if lines.is_empty():
		result.errors.append("File is empty.")
		return result

	var headers = _parse_csv_row(lines[0])
	var name_col = _find_col(headers, "name")
	var youtube_col = _find_col(headers, "youtube")
	var twitch_col = _find_col(headers, "twitch")

	if name_col == -1:
		result.errors.append('CSV must have a "name" column in the header row.')
		return result

	for i in range(1, lines.size()):
		var row = _parse_csv_row(lines[i])
		if row.size() <= name_col:
			result.errors.append("Row %d has too few columns, skipping." % (i + 1))
			continue

		var contact_name = row[name_col].strip_edges()
		if contact_name.is_empty():
			result.errors.append("Row %d has an empty name, skipping." % (i + 1))
			continue

		var contact = Contact.new()
		contact.name = contact_name

		if youtube_col != -1 and row.size() > youtube_col:
			var youtube_url = row[youtube_col].strip_edges()
			if not youtube_url.is_empty():
				var link = Contact.ContactLink.new()
				link.name = "Youtube"
				link.link = youtube_url
				contact.links.append(link)

		if twitch_col != -1 and row.size() > twitch_col:
			var twitch_url = row[twitch_col].strip_edges()
			if not twitch_url.is_empty():
				var link = Contact.ContactLink.new()
				link.name = "Twitch"
				link.link = twitch_url
				contact.links.append(link)

		result.contacts.append(contact)

	return result


static func _find_col(headers:Array, col_name:String) -> int:
	for i in headers.size():
		if headers[i].strip_edges().to_lower() == col_name:
			return i
	return -1


static func _parse_csv_row(line:String) -> Array[String]:
	var fields:Array[String] = []
	var current = ""
	var in_quotes = false
	var i = 0

	while i < line.length():
		var c = line[i]
		if c == "\"":
			if in_quotes and i + 1 < line.length() and line[i + 1] == "\"":
				current += "\""
				i += 2
				continue
			else:
				in_quotes = not in_quotes
		elif c == DELIMITER and not in_quotes:
			fields.append(current)
			current = ""
			i += 1
			continue
		else:
			current += c
		i += 1

	fields.append(current)
	return fields
