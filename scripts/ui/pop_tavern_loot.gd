class_name PopTavernLoot
extends PopWindow

## destroy(259) container scale 退场。
## 待补：playBurst 光效旋转（:468）的 FCA 化（现为 Sprite2D 光效等价）。
##
## 批5 两件套（2026-08-18）：chrome 全量进 pop_tavern_loot_content.tscn（照源 readnode 声明序）——
## 双按钮（again/close）+ reward_label + 费用行三节点（CostBg/CostIcon/CostLabel，fill 定位）。
## loot icons / FCA / shadow / burst 保留 procedural 挂 %LootHost（动态数量 + 飞出/旋转动画）。
## starshop（box_type=stone_*）分支：源 :679-731 ok 居中、无再抽按钮；magic 分支 reward_label 隐藏。

signal draw_again
# P2-GUT-2：入场 + 开箱 FCA 就位（box 阶段完成）
signal box_shown
# P2-GUT-2：所有 loot 飞出 + 品质光效加完（产出动画完成）
signal loot_anim_done

# 静态 panel 层子场景（位置/size 在 .tscn 可视化）。
const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/pop_tavern_loot_content.tscn")
const CONTENT_SCALE: float = 1.28125
const GRID_ORIGIN: Vector2 = Vector2(190.0, 150.0)
const GRID_CELL: Vector2 = Vector2(100.0, 105.0)
const GRID_COLS: int = 5
const SINGLE_POS: Vector2 = Vector2(400.0, 280.0)
# 源 :770-772 cost Label anchor(1,0.5)@ccp(240,50)（右缘 240 / 垂直中心 50）
const COST_LABEL_POS: Vector2 = Vector2(240.0, 50.0)
# 源 :1019 cost_icon 中心 y=48（略高于 label 中心 50）
const COST_ICON_Y: float = 48.0
# 源 :1022 cost_bg 中心 y=50
const COST_BG_Y: float = 50.0
# 源 :687 starshop 分支 ok 居中 ccp(400,50)（本项目 box_type=stone_*）
const STARSHOP_OK_POS: Vector2 = Vector2(400.0, 50.0)
const COST_ICON_RES_GOLD: String = "res://assets/ui/alpha/HVGA/task_gold_icon_2.png"
const COST_ICON_RES_RMB: String = "res://assets/ui/alpha/HVGA/task_rmb_icon_2.png"
const SINGLE_THRESHOLD: int = 1   # loot 种类 <= 此值用单抽布局
const BOX_ANIM_POS: Vector2 = Vector2(400.0, 240.0)
# magic 资源 eff_UI_tavern_open_magicsoul（注意源拼写 tavern 非 tarven）/ starshop 复用 gold 资源；
# stone_* 系（源 :293-295）是 eff_UI_shop_star_box_*（green/blue 为 .abc zip、purple 为 .ani）。
const BOX_FCA_MAP: Dictionary = {
	"bronze": "effect/eff_UI_tarven_open_chest",
	"silver": "effect/eff_UI_tarven_open_chest_silver",
	"gold": "effect/eff_UI_tarven_open_chest_gold",
	"magic": "effect/eff_UI_tavern_open_magicsoul",
	"starshop": "effect/eff_UI_tarven_open_chest_gold",
	"stone_green": "effect/eff_UI_shop_star_box_green",
	"stone_blue": "effect/eff_UI_shop_star_box_blue",
	"stone_purple": "effect/eff_UI_shop_star_box_purple",
}
const MAGIC_CENTER_POS: Vector2 = Vector2(400.0, 280.0)
const MAGIC_LOOT_POS: Array[Vector2] = [
	Vector2(-105.0, 95.0), Vector2(105.0, 95.0), Vector2(215.0, 10.0),
	Vector2(100.0, -95.0), Vector2(-100.0, -95.0), Vector2(-215.0, 10.0),
	Vector2(0.0, 0.0), Vector2(-160.0, -20.0), Vector2(160.0, -20.0),
	Vector2(0.0, 110.0),
]
const ANIM_BASE: String = "res://assets/anim_frames/"
const LSTR_DRAW_ONCE: StringName = &"POPTAVERNLOOT.DRAW_ONCE_AGAIN"
const LSTR_DRAW_TEN: StringName = &"POPTAVERNLOOT.DRAW_10_AGAIN"
const LSTR_CONFIRM: StringName = &"CHATCONFIG.CONFIRM"
const LSTR_OPEN_CHEST: StringName = &"CHATCONFIG.SHOW_REWAD_BY_CHEST"
const FALLBACK_DRAW_ONCE: String = "再抽一次"
const FALLBACK_DRAW_TEN: String = "再抽十次"
const FALLBACK_CONFIRM: String = "确定"
const FALLBACK_OPEN_CHEST: String = "成功打开宝箱"

const SHOW_SEC: float = 0.2
const DESTROY_SEC: float = 0.2
const BOX_BPOS: Vector2 = Vector2(400.0, 240.0)
const LOOT_ANIM_SEC: float = 0.2
const LOOT_ROTATE_DEG: float = 720.0
const BOX_FCA_LEAD_SEC: float = 0.3                # box FCA 开启后引领（简化：不等 FCA 完成）
const SHADOW_RES: String = "res://assets/ui/alpha/HVGA/tavern_get_item_bg_light_white.png"
const SHADOW_POS: Vector2 = Vector2(35.0, 35.0)
const SHADOW_FADE_SEC: float = 0.4
const LIGHT_RES_DIR: String = "res://assets/ui/alpha/HVGA/tavern_get_item_bg_light_"
const LIGHT_QUALITY_COLOR: Array[String] = ["blue", "blue", "blue", "purple", "purple", "orange"]
const LIGHT_POS: Vector2 = Vector2(33.0, 35.0)
const BURST_ROTATE_SEC: float = 5.0
const HERO_BURST_QUALITY: int = 6
const FULL_CIRCLE_DEG: float = 360.0
const HERO_ID_MAX: int = 100
# P0 magic 圆阵 / 阴影 / loot 名字（源 poptavernloot.lua:378-461 + 629-636）→ 拆 PopTavernLootMagic 控 ≤400。

var box_type: String = ""
var times: String = "one"
var cost_info: Dictionary = {}
var _cm: Variant = null
var _content: Control = null       # .tscn instantiate 根（container 子）
var _loot_host: Control = null     # %LootHost：动态 loot icons / FCA 挂载
var _cost_bg: TextureRect = null   # %CostBg：费用行底板（fill 定位）
var _cost_icon: TextureRect = null # %CostIcon：费用行货币图标（fill 换贴图+定位）
var _cost_label: Label = null      # %CostLabel：费用数字（fill 文本+定位）
var _loot_icons: Array[Control] = []
var _loot_targets: Array[Vector2] = []
var _loot_data: Array = []          # 原 loots 数组（id/amount），供 _add_loot_name_label 查名


func _g(pos: Vector2) -> Vector2:
	return BattleViewCoords.to_godot(pos.x, pos.y)


func setup_loot(loots: Array, p_cm: Variant, p_box_type: String = "", p_times: String = "one", p_cost_info: Dictionary = {}) -> void:
	box_type = p_box_type
	times = p_times
	cost_info = p_cost_info
	_cm = p_cm
	setup()
	_build_content()
	_aggregate(loots, p_cm)


# 批5 两件套：instantiate .tscn + 缓存 host/费用行节点 + fill 文本/分支布局 + 绑信号。
# 费用行三节点静态进 tscn（源 :738-773 cost_bg/cost_icon/cost readnode 声明），fill 在
# show_window 后（树内 variation 生效，Label 宽度量精确）。
func _build_content() -> void:
	_content = CONTENT_SCENE.instantiate() as Control
	container.add_child(_content)
	_loot_host = _content.get_node("%LootHost") as Control
	_cost_bg = _content.get_node("%CostBg") as TextureRect
	_cost_icon = _content.get_node("%CostIcon") as TextureRect
	_cost_label = _content.get_node("%CostLabel") as Label
	var reward_lbl: Label = _content.get_node("%RewardLabel") as Label
	reward_lbl.text = _lstr_or(LSTR_OPEN_CHEST, FALLBACK_OPEN_CHEST)
	# 源 :1036-1038 type=="magic" → reward_label:setVisible(false)
	if box_type == "magic":
		reward_lbl.visible = false
	var again_btn: TextureButton = _content.get_node("%AgainBtn") as TextureButton
	(again_btn.get_node("Label") as Label).text = _tv_text()
	again_btn.pressed.connect(_on_again)
	var close_btn: TextureButton = _content.get_node("%CloseBtn") as TextureButton
	(close_btn.get_node("Label") as Label).text = _lstr_or(LSTR_CONFIRM, FALLBACK_CONFIRM)
	close_btn.pressed.connect(func() -> void:
		AudioPlayer.play_sfx("common_click_feedback")
		remove_window())
	# 源 :678-731 starshop 分支（本项目 box_type=stone_*，star_shop_buy_window 传 stone_green/blue/purple）：
	# ok 居中 ccp(400,50)、无 tavern 再抽按钮、无 cost 行。
	if box_type.begins_with("stone_"):
		again_btn.visible = false
		var ok_center: Vector2 = _g(STARSHOP_OK_POS)
		close_btn.position = ok_center - close_btn.size * 0.5


# loots 每项独立成 icon（源 10 个相同 equip 显 10 icon，非聚合 1 个）。
func _aggregate(loots: Array, p_cm: Variant) -> void:
	var thrown: Array = loots.duplicate()
	_throw_loots(thrown)
	_loot_data = thrown   # 名字 Label 按图标顺序查（throw 后顺序 = icon 顺序）
	var is_single: bool = thrown.size() <= SINGLE_THRESHOLD
	var idx: int = 0
	for loot in thrown:
		var lid: int = int(loot["id"])
		var icon: Control = ReadequipIcon.create_icon(lid, int(loot["amount"]), p_cm)
		icon.scale = Vector2.ZERO
		icon.position = _g(BOX_BPOS)
		_loot_host.add_child(icon)
		_loot_icons.append(icon)
		_loot_targets.append(_loot_pos(idx, is_single))
		idx += 1


# + 同英雄（isHero）amount 降序（把 amount 大的同英雄 loot 提前）。
# 单机化：math.randomseed(os.time()) → BattleRng/RandomNumberGenerator 等价（仅洗牌顺序不影响产出）。
func _throw_loots(loots: Array) -> void:
	if loots.size() <= 1:
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var n: int = loots.size()
	var r0: int = rng.randi_range(0, n - 1)
	var t0: Variant = loots[0]
	loots[0] = loots[r0]
	loots[r0] = t0
	for _i in range(20):
		var r1: int = rng.randi_range(0, n - 1)
		var r2: int = rng.randi_range(0, n - 1)
		var t: Variant = loots[r1]
		loots[r1] = loots[r2]
		loots[r2] = t
	for i in range(n):
		var loot_i: Dictionary = loots[i]
		if not _is_hero_loot(loot_i):
			continue
		for j in range(i, n):
			var loot_j: Dictionary = loots[j]
			if _is_hero_loot(loot_j) and _same_hero(loot_i, loot_j) \
					and int(loot_j["amount"]) < int(loot_i["amount"]):
				var t: Variant = loots[i]
				loots[i] = loots[j]
				loots[j] = t


func _is_hero_loot(loot: Dictionary) -> bool:
	return int(loot.get("id", 0)) < HERO_ID_MAX


func _same_hero(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("id", 0)) == int(b.get("id", 0))


func _loot_pos(index: int, is_single: bool) -> Vector2:
	if box_type == "magic":
		var mi: int = clampi(index, 0, MAGIC_LOOT_POS.size() - 1)
		return _g(MAGIC_CENTER_POS + MAGIC_LOOT_POS[mi])
	if is_single:
		return _g(SINGLE_POS)
	var col: int = index % GRID_COLS
	var row: int = index / GRID_COLS
	return _g(Vector2(GRID_ORIGIN.x + GRID_CELL.x * col, GRID_ORIGIN.y + GRID_CELL.y * row))


# 源 :738-773 + :1014-1022：费用行 chrome（cost_bg/cost_icon/cost）静态进 tscn，fill 照源重排——
# label 右缘 240（anchor(1,0.5)@ccp(240,50)）、icon 右缘紧贴 label 左缘（@y48）、bg 中心 = 组中心。
# 在 show_window 后调用（树内 variation 生效，get_minimum_size 度量精确）。
func _fill_cost_row() -> void:
	var has_cost: bool = not cost_info.is_empty()
	_cost_bg.visible = has_cost
	_cost_icon.visible = has_cost
	_cost_label.visible = has_cost
	if not has_cost:
		return
	var pay: String = String(cost_info.get("pay", "Diamond"))
	_cost_label.text = str(int(cost_info.get("number", 0)))
	var label_size: Vector2 = _cost_label.get_minimum_size()
	_cost_label.size = label_size
	var label_anchor: Vector2 = _g(COST_LABEL_POS)   # (320, 510)：右缘 / 垂直中心
	_cost_label.position = label_anchor - Vector2(label_size.x, label_size.y * 0.5)
	var icon_res: String = COST_ICON_RES_RMB if pay == "Diamond" else COST_ICON_RES_GOLD
	var icon_tex: Texture2D = load(icon_res) as Texture2D
	if icon_tex == null:
		return
	_cost_icon.texture = icon_tex
	# 显示尺寸 = 纹理原始像素 ÷ CS（无 TextureConfig 条目，批5 口径手算；TexDisplaySize 现公式偏大 1.28×）
	var icon_size: Vector2 = icon_tex.get_size() / CONTENT_SCALE
	_cost_icon.size = icon_size
	var icon_center: Vector2 = _g(Vector2(COST_LABEL_POS.x, COST_ICON_Y))   # (320, 512)
	_cost_icon.position = Vector2(label_anchor.x - label_size.x - icon_size.x, icon_center.y - icon_size.y * 0.5)
	var bg_center: Vector2 = _g(Vector2(COST_LABEL_POS.x - (label_size.x + icon_size.x) * 0.5, COST_BG_Y))
	_cost_bg.position = bg_center - _cost_bg.size * 0.5


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
	AudioPlayer.play_sfx("common_click_feedback")
	draw_again.emit()
	remove_window()


func show_window(parent: Node) -> void:
	super.show_window(parent)
	_fill_cost_row()   # 树内 fill（variation 生效后 Label 宽度量精确）
	container.scale = Vector2.ZERO
	var tw: Tween = create_tween()
	tw.tween_property(container, "scale", Vector2.ONE, SHOW_SEC).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_after_show)


func _after_show() -> void:
	_play_box_anim()
	# P0 magic 圆阵（源 poptavernloot.lua:340-343 boxAnim 序尾调 createMatrixContainerAnim）：
	# box FCA 后建 circle_1/2 + 呼吸（circle_1 fadeTo 100/255 循环）。圆阵铺底，loot 飞其上。
	# 在 box_shown 之前建（box_shown 表征"box 阶段完成含圆阵"，测试 await box_shown 后圆阵应可见）。
	if box_type == "magic":
		PopTavernLootMagic.create_matrix_container_anim(self)
	box_shown.emit()
	await get_tree().create_timer(BOX_FCA_LEAD_SEC).timeout
	_play_loot_anim(0)


func _play_loot_anim(index: int) -> void:
	if index >= _loot_icons.size():
		loot_anim_done.emit()
		return
	if not is_inside_tree():
		return
	_fly_loot(index)
	await get_tree().create_timer(LOOT_ANIM_SEC).timeout
	# P0 loot 名字 Label（源 poptavernloot.lua:561-636 createLootAnim 尾部 callback）：飞完显物/英雄名。
	PopTavernLootMagic.add_loot_name_label(self, index)
	_maybe_play_burst(index)
	_play_loot_anim(index + 1)


func _fly_loot(index: int) -> void:
	var icon: Control = _loot_icons[index]
	if box_type != "magic":
		_add_shadow(icon)
	else:
		# P0 magic 阴影（源 poptavernloot.lua:559 playMagicLootShadeAnim）：magic 分支
		# 不加普通白光，改加 tavern_magicsoul_item_bg.png scale+move+fade（drop 60px→目标 + fadeout）。
		PopTavernLootMagic.play_magic_loot_shade_anim(self, index)
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(icon, "scale", Vector2.ONE, LOOT_ANIM_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(icon, "position", _loot_targets[index], LOOT_ANIM_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(icon, "rotation", deg_to_rad(LOOT_ROTATE_DEG), LOOT_ANIM_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func remove_window() -> void:
	if not is_inside_tree():
		_do_remove()
		return
	var tw: Tween = create_tween()
	tw.tween_property(container, "scale", Vector2.ZERO, DESTROY_SEC).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(_do_remove)


func _do_remove() -> void:
	super.remove_window()


func _play_box_anim() -> void:
	if not BOX_FCA_MAP.has(box_type):
		return
	var fca := FcaAnimation.new()
	fca.position = _g(BOX_ANIM_POS)
	_loot_host.add_child(fca)
	var resource: String = BOX_FCA_MAP[box_type]
	# 特效 zip 双试 .ani/.abc（stone_green/blue 是 .abc、purple/bronze 系是 .ani；
	# zip 非 Godot 资源，ResourceLoader.exists 恒 false 会让 FCA 永不加载——照
	# fca_animation.gd _read_key_data 的 FileAccess.file_exists 既有模式修正）
	var ani_path: String = ANIM_BASE + resource + ".ani"
	var abc_path: String = ANIM_BASE + resource + ".abc"
	var zip_path: String = ani_path if FileAccess.file_exists(ani_path) else abc_path
	if not FileAccess.file_exists(zip_path):
		return
	var atlas := AtlasSprite.new()
	if atlas.load_atlas_from_ani(zip_path) and fca.load_from_ani(resource, atlas):
		var actions: PackedStringArray = fca.get_action_names()
		if actions.size() > 0:
			fca.play(actions[0], false)
			AudioPlayer.play_sfx("skill_upgrade_success_blue")


func _add_shadow(icon: Control) -> void:
	if not ResourceLoader.exists(SHADOW_RES):
		return
	var shadow := Sprite2D.new()
	shadow.texture = load(SHADOW_RES)
	shadow.centered = true
	shadow.position = SHADOW_POS
	icon.add_child(shadow)
	icon.create_tween().tween_property(shadow, "modulate:a", 0.0, SHADOW_FADE_SEC)


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


func _play_burst(icon: Control, quality: int) -> void:
	var color_idx: int = clampi(quality - 1, 0, LIGHT_QUALITY_COLOR.size() - 1)
	var res: String = LIGHT_RES_DIR + LIGHT_QUALITY_COLOR[color_idx] + ".png"
	if not ResourceLoader.exists(res) or icon.scale == Vector2.ZERO:
		return
	var light := Sprite2D.new()
	light.texture = load(res)
	light.centered = true
	light.position = LIGHT_POS
	light.scale = Vector2.ONE / icon.scale
	light.z_index = -3
	icon.add_child(light)
	var tw: Tween = icon.create_tween().set_loops()
	tw.tween_property(light, "rotation", deg_to_rad(FULL_CIRCLE_DEG), BURST_ROTATE_SEC)

# P0 magic 圆阵 / 阴影 / loot 名字实现在 PopTavernLootMagic（控 ≤400 行拆出）。
