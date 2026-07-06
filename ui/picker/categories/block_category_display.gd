@tool
extends MarginContainer

const BlockCategory = preload("res://addons/block_code/ui/picker/categories/block_category.gd")
const BlockDefinition = preload("res://addons/block_code/code_generation/block_definition.gd")
const CustomBlockStore = preload("res://addons/block_code/custom_blocks/custom_block_store.gd")
const Util = preload("res://addons/block_code/ui/util.gd")

const MENU_DELETE := 0

signal block_picked(block: Block, offset: Vector2)
signal custom_block_delete_requested(block_definition: BlockDefinition)

@export var title: String:
	set = _set_title
@export var block_definitions: Array[BlockDefinition]:
	set = _set_block_definitions
@export var allow_custom_block_deletion: bool = false:
	set = _set_allow_custom_block_deletion

@onready var _context := BlockEditorContext.get_default()

@onready var _label := %Label
@onready var _blocks_container := %BlocksContainer

var _blocks: Dictionary  # String, Block


func _ready():
	_update_label()
	_update_blocks()


func _set_title(value):
	title = value
	_update_label()


func _set_block_definitions(value):
	block_definitions = value
	_update_blocks()


func _set_allow_custom_block_deletion(value):
	allow_custom_block_deletion = value
	_update_blocks()


func _update_label():
	if not _label:
		return

	_label.text = tr(title)


func _update_blocks():
	if not _blocks_container:
		return

	if not _context:
		return

	for block in _blocks.values():
		block.hide()

	for block_definition in block_definitions:
		var block = _get_or_create_block(block_definition)
		_blocks_container.move_child(block, -1)
		block.show()

	_blocks_container.visible = not block_definitions.is_empty()


func _get_or_create_block(block_definition: BlockDefinition) -> Block:
	var block: Block = _blocks.get(block_definition.name)

	if block == null:
		block = _context.block_script.instantiate_block(block_definition)
		block.can_delete = false
		block.editable = false
		block.drag_started.connect(func(block: Block, offset: Vector2): block_picked.emit(block, offset))
		_blocks_container.add_child(block)
		_blocks[block_definition.name] = block
	else:
		# If the block is being reused, make sure the context corresponds to
		# the current BlockCode node.
		block.refresh_context()

	_configure_custom_block_menu(block, block_definition)
	return block


func _configure_custom_block_menu(block: Block, block_definition: BlockDefinition):
	if not allow_custom_block_deletion:
		return
	if not CustomBlockStore.can_delete_definition(block_definition):
		return

	var context_menu_callable := _on_block_context_menu_requested.bind(block_definition)
	if not block.context_menu_requested.is_connected(context_menu_callable):
		block.context_menu_requested.connect(context_menu_callable)


func _on_block_context_menu_requested(_block: Block, screen_position: Vector2i, block_definition: BlockDefinition):
	var context_menu := PopupMenu.new()
	context_menu.add_icon_item(EditorInterface.get_editor_theme().get_icon("Remove", "EditorIcons"), tr("Delete"), MENU_DELETE)
	context_menu.id_pressed.connect(_on_context_menu_id_pressed.bind(context_menu, block_definition))
	context_menu.popup_hide.connect(func(): context_menu.queue_free())
	context_menu.position = screen_position
	add_child(context_menu)
	context_menu.popup()


func _on_context_menu_id_pressed(id: int, context_menu: PopupMenu, block_definition: BlockDefinition):
	context_menu.hide()
	if id != MENU_DELETE:
		return

	var dialog := ConfirmationDialog.new()
	dialog.ok_button_text = tr("Delete")
	dialog.dialog_text = tr('Delete custom block "%s"?') % String(block_definition.name)
	dialog.confirmed.connect(func(): custom_block_delete_requested.emit(block_definition))
	EditorInterface.popup_dialog_centered(dialog)
