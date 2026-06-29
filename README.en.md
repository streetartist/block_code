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
