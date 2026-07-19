class_name PopTavernLoot
extends PopWindow

## 抽卡产出弹窗（照源 poptavernloot.lua）。loots 聚合 → 逐个 icon 飞出动画。
## 动画照源 show(245) container scale 入场 / createLootAnim(462) icon 飞 bpos→loot 位 /
## destroy(259) container scale 退场。
## 待补：shadow 白光 FadeOut（:510）+ playBurst 光效旋转（:468）+ magic 分支 fade（:549-559）。
##
## Phase A 静态化（2026-07-18，照 hero_detail 范式）：双按钮（again/close）+ reward_label
## 进 pop_tavern_loot_content.tscn（位置/size 编辑器可视化）。loot icons / FCA / shadow / burst
## 保留 procedural 挂 %LootHost（动态数量 + 飞出/旋转动画）；cost_row 保留 procedural 挂
## %CostHost（cost_val 长度决定布局，源 :1015-1019 后处理右对齐 x=240）。

signal draw_again
# P2-GUT-2：入场 + 开箱 FCA 就位（box 阶段完成）
signal box_shown
# P2-GUT-2：所有 loot 飞出 + 品质光效加完（产出动画完成）
signal loot_anim_done

# 静态 panel 层子场景（位置/size 在 .tscn 可视化）。
const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/pop_tavern_loot_content.tscn")
const CONTENT_SCALE: float = 1.28125   # 源 hello.lua:311 setContentScaleFactor(1.28125)，cocos sprite 显示=纹理/CS（无 fix 时）
const GRID_ORIGIN: Vector2 = Vector2(190.0, 150.0)   # 源 getLootPos :417-422 十连布局起点
const GRID_CELL: Vector2 = Vector2(100.0, 105.0)     # 源 dx,dy
const GRID_COLS: int = 5                              # 源 :424 i%5
const SINGLE_POS: Vector2 = Vector2(400.0, 280.0)    # 源 单抽居中
# 源 :741-772 status==0 cost 行（消费展示）：cost_icon + cost 右对齐到 x=240（godot 320）。
const COST_ROW_RIGHT_X: float = 240.0   # 源 cost anchor(1,0.5) ccp(240,50)
const COST_ROW_Y: float = 50.0          # 源 cost/ccp(50)/cost_icon ccp(48)
const COST_ICON_RES_GOLD: String = "res://assets/ui/alpha/HVGA/task_gold_icon_2.png"
const COST_ICON_RES_RMB: String = "res://assets/ui/alpha/HVGA/task_rmb_icon_2.png"
const SINGLE_THRESHOLD: int = 1   # loot 种类 <= 此值用单抽布局
const BOX_ANIM_POS: Vector2 = Vector2(400.0, 240.0)   # 源 playBoxAnim bpos
# 源 :287-296 box_type → 开箱 FCA resource（magic .abc 格式本项目不支持，留待）
const BOX_FCA_MAP: Dictionary = {
	"bronze": "effect/eff_UI_tarven_open_chest",
	"silver": "effect/eff_UI_tarven_open_chest_silver",
	"gold": "effect/eff_UI_tarven_open_chest_gold",
}
const ANIM_BASE: String = "res://assets/anim_frames/"
# LSTR key（照源 poptavernloot.lua :662-674）。CHATCONFIG.SHOW_REWAD_BY_CHEST 源 zh-CN.lua 数据缺，
# 走中文 fallback（源 en-US "Successfully opened the treasure chest. "）。
const LSTR_DRAW_ONCE: StringName = &"POPTAVERNLOOT.DRAW_ONCE_AGAIN"   # 源 :662
const LSTR_DRAW_TEN: StringName = &"POPTAVERNLOOT.DRAW_10_AGAIN"      # 源 :664
const LSTR_CONFIRM: StringName = &"CHATCONFIG.CONFIRM"               # 源 :673 okTxt
const LSTR_OPEN_CHEST: StringName = &"CHATCONFIG.SHOW_REWAD_BY_CHEST" # 源 :674 dpText（源拼写 REWAD）
const FALLBACK_DRAW_ONCE: String = "再抽一次"
const FALLBACK_DRAW_TEN: String = "再抽十次"
const FALLBACK_CONFIRM: String = "确定"
const FALLBACK_OPEN_CHEST: String = "成功打开宝箱"   # 源 zh-CN.lua 缺 SHOW_REWAD 译文，走中文 fallback

# ---- 抽卡动画（照源 poptavernloot.lua show/createLootAnim/destroy）----
const SHOW_SEC: float = 0.2                        # 源 show CCScaleTo(0.2,1) EaseBackOut
const DESTROY_SEC: float = 0.2                     # 源 destroy CCScaleTo(0.2,0) EaseBackIn
const BOX_BPOS: Vector2 = Vector2(400.0, 240.0)    # 源 createLootAnim bpos :517（icon 起飞点）
const LOOT_ANIM_SEC: float = 0.2                   # 源 gap1 :538（飞出时长）
const LOOT_ROTATE_DEG: float = 720.0               # 源 CCRotateBy(gap1,720) :543
const BOX_FCA_LEAD_SEC: float = 0.3                # box FCA 开启后引领（简化：不等 FCA 完成）
# 源 createLootAnim shadow（:510-516）：非 magic icon 加白光 FadeOut（与飞出并行）。
const SHADOW_RES: String = "res://assets/ui/alpha/HVGA/tavern_get_item_bg_light_white.png"
const SHADOW_POS: Vector2 = Vector2(35.0, 35.0)    # 源 :512 ccp(35,35)（icon 内坐标，centered）
const SHADOW_FADE_SEC: float = 0.4                 # 源 :514 CCFadeOut(0.4)
# 源 playBurst（:468-489）：品质光效图旋转。quality 1-3 blue / 4-5 purple / 6 orange（源 light_res :469-476）。
const LIGHT_RES_DIR: String = "res://assets/ui/alpha/HVGA/tavern_get_item_bg_light_"
const LIGHT_QUALITY_COLOR: Array[String] = ["blue", "blue", "blue", "purple", "purple", "orange"]
const LIGHT_POS: Vector2 = Vector2(33.0, 35.0)     # 源 :483 ccp(33,35)
const BURST_ROTATE_SEC: float = 5.0                # 源 :486 CCRotateBy(5,360) RepeatForever
const HERO_BURST_QUALITY: int = 6                  # 源 :573 hero → playBurst(icon,6) 固定橙色
const FULL_CIRCLE_DEG: float = 360.0               # 源 :486 旋转一圈度数

var box_type: String = ""
var times: String = "one"   # 源 create :213 self.times = times（"one"/"ten"）
var cost_info: Dictionary = {}   # 源 :214 self.cost = addition.cost（{pay, number}），status==0 cost 行用
var _cm: Variant = null
var _content: Control = null       # .tscn instantiate 根（container 子）
var _loot_host: Control = null     # %LootHost：动态 loot icons / FCA 挂载
var _cost_host: Control = null     # %CostHost：cost_row procedural 挂载
var _loot_icons: Array[Control] = []
var _loot_targets: Array[Vector2] = []


# 源 cocos(800×480 左下) → Godot(960×640 左上):cx+80, 560-cy（同 battle_view_coords 标准）。
func _g(pos: Vector2) -> Vector2:
	return BattleViewCoords.to_godot(pos.x, pos.y)


# 源 create（:202-237）：loots + addition.cost + times。单机化 status 固定 0（非 EveryDayHappy 活动）。
func setup_loot(loots: Array, p_cm: Variant, p_box_type: String = "", p_times: String = "one", p_cost_info: Dictionary = {}) -> void:
	box_type = p_box_type
	times = p_times
	cost_info = p_cost_info
	_cm = p_cm
	setup()
	_build_content()
	_aggregate(loots, p_cm)
	_create_cost_row()


# Phase A：instantiate .tscn + 缓存 host + fill 双按钮文字（位置/纹理 .tscn 固化）+ 绑信号。
# 源 playButtonAnim（:656-1044）status==0 分支：tavern/tavern_press（tvText）+ ok/ok_press（okTxt）
# + reward_label（dpText 金黄 ccc3(231,206,19)）。
func _build_content() -> void:
	_content = CONTENT_SCENE.instantiate() as Control
	container.add_child(_content)
	_loot_host = _content.get_node("%LootHost") as Control
	_cost_host = _content.get_node("%CostHost") as Control
	# reward_label（源 :850-863 dpText；CHATCONFIG.SHOW_REWAD_BY_CHEST 源拼写 REWAD）
	var reward_lbl: Label = _content.get_node("%RewardLabel") as Label
	reward_lbl.text = _lstr_or(LSTR_OPEN_CHEST, FALLBACK_OPEN_CHEST)
	# again 按钮（源 :781 tavern_button_1 + tvText 金黄）
	var again_btn: TextureButton = _content.get_node("%AgainBtn") as TextureButton
	(again_btn.get_node("Label") as Label).text = _tv_text()
	again_btn.pressed.connect(_on_again)
	# close 按钮（源 :817 tavern_button_normal_1 + okTxt）
	var close_btn: TextureButton = _content.get_node("%CloseBtn") as TextureButton
	(close_btn.get_node("Label") as Label).text = _lstr_or(LSTR_CONFIRM, FALLBACK_CONFIRM)
	close_btn.pressed.connect(func() -> void:
		AudioPlayer.play_sfx("common_click_feedback")   # 源 tavern.clickCloseLoots（soundres.lua:292）
		remove_window())


# 聚合同 id（源 throwLoots :167-200 合并）→ icon 初始 scale0+bpos（源 createLootAnim :535-536 初始态）。
func _aggregate(loots: Array, p_cm: Variant) -> void:
	var agg: Dictionary = {}   # id → amount
	for loot in loots:
		var lid: int = int(loot["id"])
		agg[lid] = int(agg.get(lid, 0)) + int(loot["amount"])
	var is_single: bool = agg.size() <= SINGLE_THRESHOLD
	var idx: int = 0
	for lid in agg:
		var icon: Control = ReadequipIcon.create_icon(int(lid), int(agg[lid]), p_cm)
		icon.scale = Vector2.ZERO
		icon.position = _g(BOX_BPOS)
		_loot_host.add_child(icon)
		_loot_icons.append(icon)
		_loot_targets.append(_loot_pos(idx, is_single))
		idx += 1


func _loot_pos(index: int, is_single: bool) -> Vector2:
	if is_single:
		return _g(SINGLE_POS)
	var col: int = index % GRID_COLS
	var row: int = index / GRID_COLS
	return _g(Vector2(GRID_ORIGIN.x + GRID_CELL.x * col, GRID_ORIGIN.y + GRID_CELL.y * row))


# 源 playButtonAnim :741-772 status==0 cost 行：cost_bg + cost_icon + cost Label。
# 源 :1015-1019 后处理：cost_icon+cost 右对齐 x=240，cost_bg 居中包裹。简化：cost_icon+cost 紧贴右对齐。
# 位置依赖 cost_val 字符串长度 → 保留 procedural 挂 %CostHost。
func _create_cost_row() -> void:
	if cost_info.is_empty():
		return   # 单机化未传 cost（panel setup_loot 默认空）→ 不显消费行
	var pay: String = String(cost_info.get("pay", "Diamond"))
	var cost_val: int = int(cost_info.get("number", 0))
	var godot_right: Vector2 = _g(Vector2(COST_ROW_RIGHT_X, COST_ROW_Y))
	# cost Label 右对齐到 godot_right.x，size 估算（数字位数*12 + 8）
	var cost_str: String = str(cost_val)
	var cost_w: float = float(cost_str.length()) * 12.0 + 8.0
	var cost_lbl := Label.new()
	cost_lbl.text = cost_str
	cost_lbl.size = Vector2(cost_w, 20.0)
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cost_lbl.position = Vector2(godot_right.x - cost_w, godot_right.y - 10.0)
	cost_lbl.add_theme_color_override("font_color", Color.WHITE)
	cost_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	cost_lbl.add_theme_constant_override("outline_size", 1)
	cost_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cost_host.add_child(cost_lbl)
	# cost_icon 紧贴 cost 左侧（源 anchor 1,0.5）
	var icon_res: String = COST_ICON_RES_RMB if pay == "Diamond" else COST_ICON_RES_GOLD
	if not ResourceLoader.exists(icon_res):
		return
	var icon_tex: Texture2D = load(icon_res) as Texture2D
	var icon := TextureRect.new()
	icon.texture = icon_tex
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.size = TexDisplaySize.display_size(icon_res) if icon_tex != null else Vector2(20.0, 20.0)   # 源 poptavernloot:752-761 cost_icon t="Sprite" 无 fix
	if pay != "Gold":
		icon.scale = Vector2(1.2, 1.2)   # 源 :756 钻石 icon scale 1.2
	icon.position = Vector2(godot_right.x - cost_w - icon.size.x, godot_right.y - icon.size.y * 0.5)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cost_host.add_child(icon)


# 源 :661-668 tvText：times=="one"→DRAW_ONCE_AGAIN / "ten"→DRAW_10_AGAIN / magic 强制 once。
func _tv_text() -> String:
	if times == "ten" and box_type != "magic":
		return _lstr_or(LSTR_DRAW_TEN, FALLBACK_DRAW_TEN)
	return _lstr_or(LSTR_DRAW_ONCE, FALLBACK_DRAW_ONCE)


# cm.get_lstr 缺失（返 key 本身）→ fallback。
func _lstr_or(key: StringName, fallback: String) -> String:
	if _cm == null or not _cm.has_method("get_lstr"):
		return fallback
	var v: String = _cm.get_lstr(String(key))
	return v if v != String(key) else fallback


func _on_again() -> void:
	AudioPlayer.play_sfx("common_click_feedback")   # 源 tavern.clickTavernAgain（soundres.lua:293）
	draw_again.emit()
	remove_window()


# 源 show（245-257）：container scale 0→1（EaseBackOut）→ playBoxAnim → playLootAnim。
func show_window(parent: Node) -> void:
	super.show_window(parent)
	container.scale = Vector2.ZERO
	var tw: Tween = create_tween()
	tw.tween_property(container, "scale", Vector2.ONE, SHOW_SEC).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_after_show)


func _after_show() -> void:
	_play_box_anim()
	box_shown.emit()
	await get_tree().create_timer(BOX_FCA_LEAD_SEC).timeout
	_play_loot_anim(0)


# 源 playLootAnim：逐个 createLootAnim（index+1 链，:561 CallFunc 衔接）。
func _play_loot_anim(index: int) -> void:
	if index >= _loot_icons.size():
		loot_anim_done.emit()
		return
	if not is_inside_tree():
		return
	_fly_loot(index)
	await get_tree().create_timer(LOOT_ANIM_SEC).timeout
	_maybe_play_burst(index)   # 源 createLootAnim :561-639 CallFunc（飞行后品质光效判断）
	_play_loot_anim(index + 1)


# 源 createLootAnim 非 magic（534-548）：icon 从 bpos 飞到 loot 位 + scale0→1 + rotate720°（0.2s SineOut 并行）。
func _fly_loot(index: int) -> void:
	var icon: Control = _loot_icons[index]
	if box_type != "magic":
		_add_shadow(icon)   # 源 createLootAnim :510-516 非 magic 加白光（与飞行并行 FadeOut）
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(icon, "scale", Vector2.ONE, LOOT_ANIM_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(icon, "position", _loot_targets[index], LOOT_ANIM_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(icon, "rotation", deg_to_rad(LOOT_ROTATE_DEG), LOOT_ANIM_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


# 源 destroy（259-284）：container scale 1→0（EaseBackIn）→ cleanup。
func remove_window() -> void:
	if not is_inside_tree():
		_do_remove()
		return
	var tw: Tween = create_tween()
	tw.tween_property(container, "scale", Vector2.ZERO, DESTROY_SEC).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(_do_remove)


func _do_remove() -> void:
	super.remove_window()


# 开箱 FCA 动画（源 playBoxAnim :286）。先 add 节点（接入保证），再尝试 load/play。
func _play_box_anim() -> void:
	if not BOX_FCA_MAP.has(box_type):
		return
	var fca := FcaAnimation.new()
	fca.position = _g(BOX_ANIM_POS)
	_loot_host.add_child(fca)
	var resource: String = BOX_FCA_MAP[box_type]
	var ani_path: String = ANIM_BASE + resource + ".ani"
	if not ResourceLoader.exists(ani_path):
		return
	var atlas := AtlasSprite.new()
	if atlas.load_atlas_from_ani(ani_path) and fca.load_from_ani(resource, atlas):
		var actions: PackedStringArray = fca.get_action_names()
		if actions.size() > 0:
			fca.play(actions[0], false)
			AudioPlayer.play_sfx("skill_upgrade_success_blue")   # 源 tavern.openBoxAnim（soundres.lua:303）


# 源 createLootAnim :510-516 shadow：icon 加白光子节点 FadeOut（与飞出并行）。
func _add_shadow(icon: Control) -> void:
	if not ResourceLoader.exists(SHADOW_RES):
		return
	var shadow := Sprite2D.new()
	shadow.texture = load(SHADOW_RES)
	shadow.centered = true
	shadow.position = SHADOW_POS
	icon.add_child(shadow)
	icon.create_tween().tween_property(shadow, "modulate:a", 0.0, SHADOW_FADE_SEC)


# 源 createLootAnim :561-639 CallFunc 品质判断：hero→品质 6（:573）/ equip→quality>=ex_rank（:594/624）。
func _maybe_play_burst(index: int) -> void:
	if not is_inside_tree() or index >= _loot_icons.size():
		return
	var icon: Control = _loot_icons[index]
	if bool(icon.get_meta("is_hero", false)):
		_play_burst(icon, HERO_BURST_QUALITY)
		return
	var quality: int = int(icon.get_meta("quality", 0))
	if quality >= TavernData.get_ex_rank(box_type, _cm):
		_play_burst(icon, quality)


# 源 playBurst :468-489 light：品质光效图旋转 360°/5s（RepeatForever）。scale=1/icon.scale 抵消 icon 缩放。
# burst FCA（eff_UI_tavern_burst .abc）本项目无 .abc 支持 → 降级跳过（源 :477-481）。
func _play_burst(icon: Control, quality: int) -> void:
	var color_idx: int = clampi(quality - 1, 0, LIGHT_QUALITY_COLOR.size() - 1)
	var res: String = LIGHT_RES_DIR + LIGHT_QUALITY_COLOR[color_idx] + ".png"
	if not ResourceLoader.exists(res) or icon.scale == Vector2.ZERO:
		return
	var light := Sprite2D.new()
	light.texture = load(res)
	light.centered = true
	light.position = LIGHT_POS
	light.scale = Vector2.ONE / icon.scale   # 源 :485 抵消 icon scale 使光效大小恒定
	light.z_index = -3   # 源 addChild(icon,-3) icon 内容下层
	icon.add_child(light)
	var tw: Tween = icon.create_tween().set_loops()   # 源 CCRepeatForever
	tw.tween_property(light, "rotation", deg_to_rad(FULL_CIRCLE_DEG), BURST_ROTATE_SEC)
