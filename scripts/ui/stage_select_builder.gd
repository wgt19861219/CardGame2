class_name StageSelectBuilder
extends RefCounted

## 关卡选择 View 工厂（照源 stageselect.lua createMap/createStage/createModeButton/
## createChapterButton/createDot/createFrame/createTitle 翻译）。
## 坐标系：源 cocos(800×480 左下原点) → Godot(960×640 左上原点) = (cx+80, 560-cy)。

const StageSelectMapClass = preload("res://scripts/systems/stage_select_map.gd")
const UiButton = preload("res://scripts/ui/ui_button.gd")

# 源 hello.lua:311 setContentScaleFactor(1.28125)；cocos sprite 显示=纹理/CS（无 fix_size 时）。
const CONTENT_SCALE: float = 1.28125

const FRAME_NORMAL: String = "res://assets/ui/alpha/HVGA/stage-map-frame.png"
const FRAME_ELITE: String = "res://assets/ui/alpha/HVGA/stage-map-elite-frame.png"
const FRAME_GUILD: String = "res://assets/ui/alpha/HVGA/stage_map_guild_frame.png"
const TITLE_BG_NORMAL: String = "res://assets/ui/alpha/HVGA/Normal_title_bg.png"
const TITLE_BG_ELITE: String = "res://assets/ui/alpha/HVGA/Elite_title_bg.png"
const TITLE_BG_GUILD: String = "res://assets/ui/alpha/HVGA/guild_title_bg.png"
const MODE_BTN_BG: String = "res://assets/ui/alpha/HVGA/crusade_Button_bg.png"
const MODE_TOGGLE_NS: String = "res://assets/ui/alpha/HVGA/elitetoggle-ns.png"
const MODE_TOGGLE_S: String = "res://assets/ui/alpha/HVGA/elitetoggle-s.png"
const ARROW_PREV: String = "res://assets/ui/alpha/HVGA/prevchap.png"
const ARROW_NEXT: String = "res://assets/ui/alpha/HVGA/nextchap.png"
const DOT_NORMAL: String = "res://assets/ui/alpha/HVGA/stageselect_chapter_dot.png"
const DOT_CURRENT: String = "res://assets/ui/alpha/HVGA/stageselect_chapter_cursor.png"
const POINTER: String = "res://assets/ui/alpha/HVGA/stagepointer.png"
const STAR_BG: String = "res://assets/ui/alpha/HVGA/stageselect_star_bg.png"
const STAR: String = "res://assets/ui/alpha/HVGA/stageselect_star.png"
const CLOSE_RES: String = "res://assets/ui/alpha/HVGA/backbtn.png"
const CLOSE_PRESS: String = "res://assets/ui/alpha/HVGA/backbtn-disabled.png"
# 源 createModeButton(:725) ui_info + refreshModeButtonPosition(:233) 调整后（guild 实际不可见走 else 分支）。
const MODE_BG_POS: Vector2 = Vector2(480.0, 205.0)      # 源 buttonBg ccp(400,355) → godot
const MODE_NORMAL_POS: Vector2 = Vector2(425.0, 210.0)  # 源 refresh else ccp(345,350) → godot
const MODE_ELITE_POS: Vector2 = Vector2(535.0, 210.0)   # 源 refresh else ccp(455,350) → godot
const MODE_GUILD_POS: Vector2 = Vector2(569.0, 210.0)   # 源 guild ccp(489,350)（refresh 不调整 guild）
const TITLE_POS: Vector2 = Vector2(477.0, 167.0)        # 源 titleBg ccp(397,393) → godot（标题图 + 文字同位）
const DOT_CENTER_X: float = 480.0                      # 源 getDotPos x=400+dx*(cur-center)，dx=20
const DOT_GAP_X: float = 20.0
const DOT_NORMAL_Y: float = 520.0                      # 源 normal_chapter_dot_y=40 → 560-40
const DOT_ELITE_Y: float = 515.0                       # 源 elite_chapter_dot_y=45
const ARROW_LEFT_POS: Vector2 = Vector2(158.0, 345.0)  # 源 ccp(78,215) → godot
const ARROW_RIGHT_POS: Vector2 = Vector2(800.0, 345.0) # 源 ccp(720,215)
# 星级布局（源 createStage spos :1242-1255，相对 star_bg 局部）
const STAR_POS_1: Array = [Vector2(37.0, 15.0)]
const STAR_POS_2: Array = [Vector2(26.0, 18.0), Vector2(48.0, 18.0)]
const STAR_POS_3: Array = [Vector2(17.0, 18.0), Vector2(37.0, 15.0), Vector2(57.0, 18.0)]


static func to_godot(cx: float, cy: float) -> Vector2:
	return Vector2(cx + 80.0, 560.0 - cy)


static func create_close_button(container: Control, on_close: Callable) -> void:
	var btn: TextureButton = UiButton.make_at(CLOSE_RES, CLOSE_PRESS, Vector2(20.0, 15.0))  # 左上角留小边（用户偏好更靠左上角）
	btn.pressed.connect(on_close)
	container.add_child(btn)


# 源 createMap + createStage — 地图层（章节 bg + route + stage 圆点 + 星 + 指针）。
# 返回 {node, stage_buttons(sid->TextureButton)}。
static func create_map_layer(container: Control, chapter: int, mode: String, cm: Variant, star_of: Callable) -> Dictionary:
	var layer := Control.new()
	layer.name = "MapLayer"
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(layer)
	var ch: Dictionary = StageSelectMapClass.get_chapter(chapter)
	_make_centered_child(layer, StageSelectMapClass.get_bg_res(chapter), ch.get("bg", {}).get("pos", [400, 212]))
	_make_centered_child(layer, StageSelectMapClass.get_route_res(chapter), ch.get("route", {}).get("pos", [400, 212]))
	var tag: int = StageSelectMapClass.get_tag(chapter)
	var buttons: Dictionary = {}
	for s in StageSelectMapClass.get_stages(chapter):
		var info: Dictionary = s
		var dec: Dictionary = StageSelectMapClass.decide_stage_icon(info, tag, mode, cm, star_of)
		var icon_res: String = String(dec["icon"])
		if icon_res.is_empty() or not ResourceLoader.exists(icon_res):
			continue
		var pos: Array = info.get("pos", [0, 0])
		var btn := TextureButton.new()
		btn.texture_normal = load(icon_res) as Texture2D
		btn.ignore_texture_size = true
		btn.position = to_godot(float(pos[0]), float(pos[1])) - _tex_size(icon_res) * 0.5
		btn.set_meta(&"stage_info", info)
		var dec_type := String(dec["type"])
		if dec_type == "locked":
			btn.disabled = true   # 源 doStageTouch :125 locked 不响应点击
		else:
			_add_stars(btn, info, mode, star_of)
		layer.add_child(btn)
		if dec_type == "current":
			_add_pointer(layer, info)
		if dec_type != "locked":
			var sid: int = _current_sid(info, mode)
			if sid > 0:
				buttons[sid] = btn
	return {"node": layer, "stage_buttons": buttons}


static func _make_centered_child(parent: Node, res: String, cocos_pos: Variant) -> void:
	if res.is_empty() or not ResourceLoader.exists(res):
		return
	var tex: Texture2D = load(res) as Texture2D
	if tex == null:
		return
	var node := TextureRect.new()
	node.texture = tex
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.size = tex.get_size()
	var p: Array = cocos_pos if cocos_pos is Array else [400, 212]
	node.position = to_godot(float(p[0]), float(p[1])) - tex.get_size() * 0.5
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)


static func _add_stars(btn: TextureButton, info: Dictionary, mode: String, star_of: Callable) -> void:
	if mode == "guild":
		return
	var id: int = int(info.get("eid", 0)) if mode == "elite" else int(info.get("id", 0))
	if id <= 0 or not info.has("eid"):   # 源 :1261 仅 key 关（有 eid）显示星
		return
	var sn: int = int(star_of.call(id))
	if sn <= 0 or sn > 3:
		return
	var bg := TextureRect.new()
	bg.texture = load(STAR_BG) as Texture2D
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# 源 :1262 starBg = ed.createSprite 无 fix → 显示=纹理/CS。
	bg.size = _tex_size(STAR_BG) / CONTENT_SCALE
	bg.position = Vector2(82.0, 38.0) - bg.size * 0.5   # 源 star_bg ccp(82,38) 局部（icon 左上原点）
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(bg)
	var spos: Array = STAR_POS_3 if sn == 3 else (STAR_POS_2 if sn == 2 else STAR_POS_1)
	for i in range(sn):
		var star := TextureRect.new()
		star.texture = load(STAR) as Texture2D
		star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		# 源 :1268 star = ed.createSprite 无 fix → 显示=纹理/CS。
		star.size = _tex_size(STAR) / CONTENT_SCALE
		star.position = spos[i] - star.size * 0.5
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.add_child(star)


# 源 currentTag stagepointer（:1299-1312 上下浮动，简化静态）。
# 源 :1301-1305 — key 关（info.eid）ccp(pos.x, pos.y+60)；非 key 关 ccp(pos.x-1, pos.y+30)。
static func _add_pointer(layer: Control, info: Dictionary) -> void:
	if not ResourceLoader.exists(POINTER):
		return
	var pos: Array = info.get("pos", [0, 0])
	var cx: float = float(pos[0])
	var cy: float = float(pos[1])
	var is_key: bool = info.has("eid")
	var dx: float = -1.0 if not is_key else 0.0
	var dy: float = 30.0 if not is_key else 60.0
	var p := TextureRect.new()
	p.texture = load(POINTER) as Texture2D
	p.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# 源 :1299 currentTag = ed.createSprite 无 fix → 显示=纹理/CS。
	p.size = _tex_size(POINTER) / CONTENT_SCALE
	p.position = to_godot(cx + dx, cy + dy) - p.size * 0.5
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(p)


static func _current_sid(info: Dictionary, mode: String) -> int:
	if mode == "elite":
		return int(info.get("eid", 0))
	if mode == "guild":
		return int(info.get("guildInstanceId", 0))
	return int(info.get("id", 0))


static func _tex_size(res: String) -> Vector2:
	if not ResourceLoader.exists(res):
		return Vector2(45.0, 45.0)
	var t: Texture2D = load(res) as Texture2D
	return t.get_size() if t != null else Vector2(45.0, 45.0)


# 源 createFrame（:944+）title_bg + frame 边框；createTitle（:885）章节名 Label。
static func create_frame_and_title(container: Control, chapter: int, mode: String, cm: Variant) -> void:
	_make_centered_at(container, _title_bg_res(mode), TITLE_POS)
	# 源 createFrame :967-970 — mode != normal ccp(400,207)→godot(480,353)；normal ccp(400,205)→godot(480,355)
	var frame_y: float = 355.0 if mode == "normal" else 353.0
	_make_centered_at(container, _frame_res(mode), Vector2(480.0, frame_y))
	var chapter_table: Dictionary = cm.get_raw_table(&"Chapter")
	var ch_row: Dictionary = chapter_table.get(str(chapter), {})
	var pre: String = String(ch_row.get("Pre Chapter Name", ""))
	var name: String = String(ch_row.get("Chapter Name", ""))
	var lbl := Label.new()
	# 源 :862-863 直接索引 chapterTable[chapter]（无 fallback，假定存在）。防御性 fallback 保留 + 注释。
	# 源 :863 拼接 "Pre Chapter Name" .. "   " .. "Chapter Name"（3 空格）。
	lbl.text = pre + "   " + name if not name.is_empty() else ("第 " + str(chapter) + " 章")
	lbl.add_theme_color_override("font_color", Color(250.0 / 255.0, 205.0 / 255.0, 16.0 / 255.0))
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 2)
	lbl.position = TITLE_POS - Vector2(120.0, 12.0)
	lbl.size = Vector2(240.0, 24.0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(lbl)


static func _frame_res(mode: String) -> String:
	return FRAME_ELITE if mode == "elite" else (FRAME_GUILD if mode == "guild" else FRAME_NORMAL)


static func _title_bg_res(mode: String) -> String:
	return TITLE_BG_ELITE if mode == "elite" else (TITLE_BG_GUILD if mode == "guild" else TITLE_BG_NORMAL)


static func _make_centered_at(parent: Node, res: String, godot_center: Vector2) -> void:
	if res.is_empty() or not ResourceLoader.exists(res):
		return
	var tex: Texture2D = load(res) as Texture2D
	if tex == null:
		return
	# title_bg/frame 源 createSprite 无 fix_size → 显示尺寸=纹理/CS（[[content-scale-factor]]）
	var display_size := tex.get_size() / CONTENT_SCALE
	var node := TextureRect.new()
	node.texture = tex
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.size = display_size
	node.position = godot_center - display_size * 0.5
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)


# 源 createModeButton（:725）normal/elite/guild 三 toggle。返回 {mode->TextureButton}。
# 源 label：normal=LSTR("STAGESELECT.NORMAL")="普通"、elite=LSTR("EQUIPCRAFT.ELITE")="精英"、
# guild=LSTR("STAGESELECT.RAID")="团队"。fontinfo "ui_normal_button" size=18（:773,:809,:845）。
static func create_mode_buttons(container: Control, current_mode: String, cm: Variant, on_mode: Callable) -> Dictionary:
	var bg := TextureRect.new()
	bg.texture = load(MODE_BTN_BG) as Texture2D
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# 源 :731 buttonBg config={} → 显示=纹理/CS。
	bg.size = _tex_size(MODE_BTN_BG) / CONTENT_SCALE
	bg.position = MODE_BG_POS - bg.size * 0.5
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(bg)
	var layout: Dictionary = {
		"normal": {"pos": MODE_NORMAL_POS, "lstr": "STAGESELECT.NORMAL"},
		"elite": {"pos": MODE_ELITE_POS, "lstr": "EQUIPCRAFT.ELITE"},
		"guild": {"pos": MODE_GUILD_POS, "lstr": "STAGESELECT.RAID"},
	}
	var buttons: Dictionary = {}
	for mode in layout:
		var cfg: Dictionary = layout[mode]
		var btn := TextureButton.new()
		var selected: bool = mode == current_mode
		btn.texture_normal = load(MODE_TOGGLE_S if selected else MODE_TOGGLE_NS) as Texture2D
		btn.ignore_texture_size = true
		var sz: Vector2 = _tex_size(MODE_TOGGLE_NS)
		btn.position = Vector2(cfg["pos"]) - sz * 0.5
		btn.pressed.connect(on_mode.bind(mode))
		var lbl := Label.new()
		var lstr_key: String = String(cfg["lstr"])
		lbl.text = cm.get_lstr(lstr_key) if cm != null else lstr_key
		lbl.set_anchors_preset(Control.PRESET_CENTER)
		lbl.add_theme_font_size_override("font_size", 18)   # 源 :773 size=18
		lbl.add_theme_color_override("font_color", Color.WHITE)
		lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		lbl.add_theme_constant_override("outline_size", 2)
		btn.add_child(lbl)
		container.add_child(btn)
		buttons[mode] = btn
	return buttons


# 源 createChapterButton（:705）左右箭头（简化静态，去浮动动画）。
static func create_chapter_arrows(container: Control, has_prev: bool, has_next: bool, on_prev: Callable, on_next: Callable) -> void:
	if has_prev:
		var lb: TextureButton = UiButton.make_at(ARROW_PREV, ARROW_PREV, ARROW_LEFT_POS - _tex_size(ARROW_PREV) * 0.5)
		lb.pressed.connect(on_prev)
		container.add_child(lb)
	if has_next:
		var rb: TextureButton = UiButton.make_at(ARROW_NEXT, ARROW_NEXT, ARROW_RIGHT_POS - _tex_size(ARROW_NEXT) * 0.5)
		rb.pressed.connect(on_next)
		container.add_child(rb)


# 源 createDot（:676）+ getDotPos（:76）— 章节导航点（max 章横排，current 用 cursor）。
static func create_chapter_dots(container: Control, max_chapter: int, current: int, mode: String) -> void:
	var y: float = DOT_ELITE_Y if mode == "elite" else DOT_NORMAL_Y
	var center: float = (float(max_chapter) + 1.0) * 0.5
	for i in range(1, max_chapter + 1):
		var res: String = DOT_CURRENT if i == current else DOT_NORMAL
		if not ResourceLoader.exists(res):
			continue
		var dot := TextureRect.new()
		dot.texture = load(res) as Texture2D
		dot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		# 源 :688-693 createSprite(res.dotRes.current/normal) 无 fix → 显示=纹理/CS。
		dot.size = _tex_size(res) / CONTENT_SCALE
		dot.position = Vector2(DOT_CENTER_X + DOT_GAP_X * (float(i) - center), y) - dot.size * 0.5
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(dot)
