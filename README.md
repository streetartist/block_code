# Block Code

- [English](README.en.md)
- [简体中文](README.md)

# 块代码

块代码是一个面向 Godot 4 的插件，用可视化积木来搭建游戏逻辑，而不是手写 GDScript。这个仓库的灵感来源于原始的 [Godot Block Coding](https://github.com/endlessm/godot-block-coding) 项目，但文档、积木目录、本地化和编辑器行为都在这里作为独立代码库维护。

目标很直接：让常见游戏流程更容易搭建、更容易阅读，也更适合新手上手，同时尽量保持和 Godot 概念一致。

## 功能

- 用积木方式编写常见游戏逻辑
- 支持按分类浏览，并可搜索积木
- 支持自定义积木定义
- 内置翻译支持，包括简体中文
- 尽量贴合 Godot 编辑器的使用方式

## 需求

- Godot 4.3 或更高版本
- 如果需要编辑器内翻译，建议使用 Godot 4.4 或更高版本

## 安装

1. 将插件放到 `res://addons/block_code/`，或者如果你是按 addon 形式打包，也可以通过 Godot 编辑器安装。
2. 在 `项目 > 项目设置 > 插件` 中启用插件。
3. 打开场景，添加一个 `BlockCode` 节点，然后开始使用积木搭建逻辑。

## 使用方式

1. 选中支持积木代码的节点。
2. 添加或打开它的 BlockCode 组件。
3. 在积木面板里搜索并插入积木。
4. 通过组合积木定义节点行为。
5. 正常保存场景，生成的脚本会和项目数据一起保存。

通常可以做的事情包括：

- 移动、旋转、缩放
- 输入处理
- UI 文本和按钮逻辑
- 节点层级操作
- 场景切换和场景树控制
- 音效播放
- 基础数学与逻辑积木

## 本地化

块代码使用 Godot 的 gettext 翻译系统。

- 翻译文件位于 `addons/block_code/locale/`
- 项目已包含简体中文 `zh_CN` 支持
- 编辑器内翻译需要 Godot 4.4 或更高版本

如果你新增了面向用户的文本，请同步更新 POT/PO 文件，避免翻译漏项。

## 开发

这个项目还在持续演进中。如果你要继续扩展它，请同步维护积木目录和翻译文件，保证新增资源和字符串都能进入本地化流程。

你可以重点查看这些目录：

- `addons/block_code/blocks/`：积木定义
- `addons/block_code/ui/`：积木面板和编辑器 UI
- `addons/block_code/translation/`：本地化辅助逻辑

## 致谢

这个项目建立在原始 [Godot Block Coding](https://github.com/endlessm/godot-block-coding) 项目的思路和代码基础之上，由 Endless 团队开创。原项目仍然是积木编程概念的主要上游参考。

