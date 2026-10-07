class_name PopTavernThousand
extends PopWindow

## 魂匣百抽三选一弹窗（View 层纯代码控件，2026-10-07 自创功能，源无对应 UI；
## 纯代码先例 = confirm_dialog）。百抽已免费 roll 3 组结果，本窗 3 页签展示，玩家
## "选定本组"后 chosen 信号交宿主结算入包，其余作废；"重选"发 reroll_requested 由
## 宿主重 roll 后 update_groups 回填（免费、不关窗）。无点外关闭/无关闭 X——必须选定。
## 展示样式照抽卡效果（2026-10-07 用户拍板）：magic 开箱 FCA + 圆阵呼吸（复用
## PopTavernLootMagic）+ 聚合图标网格逐个弹出（TRANS_BACK 连弹）+ 品质旋转光
## （照 PopTavernLoot._maybe_play_burst 口径：英雄=橙光 / 魂石 quality>=ExRank=分色光）。
## 千抽→百抽（2026-10-07 同日再拍板）：千抽 102 格连弹+102 循环光效 tween 真机过载
## 卡顿，减量至 100 抽（聚合 ~40 格）根治。

signal chosen(index: int)
signal reroll_requested()

const BG_RES: String = "res://assets/ui/alpha/HVGA/equip_detail_bg.png"
const BTN_RES: String = "res://assets/ui/alpha/HVGA/tavern_button_1.png"
const BTN_PRESSED_RES: String = "res://assets/ui/alpha/HVGA/tavern_button_2.png"
const HERO_ID_MAX: int = 100
# 弹窗面板：equip_detail_bg 827×535 ÷CS = 645×417，屏幕 800×480 居中
const PANEL_SIZE: Vector2 = Vector2(645.0, 417.0)
const SCREEN_SIZE: Vector2 = Vector2(800.0, 480.0)
const TITLE_TEXT: String = "魔幻魂匣 · 百抽三选一"
const SUB_TEXT: String = "三组结果各 100 抽，选定一组获得，其余作废"
const CHOOSE_TEXT: String = "选定本组"
const REROLL_TEXT: String = "重选"
const TOTAL_FMT: String = "本组产出共 %d 件"
const TAB_LABELS: Array[String] = ["结果一", "结果二", "结果三"]
const TITLE_FONT: int = 22
const SUB_FONT: int = 13
const TOTAL_FONT: int = 14
const TITLE_TOP: float = 14.0
const SUB_TOP: float = 46.0
const TABS_TOP: float = 70.0
const LIST_TOP: float = 128.0
const LIST_BOTTOM: float = 338.0
const TOTAL_TOP: float = 340.0
const CHOOSE_BOTTOM: float = 417.0
# 两底钮成组水平居中（选定左+重选右，同为 tavern_button 尺寸，间隔同页签量级；
# 2026-10-07 用户反馈单钮居中+重选右挂致整组偏右 ~72px → 改组宽居中）
const CHOOSE_GAP: float = 14.0
# tavern_button 系 166×63 ÷CS = 129.6×49.2（tscn 同款按钮显示尺寸）
const BTN_SHOW_SIZE: Vector2 = Vector2(129.56, 49.17)
const TAB_GAP: float = 14.0
const TAB_DIM_COLOR: Color = Color(1.0, 1.0, 1.0, 0.55)
const STROKE_COLOR: Color = Color.BLACK
const STROKE_SIZE: int = 2
# ---- 抽卡效果（照 PopTavernLoot 常量口径）----
# 图标网格：create_icon 显示 73.4×74.2；7 列（内容宽 645-2×49≈547 / 78）+ 滚动看全
const GRID_COLS: int = 7
const GRID_SIDE_MARGIN: float = 49.0
const GRID_H_SEP: int = 4
const GRID_V_SEP: int = 2
const GRID_TOP: float = 132.0
# 连弹：~40 个 icon 快速逐个弹出（TRANS_BACK EASE_OUT，源逐飞 0.2s/个在数十量级过慢）
const POP_SEC: float = 0.14
const POP_INTERVAL_SEC: float = 0.035
# 品质光效（照 PopTavernLoot：LIGHT_RES_DIR 色系 / 5s 一圈 / 英雄恒橙光）
const LIGHT_RES_DIR: String = "res://assets/ui/alpha/HVGA/tavern_get_item_bg_light_"
const LIGHT_QUALITY_COLOR: Array[String] = ["blue", "blue", "blue", "purple", "purple", "orange"]
const BURST_ROTATE_SEC: float = 5.0
const FULL_CIRCLE_DEG: float = 360.0
const HERO_BURST_QUALITY: int = 6
const EX_BOX_KEY: String = "magic"
# 光贴图原始 ~200px：网格密度下缩 0.45（~90px）叠图标上层（z=+2），负 z 衬底在紧排网格被邻格盖死
const BURST_LIGHT_SCALE: float = 0.45
const BURST_LIGHT_Z: int = 2
const BURST_LIGHT_ALPHA: float = 0.85
# magic 开箱 FCA（照 PopTavernLoot.BOX_FCA_MAP["magic"]，zip 双试 .ani/.abc）
const BOX_FCA_RES: String = "effect/eff_UI_tavern_open_magicsoul"
const ANIM_BASE: String = "res://assets/anim_frames/"
const BOX_FCA_LEAD_SEC: float = 0.3

var _cm: Variant = null
var _groups: Array = []
var _current: int = 0
var _tab_btns: Array[TextureButton] = []
var _grid: GridContainer = null
var _loot_host: Control = null      # 抽卡效果层（圆阵/FCA；PopTavernLootMagic 依赖此挂点）
var _total_label: Label = null
var _choose_btn: TextureButton = null
var _reroll_btn: TextureButton = null
var _anim_gen: int = 0              # 连弹代际（页签切换/重入时旧动画链自杀）


func setup_pick(groups: Array, p_cm: Variant) -> void:
	_groups = groups
	_cm = p_cm
	shade_close_on_click = false
	setup()
	_build_content()


func _build_content() -> void:
	var panel := Control.new()
	panel.size = PANEL_SIZE
	panel.position = (SCREEN_SIZE - PANEL_SIZE) * 0.5
	container.add_child(panel)
	var bg := TextureRect.new()
	bg.texture = load(BG_RES) as Texture2D
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.size = PANEL_SIZE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(bg)
	_loot_host = Control.new()
	_loot_host.size = PANEL_SIZE
	_loot_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_loot_host)
	_add_centered_label(TITLE_TEXT, TITLE_FONT, TITLE_TOP, panel)
	_add_centered_label(SUB_TEXT, SUB_FONT, SUB_TOP, panel)
	_build_tabs(panel)
	_build_grid(panel)
	_total_label = _add_centered_label("", TOTAL_FONT, TOTAL_TOP, panel)
	var group_x: float = (PANEL_SIZE.x - (BTN_SHOW_SIZE.x * 2.0 + CHOOSE_GAP)) * 0.5
	_choose_btn = _make_button(CHOOSE_TEXT)
	_choose_btn.position = Vector2(group_x, CHOOSE_BOTTOM - BTN_SHOW_SIZE.y)
	_choose_btn.pressed.connect(_on_choose_pressed)
	panel.add_child(_choose_btn)
	_reroll_btn = _make_button(REROLL_TEXT)
	_reroll_btn.position = Vector2(group_x + BTN_SHOW_SIZE.x + CHOOSE_GAP,
		CHOOSE_BOTTOM - BTN_SHOW_SIZE.y)
	_reroll_btn.pressed.connect(_on_reroll_pressed)
	panel.add_child(_reroll_btn)
	_show_group(0)


# PopTavernLootMagic 圆阵定位钩子（panel._g(cocos)）：百抽面板局部坐标，恒返面板中心。
func _g(_pos: Vector2) -> Vector2:
	return PANEL_SIZE * 0.5


func show_window(parent: Node) -> void:
	super.show_window(parent)
	_after_show()


# 入场抽卡效果：magic 开箱 FCA + 圆阵呼吸（树内才可 create_tween/FCA）+ 图标连弹。
# 无树守卫：宿主无 parent 时 super.show_window 静默跳过，面板未进树不可建动画。
func _after_show() -> void:
	if not is_inside_tree():
		return
	PopTavernLootMagic.create_matrix_container_anim(self)
	_play_box_fca()
	await get_tree().create_timer(BOX_FCA_LEAD_SEC).timeout
	if not is_inside_tree():
		return
	_pop_icons_async()


# 居中横排文字 Label（顶部 y 定位，宽度全幅）。
func _add_centered_label(text: String, font: int, top: float, parent: Control) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_color_override("font_outline_color", STROKE_COLOR)
	lbl.add_theme_constant_override("outline_size", STROKE_SIZE)
	lbl.position = Vector2(0.0, top)
	lbl.size = Vector2(PANEL_SIZE.x, BTN_SHOW_SIZE.y * 0.5)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(lbl)
	return lbl


func _build_tabs(panel: Control) -> void:
	var host := HBoxContainer.new()
	host.add_theme_constant_override("separation", int(TAB_GAP))
	var tabs_w: float = TAB_LABELS.size() * BTN_SHOW_SIZE.x + (TAB_LABELS.size() - 1) * TAB_GAP
	host.position = Vector2((PANEL_SIZE.x - tabs_w) * 0.5, TABS_TOP)
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in TAB_LABELS.size():
		var tab := _make_button(TAB_LABELS[i])
		tab.pressed.connect(_show_group.bind(i))
		host.add_child(tab)
		_tab_btns.append(tab)
	panel.add_child(host)


# 聚合图标网格（全英雄池百抽聚合 ~40 条，ScrollContainer 垂直滚动看全；icon 带 amount 角标）。
func _build_grid(panel: Control) -> void:
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(GRID_SIDE_MARGIN, GRID_TOP)
	scroll.size = Vector2(PANEL_SIZE.x - GRID_SIDE_MARGIN * 2.0, LIST_BOTTOM - GRID_TOP)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = GRID_COLS
	_grid.add_theme_constant_override("h_separation", GRID_H_SEP)
	_grid.add_theme_constant_override("v_separation", GRID_V_SEP)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_grid)


func _make_button(text: String) -> TextureButton:
	var btn := TextureButton.new()
	btn.texture_normal = load(BTN_RES) as Texture2D
	btn.texture_pressed = load(BTN_PRESSED_RES) as Texture2D
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_SCALE
	btn.custom_minimum_size = BTN_SHOW_SIZE
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_color_override("font_outline_color", STROKE_COLOR)
	lbl.add_theme_constant_override("outline_size", STROKE_SIZE)
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(lbl)
	return btn


# 切页签：高亮当前 + 重填聚合图标网格（弹出动画随其后播）+ 总计。
func _show_group(index: int) -> void:
	_anim_gen += 1   # 旧连弹链自杀
	_current = clampi(index, 0, _groups.size() - 1)
	for i in _tab_btns.size():
		_tab_btns[i].modulate = Color.WHITE if i == _current else TAB_DIM_COLOR
	for c in _grid.get_children():
		c.queue_free()
	var rows: Array = aggregate_loots(_groups[_current])
	for row in rows:
		_grid.add_child(ReadequipIcon.create_icon(int(row["id"]), int(row["amount"]), _cm))
	_total_label.text = TOTAL_FMT % _group_total(_groups[_current])
	if is_inside_tree():
		_pop_icons_async()


# 图标逐个弹出（抽卡感核心）：scale 0→1 TRANS_BACK + 品质光效随弹出完成回调
# （_play_burst 有 scale==ZERO 守卫，须在 scale 归 1 后触发），POP_INTERVAL 快速连弹。
# 释放竞态防护（2026-10-07 实机 --debug 断点根修）：重选/切页签 queue_free 旧 icon 当帧
# 仍混在 get_children()，旧/新连弹链 await 恢复后类型化赋值会先于 is_instance_valid
# 守卫撞 freed 实例（Trying to assign invalid previously freed instance）——
# ①源头只收非 queue_free 子节点；②先 Variant 暂存过检再 as 强转；③tween 挂 icon 属主
# （icon 释放 tween 自动失效，杜绝 CallbackTweener 带 freed bind 参数触发）。
func _pop_icons_async() -> void:
	_anim_gen += 1
	var gen: int = _anim_gen
	var icons: Array = []
	for c in _grid.get_children():
		if not c.is_queued_for_deletion():
			icons.append(c)
	for i in icons.size():
		if gen != _anim_gen or not is_inside_tree():
			return   # 页签已切/窗已关，旧链自杀
		var icon_v: Variant = icons[i]
		if not is_instance_valid(icon_v) or icon_v.is_queued_for_deletion():
			continue
		var icon := icon_v as Control
		if icon == null:
			continue
		icon.scale = Vector2.ZERO
		var tw := icon.create_tween()
		tw.tween_property(icon, "scale", Vector2.ONE, POP_SEC) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_callback(_maybe_burst.bind(icon))
		await get_tree().create_timer(POP_INTERVAL_SEC).timeout


# 品质旋转光（照 PopTavernLoot._maybe_play_burst：英雄恒橙光；魂石 quality>=ExRank 分色）。
# 差异：PopTavernLoot 圆阵稀疏布局用 z=-3 光衬物品下方；百抽网格紧排（sep 4px）负 z 被
# 相邻图标整片盖住（实机像素检测零光芒）→ 光缩小 0.45 叠 z=+2 图标上层，网格密度下可见。
func _maybe_burst(icon: Control) -> void:
	if not is_instance_valid(icon):
		return
	var quality: int = int(icon.get_meta("quality", 0))
	if bool(icon.get_meta("is_hero", false)):
		_play_burst(icon, HERO_BURST_QUALITY)
		return
	if quality >= TavernData.get_ex_rank(EX_BOX_KEY, _cm):
		_play_burst(icon, quality)


func _play_burst(icon: Control, quality: int) -> void:
	var color_idx: int = clampi(quality - 1, 0, LIGHT_QUALITY_COLOR.size() - 1)
	var res: String = LIGHT_RES_DIR + LIGHT_QUALITY_COLOR[color_idx] + ".png"
	if not ResourceLoader.exists(res) or icon.scale == Vector2.ZERO:
		return
	var light := Sprite2D.new()
	light.texture = load(res)
	light.centered = true
	light.position = icon.size * 0.5
	light.scale = Vector2.ONE * BURST_LIGHT_SCALE
	light.modulate.a = BURST_LIGHT_ALPHA   # 叠上层观感柔化（实机复验：满光致个别图标泛白糊化）
	light.z_index = BURST_LIGHT_Z
	icon.add_child(light)
	var tw := icon.create_tween().set_loops()
	tw.tween_property(light, "rotation", deg_to_rad(FULL_CIRCLE_DEG), BURST_ROTATE_SEC)


# magic 开箱 FCA + 音效（照 PopTavernLoot._play_box_anim magic 分支：不缩放、播首个动作）。
func _play_box_fca() -> void:
	var ani_path: String = ANIM_BASE + BOX_FCA_RES + ".ani"
	var abc_path: String = ANIM_BASE + BOX_FCA_RES + ".abc"
	var zip_path: String = ani_path if FileAccess.file_exists(ani_path) else abc_path
	if not FileAccess.file_exists(zip_path):
		return
	var holder := Node2D.new()
	holder.position = _g(Vector2.ZERO)
	_loot_host.add_child(holder)
	var fca := FcaAnimation.new()
	holder.add_child(fca)
	var atlas := AtlasSprite.new()
	if atlas.load_atlas_from_ani(zip_path) and fca.load_from_ani(BOX_FCA_RES, atlas):
		var actions: PackedStringArray = fca.get_action_names()
		if actions.size() > 0:
			fca.play(actions[0], false)
			AudioPlayer.play_sfx("skill_upgrade_success_blue")


# 按 id 聚合 amount；英雄（id<100）行在前，其余按总量降序（玩家先看保底英雄再比魂石量）。
static func aggregate_loots(loots: Array) -> Array:
	var sums: Dictionary = {}
	for loot in loots:
		var lid: int = int(loot["id"])
		sums[lid] = int(sums.get(lid, 0)) + int(loot["amount"])
	var rows: Array = []
	for lid in sums:
		rows.append({"id": int(lid), "amount": int(sums[lid])})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_hero: bool = int(a["id"]) < HERO_ID_MAX
		var b_hero: bool = int(b["id"]) < HERO_ID_MAX
		if a_hero != b_hero:
			return a_hero
		return int(a["amount"]) > int(b["amount"]))
	return rows


static func _group_total(loots: Array) -> int:
	var total: int = 0
	for loot in loots:
		total += int(loot["amount"])
	return total


## 重选回填（宿主重 roll 后调用，2026-10-07 用户需求：不满意可免费重选）：
## 回第一组重播连弹+光效；圆阵/FCA 常驻层不重播（避免叠加）。
func update_groups(groups: Array) -> void:
	_groups = groups
	_show_group(0)


func _on_reroll_pressed() -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	reroll_requested.emit()


func _on_choose_pressed() -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	var idx: int = _current
	chosen.emit(idx)
	remove_window()
