# Block Code

Block Code is a Godot 4 plugin for building game logic with visual blocks instead of writing GDScript by hand. This repository is inspired by the original [Godot Block Coding](https://github.com/endlessm/godot-block-coding) project, but its documentation, block catalog, localization, and editor behavior are maintained here as an independent codebase.

The goal is simple: make common game workflows faster to prototype, easier to read, and less intimidating for new users, while still staying close to Godot concepts.

## Features

- Visual block-based scripting for common gameplay tasks
- Category-based block picker with search
- Support for custom block definitions
- Built-in translation support, including Simplified Chinese
- Designed to fit naturally into the Godot editor

## Requirements

- Godot 4.3 or newer
- Godot 4.4 or newer is recommended for editor-side translation support

## Install

1. Place the plugin in `res://addons/block_code/` or install it through the Godot editor if you are packaging it as an addon.
2. Enable the plugin in `Project > Project Settings > Plugins`.
3. Open a scene, add a `BlockCode` node, and start building with blocks.

## Using the plugin

1. Select a node that supports block code.
2. Add or open its BlockCode component.
3. Use the block picker to search and insert blocks.
4. Arrange blocks to define the node's behavior.
5. Save the scene normally; the generated script is stored with the project data.

Common workflows you may expect to find:

- Movement, rotation, and scale
- Input handling
- UI text and button logic
- Node hierarchy operations
- Scene switching and scene tree control
- Sound playback
- Basic math and logic blocks

## Custom Blocks

Use the `Block Market` button in the editor panel to manage custom blocks. The window has three tabs:

- `Market`: browse server blocks, preview their JSON configuration, and save a local copy for editing
- `Editor`: create or edit a block, then save it to the local repository or upload it to the server
- `Settings`: configure the server URL, which defaults to `https://block.streetartist.top`, and register or log in

Saved blocks are written to `res://block_code_user_blocks/` at the project root, so they can be committed to your own Git repository. Uploaded blocks are bound to the currently logged-in user.

The main fields are:

- `Block name`: a unique identifier using letters, numbers, and underscores, for example `set_velocity_x`
- `Category`: the picker category, for example `Custom | Movement`
- `Target node class`: optional; use `Node2D`, `CharacterBody2D`, and similar class names to show the block only for matching nodes, or leave it empty for all nodes
- `Block type`: `Entry`, `Statement`, `Value`, or `Control`
- `Display template`: the visible block text and the inputs users fill in
- `Generated GDScript template`: the GDScript produced by the block
- `Defaults JSON`: default values for the inputs

Template example:

```text
Display template:
set velocity x to {speed: FLOAT}

Generated GDScript template:
velocity.x = {speed}

Defaults JSON:
{
  "speed": 120.0
}
```

`{speed: FLOAT}` creates an editable input slot on the block. `{speed}` in the code template becomes an escaped GDScript value. Use `{{speed}}` only when raw text is needed. Supported input types are `BOOL`, `INT`, `FLOAT`, `STRING`, `STRING_NAME`, `VECTOR2`, `VECTOR3`, `COLOR`, `NODE_PATH`, `OBJECT`, and `NIL`.

## Custom Block Server

The plugin includes a single-file Python server:

```powershell
python addons/block_code/block_code_server.py --host 127.0.0.1 --port 8787
```

Server endpoints:

- `POST /api/auth/register`: register a user and return a token
- `POST /api/auth/login`: log in and return a token
- `GET /api/blocks`: list blocks
- `POST /api/blocks`: upload one block JSON object; requires login and binds the block to the current user
- `GET /api/blocks/<name>`: fetch one block
- `GET /api/me/blocks`: list blocks uploaded by the current user
- `DELETE /api/blocks/<name>`: delete one block; requires the block owner

## Localization

Block Code uses Godot's gettext-based translation system.

- Translation files live in `addons/block_code/locale/`
- The project includes Simplified Chinese (`zh_CN`) support
- Editor translation support requires Godot 4.4 or newer

If you add new user-facing text, update the POT/PO files so translations stay in sync.

## Development

This project is still evolving. If you are extending it, keep the block catalog and translation files in sync with any new resources or strings.

Useful places:

- `addons/block_code/blocks/` for block definitions
- `addons/block_code/ui/` for picker and editor UI
- `addons/block_code/translation/` for localization helpers

## Credits

This project builds on ideas and code from the original [Godot Block Coding](https://github.com/endlessm/godot-block-coding) project by Endless. That project remains the main upstream reference for the block-coding concept.
