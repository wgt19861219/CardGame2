class_name StoryView
extends Control

## 剧情演出层（View 层）— 照源 ui/storylayer.lua（256 行）。
## 全屏分节对话：底部对话框 + 角色立绘（左右站位）+ 名牌 + 文字 + 点击推进 + ShowOnce 持久化。
## 触发点：battle 波次开场 / stage_done 胜利回选 / main_scene 首进。
## 单机化：EDTables.story 数据源在源编译产物里，本项目 StoryData 自建分节文本。
## 战斗暂停集成：show 时 pauseBattle("story")，close 时 resumeBattle。

signal story_ended(story_name: String)

const BG_RES: String = "res://assets/ui/alpha/HVGA/dialogue_content_bg.png"
const SHADOW_RES: String = "res://assets/ui/alpha/HVGA/dialogue_bottom_shadow.png"
const ARROW_RES: String = "res://assets/ui/alpha/HVGA/dialogue_arrow.png"
const NAME_BG_RES: String = "res://assets/ui/alpha/HVGA/dialogue_name_bg.png"
const HERO_ICON_LEFT: Vector2 = Vector2(175.0, 100.0)
const HERO_ICON_RIGHT: Vector2 = Vector2(625.0, 100.0)
const NAME_FRAME_LEFT: Vector2 = Vector2(230.0, 120.0)
const NAME_FRAME_RIGHT: Vector2 = Vector2(620.0, 120.0)
const CONTENT_POS: Vector2 = Vector2(400.0, 60.0)
const ARROW_POS: Vector2 = Vector2(710.0, 40.0)
const TEXT_COLOR: Color = Color(117.0 / 255.0, 77.0 / 255.0, 0.0)   # 源 ccc3(117,77,0)
const SHADOW_CENTER: Vector2 = Vector2(400.0, 60.0)   # 源 storylayer.lua:28/42 shadowBg/storyBg ccp(400,60)（原 330 系注释造假+值错，T2 核实 2026-07-14 修）
const SHADOW_SIZE: Vector2 = Vector2(960.0, 600.0)     # 源 800×500 按比例→Godot 960×600（源画布×1.2）
const BG_SIZE: Vector2 = Vector2(600.0, 120.0)         # 源 storyBg 尺寸（保持原值）
# 源 hello.lua:311 setContentScaleFactor=1.28125，cocos CCSprite 显示=texture/CS。
# Godot TextureRect 默认 KEEP_SIZE 用纹理原始尺寸偏大 1.28，sprite 走 tex/CS 等价源显示。
const CONTENT_SCALE: float = 1.28125

var _story_name: String = ""
var _sections: Array = []   # StoryData 分节 [{icon,name,text,position}]
var _current_section: int = 1
var _ui: Dictionary = {}    # 节点引用
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
func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)
	_add_texture_rect(SHADOW_RES, _g(SHADOW_CENTER), SHADOW_SIZE, true)   # shadowBg 源 fix_size=CCSizeMake(800,500) 保留（Godot 960×600 等比放大）
	_add_texture_rect(BG_RES, _g(SHADOW_CENTER), BG_SIZE)           # storyBg
	var arrow := _add_texture_rect(ARROW_RES, _g(ARROW_POS), Vector2(20, 20))
	arrow.modulate.a = 0.5   # 源 getFadeAction 闪烁（简化为半透明）
	# heroIcon + nameFrame + heroName + content 由 _show_section 动态定位
	_ui["name_frame"] = _add_texture_rect(NAME_BG_RES, _g(NAME_FRAME_LEFT), Vector2(120, 30))
	var name_lbl := Label.new()
	name_lbl.add_theme_font_size_override("font_size", 24)
	name_lbl.modulate = TEXT_COLOR
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(name_lbl)
	_ui["name"] = name_lbl
	var content_lbl := Label.new()
	content_lbl.position = _g(CONTENT_POS)
	content_lbl.add_theme_font_size_override("font_size", 22)
	content_lbl.modulate = TEXT_COLOR
	content_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_lbl.custom_minimum_size = Vector2(600, 120)
	content_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(content_lbl)
	_ui["content"] = content_lbl


## 源 showStorySection:177-184 + changeStoryInfo:138-167：显示当前节 + 推进。
func _show_section() -> void:
	if _current_section > _sections.size():
		_close_story()
		return
	var section: Dictionary = _sections[_current_section - 1]
	var position: String = String(section.get("position", "left"))
	var icon_pos: Vector2 = HERO_ICON_LEFT if position == "left" else HERO_ICON_RIGHT
	# heroIcon（源 setHeroInfo：读 playIndex/monsterIndex 取战斗单位立绘，单机化用 icon 字段）
	if _ui.has("hero_icon"):
		(_ui["hero_icon"] as TextureRect).queue_free()
	var icon_res: String = String(section.get("icon", ""))
	if not icon_res.is_empty():
		_ui["hero_icon"] = _add_texture_rect(icon_res, _g(icon_pos), Vector2(120, 150))
	# 名牌 + 名字位置（左右切换，源 changeStoryInfo:150-157）
	(_ui["name_frame"] as TextureRect).position = _g(NAME_FRAME_LEFT if position == "left" else NAME_FRAME_RIGHT)
	(_ui["name"] as Label).position = _g(NAME_FRAME_LEFT if position == "left" else NAME_FRAME_RIGHT) - Vector2(50, 12)
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


# size 参数语义随 use_fix_size 切换：
#   use_fix_size=false（默认）：源 sprite 无 fix_size → 显示=texture/CS（size 参数忽略）
#   use_fix_size=true：源 fix_size（如 shadowBg CCSizeMake(800,500)）→ 显示=size（Godot 等比放大值）
@warning_ignore("unused_parameter")
func _add_texture_rect(res_path: String, pos: Vector2, size: Vector2, use_fix_size: bool = false) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = load(res_path)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var target_size: Vector2 = size if use_fix_size else (tr.texture.get_size() / CONTENT_SCALE)
	tr.position = pos - target_size / 2.0
	tr.size = target_size
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tr)
	return tr
