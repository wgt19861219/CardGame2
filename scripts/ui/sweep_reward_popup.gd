class_name SweepRewardPopup
extends PopWindow

## 扫荡战利品弹窗（照源 stagedetail.lua repeatRewardWindow :1946-2521）。
## 两件套：scenes/ui/sweep_reward_popup_content.tscn 骨架（FrameBg/TitleBg/TitleLabel/
## ScrollHost/CloseBtn）+ 本类列表构建与交错动画（每组"第N战"EXP/金币/物品行，末组
## "额外奖励"，尾标光效，close 动画完才显示——源 createLootAnim 链）。
## 受控裁剪（源对应物核查记录，2026-09-04）：点物品不弹详情卡（源 equipableList
## 项目无对应物）；尾标图 stagedetail_raid_title.png 源项目与本项目双缺（源实机同
## 不可见），仅保留 lettherebelight 光效；关闭时 playerLevelup 公告不补（本项目
## add_team_exp→check_unlocks 已有功能解锁公告链）；源 draglist 换 ScrollContainer。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/sweep_reward_popup_content.tscn")

const CS: float = 1.28125
const UI_DIR: String = "res://assets/ui/alpha/HVGA/"
const SUBTITLE_BG_RES: String = UI_DIR + "stagedetail/stagedetail_raid_subtitle_bg.png"
const ITEM_BG_RES: String = UI_DIR + "stagedetail/stagedetail_raid_item_bg.png"
const GOLD_ICON_RES: String = UI_DIR + "goldicon_small.png"
const LIGHT_RES: String = UI_DIR + "lettherebelight.png"
const LIGHT_TEX_PX: float = 385.0       # lettherebelight.png PIL 实测 385×385
# 显示尺寸（像素÷CS，源无 TextureConfig 条目/fix_wh）
const SUBTITLE_BG_SIZE: Vector2 = Vector2(533.0 / CS, 44.0 / CS)
const ITEM_BG_SIZE: Vector2 = Vector2(540.0 / CS, 98.0 / CS)
const GOLD_ICON_SIZE: Vector2 = Vector2(43.0 / CS, 40.0 / CS)
const LIGHT_SCALE: float = 0.8 / CS            # 源 createSprite px÷CS × setScale(0.8)（:2015）
# 列表纵向步进（源 createLoot lh 累计值 = godot 列表层 y 坐标）
const LIST_X_CENTER: float = 400.0
const LIST_W: float = 400.0
const LH_TITLE: float = 35.0          # 组标题后（源 lh+35）
const LH_EXP_ROW: float = 55.0        # EXP/金币行后（源 lh+55，非末组）
const LH_LAST_GROUP_HEAD: float = 20.0  # 末组 subtitle 前（源 :2038-2040 lh+20，拉开与上一组间距）
const LH_LAST_HEAD: float = 25.0      # 末组标题后（源 lh+25，无 EXP 行）
const ROW_STEP: float = 90.0          # 物品行高
const ICON_COL_X0: float = 250.0      # 源 250+75*((i-1)%5)
const ICON_COL_STEP: float = 75.0
const ICONS_PER_ROW: int = 5
const LH_GROUP_TAIL: float = 70.0     # 源 lh + 90*rows + 70
const ITEM_BG_Y_TRIM: float = 2.0     # 源 iconBg y +2（cocos 上修）→ godot y-2
const END_TAG_PAD: float = 30.0       # 源 endTag lh+30
const LIST_BOTTOM_PAD: float = 60.0
# EXP/金币行元素（源 :2089-2121，y=行中心）
const EXP_TITLE_X: float = 270.0
const EXP_VALUE_X: float = 305.0      # anchor(0,0.5) 左中
const GOLD_ICON_X: float = 432.0
const MONEY_TEXT_X: float = 456.0     # anchor(0,0.5) 左中
const EXP_VALUE_W: float = 120.0
const MONEY_TEXT_W: float = 130.0
const EMPTY_TEXT_X: float = 220.0     # 空掉落文案 anchor(0,0.5)（源 :2153-2161）
const EMPTY_TEXT_W: float = 360.0
# 文字（源字号/色：组标题 20 白；EXP:/:    N 18 #F1C171；exp 值 18 #D2C0A2；空掉落 20 #F1C171）
const FONT_TITLE: int = 20
const FONT_ROW: int = 18
const LABEL_H_TITLE: float = 28.0
const LABEL_H_ROW: float = 26.0
const C_GOLD_TEXT: Color = Color(241.0 / 255.0, 193.0 / 255.0, 113.0 / 255.0)
const C_EXP_TEXT: Color = Color(210.0 / 255.0, 192.0 / 255.0, 162.0 / 255.0)
const TITLE_W: float = 200.0
# 动画（源 playTitleAnim/playNodeAnim/playLootAnim 时值）
const TITLE_SCALE_FROM: float = 2.0
const NODE_SCALE_FROM: float = 1.5
const ANIM_DUR: float = 0.2
const FIRST_DELAY: float = 0.5
const NODE_DELAY: float = 0.1
const TAIL_DELAY: float = 0.2
const LIGHT_ROT_DUR: float = 5.0      # 源 CCRotateBy(5, 360) 循环

var cm: Variant = null
var _loot_list: Array = []
var _skip_anim: bool = false
var _anim_done: bool = false
var _content: Control = null
var _close_btn: TextureButton = null
var _title_label: Label = null
var _scroll_wrap: Control = null
var _list_layer: Control = null
var _end_light: Sprite2D = null
var _groups: Array[Dictionary] = []   # 每组 {header: Array（即时可见）, reveal: Array（交错动画）}


func setup_popup(loot_list: Array, p_cm: Variant, p_skip_anim: bool = false) -> void:
	_loot_list = loot_list
	cm = p_cm
	_skip_anim = p_skip_anim
	setup()
	_build_content()
	register_on_enter(play_scale_in)
	register_on_enter(_play)


func _build_content() -> void:
	_content = CONTENT_SCENE.instantiate() as Control
	container.add_child(_content)
	_close_btn = _content.get_node("%CloseBtn") as TextureButton
	_close_btn.pressed.connect(_on_close_pressed)
	_title_label = _content.get_node("%TitleLabel") as Label
	_title_label.text = _lstr("PRIVILEGE.FARM", "扫荡")
	_title_label.visible = false   # 弹入后 playTitleAnim 闪现（源 :2451-2466）
	var host: ScrollContainer = _content.get_node("%ScrollHost") as ScrollContainer
	# 双层：wrap 直挂 ScrollHost（minsize 驱动滚动范围；ScrollContainer 重排直接子层
	# position，实测 minsize 变化即归零——单层平移不可行），_list_layer 挂 wrap 自由平移。
	_scroll_wrap = Control.new()
	_scroll_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(_scroll_wrap)
	_list_layer = Control.new()
	_list_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 坐标系换算（坐标系三坑①，2026-09-05 居中根修）：源 draglist listLayer 挂全屏原点，
	# 内容 x 是全屏场景坐标（400=cliprect 中心）；ScrollHost 局部原点在 cliprect 左缘
	# （全屏 x=200），列表层负向平移抵消原点，源坐标直接生效、以滚动区中心居中。
	_list_layer.position = Vector2(-host.offset_left, 0.0)
	_scroll_wrap.add_child(_list_layer)
	_build_all_groups()


# 全组静态构建（节点初隐藏，出现时机交 _play 照源逐组推进；skip 分支一次全显）。
func _build_all_groups() -> void:
	var lh: float = 0.0
	var total: int = _loot_list.size()
	for k in range(1, total + 1):
		lh = _create_group(k, total, lh)
	var end_y: float = _create_end_tag(lh + END_TAG_PAD)
	_scroll_wrap.custom_minimum_size = Vector2(LIST_W, end_y + LIST_BOTTOM_PAD)


# 建第 k 组（源 createLoot:2042-2184），返组后 lh。
func _create_group(k: int, total: int, lh: float) -> float:
	var g: Dictionary = _loot_list[k - 1]
	var is_last: bool = k == total
	var header: Array = []
	var reveal: Array = []
	if is_last:
		lh += LH_LAST_GROUP_HEAD
	lh = _add_subtitle(k, is_last, lh, header)
	if is_last:
		lh += LH_LAST_HEAD
	else:
		_add_exp_row(g, lh, header)
		lh += LH_EXP_ROW
	var loots: Array = g.get("loots", [])
	var rows: int = int(ceil(float(loots.size()) / float(ICONS_PER_ROW)))
	var bg_rows: int = maxi(rows, 1)   # 源 0 掉落也摆 1 个空底板
	for r in range(bg_rows):
		reveal.append(_add_item_bg(lh + ROW_STEP * float(r) - ITEM_BG_Y_TRIM))
	for i in loots.size():
		var loot: Dictionary = loots[i]
		var col: float = float(i % ICONS_PER_ROW)
		var row: float = floor(float(i) / float(ICONS_PER_ROW))
		var icon: Control = ReadequipIcon.create_icon(int(loot.get("id", 0)), int(loot.get("amount", 1)), cm)
		icon.position = Vector2(ICON_COL_X0 + ICON_COL_STEP * col, lh + ROW_STEP * row) - icon.size * 0.5
		_list_layer.add_child(icon)
		reveal.append(icon)
	if loots.is_empty():
		reveal.append(_add_empty_label(lh - ITEM_BG_Y_TRIM))
	for n in header:
		(n as Control).visible = false
	for n in reveal:
		(n as Control).visible = false
	lh += ROW_STEP * float(maxi(rows - 1, 0)) + LH_GROUP_TAIL
	_groups.append({"header": header, "reveal": reveal})
	return lh


func _add_subtitle(k: int, is_last: bool, y: float, header: Array) -> float:
	var bg := _tex_rect(SUBTITLE_BG_RES, SUBTITLE_BG_SIZE)
	bg.position = Vector2(LIST_X_CENTER, y) - SUBTITLE_BG_SIZE * 0.5
	_list_layer.add_child(bg)
	var lbl := Label.new()
	if is_last:
		lbl.text = _lstr("STAGEDETAIL.EXTRA_BONUS", "额外奖励")
	else:
		lbl.text = _lstr("STAGEDETAIL.THE__D_BATTLE", "第%d战") % k
	lbl.add_theme_font_size_override("font_size", FONT_TITLE)
	lbl.size = Vector2(TITLE_W, LABEL_H_TITLE)
	lbl.position = Vector2(LIST_X_CENTER - TITLE_W * 0.5, y - LABEL_H_TITLE * 0.5)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list_layer.add_child(lbl)
	header.append(bg)
	header.append(lbl)
	return y + LH_TITLE


# EXP/金币行（源 :2089-2121，非末组）。
func _add_exp_row(g: Dictionary, y: float, header: Array) -> void:
	var exp_title := _row_label("EXP:", FONT_ROW, C_GOLD_TEXT, false)
	exp_title.position = Vector2(EXP_TITLE_X - TITLE_W * 0.5, y - LABEL_H_ROW * 0.5)
	var exp_value := _row_label(str(int(g.get("exp", 0))), FONT_ROW, C_EXP_TEXT, true)
	exp_value.position = Vector2(EXP_VALUE_X, y - LABEL_H_ROW * 0.5)
	exp_value.size = Vector2(EXP_VALUE_W, LABEL_H_ROW)
	var gold_icon := _tex_rect(GOLD_ICON_RES, GOLD_ICON_SIZE)
	gold_icon.position = Vector2(GOLD_ICON_X, y) - GOLD_ICON_SIZE * 0.5
	var money := _row_label(":    " + str(int(g.get("money", 0))), FONT_ROW, C_GOLD_TEXT, true)
	money.position = Vector2(MONEY_TEXT_X, y - LABEL_H_ROW * 0.5)
	money.size = Vector2(MONEY_TEXT_W, LABEL_H_ROW)
	for n in [exp_title, exp_value, gold_icon, money]:
		_list_layer.add_child(n)
		header.append(n)


func _add_item_bg(y: float) -> TextureRect:
	var bg := _tex_rect(ITEM_BG_RES, ITEM_BG_SIZE)
	bg.position = Vector2(LIST_X_CENTER, y) - ITEM_BG_SIZE * 0.5
	_list_layer.add_child(bg)
	return bg


func _add_empty_label(y: float) -> Label:
	var lbl := _row_label(_lstr("STAGEDETAIL.NO_ITEM_DROPPED_IN_THIS_RAID", "此次扫荡未获得物品"), FONT_TITLE, C_GOLD_TEXT, true)
	lbl.position = Vector2(EMPTY_TEXT_X, y - LABEL_H_TITLE * 0.5)
	lbl.size = Vector2(EMPTY_TEXT_W, LABEL_H_TITLE)
	_list_layer.add_child(lbl)
	return lbl


# 尾标（源 createEndTag:1996-2040）：light 光效旋转；raid_title 贴图双端缺（受控裁剪）。返尾标后 y。
func _create_end_tag(y: float) -> float:
	_end_light = Sprite2D.new()
	_end_light.texture = _load_tex(LIGHT_RES)
	_end_light.scale = Vector2(LIGHT_SCALE, LIGHT_SCALE)
	_end_light.centered = true
	_end_light.position = Vector2(LIST_X_CENTER, y)
	_end_light.visible = false
	_list_layer.add_child(_end_light)
	return y + LIGHT_TEX_PX * LIGHT_SCALE   # 光效显示高 = 像素÷CS×0.8（LIGHT_SCALE 已含 ÷CS）


# 动画总控（源 show→createListLayer→createLootAnim(1) 链：第1..N-1 组逐组 → 尾标 → 末组 → close）。
func _play() -> void:
	if _skip_anim:
		_finish_all()
		return
	_title_label.visible = true
	_title_label.pivot_offset = _title_label.size * 0.5
	_title_label.scale = Vector2(TITLE_SCALE_FROM, TITLE_SCALE_FROM)
	var tw: Tween = create_tween()
	tw.set_trans(Tween.TRANS_BACK)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(_title_label, "scale", Vector2.ONE, ANIM_DUR)
	await tw.finished
	var total: int = _loot_list.size()
	for k in range(1, total + 1):
		if k == total:
			await _reveal_end_tag()
		_show_header(k)
		await _reveal_nodes(k)
	_anim_done = true
	_close_btn.visible = true


func _finish_all() -> void:
	for g in _groups:
		for n in g.get("header", []) as Array:
			(n as Control).visible = true
		for n in g.get("reveal", []) as Array:
			(n as Control).visible = true
	_title_label.visible = true
	_end_light.visible = true
	_start_light_rotation()
	_anim_done = true
	_close_btn.visible = true


func _show_header(k: int) -> void:
	for n in _groups[k - 1].get("header", []) as Array:
		(n as Control).visible = true


# 逐节点交错闪现（源 playLootAnim/playNodeAnim：首延 0.5s + 0.1s/节点，delay 到点才可见再 1.5→1 BackOut）。
func _reveal_nodes(k: int) -> void:
	var nodes: Array = _groups[k - 1].get("reveal", [])
	for i in nodes.size():
		var node: Control = nodes[i]
		node.pivot_offset = node.size * 0.5
		node.scale = Vector2(NODE_SCALE_FROM, NODE_SCALE_FROM)
		var tw: Tween = create_tween()
		tw.tween_interval(FIRST_DELAY + NODE_DELAY * float(i))
		tw.tween_callback(func() -> void: node.visible = true)
		tw.tween_property(node, "scale", Vector2.ONE, ANIM_DUR).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var total: float = FIRST_DELAY + NODE_DELAY * float(maxi(nodes.size() - 1, 0)) + ANIM_DUR + TAIL_DELAY
	await get_tree().create_timer(total).timeout


# 尾标（源 createEndTag：0.5s 后显示 + 光效旋转）。
func _reveal_end_tag() -> void:
	_end_light.scale = Vector2(LIGHT_SCALE * NODE_SCALE_FROM, LIGHT_SCALE * NODE_SCALE_FROM)
	var tw: Tween = create_tween()
	tw.tween_interval(FIRST_DELAY)
	tw.tween_callback(func() -> void: _end_light.visible = true)
	tw.tween_property(_end_light, "scale", Vector2(LIGHT_SCALE, LIGHT_SCALE), ANIM_DUR).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_start_light_rotation()
	await get_tree().create_timer(FIRST_DELAY + ANIM_DUR).timeout


func _start_light_rotation() -> void:
	if _end_light == null:
		return
	var tw: Tween = create_tween().set_loops()
	tw.tween_property(_end_light, "rotation", TAU, LIGHT_ROT_DUR).from(0.0)


# 动画未完不响应关闭（源 doMainLayerTouch endPlayLootAnim 前吞全部触摸）。
func _on_close_pressed() -> void:
	if not _anim_done:
		return
	remove_window()


func _on_shade_clicked(event: InputEvent) -> void:
	if not _anim_done:
		return
	super(event)


func _row_label(text: String, font_size: int, color: Color, left_align: bool) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.size = Vector2(TITLE_W, LABEL_H_ROW)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if not left_align:
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl


# 贴图节点工厂：TextureRect 默认 EXPAND_KEEP_SIZE 以纹理原始像素为最小尺寸，会把
# size 顶回原像素、÷CS 缩小失效（2026-09-05 居中根修时一并发现，bg/图标偏大 1.28×）。
# 先 IGNORE_SIZE+SCALE 再设 size（顺序反了 size 已被顶开不会回缩），贴图拉伸到设计尺寸。
static func _tex_rect(res_path: String, sz: Vector2) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = _load_tex(res_path)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.size = sz
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


func _lstr(key: String, fallback: String) -> String:
	var s: String = String(cm.get_lstr(key))
	return s if s != key else fallback


static func _load_tex(res_path: String) -> Texture2D:
	if ResourceLoader.exists(res_path):
		return load(res_path) as Texture2D
	return null
