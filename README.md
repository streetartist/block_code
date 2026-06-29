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

## 自定义积木

点击编辑器面板顶部的 `积木市场` 可以管理自定义积木。这个入口包含三个页面：

- `市场`：从服务器浏览积木，查看 JSON 配置预览，可以保存一份到本地后再修改
- `编辑器`：创建或修改自己的积木，可以保存到本地仓库，也可以上传到服务器
- `设置`：配置服务器地址，默认是 `https://block.streetartist.top`，并可完成注册和登录

保存到本地后，积木定义会写入项目根目录的 `res://block_code_user_blocks/`，这个目录可以直接提交到你自己的 Git 仓库。上传到服务器的积木会绑定到当前登录用户。

创建一个积木时主要填写：

- `Block name`：唯一标识，只能使用字母、数字和下划线，例如 `set_velocity_x`
- `Category`：面板中的分类，例如 `Custom | Movement`
- `Target node class`：可选，填写 `Node2D`、`CharacterBody2D` 等会让积木只在对应节点上出现；留空表示所有节点可用
- `Block type`：`Entry` 是入口，`Statement` 是普通语句，`Value` 会输出一个值，`Control` 可以包含子积木
- `Display template`：积木长什么样，以及用户需要输入什么
- `Generated GDScript template`：这个积木最终生成什么 GDScript
- `Defaults JSON`：输入项的默认值

模板语法示例：

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

`{speed: FLOAT}` 会在积木上生成一个可编辑输入槽。代码模板里的 `{speed}` 会转成安全的 GDScript 值；如果你确实需要未加引号的原始文本，可以用 `{{speed}}`。支持的类型包括 `BOOL`、`INT`、`FLOAT`、`STRING`、`STRING_NAME`、`VECTOR2`、`VECTOR3`、`COLOR`、`NODE_PATH`、`OBJECT` 和 `NIL`。

## 自定义积木服务器

插件自带一个单文件 Python 服务端：

```powershell
python addons/block_code/block_code_server.py --host 127.0.0.1 --port 8787
```

服务端接口：

- `POST /api/auth/register`：注册用户并返回 token
- `POST /api/auth/login`：登录并返回 token
- `GET /api/blocks`：列出所有积木
- `POST /api/blocks`：上传一个积木 JSON，需要登录，积木会绑定到当前用户
- `GET /api/blocks/<name>`：读取单个积木
- `GET /api/me/blocks`：列出当前用户上传的积木
- `DELETE /api/blocks/<name>`：删除单个积木，需要是该积木的上传者

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
