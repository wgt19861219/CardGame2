class_name FragmentComposePanel
extends PopWindow

## 碎片合成面板（View 层）— 照源 ui/fragmentcompose.lua（485 行单页弹窗）。
## 流程：碎片图标 → 箭头 → 产物图标 + 持有量/需求 + 通用碎片提示 + 金币费用 + 合成按钮。
## Logic 走 HeroManager.compose（通用碎片补足分支照源 doCompose :123-149）。
## 单机化：金币不足降级 toast（源 :132 弹 useMidas 点金手，单机版不接）。
## Phase A 静态化（2026-07-17）：bg/arrow/cost_bg/cost_icon/close/ok + 5 Label
## 从 procedural 改 instantiate fragment_compose_content.tscn（位置/size 编辑器可视化，照 hero_detail 范式）。
## 碎片/产物图标保留 procedural 挂 %IconHost（本批只静态化 panel 层）。

signal composed   # 合成成功后通知调用方刷新（HeroPackagePanel 刷新英雄列表）

# 静态 panel 层子场景（位置/size 在 .tscn 可视化）。
const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/fragment_compose_content.tscn")
# Scale9 按钮样式（源 :427-438 ok Scale9Sprite herodetail-upgrade.png capInsets 20,20,20,20）。
const OK_RES: String = "res://assets/ui/alpha/HVGA/herodetail-upgrade.png"
const OK_PRESS_RES: String = "res://assets/ui/alpha/HVGA/herodetail-upgrade-mask.png"
const OK_CAP: Rect2 = Rect2(20.0, 20.0, 20.0, 20.0)
# 源 cocos(800×480 左下) → Godot(960×640 左上)：(cx+80, 560-cy)，同 hero_detail/handbook 范式。
const OFFSET_X: float = 80.0
const BASE_Y: float = 560.0
# 碎片/产物图标源 ccp（:471/:475）→ host 内子节点 absolute position。
const FRAG_ICON_COCOS: Vector2 = Vector2(78.0, 230.0)
const MAKE_ICON_COCOS: Vector2 = Vector2(212.0, 230.0)
# ── 颜色（源 ccc3）──
const COLOR_RED: Color = Color(1.0, 0.0, 0.0)
const COLOR_BROWN: Color = Color(50.0 / 255.0, 41.0 / 255.0, 31.0 / 255.0)
const COLOR_DARK_RED: Color = Color(155.0 / 255.0, 34.0 / 255.0, 14.0 / 255.0)
# ── 文字（源 LSTR key，setup_panel 时 cm.get_lstr 解析）──
# 源 :369 EQUIPCRAFT.SYNTHESIS_COST_（带尾下划线）/ :459 CONFIRM_SYNTHESIS / :101 SUCCESSFULLY_SYNTHESIZED_FRAGMENT
# 源 :129 INSUFFICIENT_FRAGMENT_SYNTHESIS_FAILED / :139 YOU_HAVE_ALREADY_GOT_THIS_HERO
# 源 :132 useMidas → 单机化降级 toast（源无 LSTR key，TEXT_NO_GOLD 硬编码）。
const LSTR_COST_TITLE: String = "EQUIPCRAFT.SYNTHESIS_COST_"
const LSTR_OK: String = "FRAGMENTCOMPOSE.CONFIRM_SYNTHESIS"
const LSTR_SUCCESS: String = "FRAGMENTCOMPOSE.SUCCESSFULLY_SYNTHESIZED_FRAGMENT"
const LSTR_INSUFFICIENT: String = "FRAGMENTCOMPOSE.INSUFFICIENT_FRAGMENT_SYNTHESIS_FAILED"
const LSTR_OWNED: String = "FRAGMENTCOMPOSE.YOU_HAVE_ALREADY_GOT_THIS_HERO"
const TEXT_NO_GOLD: String = "金币不足"   # 单机化降级（源 :132 useMidas 弹点金手，单机版不接）
const LSTR_SYNTHESIS_PREFIX: String = "EQUIPCRAFT.SYNTHESIS"   # 源 :273 name 前缀"合成"

var cm: Variant = null
var pd: PlayerData = null
var _target_tid: int = 0
var _info: Dictionary = {}   # 源 self.info（配方 + 持有量快照）


# 源 cocos(800×480 左下) → Godot(960×640 左上)：cx+80, 560-cy（同 daily_login/battle_view_coords 标准）。
func _g(cx: float, cy: float) -> Vector2:
	return Vector2(cx + OFFSET_X, BASE_Y - cy)


# 源 create(selectid) + getInformation :202-248。target_tid = 产物英雄 tid（源 makeId）。
func setup_panel(p_target_tid: int, p_cm: Variant, p_pd: PlayerData) -> void:
	_target_tid = p_target_tid
	cm = p_cm
	pd = p_pd
	_load_info()
	setup()
	_build_content()
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


# Phase A：panel 层从 .tscn instantiate（位置/size .tscn 固化）+ fill 动态数据/样式 + 信号绑定。
# 碎片/产物图标保留 procedural 挂 host（pos=host 局部 0,0 + 子节点 absolute）。
func _build_content() -> void:
	var content: Control = CONTENT_SCENE.instantiate() as Control
	container.add_child(content)
	# name 标题（源 :273-274 T(LSTR("EQUIPCRAFT.SYNTHESIS")) .. " " .. makeName，位置/颜色 .tscn 固化）
	var name_lbl: Label = content.get_node("%NameLabel") as Label
	name_lbl.text = cm.get_lstr(LSTR_SYNTHESIS_PREFIX) + " " + _make_name()
	# 碎片图标（源 :471 createFragment）→ 挂 %FragmentIconHost
	var frag_host: Control = content.get_node("%FragmentIconHost") as Control
	var frag_icon: Control = ReadequipIcon.create_icon(int(_info["id"]), 0, cm)
	frag_icon.position = _g(FRAG_ICON_COCOS.x, FRAG_ICON_COCOS.y)
	frag_host.add_child(frag_icon)
	# 产物图标（源 :475 createIcon(makeId)）→ 挂 %MakeIconHost
	var make_host: Control = content.get_node("%MakeIconHost") as Control
	var make_icon: Control = ReadequipIcon.create_icon(int(_info["makeId"]), 0, cm)
	make_icon.position = _g(MAKE_ICON_COCOS.x, MAKE_ICON_COCOS.y)
	make_host.add_child(make_icon)
	_fill_amount(content)       # 源 :316/:331 持有量/需求
	_fill_universal(content)    # 源 :346 通用碎片提示
	_fill_cost(content)         # 源 :359-399 金币费用
	# 关闭按钮（源 :409 herodetail-detail-close，.tscn TextureButton normal/pressed 双态自带切换）
	var close_btn: TextureButton = content.get_node("%CloseBtn") as TextureButton
	close_btn.pressed.connect(_on_close_pressed)
	# 合成按钮（源 :434 Scale9 cap 20,20,20,20 + :459 LSTR ok_label；.tscn 普通 Button 运行时套 Scale9）
	var ok_btn: Button = content.get_node("%OkBtn") as Button
	UiScale9Button.apply_with_label(ok_btn, OK_RES, OK_PRESS_RES, OK_CAP, cm.get_lstr(LSTR_OK))
	ok_btn.pressed.connect(_on_compose_pressed)


# 持有量/需求（源 :316 amount + :331 "/need"）。不足红/够棕。
func _fill_amount(content: Control) -> void:
	var have := int(_info["fragmentAmount"])
	var need := int(_info["needAmount"])
	var amount_lbl: Label = content.get_node("%AmountLabel") as Label
	amount_lbl.text = str(have)
	amount_lbl.modulate = COLOR_RED if have < need else COLOR_BROWN
	var need_lbl: Label = content.get_node("%AmountNeedLabel") as Label
	need_lbl.text = "/" + str(need)


# 通用碎片提示（源 :346，专属不够需通用补时显示）。
func _fill_universal(content: Control) -> void:
	var frag_have := int(_info["fragmentAmount"])
	var frag_need := int(_info["needAmount"])
	var uni_use: int = max(0, frag_need - frag_have)
	var uni_lbl: Label = content.get_node("%UniversalLabel") as Label
	if uni_use <= 0:
		uni_lbl.visible = false   # 专属够，不需通用补
		return
	var uni_have := int(_info["universalAmount"])
	var uni_need := int(_info["universalNeedAmount"])
	uni_lbl.text = "通用碎片 %d/%d" % [uni_have, uni_need]
	uni_lbl.visible = true


# 金币费用（源 :359-399 costBg + costTitle + goldIcon + cost）。
func _fill_cost(content: Control) -> void:
	var title_lbl: Label = content.get_node("%CostTitleLabel") as Label
	title_lbl.text = cm.get_lstr(LSTR_COST_TITLE)
	var cost := int(_info["cost"])
	var cost_lbl: Label = content.get_node("%CostLabel") as Label
	cost_lbl.text = str(cost)
	cost_lbl.modulate = COLOR_DARK_RED if cost <= _player_money() else COLOR_RED


# 源 doCompose :123-164：预校验展示原因 → HeroManager.compose → toast。
func _on_compose_pressed() -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	var frag_have := int(_info["fragmentAmount"])
	var frag_need := int(_info["needAmount"])
	var uni_avail: int = min(int(_info["universalAmount"]), int(_info["universalNeedAmount"]))
	if frag_have + uni_avail < frag_need:   # 源 :128-129 碎片不足
		_show_toast(cm.get_lstr(LSTR_INSUFFICIENT))
		return
	if _player_money() < int(_info["cost"]):   # 源 :132 金币不足（单机化降级）
		_show_toast(TEXT_NO_GOLD)
		return
	if _hero_owned(int(_info["makeId"])):   # 源 :138-139 已有英雄
		_show_toast(cm.get_lstr(LSTR_OWNED))
		return
	var ok := pd.hero_manager.compose(_target_tid)
	if ok:
		_show_toast(cm.get_lstr(LSTR_SUCCESS))
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
