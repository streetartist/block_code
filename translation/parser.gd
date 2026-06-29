@tool
## BlockCode translation parser plugin.
##
## Extracts translatable strings from BlockCode resources. Currently only
## BlockDefinition resources are handled.
extends EditorTranslationParserPlugin

const BLOCK_DEFINITION_SCRIPT_PATH := "res://addons/block_code/code_generation/block_definition.gd"
const BLOCK_DEFINITION_GD_PATH := "res://addons/block_code/code_generation/block_definition.gd"
const BLOCKS_CATALOG_GD_PATH := "res://addons/block_code/code_generation/blocks_catalog.gd"
const CONSTANTS_GD_PATH := "res://addons/block_code/ui/constants.gd"

const BLOCK_DEFINITION_DYNAMIC_MESSAGES := [
	"Set the %s property",
	"set %%s to {value: %s}",
	"Change the %s property",
	"change %%s by {value: %s}",
	"The %s property",
	"Set the %s variable",
	"set %s to {value: %s}",
	"The %s variable",
]

const CATEGORY_KEY_IGNORE := [
	"color",
	"order",
	"category",
	"default_set",
	"default_change",
	"has_setter",
	"has_change",
]

# BlockDefinition properties for translation
const block_def_tx_properties: Array[String] = [
	"category",
	"description",
	"display_template",
]


func _get_recognized_extensions() -> PackedStringArray:
	# BlockDefinition resources currently use the generic tres extension.
	return ["tres", "gd"]


func _resource_is_block_definition(resource: Resource) -> bool:
	var script := resource.get_script()
	if not script:
		return false
	return script.resource_path == BLOCK_DEFINITION_SCRIPT_PATH


func _parse_file(path: String) -> Array[PackedStringArray]:
	if path.get_extension() == "gd":
		return _parse_gd_file(path)

	# Only BlockDefinition resources are supported.
	var res = ResourceLoader.load(path, "Resource")
	if not res or not _resource_is_block_definition(res):
		return []
	# Each entry should contain [msgid, msgctxt, msgid_plural, comment],
	# where all except msgid are optional.
	var ret: Array[PackedStringArray] = []
	for prop in block_def_tx_properties:
		var value: String = res.get(prop)
		if value:
			# For now just the messages are used. It might be better to provide
			# context with msgids_context_plural to avoid conflicts.
			ret.append(PackedStringArray([value]))
	return ret


func _append_message(messages: Array[PackedStringArray], value: String):
	if value == "":
		return
	for message in messages:
		if message[0] == value:
			return
	messages.append(PackedStringArray([value]))


func _append_regex_matches(messages: Array[PackedStringArray], source: String, pattern: String):
	var regex := RegEx.create_from_string(pattern)
	for regex_match in regex.search_all(source):
		_append_message(messages, regex_match.get_string(1))


func _parse_gd_file(path: String) -> Array[PackedStringArray]:
	var messages: Array[PackedStringArray] = []

	match path:
		BLOCK_DEFINITION_GD_PATH:
			for message in BLOCK_DEFINITION_DYNAMIC_MESSAGES:
				_append_message(messages, message)
		BLOCKS_CATALOG_GD_PATH:
			var source := FileAccess.get_file_as_string(path)
			_append_regex_matches(messages, source, '"category"\\s*:\\s*"([^"]+)"')
			_append_regex_matches(messages, source, 'block_def\\.category\\s*=\\s*"([^"]+)"')
		CONSTANTS_GD_PATH:
			var source := FileAccess.get_file_as_string(path)
			_append_constant_category_keys(messages, source)

	return messages.filter(func(message): return not (message[0] in CATEGORY_KEY_IGNORE))


func _append_constant_category_keys(messages: Array[PackedStringArray], source: String):
	var regex := RegEx.create_from_string('^\\s*"([^"]+)"\\s*:')
	for line in source.split("\n"):
		var regex_match := regex.search(line)
		if regex_match:
			_append_message(messages, regex_match.get_string(1))
