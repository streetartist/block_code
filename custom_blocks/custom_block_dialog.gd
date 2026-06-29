@tool
class_name CustomBlockDialog
extends AcceptDialog

signal catalog_changed

const BlockDefinition = preload("res://addons/block_code/code_generation/block_definition.gd")
const CustomBlockStore = preload("res://addons/block_code/custom_blocks/custom_block_store.gd")
const TxUtils := preload("res://addons/block_code/translation/utils.gd")

var _tabs: TabContainer
var _market_list: ItemList
var _market_preview: TextEdit
var _market_status_label: Label

var _name_input: LineEdit
var _category_input: LineEdit
var _target_class_input: LineEdit
var _description_input: TextEdit
var _block_type_option: OptionButton
var _value_type_option: OptionButton
var _display_template_input: TextEdit
var _code_template_input: TextEdit
var _defaults_input: TextEdit
var _signal_name_input: LineEdit
var _editor_status_label: Label
var _value_type_row: Control
var _signal_name_row: Control

var _server_url_input: LineEdit
var _username_input: LineEdit
var _password_input: LineEdit
var _token_input: LineEdit
var _settings_status_label: Label

var _http_request: HTTPRequest
var _pending_request: String = ""
var _market_blocks: Array[Dictionary] = []
var _selected_market_block: Dictionary = {}


func _init():
	TxUtils.set_block_translation_domain(self)


func _ready():
	title = tr("Block Market")
	min_size = Vector2i(820, 680)
	ok_button_text = tr("Close")

	_build_ui()
	_load_settings()
	_load_example()
	_update_type_specific_fields()

	_http_request = HTTPRequest.new()
	add_child(_http_request)
	_http_request.request_completed.connect(_on_http_request_completed)


func _build_ui():
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	_tabs = TabContainer.new()
	_tabs.custom_minimum_size = Vector2(780, 560)
	margin.add_child(_tabs)

	_build_market_tab(_create_tab(tr("Market")))
	_build_editor_tab(_create_tab(tr("Editor")))
	_build_settings_tab(_create_tab(tr("Settings")))


func _create_tab(tab_name: String) -> VBoxContainer:
	var tab_margin := MarginContainer.new()
	tab_margin.name = tab_name
	tab_margin.add_theme_constant_override("margin_left", 8)
	tab_margin.add_theme_constant_override("margin_top", 8)
	tab_margin.add_theme_constant_override("margin_right", 8)
	tab_margin.add_theme_constant_override("margin_bottom", 8)
	_tabs.add_child(tab_margin)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	tab_margin.add_child(content)
	return content


func _build_market_tab(parent: VBoxContainer):
	var toolbar := HBoxContainer.new()
	parent.add_child(toolbar)

	var refresh_button := Button.new()
	refresh_button.text = tr("Refresh")
	refresh_button.pressed.connect(_refresh_market)
	toolbar.add_child(refresh_button)

	var edit_button := Button.new()
	edit_button.text = tr("Open in Editor")
	edit_button.pressed.connect(_open_selected_market_block_in_editor)
	toolbar.add_child(edit_button)

	var save_button := Button.new()
	save_button.text = tr("Save Local Copy")
	save_button.pressed.connect(_save_selected_market_block)
	toolbar.add_child(save_button)

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(split)

	_market_list = ItemList.new()
	_market_list.custom_minimum_size = Vector2(280, 0)
	_market_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_market_list.item_selected.connect(_on_market_item_selected)
	split.add_child(_market_list)

	_market_preview = TextEdit.new()
	_market_preview.editable = false
	_market_preview.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_market_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_market_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(_market_preview)

	_market_status_label = Label.new()
	_market_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(_market_status_label)


func _build_editor_tab(parent: VBoxContainer):
	var toolbar := HBoxContainer.new()
	parent.add_child(toolbar)

	var example_button := Button.new()
	example_button.text = tr("Example")
	example_button.pressed.connect(_load_example)
	toolbar.add_child(example_button)

	var save_button := Button.new()
	save_button.text = tr("Save to Local Repository")
	save_button.pressed.connect(_save_editor_block)
	toolbar.add_child(save_button)

	var upload_button := Button.new()
	upload_button.text = tr("Upload")
	upload_button.pressed.connect(_upload_editor_block)
	toolbar.add_child(upload_button)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)

	var form := VBoxContainer.new()
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.add_theme_constant_override("separation", 8)
	scroll.add_child(form)

	_name_input = LineEdit.new()
	_name_input.placeholder_text = "set_speed"
	_add_labeled_control(form, tr("Block name"), _name_input)

	_category_input = LineEdit.new()
	_category_input.placeholder_text = "Custom | Movement"
	_add_labeled_control(form, tr("Category"), _category_input)

	_target_class_input = LineEdit.new()
	_target_class_input.placeholder_text = "Node2D, CharacterBody2D, or empty for all nodes"
	_add_labeled_control(form, tr("Target node class"), _target_class_input)

	_block_type_option = OptionButton.new()
	_add_block_type("Entry", "ENTRY")
	_add_block_type("Statement", "STATEMENT")
	_add_block_type("Value", "VALUE")
	_add_block_type("Control", "CONTROL")
	_block_type_option.item_selected.connect(func(_index): _update_type_specific_fields())
	_add_labeled_control(form, tr("Block type"), _block_type_option)

	_value_type_option = OptionButton.new()
	for type_name in ["BOOL", "INT", "FLOAT", "STRING", "STRING_NAME", "VECTOR2", "VECTOR3", "COLOR", "NODE_PATH", "OBJECT", "NIL"]:
		var index: int = _value_type_option.item_count
		_value_type_option.add_item(type_name)
		_value_type_option.set_item_metadata(index, type_name)
	_value_type_row = _add_labeled_control(form, tr("Value return type"), _value_type_option)

	_signal_name_input = LineEdit.new()
	_signal_name_input.placeholder_text = "pressed"
	_signal_name_row = _add_labeled_control(form, tr("Signal name for entry blocks"), _signal_name_input)

	_description_input = TextEdit.new()
	_description_input.custom_minimum_size = Vector2(0, 64)
	_description_input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_add_labeled_control(form, tr("Description"), _description_input)

	_display_template_input = TextEdit.new()
	_display_template_input.custom_minimum_size = Vector2(0, 76)
	_display_template_input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_add_labeled_control(form, tr("Display template"), _display_template_input)

	_code_template_input = TextEdit.new()
	_code_template_input.custom_minimum_size = Vector2(0, 120)
	_code_template_input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_add_labeled_control(form, tr("Generated GDScript template"), _code_template_input)

	_defaults_input = TextEdit.new()
	_defaults_input.custom_minimum_size = Vector2(0, 90)
	_defaults_input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_add_labeled_control(form, tr("Defaults JSON"), _defaults_input)

	_editor_status_label = Label.new()
	_editor_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(_editor_status_label)


func _build_settings_tab(parent: VBoxContainer):
	_server_url_input = LineEdit.new()
	_server_url_input.placeholder_text = CustomBlockStore.DEFAULT_SERVER_URL
	_add_labeled_control(parent, tr("Server URL"), _server_url_input)

	_username_input = LineEdit.new()
	_username_input.placeholder_text = "username"
	_add_labeled_control(parent, tr("Username"), _username_input)

	_password_input = LineEdit.new()
	_password_input.secret = true
	_password_input.placeholder_text = "password"
	_add_labeled_control(parent, tr("Password"), _password_input)

	_token_input = LineEdit.new()
	_token_input.secret = true
	_token_input.placeholder_text = tr("Created by register or login")
	_add_labeled_control(parent, tr("Access token"), _token_input)

	var toolbar := HBoxContainer.new()
	parent.add_child(toolbar)

	var save_button := Button.new()
	save_button.text = tr("Save Settings")
	save_button.pressed.connect(_save_settings_from_inputs)
	toolbar.add_child(save_button)

	var register_button := Button.new()
	register_button.text = tr("Register")
	register_button.pressed.connect(_register_account)
	toolbar.add_child(register_button)

	var login_button := Button.new()
	login_button.text = tr("Login")
	login_button.pressed.connect(_login_account)
	toolbar.add_child(login_button)

	_settings_status_label = Label.new()
	_settings_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(_settings_status_label)


func _add_labeled_control(parent: Control, label_text: String, control: Control) -> Control:
	var row := VBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 2)

	var label := Label.new()
	label.text = label_text
	row.add_child(label)

	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	parent.add_child(row)
	return row


func _add_block_type(label: String, type_name: String):
	var index: int = _block_type_option.item_count
	_block_type_option.add_item(label)
	_block_type_option.set_item_metadata(index, type_name)


func _load_settings():
	var settings: Dictionary = CustomBlockStore.load_settings()
	_server_url_input.text = CustomBlockStore.normalize_server_url(String(settings.get("server_url", CustomBlockStore.DEFAULT_SERVER_URL)))
	_username_input.text = String(settings.get("username", ""))
	_token_input.text = String(settings.get("token", ""))


func _save_settings_from_inputs():
	var settings := _settings_from_inputs()
	var error := CustomBlockStore.save_settings(settings)
	if error != OK:
		_set_status(_settings_status_label, tr("Failed to save settings: %s") % error_string(error), true)
		return
	_set_status(_settings_status_label, tr("Settings saved."))


func _settings_from_inputs() -> Dictionary:
	return {
		"server_url": CustomBlockStore.normalize_server_url(_server_url_input.text),
		"username": _username_input.text.strip_edges(),
		"token": _token_input.text.strip_edges(),
	}


func _refresh_market():
	if _request_json("market_list", "/api/blocks", HTTPClient.METHOD_GET, {}, false) == OK:
		_set_status(_market_status_label, tr("Loading market blocks..."))


func _register_account():
	var payload := {
		"username": _username_input.text.strip_edges(),
		"password": _password_input.text,
	}
	if _request_json("register", "/api/auth/register", HTTPClient.METHOD_POST, payload, false) == OK:
		_set_status(_settings_status_label, tr("Registering..."))


func _login_account():
	var payload := {
		"username": _username_input.text.strip_edges(),
		"password": _password_input.text,
	}
	if _request_json("login", "/api/auth/login", HTTPClient.METHOD_POST, payload, false) == OK:
		_set_status(_settings_status_label, tr("Logging in..."))


func _save_editor_block():
	var block_definition := _definition_from_form()
	if block_definition == null:
		return
	_save_definition_to_repository(block_definition, _editor_status_label)


func _upload_editor_block():
	var block_definition := _definition_from_form()
	if block_definition == null:
		return
	var payload := CustomBlockStore.definition_to_dictionary(block_definition)
	if _request_json("upload", "/api/blocks", HTTPClient.METHOD_POST, payload, true) == OK:
		_set_status(_editor_status_label, tr("Uploading block..."))


func _save_selected_market_block():
	if _selected_market_block.is_empty():
		_set_status(_market_status_label, tr("Select a market block first."), true)
		return
	var block_definition := CustomBlockStore.dictionary_to_definition(_selected_market_block)
	_save_definition_to_repository(block_definition, _market_status_label)


func _open_selected_market_block_in_editor():
	if _selected_market_block.is_empty():
		_set_status(_market_status_label, tr("Select a market block first."), true)
		return
	_load_definition_into_form(CustomBlockStore.dictionary_to_definition(_selected_market_block))
	_tabs.current_tab = 1
	_set_status(_editor_status_label, tr("Market block loaded into the editor."))


func _save_definition_to_repository(block_definition: BlockDefinition, status_label: Label):
	var result: Dictionary = CustomBlockStore.save_definition(block_definition)
	if int(result.get("error", FAILED)) != OK:
		_set_status(status_label, tr("Save failed: %s") % "; ".join(result.get("errors", [])), true)
		return

	_set_status(status_label, tr("Saved to %s.") % String(result.get("path", "")))
	catalog_changed.emit()


func _request_json(action: String, path: String, method: int, payload: Dictionary = {}, use_auth: bool = false) -> Error:
	var settings := _settings_from_inputs()
	var server_url := String(settings.server_url)
	var headers: Array[String] = ["Content-Type: application/json"]
	var body := ""

	if use_auth:
		var token := String(settings.token)
		if token.is_empty():
			_tabs.current_tab = 2
			_set_status(_settings_status_label, tr("Login before uploading."), true)
			return ERR_UNAUTHORIZED
		headers.append("Authorization: Bearer %s" % token)

	if method != HTTPClient.METHOD_GET:
		body = JSON.stringify(payload)

	var error := _http_request.request(server_url + path, PackedStringArray(headers), method, body)
	if error == OK:
		_pending_request = action
	return error


func _on_http_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
	var response_text := body.get_string_from_utf8()
	if result != HTTPRequest.RESULT_SUCCESS:
		_handle_request_error(tr("Server request failed: %s") % result)
		return

	var parsed: Dictionary = _parse_json(response_text)
	if response_code < 200 or response_code >= 300:
		var message := response_text
		if parsed.get("error", OK) == OK:
			message = String(parsed.data.get("error", response_text))
		_handle_request_error(tr("Server returned HTTP %s: %s") % [response_code, message])
		return

	if parsed.get("error", OK) != OK:
		_handle_request_error(tr("Server response JSON is invalid: %s") % String(parsed.get("message", "")))
		return

	var data: Dictionary = parsed.data
	match _pending_request:
		"market_list":
			_load_market_blocks(data)
		"register", "login":
			_finish_auth_request(data)
		"upload":
			_set_status(_editor_status_label, tr("Uploaded."))
		_:
			pass
	_pending_request = ""


func _handle_request_error(message: String):
	match _pending_request:
		"market_list":
			_set_status(_market_status_label, message, true)
		"register", "login":
			_set_status(_settings_status_label, message, true)
		"upload":
			_set_status(_editor_status_label, message, true)
		_:
			_set_status(_settings_status_label, message, true)
	_pending_request = ""


func _load_market_blocks(data: Dictionary):
	var blocks = data.get("blocks", [])
	if not (blocks is Array):
		_set_status(_market_status_label, tr("Server response must contain a blocks array."), true)
		return

	_market_blocks.clear()
	_market_list.clear()
	_selected_market_block = {}
	_market_preview.text = ""

	for block in blocks:
		if not (block is Dictionary):
			continue
		_market_blocks.append(block)
		var title := "%s  -  %s" % [String(block.get("name", "")), String(block.get("owner", ""))]
		_market_list.add_item(title)

	_set_status(_market_status_label, tr("Loaded %d market block(s).") % _market_blocks.size())


func _finish_auth_request(data: Dictionary):
	var username := String(data.get("username", _username_input.text.strip_edges()))
	var token := String(data.get("token", ""))
	if token.is_empty():
		_set_status(_settings_status_label, tr("Server did not return a token."), true)
		return

	_username_input.text = username
	_token_input.text = token
	_save_settings_from_inputs()
	_set_status(_settings_status_label, tr("Logged in as %s.") % username)


func _on_market_item_selected(index: int):
	if index < 0 or index >= _market_blocks.size():
		return
	_selected_market_block = _market_blocks[index]
	_market_preview.text = JSON.stringify(_selected_market_block, "\t")


func _load_example():
	_name_input.text = "set_velocity_x"
	_category_input.text = "Custom | Movement"
	_target_class_input.text = "CharacterBody2D"
	_description_input.text = "Set this character body's horizontal velocity."
	_select_option_by_metadata(_block_type_option, "STATEMENT")
	_select_option_by_metadata(_value_type_option, "FLOAT")
	_signal_name_input.text = ""
	_display_template_input.text = "set velocity x to {speed: FLOAT}"
	_code_template_input.text = "velocity.x = {speed}"
	_defaults_input.text = "{\n  \"speed\": 120.0\n}"
	if _editor_status_label:
		_set_status(_editor_status_label, tr("Example loaded."))


func _load_definition_into_form(block_definition: BlockDefinition):
	_name_input.text = String(block_definition.name)
	_category_input.text = block_definition.category
	_target_class_input.text = block_definition.target_node_class
	_description_input.text = block_definition.description
	_select_option_by_metadata(_block_type_option, CustomBlockStore.block_type_to_string(block_definition.type))
	_select_option_by_metadata(_value_type_option, CustomBlockStore.variant_type_to_string(block_definition.variant_type))
	_signal_name_input.text = block_definition.signal_name
	_display_template_input.text = block_definition.display_template
	_code_template_input.text = block_definition.code_template
	_defaults_input.text = JSON.stringify(CustomBlockStore.defaults_to_json(block_definition.defaults), "\t")
	_update_type_specific_fields()


func _update_type_specific_fields():
	var block_type := _get_selected_metadata(_block_type_option)
	_value_type_row.visible = block_type == "VALUE"
	_signal_name_row.visible = block_type == "ENTRY"


func _definition_from_form() -> BlockDefinition:
	var defaults := {}
	var defaults_text := _defaults_input.text.strip_edges()
	if not defaults_text.is_empty():
		var parsed := _parse_json(defaults_text)
		if parsed.error != OK:
			_set_status(_editor_status_label, tr("Defaults JSON is invalid: %s") % String(parsed.message), true)
			return null
		if not (parsed.data is Dictionary):
			_set_status(_editor_status_label, tr("Defaults JSON must be an object."), true)
			return null
		defaults = parsed.data

	var data := {
		"name": _name_input.text.strip_edges(),
		"target_node_class": _target_class_input.text.strip_edges(),
		"description": _description_input.text,
		"category": _category_input.text.strip_edges(),
		"type": _get_selected_metadata(_block_type_option),
		"variant_type": _get_selected_metadata(_value_type_option),
		"display_template": _display_template_input.text,
		"code_template": _code_template_input.text,
		"defaults": defaults,
		"signal_name": _signal_name_input.text.strip_edges(),
	}

	var block_definition := CustomBlockStore.dictionary_to_definition(data)
	var errors: Array[String] = CustomBlockStore.validate_definition(block_definition)
	if not errors.is_empty():
		_set_status(_editor_status_label, "; ".join(errors), true)
		return null

	return block_definition


func _parse_json(text: String) -> Dictionary:
	var json := JSON.new()
	var error := json.parse(text)
	if error != OK:
		return {"error": error, "message": json.get_error_message(), "data": {}}
	if not (json.data is Dictionary):
		return {"error": ERR_INVALID_DATA, "message": "root must be an object", "data": {}}
	return {"error": OK, "message": "", "data": json.data}


func _get_selected_metadata(option: OptionButton) -> String:
	if option.selected < 0:
		return ""
	return String(option.get_item_metadata(option.selected))


func _select_option_by_metadata(option: OptionButton, metadata: String):
	for index in range(option.item_count):
		if String(option.get_item_metadata(index)) == metadata:
			option.select(index)
			return


func _set_status(label: Label, message: String, is_error: bool = false):
	if label == null:
		return
	label.text = message
	label.add_theme_color_override("font_color", Color("ff6b6b") if is_error else Color("8bd450"))
