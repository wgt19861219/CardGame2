class_name StageSelectBuilder
extends RefCounted

## 关卡选择 View 工厂（照源 stageselect.lua createMap/createStage/createModeButton/
## createChapterButton/createDot/createFrame/createTitle 翻译）。
## 重构（2026-07-17）：base 静态元素（bg/close/mode toggle/箭头）进 stage_select_content.tscn，
## 本类只 fill mode toggle 纹理/文本 + procedural 建动态层（map_layer、frame/title、dots）。
## 坐标系：源 cocos(800×480 左下原点) → Godot(960×640 左上原点) = (cx+80, 560-cy)。

const StageSelectMapClass = preload("res://scripts/systems/stage_select_map.gd")

const FRAME_NORMAL: String = "res://assets/ui/alpha/HVGA/stage-map-frame.png"
const FRAME_ELITE: String = "res://assets/ui/alpha/HVGA/stage-map-elite-frame.png"
const FRAME_GUILD: String = "res://assets/ui/alpha/HVGA/stage_map_guild_frame.png"
const TITLE_BG_NORMAL: String = "res://assets/ui/alpha/HVGA/Normal_title_bg.png"
const TITLE_BG_ELITE: String = "res://assets/ui/alpha/HVGA/Elite_title_bg.png"
const TITLE_BG_GUILD: String = "res://assets/ui/alpha/HVGA/guild_title_bg.png"
const MODE_TOGGLE_NS: String = "res://assets/ui/alpha/HVGA/elitetoggle-ns.png"
const MODE_TOGGLE_S: String = "res://assets/ui/alpha/HVGA/elitetoggle-s.png"
const DOT_NORMAL: String = "res://assets/ui/alpha/HVGA/stageselect_chapter_dot.png"
const DOT_CURRENT: String = "res://assets/ui/alpha/HVGA/stageselect_chapter_cursor.png"
const POINTER: String = "res://assets/ui/alpha/HVGA/stagepointer.png"
const STAR_BG: String = "res://assets/ui/alpha/HVGA/stageselect_star_bg.png"
const STAR: String = "res://assets/ui/alpha/HVGA/stageselect_star.png"
const TITLE_POS: Vector2 = Vector2(477.0, 167.0)        # 源 titleBg ccp(397,393) → godot（标题图 + 文字同位）
const DOT_CENTER_X: float = 480.0                      # 源 getDotPos x=400+dx*(cur-center)，dx=20
const DOT_GAP_X: float = 20.0
const DOT_NORMAL_Y: float = 520.0                      # 源 normal_chapter_dot_y=40 → 560-40
const DOT_ELITE_Y: float = 515.0                       # 源 elite_chapter_dot_y=45
# 星级布局（源 createStage spos :1242-1255，相对 star_bg 局部）
const STAR_POS_1: Array = [Vector2(37.0, 15.0)]
const STAR_POS_2: Array = [Vector2(26.0, 18.0), Vector2(48.0, 18.0)]
const STAR_POS_3: Array = [Vector2(17.0, 18.0), Vector2(37.0, 15.0), Vector2(57.0, 18.0)]

# 源 stageselect.lua:1610-1612 clipStencil 712×372 @ cocos(44,20)。
# cocos (44,20) 左下原点 → godot (44+80, 560-(20+372)) = (124,168) 左上原点；size 不变（to_godot 不缩放）。
const CLIP_RECT: Rect2 = Rect2(124.0, 168.0, 712.0, 372.0)
const CLIP_OFFSET: Vector2 = Vector2(124.0, 168.0)   # layer 局部坐标系偏移：子节点 position 减此值


static func to_godot(cx: float, cy: float) -> Vector2:
	return Vector2(cx + 80.0, 560.0 - cy)


# fill .tscn %ModeNormalBtn/EliteBtn/GuildBtn 纹理（selected=elitetoggle-s 否则 ns）+ Label LSTR 文本。
# 源 createModeButton(:725) 建节点 + refreshModeButtonPosition(:233) 调位置 + updateModeButtonState(:292)
# 切 _press visible + label color。本项目位置/size .tscn 固化，此处只切纹理 + 填文本（TextureButton
# normal 双态简化，源 Sprite+press 切 visible 等价）。
# 源 label：normal=LSTR("STAGESELECT.NORMAL")="普通"、elite=LSTR("EQUIPCRAFT.ELITE")="精英"、
# guild=LSTR("STAGESELECT.RAID")="团队"。fontinfo "ui_normal_button" size=18（:773,:809,:845）。
static func fill_mode_toggle(buttons: Dictionary, current_mode: String, cm: Variant) -> void:
	var lstr_keys: Dictionary = {
		"normal": "STAGESELECT.NORMAL",
		"elite": "EQUIPCRAFT.ELITE",
		"guild": "STAGESELECT.RAID",
	}
	for mode in buttons:
		var btn: TextureButton = buttons[mode]
		# ignore_texture_size=true 不设 stretch_mode → 默认 KEEP 纹理原尺寸(129×67)溢出 offset(100.6×52.2)致相邻重叠
		# （[[texture-button-stretch-mode-keep-default]]，同 hero_package tab 根因），强制 SCALE 缩到 offset size
		btn.stretch_mode = TextureButton.STRETCH_SCALE
		var selected: bool = mode == current_mode
		var res_path: String = MODE_TOGGLE_S if selected else MODE_TOGGLE_NS
		if ResourceLoader.exists(res_path):
			btn.texture_normal = load(res_path) as Texture2D
		var lbl: Label = null
		for child in btn.get_children():
			if child is Label:
				lbl = child
				break
		if lbl != null:
			var key: String = String(lstr_keys[mode])
			lbl.text = String(cm.get_lstr(key)) if cm != null else key


# 源 createMap + createStage — 地图层（章节 bg + route + stage 圆点 + 星 + 指针）。
# 返回 {node, stage_buttons(sid->TextureButton)}。
# 源 stageselect.lua:1608-1615 create — clipLayer = ClippingNode(stencil=712×372 @ cocos(44,20))，
# mapContainer 挂 clipLayer 下，剪掉章节 bg 超出 frame 边框的部分。
# Godot 等价：layer 自身设 clip_contents=true + rect=(124,168,712,372)，子节点 position 减 CLIP_OFFSET。
# cocos clipStencil(44,20) → godot (44+80, 560-(20+372)) = (124,168)；712×372 不变（to_godot 不缩放）。
static func create_map_layer(container: Control, chapter: int, mode: String, cm: Variant, star_of: Callable) -> Dictionary:
	var layer := Control.new()
	layer.name = "MapLayer"
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.clip_contents = true
	layer.position = CLIP_RECT.position
	layer.size = CLIP_RECT.size
	container.add_child(layer)
	var ch: Dictionary = StageSelectMapClass.get_chapter(chapter)
	_make_centered_child(layer, StageSelectMapClass.get_bg_res(chapter), ch.get("bg", {}).get("pos", [400, 212]), CLIP_OFFSET)
	_make_centered_child(layer, StageSelectMapClass.get_route_res(chapter), ch.get("route", {}).get("pos", [400, 212]), CLIP_OFFSET)
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
		btn.size = TexDisplaySize.display_size(icon_res)   # 源 createSprite ContentScale 已含；修 ignore_texture_size 不设 size → 0×0 不可点（同 [[texture-button-ignore-texture-size-zero]]）
		btn.position = to_godot(float(pos[0]), float(pos[1])) - btn.size * 0.5 - CLIP_OFFSET
		btn.set_meta(&"stage_info", info)
		var dec_type := String(dec["type"])
		if dec_type == "locked":
			btn.disabled = true   # 源 doStageTouch :125 locked 不响应点击
		else:
			_add_stars(btn, info, mode, star_of)
		layer.add_child(btn)
		if dec_type == "current":
			_add_pointer(layer, info, CLIP_OFFSET)
		if dec_type != "locked":
			var sid: int = _current_sid(info, mode)
			if sid > 0:
				buttons[sid] = btn
	return {"node": layer, "stage_buttons": buttons}


static func _make_centered_child(parent: Node, res: String, cocos_pos: Variant, offset: Vector2 = Vector2.ZERO) -> void:
	if res.is_empty() or not ResourceLoader.exists(res):
		return
	var tex: Texture2D = load(res) as Texture2D
	if tex == null:
		return
	var node := TextureRect.new()
	node.texture = tex
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# 源 createSprite = CCSprite + setScale(ContentScale)，显示=纹理 × ContentScale / CS（_display_size 已含）。
	# 修 bug：原 tex.get_size()/CS 漏乘 ContentScale，致章节 bg 显示 365×198 偏小（应 730×396 铺满）。
	var display_size: Vector2 = TexDisplaySize.display_size(res)
	node.size = display_size
	var p: Array = cocos_pos if cocos_pos is Array else [400, 212]
	node.position = to_godot(float(p[0]), float(p[1])) - display_size * 0.5 - offset
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
	# 源 :1262 starBg = ed.createSprite（含 ContentScale，本项目 STAR_BG 无 TextureConfig 条目 → CS=1 等价）。
	bg.size = TexDisplaySize.display_size(STAR_BG)
	bg.position = Vector2(82.0, 38.0) - bg.size * 0.5   # 源 star_bg ccp(82,38) 局部（icon 左上原点）
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(bg)
	var spos: Array = STAR_POS_3 if sn == 3 else (STAR_POS_2 if sn == 2 else STAR_POS_1)
	for i in range(sn):
		var star := TextureRect.new()
		star.texture = load(STAR) as Texture2D
		star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		# 源 :1268 star = ed.createSprite（含 ContentScale，STAR 无条目 → CS=1 等价）。
		star.size = TexDisplaySize.display_size(STAR)
		star.position = spos[i] - star.size * 0.5
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.add_child(star)


# 源 currentTag stagepointer（:1299-1312 上下浮动，简化静态）。
# 源 :1301-1305 — key 关（info.eid）ccp(pos.x, pos.y+60)；非 key 关 ccp(pos.x-1, pos.y+30)。
static func _add_pointer(layer: Control, info: Dictionary, offset: Vector2 = Vector2.ZERO) -> void:
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
	# 源 :1299 currentTag = ed.createSprite（含 ContentScale，POINTER 无条目 → CS=1 等价）。
	p.size = TexDisplaySize.display_size(POINTER)
	p.position = to_godot(cx + dx, cy + dy) - p.size * 0.5 - offset
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(p)


static func _current_sid(info: Dictionary, mode: String) -> int:
	if mode == "elite":
		return int(info.get("eid", 0))
	if mode == "guild":
		return int(info.get("guildInstanceId", 0))
	return int(info.get("id", 0))




# 源 createFrame（:944+）title_bg + frame 边框；createTitle（:885）章节名 Label。
# 三 mode frame/title_bg 纹理 size 不同 → 保留 procedural 建（每次 _refresh_view 清 FrameLayer 重建）。
static func create_frame_and_title(container: Control, chapter: int, mode: String, cm: Variant) -> void:
	# 源 z order（mainLayer addChild 第二参）：frameContainer=5（下）、titleBg=21、titleContainer=22（上）。
	# 本项目靠建序定 z（add_child 后建在上）：frame 先建（z 下），title_bg 后建（z 上压 frame 上边框，照源 titleBg 压 frame），
	# title Label 最后建（行 224，z 最上，照源 titleContainer=22）。原序 title_bg→frame 致 frame 压 title_bg 被用户反馈"标题被边框挡"。
	# 源 createFrame :967-970 — mode != normal ccp(400,207)→godot(480,353)；normal ccp(400,205)→godot(480,355)
	var frame_y: float = 355.0 if mode == "normal" else 353.0
	_make_centered_at(container, _frame_res(mode), Vector2(480.0, frame_y))
	_make_centered_at(container, _title_bg_res(mode), TITLE_POS)
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
	# title_bg/frame 源 createSprite（含 ContentScale；本项目 Normal_title_bg/stage-map-frame 等条目 CS=0 → 返 1，等价）。
	var display_size := TexDisplaySize.display_size(res)
	var node := TextureRect.new()
	node.texture = tex
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.size = display_size
	node.position = godot_center - display_size * 0.5
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)


# 源 createDot（:676）+ getDotPos（:76）— 章节导航点（max 章横排，current 用 cursor）。
# panel 持有 %DotContainer，每次 _refresh_view 清空再 procedural 建挂入（数量随 max_chapter 动态）。
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
		# 源 :688-693 createSprite（含 ContentScale，dot 纹理无条目 → CS=1 等价）。
		dot.size = TexDisplaySize.display_size(res)
		dot.position = Vector2(DOT_CENTER_X + DOT_GAP_X * (float(i) - center), y) - dot.size * 0.5
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(dot)
