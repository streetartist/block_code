extends Resource

const SCRIPT_IDENTIFIER_PREFIX = "__block_code_var_"

const RESERVED_WORDS = {
	"and": true,
	"as": true,
	"assert": true,
	"await": true,
	"break": true,
	"class": true,
	"class_name": true,
	"const": true,
	"continue": true,
	"elif": true,
	"else": true,
	"enum": true,
	"extends": true,
	"false": true,
	"for": true,
	"func": true,
	"if": true,
	"in": true,
	"is": true,
	"match": true,
	"not": true,
	"null": true,
	"or": true,
	"pass": true,
	"return": true,
	"self": true,
	"signal": true,
	"static": true,
	"super": true,
	"true": true,
	"var": true,
	"void": true,
	"while": true,
}

@export var var_name: String
@export var var_type: Variant.Type


func _init(p_var_name: String = "", p_var_type: Variant.Type = TYPE_NIL):
	var_name = p_var_name
	var_type = p_var_type


func get_script_identifier() -> String:
	return get_script_identifier_for_name(var_name)


static func get_script_identifier_for_name(name: String) -> String:
	if _is_plain_gdscript_identifier(name):
		return name

	var identifier := SCRIPT_IDENTIFIER_PREFIX
	if name.is_empty():
		return identifier + "0"

	for i in range(name.length()):
		if i > 0:
			identifier += "_"
		identifier += str(name.unicode_at(i))

	return identifier


static func _is_plain_gdscript_identifier(name: String) -> bool:
	if name.is_empty() or name.begins_with(SCRIPT_IDENTIFIER_PREFIX) or RESERVED_WORDS.has(name):
		return false

	var first_code := name.unicode_at(0)
	if not _is_ascii_identifier_start(first_code):
		return false

	for i in range(1, name.length()):
		if not _is_ascii_identifier_part(name.unicode_at(i)):
			return false

	return true


static func _is_ascii_identifier_start(code: int) -> bool:
	return code == 95 or (code >= 65 and code <= 90) or (code >= 97 and code <= 122)


static func _is_ascii_identifier_part(code: int) -> bool:
	return _is_ascii_identifier_start(code) or (code >= 48 and code <= 57)
