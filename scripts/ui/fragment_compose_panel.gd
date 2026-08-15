class_name FragmentComposePanel
extends PopWindow

## 碎片合成面板（View 层）— 照源 ui/fragmentcompose.lua（485 行单页弹窗）。
## 流程：碎片图标 → 箭头 → 产物图标 + 持有量/需求 + 通用碎片提示 + 金币费用 + 合成按钮。
## Logic 走 HeroManager.compose（通用碎片补足分支照源 doCompose :123-149）。
## 单机化：金币不足降级 toast（源 :132 弹 useMidas 点金手，单机版不接）。
## 两件套（批 1 Task 6 核对级，2026-08-15）：静态树在 fragment_compose_content.tscn
## （源 readnode root=bg sprite → tscn PanelLayer 容器承载 bg 局部空间，坐标系坑 #1），
## 本脚本只做业务/信号/fill；颜色走 variation + font_color override（stone_detail 口径）。

signal composed   # 合成成功后通知调用方刷新（HeroPackagePanel 刷新英雄列表）

# 静态 panel 层子场景（位置/size 在 .tscn 可视化）。
const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/fragment_compose_content.tscn")
# ── 颜色（源 ccc3 可见行为）──
# amount：getInformation :241-245（初始染色）——不足红 / 足棕(169,91,28)。
const COLOR_AMOUNT_LOW: Color = Color(1.0, 0.0, 0.0)
const COLOR_AMOUNT_OK: Color = Color(169.0 / 255.0, 91.0 / 255.0, 28.0 / 255.0)
# cost：refreshCostColor :108-119（create :481 末尾刷新覆盖 :402 初始色）——不足红 / 足棕。
const COLOR_COST_LOW: Color = Color(232.0 / 255.0, 18.0 / 255.0, 18.0 / 255.0)
const COLOR_COST_OK: Color = Color(182.0 / 255.0, 65.0 / 255.0, 21.0 / 255.0)
# ── 文字（源 LSTR key，setup_panel 时 cm.get_lstr 解析）──
const LSTR_COST_TITLE: String = "EQUIPCRAFT.SYNTHESIS_COST_"
const LSTR_OK: String = "FRAGMENTCOMPOSE.CONFIRM_SYNTHESIS"
const LSTR_SUCCESS: String = "FRAGMENTCOMPOSE.SUCCESSFULLY_SYNTHESIZED_FRAGMENT"
const LSTR_INSUFFICIENT: String = "FRAGMENTCOMPOSE.INSUFFICIENT_FRAGMENT_SYNTHESIS_FAILED"
const LSTR_OWNED: String = "FRAGMENTCOMPOSE.YOU_HAVE_ALREADY_GOT_THIS_HERO"
const TEXT_NO_GOLD: String = "金币不足"   # 单机化降级（源 :132 useMidas 弹点金手，单机版不接）
const LSTR_SYNTHESIS_PREFIX: String = "EQUIPCRAFT.SYNTHESIS"
# name 标题宽上限（源 :477 长名溢出 scale 缩小）：NameLabel rect 32→252 = 220px
# （源阈值 200/目标 210，受控偏离对齐 tscn 框宽，见 task-6-report）。
const NAME_MAX_W: float = 220.0

var cm: Variant = null
var pd: PlayerData = null
var _target_tid: int = 0
var _info: Dictionary = {}


func setup_panel(p_target_tid: int, p_cm: Variant, p_pd: PlayerData) -> void:
	play_open_sfx = true   # T4：原 register_on_enter 音效样板上收基类
	_target_tid = p_target_tid
	cm = p_cm
	pd = p_pd
	_load_info()
	setup()
	_build_content()
	# 源 EaseBackOut 0.2s：弹窗缩放入场（P2-10）。
	register_on_enter(play_scale_in)


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


# fill 动态数据/样式 + 信号绑定；静态结构与位置在 .tscn（PanelLayer 局部坐标照源）。
func _build_content() -> void:
	var content: Control = CONTENT_SCENE.instantiate() as Control
	container.add_child(content)
	# name 标题（源 :273-274 T(LSTR("EQUIPCRAFT.SYNTHESIS")) .. " " .. makeName）
	# 源 fragmentcompose.lua:477：长名溢出时 scale 缩小。
	var name_lbl: Label = content.get_node("%NameLabel") as Label
	name_lbl.text = cm.get_lstr(LSTR_SYNTHESIS_PREFIX) + " " + _make_name()
	var name_w: float = name_lbl.get_combined_minimum_size().x
	if name_w > NAME_MAX_W:
		name_lbl.scale = Vector2(NAME_MAX_W / name_w, NAME_MAX_W / name_w)
	# 碎片图标（源 :471 createFragment at (78,230) 中心锚）→ 挂零尺寸点
	# %FragmentIconHost（tscn 定位图标中心），负半偏移居中（stone_detail 同款）。
	var frag_host: Control = content.get_node("%FragmentIconHost") as Control
	var frag_icon: Control = ReadequipIcon.create_icon(int(_info["id"]), 0, cm)
	frag_icon.position = -frag_icon.size * 0.5
	frag_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frag_host.add_child(frag_icon)
	# 产物图标（源 :475 createIcon(makeId) at (212,230) 中心锚）→ %MakeIconHost
	var make_host: Control = content.get_node("%MakeIconHost") as Control
	var make_icon: Control = ReadequipIcon.create_icon(int(_info["makeId"]), 0, cm)
	make_icon.position = -make_icon.size * 0.5
	make_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	make_host.add_child(make_icon)
	_fill_amount(content)
	_fill_universal(content)
	_fill_cost(content)
	# 关闭按钮（源 :409 herodetail-detail-close，.tscn TextureButton normal/pressed 双态自带切换）
	var close_btn: TextureButton = content.get_node("%CloseBtn") as TextureButton
	close_btn.pressed.connect(_on_close_pressed)
	# 合成按钮（源 :434 Scale9 cap 20,20,20,20 + :459 LSTR ok_label；
	# 三态样式/字号走 .tscn FragmentComposeOkButton variation，text 此处 fill）
	var ok_btn: Button = content.get_node("%OkBtn") as Button
	ok_btn.text = cm.get_lstr(LSTR_OK)
	ok_btn.pressed.connect(_on_compose_pressed)


# 持有量/需求（源 :316 amount + :331 "/need"）。色照源 getInformation :241-245
# 可见行为：不足红 / 足棕(169,91,28)——font_color override 非 modulate（防乘色偏差）。
func _fill_amount(content: Control) -> void:
	var have := int(_info["fragmentAmount"])
	var need := int(_info["needAmount"])
	var amount_lbl: Label = content.get_node("%AmountLabel") as Label
	amount_lbl.text = str(have)
	amount_lbl.add_theme_color_override(&"font_color", COLOR_AMOUNT_LOW if have < need else COLOR_AMOUNT_OK)
	var need_lbl: Label = content.get_node("%AmountNeedLabel") as Label
	need_lbl.text = "/" + str(need)


# 通用碎片提示（源 :337-351）：text = lackText（:236-240 两分支同为 INSUFFICIENT
# 文案，复制粘贴死分支，照可见行为直译），visible = 专属碎片不足（lackAmount~=0）。
func _fill_universal(content: Control) -> void:
	var frag_have := int(_info["fragmentAmount"])
	var frag_need := int(_info["needAmount"])
	var uni_use: int = max(0, frag_need - frag_have)
	var uni_lbl: Label = content.get_node("%UniversalLabel") as Label
	if uni_use <= 0:
		uni_lbl.visible = false   # 专属够，不提示
		return
	uni_lbl.text = cm.get_lstr(LSTR_INSUFFICIENT)
	uni_lbl.visible = true


# 金币费用（源 :359-404 costBg + costTitle + goldIcon + cost；色照源
# refreshCostColor :108-119，create :481 末尾刷新覆盖 :402 初始色）。
func _fill_cost(content: Control) -> void:
	var title_lbl: Label = content.get_node("%CostTitleLabel") as Label
	title_lbl.text = cm.get_lstr(LSTR_COST_TITLE)
	var cost := int(_info["cost"])
	var cost_lbl: Label = content.get_node("%CostLabel") as Label
	cost_lbl.text = str(cost)
	cost_lbl.add_theme_color_override(&"font_color", COLOR_COST_LOW if cost > _player_money() else COLOR_COST_OK)


func _on_compose_pressed() -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	var frag_have := int(_info["fragmentAmount"])
	var frag_need := int(_info["needAmount"])
	var uni_avail: int = min(int(_info["universalAmount"]), int(_info["universalNeedAmount"]))
	if frag_have + uni_avail < frag_need:
		_show_toast(cm.get_lstr(LSTR_INSUFFICIENT))
		return
	if _player_money() < int(_info["cost"]):
		_show_toast(TEXT_NO_GOLD)
		return
	if _hero_owned(int(_info["makeId"])):
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
