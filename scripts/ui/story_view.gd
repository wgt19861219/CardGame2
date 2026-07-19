class_name StoryView
extends Control

## 剧情演出层（View 层）— 照源 ui/storylayer.lua（256 行）。
## 全屏分节对话：底部对话框 + 角色立绘（左右站位）+ 名牌 + 文字 + 点击推进 + ShowOnce 持久化。
## 触发点：battle 波次开场 / stage_done 胜利回选 / main_scene 首进。
## 单机化：EDTables.story 数据源在源编译产物里，本项目 StoryData 自建分节文本。
## 战斗暂停集成：show 时 pauseBattle("story")，close 时 resumeBattle。
##
## 重构（2026-07-18，hero_detail 范式）：对话框 chrome（shadowBg/storyBg/arrow/nameFrame/name/content）
## 静态化进 scenes/ui/story_view_content.tscn（位置/size/texture/font/color 编辑器可视化调，坐标已按
## to_godot + texture/CS 算好固化）；heroIcon 每个 section 不同 icon，保留 procedural 挂 panel 自身。
## Control 非 PopWindow，content 挂 panel 自身（同 shortcut 范式）。

signal story_ended(story_name: String)

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/story_view_content.tscn")

const HERO_ICON_LEFT: Vector2 = Vector2(175.0, 100.0)
const HERO_ICON_RIGHT: Vector2 = Vector2(625.0, 100.0)
const NAME_FRAME_LEFT: Vector2 = Vector2(230.0, 120.0)
const NAME_FRAME_RIGHT: Vector2 = Vector2(620.0, 120.0)
# 源 hello.lua:311 setContentScaleFactor=1.28125，cocos CCSprite 显示=texture/CS。
# heroIcon 源 sprite 无 fix_size → 显示=texture/CS（Godot TextureRect expand=IGNORE_SIZE + size=target）。
const CONTENT_SCALE: float = 1.28125

var _story_name: String = ""
var _sections: Array = []   # StoryData 分节 [{icon,name,text,position}]
var _current_section: int = 1
var _ui: Dictionary = {}    # 节点引用（name_frame/name/content/hero_icon）
var _shown_once: Dictionary = {}   # ShowOnce 持久化（会话内，源 CCUserDefault）


# 源 cocos(800×480 左下) → Godot(960×640 左上):cx+80, 560-cy（同 battle_view_coords 标准）。
# Phase 4 早期直接用源值漏转，2026-07-14 补 to_godot。
func _g(pos: Vector2) -> Vector2:
	return BattleViewCoords.to_godot(pos.x, pos.y)


## 源 showStory（:218-249）：加载分节 + ShowOnce 检查 + 创建层 + 首节 + pauseBattle。
func show_story(story_name: String) -> void:
	var data: Dictionary = StoryData.get_story(story_name)
	if data.is_empty():
		story_ended.emit(story_name)
		return   # 无此剧情数据，直接结束（单机化：剧情可选）
	if bool(data.get("show_once", false)) and _shown_once.get(story_name, false):
		story_ended.emit(story_name)
		return   # ShowOnce 已播过
	_story_name = story_name
	_sections = data.get("content", [])
	_current_section = 1
	_shown_once[story_name] = true
	_build_ui()
	_show_section()


## 创建对话框 UI（源 createMainLayer:108-117 + uiRes 装配）。
## chrome 静态节点从 .tscn instantiate（位置/size/texture/font/color 已固化）；
## heroIcon 留 _show_section 动态创建（每节 icon 不同）。Control 非 PopWindow，content 挂 panel 自身。
func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP   # 自身吞点击（gui_input 推进剧情）
	gui_input.connect(_on_gui_input)
	var content := CONTENT_SCENE.instantiate()
	add_child(content)
	_ui["name_frame"] = content.get_node("%NameFrame") as TextureRect
	_ui["name"] = content.get_node("%Name") as Label
	_ui["content"] = content.get_node("%Content") as Label


## 源 showStorySection:177-184 + changeStoryInfo:138-167：显示当前节 + 推进。
func _show_section() -> void:
	if _current_section > _sections.size():
		_close_story()
		return
	var section: Dictionary = _sections[_current_section - 1]
	var position: String = String(section.get("position", "left"))
	# heroIcon（源 setHeroInfo：读 playIndex/monsterIndex 取战斗单位立绘，单机化用 icon 字段）
	if _ui.has("hero_icon"):
		(_ui["hero_icon"] as TextureRect).queue_free()
	var icon_res: String = String(section.get("icon", ""))
	if not icon_res.is_empty():
		var icon_pos: Vector2 = HERO_ICON_LEFT if position == "left" else HERO_ICON_RIGHT
		_ui["hero_icon"] = _add_hero_icon(icon_res, icon_pos)
	# 名牌 + 名字位置（左右切换，源 changeStoryInfo:150-157）
	var name_pos: Vector2 = _g(NAME_FRAME_LEFT if position == "left" else NAME_FRAME_RIGHT)
	(_ui["name_frame"] as TextureRect).position = name_pos
	(_ui["name"] as Label).position = name_pos - Vector2(50, 12)
	(_ui["name"] as Label).text = String(section.get("name", ""))
	(_ui["content"] as Label).text = String(section.get("text", ""))
	_current_section += 1


## 源 onMainLayerTouch:186-199：点击屏幕推进下一节。
func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_show_section()


## 源 closeStory:168-175：关闭层 + resumeBattle + FireEvent StoryEnd。
func _close_story() -> void:
	queue_free()
	story_ended.emit(_story_name)


# heroIcon（源 sprite 无 fix_size）→ 显示=texture/CS（center 为中心点，转左上角 position）。
func _add_hero_icon(res_path: String, center_pos: Vector2) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = load(res_path)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var target_size: Vector2 = TexDisplaySize.display_size(res_path)
	tr.position = center_pos - target_size / 2.0
	tr.size = target_size
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tr)
	return tr
