@tool
extends Object

const BlockDefinition = preload("res://addons/block_code/code_generation/block_definition.gd")
const Types = preload("res://addons/block_code/types/types.gd")
const Util = preload("res://addons/block_code/code_generation/util.gd")

const SCHEMA_VERSION = 1
const USER_BLOCKS_DIR = "res://block_code_user_blocks"
const ADDON_USER_BLOCKS_DIR = "res://addons/block_code/user_blocks"
const SETTINGS_PATH = "user://block_code_custom_blocks.cfg"
const DEFAULT_SERVER_URL = "https://block.streetartist.top"

const BLOCK_TYPE_TO_STRING = {
	Types.BlockType.ENTRY: "ENTRY",
	Types.BlockType.STATEMENT: "STATEMENT",
	Types.BlockType.VALUE: "VALUE",
	Types.BlockType.CONTROL: "CONTROL",
}

const STRING_TO_BLOCK_TYPE = {
	"ENTRY": Types.BlockType.ENTRY,
	"STATEMENT": Types.BlockType.STATEMENT,
	"VALUE": Types.BlockType.VALUE,
	"CONTROL": Types.BlockType.CONTROL,
}

static var _name_regex := RegEx.create_from_string("^[A-Za-z_][A-Za-z0-9_]*$")
static var _filename_regex := RegEx.create_from_string("[^A-Za-z0-9_\\-]+")
static var _display_parameter_regex := RegEx.create_from_string("\\[(?<out_parameter>[^\\]]+)\\]|\\{const (?<const_parameter>[^}]+)\\}|\\{(?!const )(?<in_parameter>[^}]+)\\}")


static func ensure_user_blocks_dir() -> Error:
	return DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(USER_BLOCKS_DIR))


static func load_settings() -> Dictionary:
	var config := ConfigFile.new()
	var error := config.load(SETTINGS_PATH)
	var settings := {
		"server_url": DEFAULT_SERVER_URL,
		"username": "",
		"token": "",
	}
	if error != OK:
		return settings

	settings.server_url = String(config.get_value("server", "url", DEFAULT_SERVER_URL))
	settings.username = String(config.get_value("account", "username", ""))
	settings.token = String(config.get_value("account", "token", ""))
	return settings


static func save_settings(settings: Dictionary) -> Error:
	var config := ConfigFile.new()
	config.set_value("server", "url", normalize_server_url(String(settings.get("server_url", DEFAULT_SERVER_URL))))
	config.set_value("account", "username", String(settings.get("username", "")))
	config.set_value("account", "token", String(settings.get("token", "")))
	return config.save(SETTINGS_PATH)


static func normalize_server_url(url: String) -> String:
	var normalized := url.strip_edges()
	if normalized.is_empty():
		normalized = DEFAULT_SERVER_URL
	while normalized.ends_with("/"):
		normalized = normalized.trim_suffix("/")
	return normalized


static func get_definition_path(block_name: String) -> String:
	return "%s/%s.tres" % [USER_BLOCKS_DIR, sanitize_file_name(block_name)]


static func sanitize_file_name(block_name: String) -> String:
	var file_name := _filename_regex.sub(block_name.strip_edges().to_lower(), "_", true)
	if file_name.is_empty():
		return "custom_block"
	return file_name


static func save_definition(block_definition: BlockDefinition) -> Dictionary:
	var errors := validate_definition(block_definition)
	if not errors.is_empty():
		return {"error": ERR_INVALID_DATA, "path": "", "errors": errors}

	var dir_error := ensure_user_blocks_dir()
	if dir_error != OK:
		return {"error": dir_error, "path": "", "errors": ["Cannot create %s." % USER_BLOCKS_DIR]}

	var path := get_definition_path(String(block_definition.name))
	var save_error := ResourceSaver.save(block_definition, path)
	return {"error": save_error, "path": path, "errors": []}


static func can_delete_definition(block_definition: BlockDefinition) -> bool:
	return not get_deletable_definition_path(block_definition).is_empty()


static func delete_definition(block_definition: BlockDefinition) -> Dictionary:
	var path := get_deletable_definition_path(block_definition)
	if path.is_empty():
		return {"error": ERR_INVALID_PARAMETER, "path": "", "errors": ["This custom block cannot be deleted."]}
	if not FileAccess.file_exists(path):
		return {"error": ERR_FILE_NOT_FOUND, "path": path, "errors": ["Cannot find %s." % path]}

	var error := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if error != OK:
		return {"error": error, "path": path, "errors": ["Cannot delete %s." % path]}

	return {"error": OK, "path": path, "errors": []}


static func get_deletable_definition_path(block_definition: BlockDefinition) -> String:
	if block_definition == null:
		return ""

	var path := block_definition.resource_path
	if path.get_extension().to_lower() != "tres":
		return ""
	if path == USER_BLOCKS_DIR or not path.begins_with(USER_BLOCKS_DIR + "/"):
		return ""
	return path


static func load_definitions() -> Array[BlockDefinition]:
	var result: Array[BlockDefinition] = []
	for directory in [USER_BLOCKS_DIR, ADDON_USER_BLOCKS_DIR]:
		result.append_array(_load_resource_definitions(directory))
		result.append_array(_load_json_definitions(directory))
	return result


static func _load_resource_definitions(directory: String) -> Array[BlockDefinition]:
	var result: Array[BlockDefinition] = []
	for file_path in Util.get_files_in_dir_recursive(directory, "*.tres"):
		var block_definition := load(file_path) as BlockDefinition
		if block_definition == null:
			push_warning("Skipping invalid custom block resource: %s" % file_path)
			continue
		var errors := validate_definition(block_definition)
		if not errors.is_empty():
			push_warning("Skipping invalid custom block %s: %s" % [file_path, "; ".join(errors)])
			continue
		result.append(block_definition)
	return result


static func _load_json_definitions(directory: String) -> Array[BlockDefinition]:
	var result: Array[BlockDefinition] = []
	for file_path in Util.get_files_in_dir_recursive(directory, "*.json"):
		var parsed := _read_json_file(file_path)
		if parsed.is_empty():
			continue
		var blocks := parsed.get("blocks", [parsed])
		if not (blocks is Array):
			push_warning("Skipping invalid custom block JSON: %s" % file_path)
			continue
		for block_data in blocks:
			if not (block_data is Dictionary):
				continue
			var block_definition := dictionary_to_definition(block_data)
			var errors := validate_definition(block_definition)
			if not errors.is_empty():
				push_warning("Skipping invalid custom block in %s: %s" % [file_path, "; ".join(errors)])
				continue
			result.append(block_definition)
	return result


static func _read_json_file(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		return {}

	var text := FileAccess.get_file_as_string(file_path)
	var json := JSON.new()
	var error := json.parse(text)
	if error != OK:
		push_warning("Cannot parse %s: %s" % [file_path, json.get_error_message()])
		return {}
	if not (json.data is Dictionary):
		push_warning("Custom block JSON root must be an object: %s" % file_path)
		return {}
	return json.data


static func dictionary_to_definition(data: Dictionary) -> BlockDefinition:
	var block_type := _parse_block_type(data.get("type", "STATEMENT"))
	var variant_type := _parse_variant_type(data.get("variant_type", "NIL"))
	if block_type != Types.BlockType.VALUE:
		variant_type = TYPE_NIL

	var block_definition := BlockDefinition.new(
		StringName(String(data.get("name", "")).strip_edges()),
		String(data.get("target_node_class", "")).strip_edges(),
		String(data.get("description", "")),
		String(data.get("category", "Custom")).strip_edges(),
		block_type,
		variant_type,
		String(data.get("display_template", "")),
		String(data.get("code_template", "")),
		{},
		String(data.get("signal_name", "")).strip_edges(),
		"",
		null,
		bool(data.get("is_advanced", false))
	)

	var defaults = data.get("defaults", {})
	if defaults is Dictionary:
		block_definition.defaults = coerce_defaults(defaults, get_display_parameter_types(block_definition.display_template))

	return block_definition


static func definition_to_dictionary(block_definition: BlockDefinition) -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"name": String(block_definition.name),
		"target_node_class": block_definition.target_node_class,
		"description": block_definition.description,
		"category": block_definition.category,
		"type": block_type_to_string(block_definition.type),
		"variant_type": variant_type_to_string(block_definition.variant_type),
		"display_template": block_definition.display_template,
		"code_template": block_definition.code_template,
		"defaults": defaults_to_json(block_definition.defaults),
		"signal_name": block_definition.signal_name,
		"is_advanced": block_definition.is_advanced,
	}


static func block_summary_to_text(data: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("name: %s" % String(data.get("name", "")))
	lines.append("category: %s" % String(data.get("category", "")))
	lines.append("owner: %s" % String(data.get("owner", "")))
	lines.append("type: %s" % String(data.get("type", "")))
	lines.append("target_node_class: %s" % String(data.get("target_node_class", "")))
	lines.append("")
	lines.append(String(data.get("description", "")))
	return "\n".join(lines)


static func validate_definition(block_definition: BlockDefinition) -> Array[String]:
	var errors: Array[String] = []
	var block_name := String(block_definition.name).strip_edges()

	if block_name.is_empty():
		errors.append("Name is required.")
	elif _name_regex.search(block_name) == null:
		errors.append("Name must start with a letter or underscore and contain only letters, numbers, and underscores.")

	if block_definition.category.strip_edges().is_empty():
		errors.append("Category is required.")

	if not BLOCK_TYPE_TO_STRING.has(block_definition.type):
		errors.append("Block type must be ENTRY, STATEMENT, VALUE, or CONTROL.")

	if block_definition.type == Types.BlockType.VALUE and not Types.VARIANT_TYPE_TO_STRING.has(block_definition.variant_type):
		errors.append("Value blocks need a valid return type.")

	if block_definition.display_template.strip_edges().is_empty():
		errors.append("Display template is required.")

	if block_definition.code_template.strip_edges().is_empty():
		errors.append("Code template is required.")

	errors.append_array(validate_display_template(block_definition.display_template))

	var parameter_types := get_display_parameter_types(block_definition.display_template)
	for default_name in block_definition.defaults.keys():
		if not parameter_types.has(default_name):
			errors.append("Default value '%s' is not used in the display template." % default_name)

	return errors


static func validate_display_template(display_template: String) -> Array[String]:
	var errors: Array[String] = []
	var parameter_names: Array[String] = []
	for regex_match in _display_parameter_regex.search_all(display_template):
		var parameter_string := _get_parameter_string(regex_match)
		var parsed := parse_parameter_format(parameter_string)
		if parsed.has("error"):
			errors.append(parsed.error)
			continue
		if parameter_names.has(parsed.name):
			errors.append("Parameter '%s' is defined more than once." % parsed.name)
		parameter_names.append(parsed.name)
	return errors


static func get_display_parameter_types(display_template: String) -> Dictionary:
	var result := {}
	for regex_match in _display_parameter_regex.search_all(display_template):
		var parsed := parse_parameter_format(_get_parameter_string(regex_match))
		if parsed.has("error"):
			continue
		result[parsed.name] = parsed.type
	return result


static func parse_parameter_format(parameter_format: String) -> Dictionary:
	var split := parameter_format.split(":", true, 1)
	var parameter_name := split[0].strip_edges() if split.size() > 0 else ""
	var type_name := split[1].strip_edges().to_upper() if split.size() > 1 else ""

	if parameter_name.is_empty():
		return {"error": "A template parameter is missing its name."}
	if _name_regex.search(parameter_name) == null:
		return {"error": "Parameter '%s' must contain only letters, numbers, and underscores." % parameter_name}
	if type_name.is_empty():
		return {"error": "Parameter '%s' is missing a type." % parameter_name}
	if not Types.STRING_TO_VARIANT_TYPE.has(type_name):
		return {"error": "Parameter '%s' uses unsupported type '%s'." % [parameter_name, type_name]}

	return {"name": parameter_name, "type": Types.STRING_TO_VARIANT_TYPE[type_name]}


static func coerce_defaults(defaults: Dictionary, parameter_types: Dictionary) -> Dictionary:
	var result := {}
	for key in defaults.keys():
		var parameter_name := String(key)
		var parameter_type = parameter_types.get(parameter_name, TYPE_NIL)
		result[parameter_name] = _coerce_default_value(defaults[key], parameter_type)
	return result


static func defaults_to_json(defaults: Dictionary) -> Dictionary:
	var result := {}
	for key in defaults.keys():
		result[String(key)] = _variant_to_json(defaults[key])
	return result


static func block_type_to_string(block_type: int) -> String:
	return BLOCK_TYPE_TO_STRING.get(block_type, "STATEMENT")


static func variant_type_to_string(variant_type: Variant.Type) -> String:
	return Types.VARIANT_TYPE_TO_STRING.get(variant_type, "NIL")


static func _get_parameter_string(regex_match: RegExMatch) -> String:
	if regex_match.names.has("in_parameter"):
		return regex_match.get_string("in_parameter")
	if regex_match.names.has("out_parameter"):
		return regex_match.get_string("out_parameter")
	if regex_match.names.has("const_parameter"):
		return regex_match.get_string("const_parameter")
	return ""


static func _parse_block_type(value) -> int:
	if value is int:
		return value if BLOCK_TYPE_TO_STRING.has(value) else Types.BlockType.STATEMENT
	var type_name := String(value).strip_edges().to_upper()
	return STRING_TO_BLOCK_TYPE.get(type_name, Types.BlockType.STATEMENT)


static func _parse_variant_type(value) -> Variant.Type:
	if value is int:
		return value
	var type_name := String(value).strip_edges().to_upper()
	return Types.STRING_TO_VARIANT_TYPE.get(type_name, TYPE_NIL)


static func _coerce_default_value(value, target_type: Variant.Type):
	match target_type:
		TYPE_BOOL:
			return bool(value)
		TYPE_INT:
			return int(value)
		TYPE_FLOAT:
			return float(value)
		TYPE_STRING:
			return String(value)
		TYPE_STRING_NAME:
			return StringName(String(value))
		TYPE_NODE_PATH:
			return NodePath(String(value))
		TYPE_VECTOR2:
			if value is Array and value.size() >= 2:
				return Vector2(float(value[0]), float(value[1]))
			if value is Dictionary:
				return Vector2(float(value.get("x", 0.0)), float(value.get("y", 0.0)))
			return Vector2.ZERO
		TYPE_VECTOR3:
			if value is Array and value.size() >= 3:
				return Vector3(float(value[0]), float(value[1]), float(value[2]))
			if value is Dictionary:
				return Vector3(float(value.get("x", 0.0)), float(value.get("y", 0.0)), float(value.get("z", 0.0)))
			return Vector3.ZERO
		TYPE_COLOR:
			if value is Array and value.size() >= 3:
				var alpha := float(value[3]) if value.size() >= 4 else 1.0
				return Color(float(value[0]), float(value[1]), float(value[2]), alpha)
			if value is String:
				return Color(String(value))
			return Color.WHITE
		_:
			return value


static func _variant_to_json(value):
	match typeof(value):
		TYPE_VECTOR2:
			return [value.x, value.y]
		TYPE_VECTOR3:
			return [value.x, value.y, value.z]
		TYPE_COLOR:
			return [value.r, value.g, value.b, value.a]
		TYPE_NODE_PATH, TYPE_STRING_NAME:
			return String(value)
		_:
			return value
