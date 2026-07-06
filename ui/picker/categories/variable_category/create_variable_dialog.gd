@tool
extends ConfirmationDialog

const BlockCodePlugin = preload("res://addons/block_code/block_code_plugin.gd")
const VariableDefinition = preload("res://addons/block_code/code_generation/variable_definition.gd")

signal create_variable(var_name: String, var_type: String)

@onready var _context := BlockEditorContext.get_default()

@onready var _variable_input := %VariableInput
@onready var _type_option := %TypeOption
@onready var _messages := %Messages

const available_types = ["STRING", "BOOL", "INT", "FLOAT", "VECTOR2", "COLOR"]

const _ALLOWED_ASCII_SYMBOLS = {
	45: true, # -
	95: true, # _
}


func _ready():
	_type_option.clear()
	_type_option.focus_next = get_cancel_button().get_path()
	get_cancel_button().focus_previous = _type_option.get_path()
	get_ok_button().focus_next = _variable_input.get_path()
	_variable_input.focus_previous = get_ok_button().get_path()

	for type in available_types:
		_type_option.add_item(type)

	_clear()


func _clear():
	# Workaround for POT generation extracting empty string.
	_variable_input.text = str("")
	get_ok_button().disabled = check_errors(_variable_input.text)
	_type_option.select(0)


func _on_variable_input_text_changed(new_text):
	get_ok_button().disabled = check_errors(new_text)


func check_errors(new_var_name: String) -> bool:
	if new_var_name.contains(" "):
		var caret_column = _variable_input.caret_column
		new_var_name = new_var_name.replace(" ", "_")
		_variable_input.text = new_var_name
		_variable_input.caret_column = caret_column

	_messages.clear()

	var errors: Array = []

	if new_var_name == "":
		errors.append("Variable requires a name")
	elif new_var_name == "_":
		errors.append("Variable name cannot be a single underscore")
	elif RegEx.create_from_string("^[0-9]").search(new_var_name) != null:
		errors.append("Variable name cannot start with numbers")

	if new_var_name.begins_with("__"):
		errors.append("Variable name cannot start with two underscores")

	if new_var_name.begins_with(VariableDefinition.SCRIPT_IDENTIFIER_PREFIX):
		errors.append("Variable name uses a reserved prefix")

	if _contains_invalid_variable_name_character(new_var_name):
		errors.append("Variable name cannot contain special characters")

	var duplicate_variable_name := false
	if _context.block_script:
		for variable in _context.block_script.variables:
			if variable.var_name == new_var_name:
				duplicate_variable_name = true
				break

	if duplicate_variable_name:
		errors.append("Variable already exists")

	if errors.is_empty():
		_messages.push_context()
		_messages.push_color(Color("73F27F"))
		_messages.push_list(0, RichTextLabel.LIST_DOTS, false)

		_messages.add_text("Will create new variable")

		_messages.pop_context()

		return false
	else:
		_messages.push_context()
		_messages.push_color(Color("FF786B"))
		_messages.push_list(0, RichTextLabel.LIST_DOTS, false)

		for error in errors:
			_messages.add_text(error)
			_messages.newline()

		_messages.pop_context()

		return true


func _contains_invalid_variable_name_character(var_name: String) -> bool:
	for i in range(var_name.length()):
		var code := var_name.unicode_at(i)
		if code > 127:
			continue

		if _is_ascii_letter_or_digit(code) or _ALLOWED_ASCII_SYMBOLS.has(code):
			continue

		return true

	return false


func _is_ascii_letter_or_digit(code: int) -> bool:
	return (code >= 48 and code <= 57) or (code >= 65 and code <= 90) or (code >= 97 and code <= 122)


func _on_confirmed():
	if check_errors(_variable_input.text):
		return

	create_variable.emit(_variable_input.text, _type_option.get_item_text(_type_option.selected))
	hide()
	_clear()


func _on_canceled():
	_clear()


func _on_about_to_popup() -> void:
	_variable_input.grab_focus()


func _on_focus_entered() -> void:
	_variable_input.grab_focus()


func _on_variable_input_text_submitted(new_text: String) -> void:
	_on_confirmed()
