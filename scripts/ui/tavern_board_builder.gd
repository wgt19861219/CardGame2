class_name TavernBoardBuilder
extends RefCounted

## 抽卡 board scroll_board 工厂（照源 tavern.lua createBaseBoard:594 +
## createCommonLayer:653 / createMagicLayer:949 翻译）。
## 结构：container > board_bg + board_title(缺图降级 Label) + clipLayer(206×320 clip_contents)
##   > scroll_board(13 节点：light/box[/box_bg magic]/ad(缺图跳过)/cost_bg/check/arrow/
##     one_bg+one_cost+one_buy / ten_bg+ten_cost+ten_prompt+ten_buy [/drop_bg 4 组 magic])
## 滑动（源 doClickCheck:1576 / doClickArrow:1584）：scroll_board.position.y 0↔-320，
##   CCMoveTo(0.2) EaseSineIn(展开)/EaseSineOut(收回) → Godot Tween TRANS_SINE。
## 坐标：源 Cocos(左下原点 y 向上) → Godot(左上 y 向下)，子节点 y = CLIP_H - cocos_y。
## board 横排中心照源 draglist(80,80)+board_bg ccp(160,205) → Godot (240,355)/(480,355)/(720,355)。
## magic drop_bg 4 组背景框由本 builder 建，heroIcons 由 panel _fill_magic_heroicons 运行时填
## （照源 doRefrehMagicHeroIcon:1290，ask_magicsoul 回复后才有 ID）。

const CLIP_W: float = 206.0
const CLIP_H: float = 320.0
const SCROLL_CX: float = 109.0
const SLIDE_OFFSET: float = 320.0
const SLIDE_DURATION: float = 0.2
const RES_DIR: String = "res://assets/ui/alpha/HVGA/"
const LIGHT_ROTATE_SEC: float = 5.0
const FULL_CIRCLE_DEG: float = 360.0
# board 的 _tex/_button 工厂（纯 Sprite 无 fix_size）照源 /CS；_scale9 用源 scaleSize（1:1）不动。
const CONTENT_SCALE: float = 1.28125

# res 映射（照源 parameter/tavernres.lua）
const BOARD_BG: Dictionary = {"bronze": "tavern_bg_1.png", "gold": "tavern_bg_3.png", "magic": "tavern_bg_2.png"}
const BOX_RES: Dictionary = {"bronze": "tavern_bg_chest_1.png", "gold": "tavern_bg_chest_3.png", "magic": "tavern_bg_chest_4.png"}
const LIGHT_RES: Dictionary = {"gold": "tavern_light_rotate_3.png", "magic": "tavern_light_rotate_2.png"}
const IS_LIGHT_VISIBLE: Dictionary = {"bronze": false, "gold": true, "magic": true}
const MAGIC_BOX_BG_RES: String = "tavern_magicsoul_mark1.png"
const COST_BG_RES: String = "tavern_cost_bg.png"
const COST_FRAME_RES: String = "tavern_cost_frame.png"
const COST_FRAME_CAP: Rect2 = Rect2(40.0, 0.0, 57.0, 32.0)
const COST_FRAME_SIZE: Vector2 = Vector2(100.0, 32.0)
const CHECK_RES: String = "tavern_button_1.png"
const CHECK_PRESS_RES: String = "tavern_button_2.png"
const ARROW_RES: String = "tavern_up.png"
const ONE_BUY_RES: String = "tavern_button_normal_1.png"
const ONE_BUY_PRESS_RES: String = "tavern_button_normal_2.png"
const TEN_BUY_RES: String = "tavern_button_1.png"
const TEN_BUY_PRESS_RES: String = "tavern_button_2.png"
const GOLD_ICON_RES: String = "task_gold_icon_2.png"
const RMB_ICON_RES: String = "task_rmb_icon_2.png"
const TITLE_COLOR: Color = Color(1.0, 0.81, 0.07)
const COST_FRAME_CAP_MAGIC: Rect2 = Rect2(10.0, 10.0, 20.0, 20.0)
# magic drop_bg 4 组（源 createMagicLayer:1068-1147 tavern_magicsoul_hero_bg Scale9 cap 10,10,20,20）
const MAGIC_HERO_BG_RES: String = "tavern_magicsoul_hero_bg.png"
const DROP_BG_CAP: Rect2 = Rect2(10.0, 10.0, 20.0, 20.0)
const DROP_BG_LEFT_SIZE: Vector2 = Vector2(130.0, 50.0)
const DROP_BG_RIGHT_SIZE: Vector2 = Vector2(50.0, 50.0)
const DROP_BG_DAY_SIZE: Vector2 = Vector2(150.0, 75.0)
const DROP_BG_MONTH_SIZE: Vector2 = Vector2(150.0, 75.0)


# 建 board（container 中心 = godot_center）。
# cost_info: {once_cost, ten_cost, once_pay, ten_pay}（TavernData 读）。
# handlers: {on_check: Callable, on_arrow: Callable, on_once: Callable, on_ten: Callable}（均已 bind key）。
# texts: {check_label, once_label, ten_label, day_title, month_title, ten_prompt_text}（panel LSTR 化后注入）。
# 返回 {container, scroll_board, check_btn, arrow_btn, once_btn, ten_btn, once_cost_lbl, ten_cost_lbl, box, light}。
static func create_board(key: String, godot_center: Vector2, cost_info: Dictionary, handlers: Dictionary, texts: Dictionary) -> Dictionary:
	var is_magic: bool = key == "magic"
	var container := Control.new()
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.size = Vector2(CLIP_W, CLIP_H)
	container.position = godot_center - Vector2(CLIP_W, CLIP_H) * 0.5
	# board_bg（源 :608 res.board_bg[key]，居中 clipLayer）
	var board_bg := _tex(RES_DIR + String(BOARD_BG[key]))
	board_bg.position = (Vector2(CLIP_W, CLIP_H) - board_bg.size) * 0.5
	container.add_child(board_bg)
	# board_title_bg（源 :619 tavern_title_bg.png，所有卡池共用，board_title 衬底）。
	var title_bg := _tex(RES_DIR + "tavern_title_bg.png")
	title_bg.position = Vector2(CLIP_W * 0.5, 25.0) - title_bg.size * 0.5
	container.add_child(title_bg)
	# board_title 缺图降级 Label（源 :630 tavern_title_N.png 源缺，降级卡池名）。
	var title_lbl := Label.new()
	title_lbl.text = _display_name(key)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.size = Vector2(CLIP_W, 24.0)
	title_lbl.position = Vector2(0.0, -2.0)
	title_lbl.add_theme_color_override("font_color", TITLE_COLOR)
	title_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	title_lbl.add_theme_constant_override("outline_size", 2)
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(title_lbl)
	# clipLayer（源 :641 ClippingNode stencil 206×320 → Godot clip_contents）
	var clip := Control.new()
	clip.clip_contents = true
	clip.size = Vector2(CLIP_W, CLIP_H)
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(clip)
	# scroll_board（源 :648 CCLayer，position (0,0)，滑动改 position.y）
	var scroll := Control.new()
	scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(scroll)
	var nodes := _build_scroll_nodes(key, scroll, cost_info, handlers, is_magic, texts)
	return {
		"container": container,
		"scroll_board": scroll,
		"check_btn": nodes["check"],
		"arrow_btn": nodes["arrow"],
		"once_btn": nodes.get("once_buy", null),
		"ten_btn": nodes["ten_buy"],
		"once_cost_lbl": nodes.get("once_cost", null),
		"ten_cost_lbl": nodes["ten_cost"],
		"box": nodes.get("box", null),
		"light": nodes.get("light", null),
	}


static func expand(scroll: Control) -> void:
	var tw: Tween = scroll.create_tween()
	tw.tween_property(scroll, "position:y", -SLIDE_OFFSET, SLIDE_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


static func collapse(scroll: Control) -> void:
	var tw: Tween = scroll.create_tween()
	tw.tween_property(scroll, "position:y", 0.0, SLIDE_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


# TextureRect rotation 绕 pivot_offset，照源 Sprite anchor(0.5,0.5) 中心 → 设 pivot_offset=size/2。
static func play_light_anim(board: Dictionary) -> void:
	var light: TextureRect = board.get("light", null)
	if light == null:
		return
	light.pivot_offset = light.size * 0.5
	var tw: Tween = light.create_tween().set_loops()
	tw.tween_property(light, "rotation", deg_to_rad(FULL_CIRCLE_DEG), LIGHT_ROTATE_SEC)


# ---- 内部 ----

# texts 由 panel 用 cm.get_lstr 准备后注入（builder 不查 LSTR，保持纯结构）。
static func _build_scroll_nodes(key: String, scroll: Control, cost_info: Dictionary, handlers: Dictionary, is_magic: bool, texts: Dictionary) -> Dictionary:
	var nodes: Dictionary = {}
	var cx: float = 110.0 if is_magic else SCROLL_CX
	# light（源 :664 ccp(109,270) / magic :965 ccp(110,250)，visible=is_light_visible）
	if IS_LIGHT_VISIBLE.get(key, false) and LIGHT_RES.has(key):
		var light := _tex(RES_DIR + String(LIGHT_RES[key]))
		light.position = _scroll_pos(cx, 250.0 if is_magic else 270.0, light.size)
		scroll.add_child(light)
		nodes["light"] = light
	# magic box_bg（源 :978 tavern_magicsoul_mark1.png ccp(110,250)）
	if is_magic:
		var box_bg := _tex(RES_DIR + MAGIC_BOX_BG_RES)
		box_bg.position = _scroll_pos(cx, 250.0, box_bg.size)
		scroll.add_child(box_bg)
	# box（源 :679 ccp(109,270) / magic :989 ccp(110,280)）
	var box := _tex(RES_DIR + String(BOX_RES[key]))
	box.position = _scroll_pos(cx, 280.0 if is_magic else 270.0, box.size)
	scroll.add_child(box)
	nodes["box"] = box
	# ad（源 :690 tavern_ad_* 全缺图，跳过）
	# cost_bg（源 :700 ccp(109,105)）
	var cost_bg := _tex(RES_DIR + COST_BG_RES)
	cost_bg.position = _scroll_pos(cx, 105.0, cost_bg.size)
	scroll.add_child(cost_bg)
	# check + check_label "查看"（源 :712 ccp(109,60) + :737 RECHARGE.VIEW）
	var check := _button(CHECK_RES, CHECK_PRESS_RES, cx, 60.0)
	_center_label(String(texts.get("check_label", "查看")), check)
	check.pressed.connect(handlers["on_check"])
	scroll.add_child(check)
	nodes["check"] = check
	# arrow（源 :750 ccp(109,0)，上下浮动动画简化静态）
	var arrow := _button(ARROW_RES, ARROW_RES, cx, 0.0)
	arrow.pressed.connect(handlers["on_arrow"])
	scroll.add_child(arrow)
	nodes["arrow"] = arrow
	# magic drop_bg 4 组（源 createMagicLayer:1068-1147，heroIcons 由 panel _fill_magic_heroicons 运行时填）
	if is_magic:
		_build_magic_dropbg(scroll, texts)
	# one_bg + one_Icon + one_cost + one_buy（源 :759-832，magic 无单抽跳过）
	if not is_magic:
		var once_pay: String = String(cost_info.get("once_pay", "Diamond"))
		var once_cost_lbl := _cost_row(scroll, SCROLL_CX, -87.0, once_pay, int(cost_info.get("once_cost", 0)))
		nodes["once_cost"] = once_cost_lbl
		var one_buy := _button(ONE_BUY_RES, ONE_BUY_PRESS_RES, SCROLL_CX, -130.0)
		_center_label(String(texts.get("once_label", "购买1个")), one_buy)
		one_buy.pressed.connect(handlers["on_once"])
		scroll.add_child(one_buy)
		nodes["once_buy"] = one_buy
	# ten_bg + ten_Icon + ten_cost + ten_prompt + ten_buy（源 :833-918）
	var ten_pay: String = String(cost_info.get("ten_pay", "Diamond"))
	var ten_cost_lbl := _cost_row(scroll, cx, -212.0, ten_pay, int(cost_info.get("ten_cost", 0)))
	nodes["ten_cost"] = ten_cost_lbl
	# ten_prompt（源 :873 ccp(108,-180) / magic combo_prompt :1188 ccp(110,-183)）
	var prompt := Label.new()
	prompt.text = String(texts.get("ten_prompt_text", ""))
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.size = Vector2(CLIP_W, 20.0)
	prompt.position = _scroll_pos(108.0, -180.0, prompt.size)
	prompt.theme_type_variation = &"BodyLabelThin"
	prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(prompt)
	var ten_buy := _button(TEN_BUY_RES, TEN_BUY_PRESS_RES, cx, -260.0)
	_center_label(String(texts.get("ten_label", "购买10个")), ten_buy)
	ten_buy.pressed.connect(handlers["on_ten"])
	scroll.add_child(ten_buy)
	nodes["ten_buy"] = ten_buy
	return nodes


static func _build_magic_dropbg(scroll: Control, texts: Dictionary) -> void:
	var left_bg := _scale9(RES_DIR + MAGIC_HERO_BG_RES, DROP_BG_LEFT_SIZE, DROP_BG_CAP)
	left_bg.name = "drop_bg_left"
	left_bg.position = _scroll_pos(82.0, 175.0, left_bg.size)
	scroll.add_child(left_bg)
	var right_bg := _scale9(RES_DIR + MAGIC_HERO_BG_RES, DROP_BG_RIGHT_SIZE, DROP_BG_CAP)
	right_bg.name = "drop_bg_right"
	right_bg.position = _scroll_pos(175.0, 175.0, right_bg.size)
	scroll.add_child(right_bg)
	var day_bg := _scale9(RES_DIR + MAGIC_HERO_BG_RES, DROP_BG_DAY_SIZE, DROP_BG_CAP)
	day_bg.name = "drop_bg_day"
	day_bg.position = _scroll_pos(107.0, -130.0, day_bg.size)
	scroll.add_child(day_bg)
	_drop_title(scroll, String(texts.get("day_title", "今日热点")), 107.0, -106.0)
	var month_bg := _scale9(RES_DIR + MAGIC_HERO_BG_RES, DROP_BG_MONTH_SIZE, DROP_BG_CAP)
	month_bg.name = "drop_bg_month"
	month_bg.position = _scroll_pos(107.0, -52.0, month_bg.size)
	scroll.add_child(month_bg)
	_drop_title(scroll, String(texts.get("month_title", "本周热点")), 107.0, -30.0)


static func _drop_title(scroll: Control, text: String, cx: float, cy: float) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size = Vector2(CLIP_W, 20.0)
	lbl.position = _scroll_pos(cx, cy, lbl.size)
	lbl.theme_type_variation = &"BodyLabelThin"
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(lbl)


# ccp(109,-87/-212) bg + ccp(64,-87/-213) icon + ccp(144,-87/-212) cost anchor(1,0.5)。
# 返回 cost Label（供刷新）。
static func _cost_row(scroll: Control, cx: float, cy: float, pay: String, cost_val: int) -> Label:
	var bg := _scale9(RES_DIR + COST_FRAME_RES, COST_FRAME_SIZE, COST_FRAME_CAP)
	bg.position = _scroll_pos(cx, cy, bg.size)
	scroll.add_child(bg)
	var icon_res: String = RES_DIR + (GOLD_ICON_RES if pay == "Gold" else RMB_ICON_RES)
	var icon := _tex(icon_res)
	if pay != "Gold":
		icon.scale = Vector2(1.2, 1.2)
	icon.position = _scroll_pos(64.0, cy, icon.size)
	scroll.add_child(icon)
	# cost Label（源 anchor ccp(1,0.5) ccp(144,cy)，右对齐到 x=144）
	var lbl := Label.new()
	lbl.text = str(cost_val)
	lbl.size = Vector2(40.0, 20.0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl.position = _scroll_pos(144.0, cy, lbl.size)
	lbl.theme_type_variation = &"BodyLabelThin"
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(lbl)
	return lbl


static func _scroll_pos(cx: float, cy: float, tex_size: Vector2) -> Vector2:
	return Vector2(cx, CLIP_H - cy) - tex_size * 0.5


static func _tex(res_path: String) -> TextureRect:
	var t := TextureRect.new()
	t.texture = load(res_path) as Texture2D
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	if t.texture != null:
		t.size = TexDisplaySize.display_size(res_path)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


static func _scale9(res_path: String, size: Vector2, cap: Rect2) -> NinePatchRect:
	var n := NinePatchRect.new()
	n.texture = load(res_path) as Texture2D
	n.patch_margin_left = int(cap.position.x)
	n.patch_margin_top = int(cap.position.y)
	if n.texture != null:
		n.patch_margin_right = int(n.texture.get_width() - cap.position.x - cap.size.x)
		n.patch_margin_bottom = int(n.texture.get_height() - cap.position.y - cap.size.y)
	n.custom_minimum_size = size
	n.size = size
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return n


static func _button(normal: String, pressed: String, cx: float, cy: float) -> TextureButton:
	var btn := TextureButton.new()
	btn.texture_normal = load(RES_DIR + normal) as Texture2D
	btn.texture_pressed = load(RES_DIR + pressed) as Texture2D
	btn.ignore_texture_size = true
	var sz: Vector2 = TexDisplaySize.display_size(RES_DIR + normal) if btn.texture_normal != null else Vector2(80.0, 32.0)
	btn.size = sz
	btn.position = _scroll_pos(cx, cy, sz)
	return btn


static func _center_label(text: String, btn: TextureButton) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.size = btn.size
	lbl.position = Vector2.ZERO
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.theme_type_variation = &"BodyLabel"
	btn.add_child(lbl)
	return lbl


static func _display_name(key: String) -> String:
	match key:
		"bronze": return "青铜酒馆"
		"gold": return "黄金酒馆"
		"magic": return "魂匣"
		_: return key
