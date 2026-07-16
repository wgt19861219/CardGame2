class_name StageDetailBuilder
extends RefCounted

## 关卡详情 View 构造器（View helper）— 照源 stagedetail.lua create:1536-1934 翻译。
## StageDetailPanel 委托本类装配 ~20 节点 + createEnemy:1142 / createReward:1193 / createStars:1212。
## 坐标：源 cocos（800×480，y 向上，原点左下）→ Godot（960×640，y 向下）。
## 面板 800×480 居中 offset(80,80)：Godot = (cocos_x + 80, 560 - cocos_y)。

const OFFSET_X: float = 80.0
const PANEL_H: float = 480.0
const OFFSET_Y: float = 80.0

const C_TITLE: Color = Color(250.0 / 255.0, 205.0 / 255.0, 16.0 / 255.0)     # :1644 toccc3(16436496)
const C_WHITE: Color = Color(1.0, 1.0, 1.0)                                  # :1659 toccc3(16777215)
const C_SECTION: Color = Color(241.0 / 255.0, 193.0 / 255.0, 113.0 / 255.0)  # toccc3(15843697)
const C_NUM: Color = Color(245.0 / 255.0, 225.0 / 255.0, 190.0 / 255.0)      # toccc3(16114110)
const C_DISABLE: Color = Color(1.0, 102.0 / 255.0, 49.0 / 255.0)             # toccc3(16737841)
const C_RESET: Color = Color(1.0, 206.0 / 255.0, 31.0 / 255.0)               # :1816 ccc3(255,206,31)

const UI_DIR: String = "res://assets/ui/alpha/HVGA/"
const FRAME2_RES: String = UI_DIR + "detail_bg_2.png"
const TITLE_BG_RES: String = UI_DIR + "detail_title_bg.png"
const POWER_ICON_RES: String = UI_DIR + "vitalityicon.png"
const ENEMY_BG_RES: String = UI_DIR + "detail_enemy_bg.png"
const GO_BTN_RES: String = UI_DIR + "startbtn.png"
const GO_BTN_DISABLE_RES: String = UI_DIR + "startbtn-disabled.png"
const RESET_RES: String = UI_DIR + "tavern_button_normal_1.png"
const RESET_PRESS_RES: String = UI_DIR + "tavern_button_normal_2.png"
const BOSS_TAG_RES: String = UI_DIR + "stagedetail_boss_tag.png"
const STAR_RES: String = UI_DIR + "detail_star.png"
const STAR_GREY_RES: String = UI_DIR + "detail_star_grey.png"

const RESET_SIZE: Vector2 = Vector2(100.0, 50.0)
const POWER_ICON_SIZE: Vector2 = Vector2(24.0, 30.0)
const ENEMY_CONTAINER: float = 104.0  # ReadheroIcon.CONTAINER_SIZE.x
const ENEMY_OX: float = 205.0
const ENEMY_OY: float = 168.0
const ENEMY_GAP: float = 80.0
const REWARD_OX: float = 205.0
const REWARD_OY: float = 50.0


# 源 getResInformation :623-678。resInfo（frame/title_bg/title_bg_size/star_gap/go_btn_pos/frame_pos）。
static func get_res_info(stage_type: String) -> Dictionary:
	match stage_type:
		"normal":
			return _pack(UI_DIR + "stage-map-frame.png", UI_DIR + "Normal_title_bg.png", Vector2(504.0, 12.0), 55, Vector2(698.0, 80.0), Vector2(400.0, 205.0))
		"elite", "dungeon":
			return _pack(UI_DIR + "stage-map-elite-frame.png", UI_DIR + "Elite_title_bg.png", Vector2(404.0, 12.0), 50, Vector2(678.0, 80.0), Vector2(400.0, 207.0))
		"raid":
			return _pack(UI_DIR + "stage_map_guild_frame.png", UI_DIR + "guild_title_bg.png", Vector2(404.0, 12.0), 50, Vector2(678.0, 80.0), Vector2(400.0, 207.0))
	return _pack(UI_DIR + "stage-map-frame.png", UI_DIR + "Normal_title_bg.png", Vector2(504.0, 12.0), 55, Vector2(698.0, 80.0), Vector2(400.0, 205.0))


static func _pack(frame: String, title_bg: String, bg_size: Vector2, star_gap: int, go_btn: Vector2, frame_pos: Vector2) -> Dictionary:
	return {"frame": frame, "title_bg": title_bg, "title_bg_size": bg_size, "star_gap": star_gap, "go_btn_pos": go_btn, "frame_pos": frame_pos}


static func to_godot(cocos_pos: Vector2) -> Vector2:
	return Vector2(cocos_pos.x + OFFSET_X, PANEL_H - cocos_pos.y + OFFSET_Y)


# 源 create:1585-1883 ui_info ~20 节点。返 ui 引用 dict（panel 后处理显隐/色用）。
# cm: ConfigManager，用于 LSTR 化硬编码中文（源 stagedetail.lua :1686/:1730/:1807/:1834/:1848）。
static func build(parent: Node, info: Dictionary, res_info: Dictionary, cm: Variant) -> Dictionary:
	var ui: Dictionary = {}
	var left: int = int(info.get("count_limit", 0)) - int(info.get("count", 0))
	# 源 LSTR key（STAGEDETAIL.* / EXERCISE.* / EQUIPINFO.*）。
	var lstr_power: String = String(cm.get_lstr("STAGEDETAIL.PHYSICAL_EXERTION"))  # 源 :1686
	var lstr_left: String = String(cm.get_lstr("EXERCISE.REMAINING_TIMES_FOR_TODAY_"))  # 源 :1730
	var lstr_buy: String = String(cm.get_lstr("EQUIPINFO.PURCHASE"))  # 源 :1807
	var lstr_enemy: String = String(cm.get_lstr("STAGEDETAIL.ENEMY_LINEUP"))  # 源 :1834
	var lstr_award: String = String(cm.get_lstr("STAGEDETAIL.MAY_BE_OBTAINED"))  # 源 :1848
	ui["frame2"] = _sprite_center(parent, FRAME2_RES, Vector2(400.0, 205.0))
	ui["frame3"] = _sprite_center(parent, String(res_info.get("frame", "")), Vector2(res_info.get("frame_pos", Vector2(400.0, 205.0))))
	ui["title_bg"] = _scale9(parent, TITLE_BG_RES, 100, 0, Vector2(400.0, 355.0), Vector2(res_info.get("title_bg_size", Vector2(504.0, 12.0))))
	ui["map_title_bg"] = _sprite_center(parent, String(res_info.get("title_bg", "")), Vector2(397.0, 393.0))
	ui["title"] = _label(parent, String(info.get("title", "")), Vector2(397.0, 393.0), C_TITLE, 0, Vector2(0.5, 0.5))
	var detail_lbl: Label = _label(parent, String(info.get("detail", "")), Vector2(70.0, 290.0), C_WHITE, 21, Vector2(0.0, 0.5))
	detail_lbl.visible = bool(info.get("is_key_stage", false)) or String(info.get("detail", "")) != ""
	ui["detail"] = detail_lbl
	ui["power_title"] = _label(parent, lstr_power, Vector2(70.0, 230.0), C_SECTION, 22, Vector2(0.0, 0.0))
	ui["power_number"] = _label(parent, str(info.get("power", 0)), Vector2(170.0, 230.0), C_NUM, 22, Vector2(0.0, 0.0))
	ui["power_icon"] = _sprite_local(parent, POWER_ICON_RES, to_godot(Vector2(200.0, 228.0)), POWER_ICON_SIZE)
	# 源 :1730 T(LSTR("EXERCISE.REMAINING_TIMES_FOR_TODAY_"), count) — key="今日剩余次数:"，%d 拼接（项目 LSTR 值冒号结尾）。
	ui["count_title"] = _label(parent, lstr_left + str(left), Vector2(250.0, 230.0), C_SECTION, 22, Vector2(0.0, 0.0))
	var cn: Label = _label(parent, str(left), Vector2(390.0, 230.0), C_NUM, 22, Vector2(0.0, 0.0))
	cn.visible = false
	ui["count_number"] = cn
	ui["total_number"] = _label(parent, "/ " + str(info.get("count_limit", "??")), Vector2(410.0, 230.0), C_NUM, 22, Vector2(0.0, 0.0))
	ui["reset"] = _texture_button(parent, RESET_RES, RESET_PRESS_RES, Vector2(500.0, 242.0), RESET_SIZE)
	ui["reset_label"] = _label_local(ui["reset"] as TextureButton, lstr_buy, Vector2(50.0, 25.0), C_RESET, 0)
	ui["enemy_bg"] = _sprite_local(parent, ENEMY_BG_RES, to_godot(Vector2(90.0, 130.0)), Vector2.ZERO)
	ui["enemy_title"] = _label(parent, lstr_enemy, Vector2(70.0, 157.0), C_SECTION, 22, Vector2(0.0, 0.0))
	ui["award_title"] = _label(parent, lstr_award, Vector2(70.0, 77.0), C_SECTION, 22, Vector2(0.0, 0.0))
	ui["go_button"] = _texture_button(parent, GO_BTN_RES, "", Vector2(res_info.get("go_btn_pos", Vector2(698.0, 80.0))), Vector2.ZERO)
	var gs: Sprite2D = _sprite_local(ui["go_button"] as Node, GO_BTN_DISABLE_RES, Vector2.ZERO, Vector2.ZERO)
	gs.visible = false
	ui["go_button_shade"] = gs
	return ui


# 源 createEnemy :1142-1192。enemies: [{tid, level, stars, is_boss}]。
static func create_enemy(parent: Node, enemies: Array, cm: Variant) -> void:
	var idx: int = 0
	for e in enemies:
		var tid: int = int(e.get("tid", 0))
		if tid == 0:
			continue
		var is_boss: bool = bool(e.get("is_boss", false))
		var icon := ReadheroIcon.new()
		var rank: int = mini(ExcavateData.hero_level_to_rank(int(e.get("level", 1))), 8)  # 源 :1153-1157 >8 截 8
		icon.setup({"id": tid, "rank": rank, "stars": int(e.get("stars", 0))}, cm)
		var length: float = 80.0 if is_boss else 70.0
		var s: float = length / ENEMY_CONTAINER
		var bx: float = ENEMY_OX + ENEMY_GAP * float(idx) + (5.0 if is_boss else 0.0)
		var by: float = ENEMY_OY + (5.0 if is_boss else 0.0)
		icon.scale = Vector2(s, s)
		icon.position = to_godot(Vector2(bx, by)) - Vector2(ENEMY_CONTAINER * s, ENEMY_CONTAINER * s) * 0.5
		if icon.ori_icon is Sprite2D:
			(icon.ori_icon as Sprite2D).flip_h = true  # 源 :1165 setFlipX(true)
		parent.add_child(icon)
		if is_boss:
			_add_boss_tag(icon)
		idx += 1


# 源 :1179 stagedetail_boss_tag.png（本项目缺）→ 图缺降级 "BOSS" 红字。
static func _add_boss_tag(icon: ReadheroIcon) -> void:
	var host: Node = icon.icon if icon.icon != null else icon
	if ResourceLoader.exists(BOSS_TAG_RES):
		var tag := Sprite2D.new()
		tag.texture = load(BOSS_TAG_RES)
		tag.centered = false
		tag.position = Vector2(52.0, 20.0)
		tag.z_index = 10
		host.add_child(tag)
	else:
		var lbl := Label.new()
		lbl.text = "BOSS"
		lbl.position = Vector2(20.0, 0.0)
		lbl.add_theme_color_override("font_color", Color.RED)
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.z_index = 10
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		host.add_child(lbl)


# 源 createReward :1193-1211。drops: [{item_id}]（hero/equip create_icon 自动判）。
static func create_reward(parent: Node, drops: Array, cm: Variant) -> void:
	var idx: int = 0
	for d in drops:
		var item_id: int = int(d.get("item_id", 0))
		if item_id == 0:
			continue
		var icon: Control = ReadequipIcon.create_icon(item_id, 1, cm)
		var gx: float = REWARD_OX + 80.0 * float(idx) + OFFSET_X
		var gy: float = PANEL_H - REWARD_OY + OFFSET_Y  # anchor(0.5,0) 底对齐 → 左上偏移
		icon.position = Vector2(gx - ReadequipIcon.ICON_SIZE * 0.5, gy - ReadequipIcon.ICON_SIZE)
		parent.add_child(icon)
		idx += 1


# 源 createStars :1212-1260。pos ccp(320+gap*i,336) scale0.8；i<star_count 亮 / else 灰。
static func create_stars(parent: Node, star_count: int, star_gap: int) -> void:
	for i in range(3):
		var res_path: String = STAR_RES if i < star_count else STAR_GREY_RES
		var s := Sprite2D.new()
		if ResourceLoader.exists(res_path):
			s.texture = load(res_path)
		s.centered = false
		s.position = to_godot(Vector2(320.0 + float(star_gap) * float(i), 336.0))
		s.scale = Vector2(0.8, 0.8)
		parent.add_child(s)


static func _sprite_center(parent: Node, res_path: String, cocos_pos: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	if ResourceLoader.exists(res_path):
		s.texture = load(res_path)
	s.centered = true
	s.position = to_godot(cocos_pos)
	parent.add_child(s)
	return s


# pos 语义由调用方定（主层用 to_godot，子节点用本地坐标）；centered=false + fix_size 缩放。
static func _sprite_local(parent: Node, res_path: String, pos: Vector2, fix_size: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	if ResourceLoader.exists(res_path):
		s.texture = load(res_path)
	s.centered = false
	s.position = pos
	if fix_size.length() > 0.0 and s.texture != null:
		s.scale = Vector2(fix_size.x / float(s.texture.get_width()), fix_size.y / float(s.texture.get_height()))
	parent.add_child(s)
	return s


static func _scale9(parent: Node, res_path: String, cap_l: int, cap_t: int, cocos_pos: Vector2, size: Vector2) -> NinePatchRect:
	return _place_scale9(parent, res_path, cap_l, cap_t, to_godot(cocos_pos) - size * 0.5, size)


# 可点击按钮（go_button/reset）。中心定位；forced_size>0 时拉伸到该尺寸（reset 100×50 近似源 Scale9）。
static func _texture_button(parent: Node, res_path: String, pressed_res: String, cocos_pos: Vector2, forced_size: Vector2) -> TextureButton:
	var b := TextureButton.new()
	var tex: Texture2D = null
	if ResourceLoader.exists(res_path):
		tex = load(res_path)
		b.texture_normal = tex
	if pressed_res != "" and ResourceLoader.exists(pressed_res):
		b.texture_pressed = load(pressed_res)
	var ts: Vector2 = tex.get_size() if tex != null else Vector2.ZERO
	if forced_size.length() > 0.0:
		b.custom_minimum_size = forced_size
		b.ignore_texture_size = true
		ts = forced_size
	b.position = to_godot(cocos_pos) - ts * 0.5
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(b)
	return b


# 源 Scale9Sprite capInsets(中心区)→ Godot patch_margin(4 边)；left/top 对称近似 right/bottom。
static func _place_scale9(parent: Node, res_path: String, cap_l: int, cap_t: int, pos: Vector2, size: Vector2) -> NinePatchRect:
	var n := NinePatchRect.new()
	if ResourceLoader.exists(res_path):
		n.texture = load(res_path)
	n.patch_margin_left = cap_l
	n.patch_margin_top = cap_t
	n.patch_margin_right = cap_l
	n.patch_margin_bottom = cap_t
	n.position = pos
	n.size = size
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(n)
	return n


static func _label(parent: Node, text: String, cocos_pos: Vector2, color: Color, font_size: int, anchor: Vector2) -> Label:
	var lbl := Label.new()
	lbl.text = text
	if font_size > 0:
		lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.position = to_godot(cocos_pos)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if anchor.x >= 0.5 else HORIZONTAL_ALIGNMENT_LEFT
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER if anchor.y >= 0.5 else VERTICAL_ALIGNMENT_TOP
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(lbl)
	return lbl


static func _label_local(parent: Node, text: String, local_pos: Vector2, color: Color, font_size: int) -> Label:
	var lbl := Label.new()
	lbl.text = text
	if font_size > 0:
		lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.position = local_pos
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(lbl)
	return lbl
