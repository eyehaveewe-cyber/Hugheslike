@tool
extends RefCounted
## Guarded JSON persistence, including Godot's StringName dictionary shorthand.

static func json_problem(value: Variant, location: String = "$", depth: int = 0) -> String:
	if depth > 64:
		return location + ": nesting exceeds 64 levels."
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_STRING, TYPE_STRING_NAME:
			return ""
		TYPE_INT:
			return "" if value >= -9007199254740991 and value <= 9007199254740991 else location + ": integer exceeds exact JSON reader range."
		TYPE_FLOAT:
			return "" if is_finite(value) else location + ": non-finite numbers cannot be saved as JSON."
		TYPE_ARRAY:
			for index in range(value.size()):
				var error: String = json_problem(value[index], location + "[" + str(index) + "]", depth + 1)
				if not error.is_empty():
					return error
		TYPE_DICTIONARY:
			var names: Dictionary = {}
			for key in value:
				if not (key is String or key is StringName):
					return location + ": JSON object keys must be text."
				var name: String = str(key)
				if names.has(name):
					return location + ": duplicate normalized JSON key " + name
				names[name] = true
				var error: String = json_problem(value[key], location + "." + name, depth + 1)
				if not error.is_empty():
					return error
		_:
			return location + ": unsupported JSON value type " + type_string(typeof(value))
	return ""

static func json_value(value: Variant) -> Variant:
	# Dictionary.member assignments may create StringName keys. Normalize to the
	# JSON domain before writing, without rounding numbers or dropping fields.
	if value is StringName:
		return str(value)
	if value is Dictionary:
		var object: Dictionary = {}
		for key in value:
			object[str(key)] = json_value(value[key])
		return object
	if value is Array:
		var array: Array = []
		for item in value:
			array.append(json_value(item))
		return array
	return value

static func save_json(doc: Dictionary, path: String, expected_hash: String) -> String:
	var problem: String = json_problem(doc)
	if not problem.is_empty():
		return "Save refused: " + problem
	var current: String = FileAccess.get_file_as_string(path).sha256_text() if FileAccess.file_exists(path) else ""
	if current != expected_hash:
		return "Save refused: the file changed outside this atlas. Export a copy, then reload and reconcile."
	var directory: String = ProjectSettings.globalize_path(path.get_base_dir())
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		return "Cannot create data directory: " + directory
	var text: String = JSON.stringify(json_value(doc), "\t", true, true) + "\n"
	var temporary: String = path + ".tmp"
	var file: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return "Cannot write temporary file: " + error_string(FileAccess.get_open_error())
	file.store_string(text)
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK or FileAccess.get_file_as_string(temporary) != text:
		return "Temporary write failed. Original file was not changed."
	var absolute: String = ProjectSettings.globalize_path(path)
	var backup: String = absolute + ".bak"
	var had_file: bool = FileAccess.file_exists(path)
	if had_file:
		if FileAccess.file_exists(backup) and DirAccess.remove_absolute(backup) != OK:
			return "Cannot replace backup. Original file was not changed."
		if DirAccess.rename_absolute(absolute, backup) != OK:
			return "Cannot make backup. Original file was not changed."
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), absolute) != OK:
		if had_file:
			var restore_error: Error = DirAccess.rename_absolute(backup, absolute)
			if restore_error != OK:
				return "Save and rollback failed. Recover the intact .bak file manually."
		return "Could not install saved file; original restored where possible. Inspect .bak if needed."
	return ""

static func json_equal(left: Variant, right: Variant) -> bool:
	var left_numeric: bool = left is int or left is float
	var right_numeric: bool = right is int or right is float
	if left_numeric and right_numeric:
		return float(left) == float(right)
	if (left is String or left is StringName) and (right is String or right is StringName):
		return str(left) == str(right)
	if typeof(left) != typeof(right):
		return false
	if left is Dictionary:
		if left.size() != right.size():
			return false
		var right_text_keys: Dictionary = {}
		for key in right:
			right_text_keys[str(key)] = right[key]
		for key in left:
			if not right_text_keys.has(str(key)) or not json_equal(left[key], right_text_keys[str(key)]):
				return false
		return true
	if left is Array:
		if left.size() != right.size():
			return false
		for index in range(left.size()):
			if not json_equal(left[index], right[index]):
				return false
		return true
	return left == right
