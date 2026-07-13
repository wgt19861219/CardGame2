class_name RanklistSummary
extends PopWindow

## 排行榜摘要弹窗（View 层）— 照源 ranklist/userpvpsummary.lua create :18-207。
## main_vit_tips frame 345×305 + 头像 + name/level + 上轮排名 + 总战力。
## NPC 假数据简化：源 win_cnt/heroes(5 英雄图标)/guild 目标 NPC 无数据，跳过（下轮 NPC 假数据扩展）。
## 坐标源 ccp(400,240) → 目标 _to_godot(480,320) → frame 左上。

const FRAME_RES: String = "res://assets/ui/alpha/HVGA/main_vit_tips.png"
const FRAME_SIZE: Vector2 = Vector2(345.0, 305.0)  # 源 :34 scaleSize
const FRAME_POS: Vector2 = Vector2(308.0, 168.0)  # 源 ccp(400,240) → 中心(480,320) → 左上
const TITLE_COLOR: Color = Color(1.0, 204.0 / 255.0, 118.0 / 255.0)  # 源 :96 ccc3(255,204,118)
const VALUE_COLOR: Color = Color(247.0 / 255.0, 236.0 / 255.0, 198.0 / 255.0)  # 源 :138 ccc3(247,236,198)
const HEAD_SIZE: Vector2 = Vector2(65.0, 65.0)  # 源 :57 fix_size
const HEAD_POS: Vector2 = Vector2(52.0, 272.0)  # 源 :54 frame 内（y 向上→Godot 翻转简化近似）

var _cm: Variant


func setup_panel(p_name: String, level: int, param: int, avatar: int, rank: int, cm: Variant) -> void:
	_cm = cm
	setup()
	_build(p_name, level, param, avatar, rank)


func _build(p_name: String, level: int, param: int, avatar: int, rank: int) -> void:
	shade_layer.gui_input.connect(_on_shade_input)
	var frame := TextureRect.new()
	frame.texture = load(FRAME_RES)
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.size = FRAME_SIZE
	frame.position = FRAME_POS
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(frame)
	_add_avatar(frame, avatar)
	_add_label(frame, p_name + " Lv" + str(level), Vector2(110.0, 40.0), VALUE_COLOR)
	_add_label(frame, "上轮排名", Vector2(30.0, 83.0), TITLE_COLOR)  # 源 :88 LASTRANK
	_add_label(frame, str(rank), Vector2(162.0, 83.0), VALUE_COLOR)
	_add_label(frame, "总战力", Vector2(30.0, 171.0), TITLE_COLOR)  # 源 :144 ALLFIGHTVALUE
	_add_label(frame, str(param), Vector2(162.0, 171.0), VALUE_COLOR)


func _add_avatar(frame: Control, avatar: int) -> void:
	if _cm == null:
		return
	var pic: String = String(_cm.get_raw_table(&"Avatar").get(str(avatar), {}).get("Picture", ""))
	if pic.is_empty():
		return
	var head_path: String = "res://assets/ui/" + pic.substr(3)
	if not ResourceLoader.exists(head_path):
		return
	var head := TextureRect.new()
	head.texture = load(head_path)
	head.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	head.size = HEAD_SIZE
	head.position = HEAD_POS
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(head)


func _add_label(parent: Control, text: String, pos: Vector2, color: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.position = pos
	lbl.add_theme_color_override("font_color", color)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(lbl)


# 源 :7-15 btRegisterOutClick：点框外 destroy。
func _on_shade_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		remove_window()
