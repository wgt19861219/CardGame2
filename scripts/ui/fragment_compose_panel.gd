class_name FragmentComposePanel
extends PopWindow

## 碎片合成面板（View 层）— 照源 ui/fragmentcompose.lua（485 行单页弹窗）。
## 流程：碎片图标 → 箭头 → 产物图标 + 持有量/需求 + 通用碎片提示 + 金币费用 + 合成按钮。
## Logic 走 HeroManager.compose（通用碎片补足分支照源 doCompose :123-149）。
## 单机化：金币不足降级 toast（源 :132 弹 useMidas 点金手，单机版不接）。
## 坐标用源 cocos 值直接（视觉校准留 Phase 4 MCP 验收，同 EquipCraftPanel/EquipStrengthenPanel 约定）。

signal composed   # 合成成功后通知调用方刷新（HeroPackagePanel 刷新英雄列表）

# ── 坐标常量（源 cocos 值）──
const BG_POS: Vector2 = Vector2(400.0, 240.0)         # 源 :262
const NAME_POS: Vector2 = Vector2(142.0, 348.0)       # 源 :277
const FRAG_ICON_POS: Vector2 = Vector2(78.0, 230.0)   # 源 :471
const ARROW_POS: Vector2 = Vector2(145.0, 230.0)      # 源 :304
const MAKE_ICON_POS: Vector2 = Vector2(212.0, 230.0)  # 源 :475
const AMOUNT_POS: Vector2 = Vector2(78.0, 178.0)      # 源 :316（持有量）
const AMOUNT_NEED_OFFSET: float = 40.0                # 源 :331 "/need" 同行右移
const UNIVERSAL_POS: Vector2 = Vector2(145.0, 130.0)  # 源 :346
const COST_BG_POS: Vector2 = Vector2(142.0, 95.0)     # 源 :359
const COST_BG_SIZE: Vector2 = Vector2(260.0, 32.0)
const COST_TITLE_POS: Vector2 = Vector2(72.0, 94.0)   # 源 :373
const COST_ICON_POS: Vector2 = Vector2(152.0, 95.0)   # 源 :386
const COST_POS: Vector2 = Vector2(180.0, 94.0)        # 源 :399
const CLOSE_POS: Vector2 = Vector2(280.0, 375.0)      # 源 :412
const CLOSE_RES: String = "res://assets/ui/alpha/HVGA/herodetail-detail-close.png"   # 源 :409
const CLOSE_PRESS_RES: String = "res://assets/ui/alpha/HVGA/herodetail-detail-close-p.png"   # 源 :419
const OK_POS: Vector2 = Vector2(145.0, 45.0)          # 源 :434
const OK_SIZE: Vector2 = Vector2(250.0, 49.0)
const OK_RES: String = "res://assets/ui/alpha/HVGA/herodetail-upgrade.png"
const OK_PRESS_RES: String = "res://assets/ui/alpha/HVGA/herodetail-upgrade-mask.png"
const OK_CAP: Rect2 = Rect2(20.0, 20.0, 20.0, 20.0)
# ── 资源 ──
const BG_PATH: String = "res://assets/ui/alpha/HVGA/fragment_compose_bg.png"
const ARROW_PATH: String = "res://assets/ui/alpha/HVGA/fragment_compose_arrow.png"
const COST_BG_PATH: String = "res://assets/ui/alpha/HVGA/equip_craft_money_bg.png"
const GOLD_ICON_PATH: String = "res://assets/ui/alpha/HVGA/goldicon.png"
# ── 颜色（源 ccc3）──
const COLOR_RED: Color = Color(1.0, 0.0, 0.0)
const COLOR_TITLE_RED: Color = Color(184.0 / 255.0, 6.0 / 255.0, 6.0 / 255.0)
const COLOR_BROWN: Color = Color(50.0 / 255.0, 41.0 / 255.0, 31.0 / 255.0)
const COLOR_DARK_RED: Color = Color(155.0 / 255.0, 34.0 / 255.0, 14.0 / 255.0)
const COLOR_ORANGE: Color = Color(182.0 / 255.0, 65.0 / 255.0, 21.0 / 255.0)
# ── 文字（源 LSTR）──
const TEXT_COST_TITLE: String = "合成费用 "           # 源 FRAGMENTCOMPOSE.SYNTHESIS_COST
const TEXT_OK: String = "确认合成"                    # 源 FRAGMENTCOMPOSE.CONFIRM_SYNTHESIS
const TEXT_SUCCESS: String = "成功合成碎片"           # 源 :101
const TEXT_INSUFFICIENT: String = "碎片不足，合成失败" # 源 :128
const TEXT_OWNED: String = "您已经拥有此英雄"         # 源 :138
const TEXT_NO_GOLD: String = "金币不足"               # 单机化降级（源 :132 useMidas）

var cm: Variant = null
var pd: PlayerData = null
var _target_tid: int = 0
var _info: Dictionary = {}   # 源 self.info（配方 + 持有量快照）


# 源 cocos(800×480 左下) → Godot(960×640 左上):cx+80, 560-cy（同 daily_login/battle_view_coords 标准）。
# Phase 4 早期直接用源值漏转，2026-07-14 补 to_godot（见验收记录-battle坐标系统性bug修复）。
func _g(pos: Vector2) -> Vector2:
	return BattleViewCoords.to_godot(pos.x, pos.y)


# 源 create(selectid) + getInformation :202-248。target_tid = 产物英雄 tid（源 makeId）。
func setup_panel(p_target_tid: int, p_cm: Variant, p_pd: PlayerData) -> void:
	_target_tid = p_target_tid
	cm = p_cm
	pd = p_pd
	_load_info()
	setup()
	_build_ui()
	register_on_enter(func() -> void: AudioPlayer.play_sfx("common_popup_window"))


# 源 :202-248 getInformation：Fragment[tid] 配方 + 玩家持有量。
func _load_info() -> void:
	var frag_id: int = cm.get_int(&"Fragment", _target_tid, &"Fragment ID")
	var frag_need: int = cm.get_int(&"Fragment", _target_tid, &"Fragment Count")
	var uni_id: int = cm.get_int(&"Fragment", _target_tid, &"Universal Fragment ID")
	var uni_need: int = cm.get_int(&"Fragment", _target_tid, &"Universal Fragment Count")
	var expense: int = cm.get_int(&"Fragment", _target_tid, &"Expense")
	_info = {
		"id": frag_id, "needAmount": frag_need,
		"universalId": uni_id, "universalNeedAmount": uni_need,
		"cost": expense, "makeId": _target_tid,
		"fragmentAmount": _frag_count(frag_id),
		"universalAmount": _frag_count(uni_id),
	}


func _build_ui() -> void:
	if ResourceLoader.exists(BG_PATH):
		var bg := TextureRect.new()
		bg.texture = load(BG_PATH)
		bg.position = _g(BG_POS) - bg.get_minimum_size() / 2.0   # 中心锚定（源 setPosition(400,240)→Godot）
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(bg)
	# name 标题（源 :277 "合成 " + makeName）
	var name_lbl := Label.new()
	name_lbl.text = "合成 " + _make_name()
	name_lbl.position = _g(NAME_POS)
	name_lbl.modulate = COLOR_TITLE_RED
	container.add_child(name_lbl)
	# 碎片图标（源 :471 createFragment）
	var frag_icon: Control = ReadequipIcon.create_icon(int(_info["id"]), 0, cm)
	frag_icon.position = _g(FRAG_ICON_POS)
	container.add_child(frag_icon)
	# 箭头（源 :304）
	if ResourceLoader.exists(ARROW_PATH):
		var arrow := TextureRect.new()
		arrow.texture = load(ARROW_PATH)
		arrow.position = _g(ARROW_POS) - arrow.get_minimum_size() / 2.0
		arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(arrow)
	# 产物图标（源 :475 createIcon(makeId)）
	var make_icon: Control = ReadequipIcon.create_icon(int(_info["makeId"]), 0, cm)
	make_icon.position = _g(MAKE_ICON_POS)
	container.add_child(make_icon)
	_build_amount_label()       # 源 :316/:331 持有量/需求
	_build_universal_hint()     # 源 :346 通用碎片提示
	_build_cost()               # 源 :359-399 金币费用
	# 关闭按钮（源 :409 herodetail-detail-close + :419 close_down，中心定位照源 ccp(280,375)→Godot）
	var close: TextureButton = UiButton.make(CLOSE_RES, CLOSE_PRESS_RES, _g(CLOSE_POS))
	close.pressed.connect(_on_close_pressed)
	container.add_child(close)
	# 合成按钮（源 :434）
	var ok: Button = UiScale9Button.make_centered(OK_RES, OK_PRESS_RES, _g(OK_POS), OK_SIZE, OK_CAP, TEXT_OK)
	ok.pressed.connect(_on_compose_pressed)
	container.add_child(ok)


# 持有量/需求（源 :316 amount + :331 "/need" 同行右移）。不足红/够棕。
func _build_amount_label() -> void:
	var have := int(_info["fragmentAmount"])
	var need := int(_info["needAmount"])
	var lbl := Label.new()
	lbl.text = str(have)
	lbl.position = _g(AMOUNT_POS)
	lbl.modulate = COLOR_RED if have < need else COLOR_BROWN
	container.add_child(lbl)
	var need_lbl := Label.new()
	need_lbl.text = "/" + str(need)
	need_lbl.position = _g(AMOUNT_POS) + Vector2(AMOUNT_NEED_OFFSET, 0.0)
	need_lbl.modulate = COLOR_BROWN
	container.add_child(need_lbl)


# 通用碎片提示（源 :346，专属不够需通用补时显示）。
func _build_universal_hint() -> void:
	var frag_have := int(_info["fragmentAmount"])
	var frag_need := int(_info["needAmount"])
	var uni_use: int = max(0, frag_need - frag_have)
	if uni_use <= 0:
		return   # 专属够，不需通用补
	var uni_have := int(_info["universalAmount"])
	var uni_need := int(_info["universalNeedAmount"])
	var lbl := Label.new()
	lbl.text = "通用碎片 %d/%d" % [uni_have, uni_need]
	lbl.position = _g(UNIVERSAL_POS)
	lbl.modulate = COLOR_ORANGE
	container.add_child(lbl)


# 金币费用（源 :359-399 costBg + costTitle + goldIcon + cost）。
func _build_cost() -> void:
	var cost := int(_info["cost"])
	if ResourceLoader.exists(COST_BG_PATH):
		var cost_bg := TextureRect.new()
		cost_bg.texture = load(COST_BG_PATH)
		cost_bg.position = _g(COST_BG_POS) - COST_BG_SIZE / 2.0
		cost_bg.size = COST_BG_SIZE
		cost_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(cost_bg)
	var title := Label.new()
	title.text = TEXT_COST_TITLE
	title.position = _g(COST_TITLE_POS)
	title.modulate = COLOR_BROWN
	container.add_child(title)
	if ResourceLoader.exists(GOLD_ICON_PATH):
		var gi := TextureRect.new()
		gi.texture = load(GOLD_ICON_PATH)
		gi.position = _g(COST_ICON_POS)
		gi.scale = Vector2(0.8, 0.8)
		gi.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(gi)
	var cost_lbl := Label.new()
	cost_lbl.text = str(cost)
	cost_lbl.position = _g(COST_POS)
	cost_lbl.modulate = COLOR_DARK_RED if cost <= _player_money() else COLOR_RED
	container.add_child(cost_lbl)


# 源 doCompose :123-164：预校验展示原因 → HeroManager.compose → toast。
func _on_compose_pressed() -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	var frag_have := int(_info["fragmentAmount"])
	var frag_need := int(_info["needAmount"])
	var uni_avail: int = min(int(_info["universalAmount"]), int(_info["universalNeedAmount"]))
	if frag_have + uni_avail < frag_need:   # 源 :128 碎片不足
		_show_toast(TEXT_INSUFFICIENT)
		return
	if _player_money() < int(_info["cost"]):   # 源 :132 金币不足（单机化降级）
		_show_toast(TEXT_NO_GOLD)
		return
	if _hero_owned(int(_info["makeId"])):   # 源 :138 已有英雄
		_show_toast(TEXT_OWNED)
		return
	var ok := pd.hero_manager.compose(_target_tid)
	if ok:
		_show_toast(TEXT_SUCCESS)
		composed.emit()
		remove_window()


func _on_close_pressed() -> void:
	AudioPlayer.play_sfx("common_close_popup_window")
	remove_window()


func _make_name() -> String:
	return cm.get_lstr(String(cm.get_raw_table("Unit").get(str(_target_tid), {}).get("Display Name", str(_target_tid))))


func _frag_count(frag_id: int) -> int:
	if pd == null or pd.hero_manager == null:
		return 0
	return int(pd.hero_manager.fragments.get(frag_id, 0))


func _player_money() -> int:
	if pd == null or pd.hero_manager == null:
		return 0
	return pd.hero_manager.gold


func _hero_owned(tid: int) -> bool:
	if pd == null or pd.hero_manager == null:
		return false
	for inst_id in pd.hero_manager.heroes:
		if (pd.hero_manager.heroes[inst_id] as HeroInstance).tid == tid:
			return true
	return false


# 源 ed.showToast（本项目 Toast autoload，headless 安全降级，同 EquipCraftPanel）。
func _show_toast(text: String) -> void:
	if Engine.is_editor_hint():
		return
	var toast_node: Node = Engine.get_main_loop().root.get_node_or_null("/root/Toast")
	if toast_node != null and toast_node.has_method("show_text"):
		toast_node.show_text(text)
