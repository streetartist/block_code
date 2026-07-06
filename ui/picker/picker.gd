@tool
extends MarginContainer

const BlockDefinition = preload("res://addons/block_code/code_generation/block_definition.gd")
const BlockCategory = preload("res://addons/block_code/ui/picker/categories/block_category.gd")
const BlockCategoryButtonScene = preload("res://addons/block_code/ui/picker/categories/block_category_button.tscn")
const BlockCategoryButton = preload("res://addons/block_code/ui/picker/categories/block_category_button.gd")
const BlockCategoryDisplay = preload("res://addons/block_code/ui/picker/categories/block_category_display.gd")
const BlockCategoryDisplayScene = preload("res://addons/block_code/ui/picker/categories/block_category_display.tscn")
const CustomBlockStore = preload("res://addons/block_code/custom_blocks/custom_block_store.gd")
const TxUtils := preload("res://addons/block_code/translation/utils.gd")
const VariableCategoryDisplayScene = preload("res://addons/block_code/ui/picker/categories/variable_category/variable_category_display.tscn")
const VariableDefinition = preload("res://addons/block_code/code_generation/variable_definition.gd")

const CATEGORY_ORDER_OVERRIDE = {
	"Lifecycle": [&"ready", &"process", &"physics_process", &"set_process_enabled", &"set_physics_process_enabled", &"queue_free", &"queue_free_node"],
	"Loops": [&"for", &"while", &"break", &"continue", &"await_scene_ready", &"wait_seconds"],
	"Log": [&"print"],
	"Communication | Methods": [&"define_method", &"call_method_group", &"call_method_node"],
	"Communication | Scenes": [&"current_scene", &"get_tree", &"switch_scene", &"reload_current_scene", &"set_game_paused", &"quit_game"],
	"Communication | Nodes": [&"get_node", &"get_parent", &"get_node_parent", &"get_child", &"get_child_count", &"find_child", &"node_name", &"set_node_name", &"add_child", &"add_child_to_node", &"remove_child", &"remove_child_from_node"],
	"Communication | Groups": [&"add_to_group", &"add_node_to_group", &"remove_from_group", &"remove_node_from_group", &"is_in_group", &"is_node_in_group"],
	"Variables": [&"vector2"],
	"Math": [&"add", &"subtract", &"multiply", &"divide", &"abs", &"clamp", &"min", &"max", &"floor", &"ceil", &"round", &"lerp", &"move_toward", &"pow", &"randf_range", &"randi_range", &"sin", &"cos", &"tan", &"vector2", &"vector3", &"vector2_xy", &"vector3_xyz", &"vector_multiply", &"vector3_multiply", &"vector_from_angle", &"vector2_length", &"vector2_normalized", &"vector2_distance_to", &"vector2_direction_to", &"vector2_angle"],
	"Logic | Conditionals": [&"if", &"else", &"else_if"],
	"Input": [&"is_input_actioned", &"input_axis", &"action_strength", &"is_mouse_button_pressed", &"mouse_position", &"characterbody2d_move", &"characterbody2d_is_on_floor"],
	"Sounds": [&"load_sound", &"play_sound", &"pause_continue_sound", &"stop_sound", &"audiostreamplayer_play", &"audiostreamplayer_stop", &"audio_is_playing", &"audio_set_volume_db", &"audio_set_pitch_scale"],
	"Transform | Position": [&"node_position", &"node_global_position", &"set_node_position", &"change_node_position", &"set_node_global_position"],
	"Transform | Rotation": [&"node_rotation_degrees", &"set_node_rotation_degrees", &"change_node_rotation_degrees", &"node_look_at"],
	"Transform | Scale": [&"node_scale", &"set_node_scale"],
	"Graphics | Visibility": [&"show_node", &"hide_node", &"set_node_visible", &"node_is_visible"],
	"Graphics | Modulate": [&"set_node_modulate"],
	"Graphics | Viewport": [&"viewport_width", &"viewport_height", &"viewport_center"],
	"Lifecycle | Spawn": [&"instantiate_scene"],
}

signal block_picked(block: Block, offset: Vector2)
signal variable_created(variable: VariableDefinition)
signal variables_deleted(variables: Array[String])
signal custom_block_deleted

@onready var _context := BlockEditorContext.get_default()

@onready var _block_list := %BlockList
@onready var _block_scroll := %BlockScroll
@onready var _category_list := %CategoryList
@onready var _search_box: LineEdit = %SearchBox
@onready var _widget_container := %WidgetContainer

var scroll_tween: Tween

var _category_buttons: Dictionary  # String, BlockCategoryButton
var _category_displays: Dictionary  # String, BlockCategoryDisplay
var _advanced_mode: bool = false
var _search_text: String = ""


func _init():
	TxUtils.set_block_translation_domain(self)


func _ready() -> void:
	_context.changed.connect(_on_context_changed)
	_search_box.text_changed.connect(_on_search_text_changed)


func _on_context_changed():
	_block_scroll.scroll_vertical = 0
	_update_block_components()


func reload_blocks():
	_update_block_components()


static func _sort_blocks_by_list_order(block_definition_a, block_definition_b, name_order: Array) -> bool:
	var a_order = name_order.find(block_definition_a.name)
	var b_order = name_order.find(block_definition_b.name)
	return a_order >= 0 and a_order < b_order or b_order == -1


func _update_block_components():
	var block_categories: Array[BlockCategory]

	if _context.block_script:
		block_categories = _context.block_script.get_available_categories()
		block_categories.sort_custom(BlockCategory.sort_by_order)

	for block_category_button: BlockCategoryButton in _category_buttons.values():
		block_category_button.hide()

	for block_category_display: BlockCategoryDisplay in _category_displays.values():
		block_category_display.hide()

	var unique_category_prefixes: Array[String]
	for category in block_categories:
		var block_definitions := _context.block_script.get_blocks_in_category(category)

		if not _advanced_mode:
			block_definitions = block_definitions.filter(func(definition): return not definition.is_advanced)
		if not _search_text.is_empty():
			block_definitions = block_definitions.filter(_block_definition_matches_search.bind(category))

		var order_override = CATEGORY_ORDER_OVERRIDE.get(category.name)
		if order_override:
			block_definitions.sort_custom(_sort_blocks_by_list_order.bind(order_override))

		var should_show_category := category.name == "Variables" or not block_definitions.is_empty()
		if should_show_category and not unique_category_prefixes.has(category.name.get_slice(" |", 0)):
			var block_category_button := _get_or_create_block_category_button(category)
			_category_list.move_child(block_category_button, -1)
			block_category_button.show()
			unique_category_prefixes.append(category.name.get_slice(" |", 0))

		var block_category_display := _get_or_create_block_category_display(category)
		block_category_display.block_definitions = block_definitions
		_block_list.move_child(block_category_display, -1)
		if should_show_category:
			block_category_display.show()


func _get_or_create_block_category_button(category: BlockCategory) -> BlockCategoryButton:
	var block_category_button: BlockCategoryButton = _category_buttons.get(category.name)

	if block_category_button == null:
		block_category_button = BlockCategoryButtonScene.instantiate()
		block_category_button.category = category
		block_category_button.selected.connect(_category_selected.bind(category.name))
		_category_list.add_child(block_category_button)
		_category_buttons[category.name] = block_category_button

	return block_category_button


func _get_or_create_block_category_display(category: BlockCategory) -> BlockCategoryDisplay:
	var block_category_display: BlockCategoryDisplay = _category_displays.get(category.name)

	if block_category_display == null:
		if category.name != "Variables":
			block_category_display = BlockCategoryDisplayScene.instantiate()
		else:
			block_category_display = VariableCategoryDisplayScene.instantiate()
			block_category_display.variable_created.connect(func(variable): variable_created.emit(variable))
			block_category_display.variables_deleted.connect(func(variables): variables_deleted.emit(variables))
		block_category_display.title = category.name if category else ""
		block_category_display.allow_custom_block_deletion = true
		block_category_display.block_picked.connect(func(block: Block, offset: Vector2): block_picked.emit(block, offset))
		block_category_display.custom_block_delete_requested.connect(_delete_custom_block)

		_block_list.add_child(block_category_display)
		_category_displays[category.name] = block_category_display

	return block_category_display


func _delete_custom_block(block_definition: BlockDefinition):
	var result := CustomBlockStore.delete_definition(block_definition)
	if int(result.get("error", FAILED)) != OK:
		_show_custom_block_delete_error(result)
		return

	custom_block_deleted.emit()


func _show_custom_block_delete_error(result: Dictionary):
	var errors: Array = result.get("errors", [])
	var error_text := "; ".join(errors)
	if error_text.is_empty():
		error_text = error_string(int(result.get("error", FAILED)))

	var dialog := AcceptDialog.new()
	dialog.dialog_text = tr("Failed to delete custom block: %s") % error_text
	EditorInterface.popup_dialog_centered(dialog)


func _block_definition_matches_search(block_definition: BlockDefinition, category: BlockCategory) -> bool:
	var query := _search_text.to_lower()
	var property_name := block_definition.property_name if block_definition.property_name else ""
	var fields := [
		String(block_definition.name),
		block_definition.description,
		block_definition.display_template,
		block_definition.category,
		property_name,
		String(TxUtils.translate(block_definition.description)),
		String(TxUtils.translate(block_definition.display_template)),
		String(TxUtils.translate(block_definition.category)),
		String(TxUtils.translate(property_name)),
	]
	if category:
		fields.append(category.name)
		fields.append(String(TxUtils.translate(category.name)))
	for field in fields:
		if field.to_lower().contains(query):
			return true
	return false


func scroll_to(y: float):
	if scroll_tween:
		scroll_tween.kill()
	scroll_tween = create_tween()
	scroll_tween.tween_property(_block_scroll, "scroll_vertical", y, 0.2)


func _category_selected(category_name: String):
	var block_category_display := _category_displays.get(category_name)
	if block_category_display:
		scroll_to(block_category_display.position.y)


func set_collapsed(collapsed: bool):
	_widget_container.visible = not collapsed


func set_advanced(advanced: bool):
	_advanced_mode = advanced
	reload_blocks()


func _on_search_text_changed(new_text: String):
	_search_text = new_text.strip_edges()
	reload_blocks()
