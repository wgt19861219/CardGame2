class_name BattleResourceMarker
extends Control

## HUD 资源标记（goldmarker / lootmarker）— 照源 battle_scene.lua resetUI :1309-1339
## + addGold/addLootMarker :957-1014 翻译（Phase 4 子件）。
## Scale9 bg（battle_number_bg）+ icon（goldicon_small/chest_small）+ Label text
## （源 createNumbers 拼数字精灵图，本项目 digits 缺→Label 适配，同 popup/timer）。
## gold 拾取：text scale 1.25→1 缩放闪动（源 :1003-1012）。
## loot 拾取：holo 光环 scale 0.4→1.2 + fade 闪动（源 :970-985）。
## marker 原点 = bg 左上角（源 anchor(1,0.5)+position 反算：goldmarker (110,440)→bg左上 (10,418)；
## lootmarker (210,440)→bg左上 (125,418)），由 scene.setup 传入。
##
## 重构（2026-07-17，hero_detail 范式）：bg + icon + label 静态节点搬进
## scenes/battle/battle_resource_marker_content.tscn（位置/size 编辑器可视化调），
## Control 组件 content 挂 panel 自身（坑 7）。setup instantiate + get_node("%Xxx") as
## 取节点 + _apply_kind_layout fill GOLD/LOOT 差异（bg size / icon texture+pos / label pos）。
## font_size/font_color/alignment 固化 .tscn theme_override（不再 LabelSettings 运行时建）。

const CONTENT_SCENE: PackedScene = preload("res://scenes/battle/battle_resource_marker_content.tscn")
const BG_PATH: String = "res://assets/ui/alpha/HVGA/battle_number_bg.png"
const GOLD_ICON_PATH: String = "res://assets/ui/alpha/HVGA/goldicon_small.png"
const LOOT_ICON_PATH: String = "res://assets/ui/alpha/HVGA/chest_small.png"
const HOLO_PATH: String = "res://assets/ui/alpha/HVGA/holo.png"

enum Kind { GOLD, LOOT }

const GOLD_SIZE: Vector2 = Vector2(100.0, 44.0)        # 源 :1314 CCSizeMake(100,44)
const LOOT_SIZE: Vector2 = Vector2(85.0, 44.0)         # 源 :1330 CCSizeMake(85,44)
const GOLD_TEXT_POS: Vector2 = Vector2(33.0, 22.0)     # 源 :1002 goldmarker_text position
const LOOT_TEXT_POS: Vector2 = Vector2(25.0, 22.0)     # 源 :969 lootmarker_text position
const ICON_RIGHT_OFFSET: float = 4.0                   # 源 :1318/1334 size.width - 4
const LOOT_HOLO_POS: Vector2 = Vector2(24.0, 24.0)     # 源 :975
const LOOT_HOLO_INIT_SCALE: float = 0.4                # 源 :976 setScale(0.4)
const GOLD_PULSE_DURATION: float = 0.1                 # 源 :1004
const GOLD_PULSE_SCALE: float = 1.25                   # 源 :1007 setScale(1.25)
const LOOT_PULSE_DURATION: float = 0.3                 # 源 :972
const LOOT_PULSE_SCALE: float = 1.2                    # 源 :977 ScaleTo(1.2)
const LABEL_BOX: Vector2 = Vector2(60.0, 22.0)         # Label 居中盒（中心对齐 text_pos，.tscn offset 固化 size）

var kind: int = Kind.GOLD
var _text: Label = null
var _bg: NinePatchRect = null
var _icon: Sprite2D = null
var _value: int = 0


# 源 goldmarker/lootmarker 装配：bg_top_left = bg 左上角坐标（marker.position）。
# .tscn 已固化 GOLD 基准（bg 100×44 + goldicon + label(33,22) 居中盒）；
# LOOT 由 _apply_kind_layout 覆盖为 85×44 + chest + label(25,22)。
func setup(p_kind: int, bg_top_left: Vector2) -> void:
	kind = p_kind
	position = bg_top_left
	var content := CONTENT_SCENE.instantiate()
	add_child(content)   # Control 组件 content 挂 panel 自身（坑 7，坐标原点 = marker 原点）
	_bg = content.get_node("%Bg") as NinePatchRect
	_icon = content.get_node("%Icon") as Sprite2D
	_text = content.get_node("%ValueLabel") as Label
	_apply_kind_layout()
	set_value(0)


# fill GOLD/LOOT 差异：bg size + icon texture/pos + label pos。
# 源 anchor(1,0.5) position(size.w-4, size.h*0.5) → icon 右中在 (w-4, h/2)。
func _apply_kind_layout() -> void:
	var marker_size: Vector2 = GOLD_SIZE if kind == Kind.GOLD else LOOT_SIZE
	var icon_path: String = GOLD_ICON_PATH if kind == Kind.GOLD else LOOT_ICON_PATH
	var text_center: Vector2 = GOLD_TEXT_POS if kind == Kind.GOLD else LOOT_TEXT_POS
	if _bg != null:
		_bg.size = marker_size
	if _icon != null:
		var tex: Texture2D = _load_tex(icon_path)
		if tex != null:
			_icon.texture = tex
			_icon.position = Vector2(
				marker_size.x - ICON_RIGHT_OFFSET - float(tex.get_width()),
				marker_size.y * 0.5 - float(tex.get_height()) * 0.5
			)
	if _text != null:
		_text.position = text_center - LABEL_BOX * 0.5


# 源 addGold/addLootMarker：text 显 value（gold 千分位，loot 原值）。
func set_value(value: int) -> void:
	_value = value
	var s: String = _format_num_with_comma(value) if kind == Kind.GOLD else str(value)
	if _text != null:
		_text.text = s


func get_value() -> int:
	return _value


# 源 addGold :1003-1012：text scale 1.25→1（CCSpawn FadeTo(255) 无效 + ScaleTo(1)）。
func pulse_gold() -> void:
	if kind != Kind.GOLD or _text == null:
		return
	_text.scale = Vector2(GOLD_PULSE_SCALE, GOLD_PULSE_SCALE)
	var t := create_tween()
	t.tween_property(_text, "scale", Vector2.ONE, GOLD_PULSE_DURATION)


# 源 addLootMarker :970-985：holo 光环 scale 0.4→1.2 + fade 255→0 后移除。
func pulse_loot() -> void:
	if kind != Kind.LOOT:
		return
	var tex: Texture2D = _load_tex(HOLO_PATH)
	if tex == null:
		return
	var holo := Sprite2D.new()
	holo.texture = tex
	holo.position = LOOT_HOLO_POS
	holo.scale = Vector2(LOOT_HOLO_INIT_SCALE, LOOT_HOLO_INIT_SCALE)
	holo.z_index = -1   # 源 addChild(holo, -1) 装饰底层
	add_child(holo)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(holo, "scale", Vector2(LOOT_PULSE_SCALE, LOOT_PULSE_SCALE), LOOT_PULSE_DURATION)
	t.tween_property(holo, "modulate:a", 0.0, LOOT_PULSE_DURATION)
	t.chain().tween_callback(holo.queue_free)


# 源 tools.lua:449 formatNumWithComma — 千分位逗号（gold 显示用）。
static func _format_num_with_comma(amount: int) -> String:
	var s := str(amount)
	var regex := RegEx.new()
	regex.compile("^(\\d+)(\\d{3})")
	while regex.search(s) != null:
		s = regex.sub(s, "$1,$2", true)
	return s


func _load_tex(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D
