class_name TavernPanel
extends PopWindow

## 抽卡面板（View 层）——两件套范式（批2 Task 7，2026-08-16）。
## 静态结构全在 tavern_content.tscn：3 卡池 board（bronze/gold/magic）×
## container(206×320) > BoardBg/TitleImage/TitleArt + Clip(裁剪) > Scroll（卡池内容，
## 源 createBaseBoard:594 + createCommonLayer:653 / createMagicLayer:949 静态化）。
## 原 procedural board 工厂（336 行）退役；panel 只做业务 + 信号 connect + fill
## （LSTR 文案/费用数值）+ 滑动 tween（源 doClickCheck:1576 上滑 320 / doClickArrow:1584）。
## magic drop_bg 4 组 heroIcons 运行时填（源 doRefrehMagicHeroIcon:1290，
## ask_magicsoul 回复后才有 ID，动态行不走 tscn）。
## Cost + Cost Type 从表读（TavernData.get_tavern_info）；magic 源无单抽 → tscn 无单抽区，
## ten_buy 标签照源 :1225 = BUY__D % 1（"购买1个"，唯一按钮按单抽计费）。
## 面板级 _preview_container 保留兼容 test_tavern_magic（非独占不能改），magic 主预览在 Scroll 内。

signal drawn

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/tavern_content.tscn")
const POOL_KEYS: Array[String] = ["Bronze", "Gold", "MagicSoul"]
# Scroll 局部空间高（源 clip stencil 206×320；子节点 y = CLIP_H - cocos_y）
const CLIP_H: float = 320.0
# 源 doClickCheck:1576 CCMoveTo(0.2, (0,320)) EaseSineIn / doClickArrow:1584 EaseSineOut
const SLIDE_OFFSET: float = 320.0
const SLIDE_DURATION: float = 0.2
# 源 playLightAnim :577 gold/magic light CCRotateBy(5, 360) 循环
const LIGHT_ROTATE_SEC: float = 5.0
const FULL_CIRCLE_DEG: float = 360.0
# 源 tavern.lua:566-574 getArrowudAnim：arrow MoveBy(1, (0,-5)) SineInOut ↔ reverse 循环
const ARROW_FLOAT_OFFSET_Y: float = -5.0
const ARROW_FLOAT_SEC: float = 1.0
const REFRESH_INTERVAL_SEC: float = 1.0
const MAGIC_VIP_KEY: String = "Magic Soul Box"
const LSTR_CHECK: StringName = &"RECHARGE.VIEW"
const LSTR_BUY_D: StringName = &"TAVERN.BUY__D"
const LSTR_DAY_TITLE: StringName = &"TAVERN.TODAYS_HIGHLIGHT"
const LSTR_MONTH_TITLE: StringName = &"TAVERN.HOT_IN_THIS_WEEK"
const LSTR_TEN_PROMPT: Dictionary = {
	"bronze": &"TAVERNRES.ONE_BLUE_ITEM_IS_DOOMED_TO_BE_GOT_IF_YOU_DRAW_10TIMES_AT_ONE_TIME",
	"gold": &"TAVERNRES.HERO_IS_DOOMED_TO_BE_GOT_IF_YOU_DRAW_10TIMES_AT_ONE_TIME",
	"magic": &"TAVERNRES.CAN_GET_MULTIPLE_SOUL_STONES",
}
# LSTR key 缺失时的中文 fallback（cm.get_lstr 缺失返 key 本身，panel 判 key==val 走 fallback）
const FALLBACK_CHECK: String = "查看"
const FALLBACK_BUY_FMT: String = "购买%d个"
const FALLBACK_DAY_TITLE: String = "今日热点"
const FALLBACK_MONTH_TITLE: String = "本周热点"
const FALLBACK_TEN_PROMPT: Dictionary = {
	"bronze": "十连抽必得蓝色物品",
	"gold": "十连抽必得英雄",
	"magic": "可获大量灵魂石",
}

var _cm: Variant = null
var _player: PlayerData = null
var _rng: BattleRng = null
var _current_pool: String = "Bronze"
var _boards: Dictionary = {}   # key -> board 节点 Dictionary（tscn 静态节点引用）
var _content: Control = null
var _result_label: Label = null
var _status_label: Label = null
var _preview_label: Label = null
var _preview_container: HBoxContainer = null
var _board_host: Control = null   # .tscn %BoardHost（3 board 挂载点）
var _refresh_timer: float = 0.0


func setup_panel(p_player: PlayerData, rng: BattleRng) -> void:
	hud_identity = "tavern"   # T4：原 apply/remove override 样板上收基类
	_player = p_player
	_rng = rng
	_cm = p_player.cm
	setup()
	_build_content()


# 静态结构 instantiate + 面板级节点引用 + 3 board 绑定（fill 文案/费用 + 信号 connect）。
func _build_content() -> void:
	_content = CONTENT_SCENE.instantiate() as Control
	container.add_child(_content)
	_board_host = _content.get_node("%BoardHost") as Control
	_result_label = _content.get_node("%ResultLabel") as Label
	_status_label = _content.get_node("%StatusLabel") as Label
	_preview_container = _content.get_node("%PreviewContainer") as HBoxContainer
	_preview_label = _content.get_node("%PreviewLabel") as Label
	var close_btn: TextureButton = _content.get_node("%CloseBtn") as TextureButton
	close_btn.pressed.connect(remove_window)
	_bind_boards()
	_refresh_countdown_label()


# 源 createItemLayer:1371：3 board 装配 + 末尾 playLightAnim（源 :1397 gold/magic light 旋转）。
# board 静态结构在 tscn，此处只 bind（fill 文案/费用 + connect）+ 播动画。
func _bind_boards() -> void:
	for i in POOL_KEYS.size():
		var key: String = POOL_KEYS[i]
		var src_key: String = _src_key(key)
		var cost_info: Dictionary = _read_cost_info(key)
		var texts: Dictionary = _build_board_texts(src_key)
		var board: Dictionary = _bind_board(key, cost_info, texts)
		_boards[key] = board
		_play_light_anim(board)
		_play_arrow_float_anim(board)
	_refresh_magic_board_visibility()


# 绑定单张 board：tscn %XxxBoard 容器 + 相对路径取内部节点（board 内节点用通用名，
# 不开 unique_name_in_owner——owner 级唯一，3 board 同名会冲突）+ fill + connect。
# 返回 {container, scroll_board, check_btn, arrow_btn, once_btn, ten_btn,
#   once_cost_lbl, ten_cost_lbl, box, light}（键名沿 builder 期约定，测试锚定）。
func _bind_board(key: String, cost_info: Dictionary, texts: Dictionary) -> Dictionary:
	# tscn 节点前缀：MagicSoul 池键对应短名 Magic（%MagicBoard）
	var board_id: String = "Magic" if key == "MagicSoul" else key
	var container: Control = _content.get_node("%" + board_id + "Board") as Control
	var scroll: Control = container.get_node("Clip/Scroll") as Control
	var check: TextureButton = scroll.get_node("CheckBtn") as TextureButton
	(check.get_node("CheckLabel") as Label).text = String(texts["check_label"])
	check.pressed.connect(_on_check_pressed.bind(key))
	var arrow: TextureButton = scroll.get_node("ArrowBtn") as TextureButton
	arrow.pressed.connect(_on_arrow_pressed.bind(key))
	# 十连区（bronze/gold/magic 共有）：费用 + 提示 + 按钮
	var ten_cost_lbl: Label = scroll.get_node("TenCostLabel") as Label
	ten_cost_lbl.text = str(int(cost_info.get("ten_cost", 0)))
	var ten_prompt: Label = scroll.get_node("TenPromptLabel") as Label
	ten_prompt.text = String(texts["ten_prompt_text"])
	var ten_buy: TextureButton = scroll.get_node("TenBuyBtn") as TextureButton
	(ten_buy.get_node("TenBuyLabel") as Label).text = String(texts["ten_label"])
	ten_buy.pressed.connect(_on_ten_pressed.bind(key))
	# 单抽区（源 magic 无 one 条目 → tscn 无单抽区，once_btn 为 null）
	var once_btn: TextureButton = scroll.get_node_or_null("OneBuyBtn") as TextureButton
	var once_cost_lbl: Label = null
	if once_btn != null:
		(once_btn.get_node("OneBuyLabel") as Label).text = String(texts["once_label"])
		once_btn.pressed.connect(_on_once_pressed.bind(key))
		once_cost_lbl = scroll.get_node("OneCostLabel") as Label
		once_cost_lbl.text = str(int(cost_info.get("once_cost", 0)))
	# magic drop_bg 标题（源 drop_day_title :1113 / drop_month_title :1139）
	if key == "MagicSoul":
		(scroll.get_node("DayTitle") as Label).text = String(texts["day_title"])
		(scroll.get_node("MonthTitle") as Label).text = String(texts["month_title"])
	return {
		"container": container,
		"scroll_board": scroll,
		"check_btn": check,
		"arrow_btn": arrow,
		"once_btn": once_btn,
		"ten_btn": ten_buy,
		"once_cost_lbl": once_cost_lbl,
		"ten_cost_lbl": ten_cost_lbl,
		"box": scroll.get_node("Box") as TextureRect,
		"light": scroll.get_node_or_null("Light") as TextureRect,
	}


# showvip > vip → magicLayer.setVisible(false)（源同时重排 bronze/gold 居中；本项目简化保 3 board 横排孔位）。
# showvip <= vip → magicLayer.setVisible(true)（达 unlock-2 起显示；达 unlock 可抽，_on_draw 内门控）。
func _refresh_magic_board_visibility() -> void:
	if _player == null or _cm == null:
		return
	var showvip: int = VipData.get_area_show_vip(MAGIC_VIP_KEY, _cm)
	var magic_board: Dictionary = _boards.get("MagicSoul", {})
	if magic_board.is_empty():
		return
	var container: Control = magic_board.get("container", null)
	if container != null:
		container.visible = showvip <= _player.vip_level


func _build_board_texts(src_key: String) -> Dictionary:
	return {
		"check_label": _lstr_or(LSTR_CHECK, FALLBACK_CHECK),
		"once_label": _lstr_or(LSTR_BUY_D, FALLBACK_BUY_FMT) % 1,
		# magic ten_buy 标签照源 :1225 = BUY__D % 1（唯一按钮按单抽计费）
		"ten_label": _lstr_or(LSTR_BUY_D, FALLBACK_BUY_FMT) % (1 if src_key == "magic" else 10),
		"day_title": _lstr_or(LSTR_DAY_TITLE, FALLBACK_DAY_TITLE),
		"month_title": _lstr_or(LSTR_MONTH_TITLE, FALLBACK_MONTH_TITLE),
		"ten_prompt_text": _ten_prompt_text(src_key),
	}


func _ten_prompt_text(src_key: String) -> String:
	var lstr_key: StringName = LSTR_TEN_PROMPT.get(src_key, &"")
	if lstr_key == &"":
		return String(FALLBACK_TEN_PROMPT.get(src_key, ""))
	return _lstr_or(lstr_key, String(FALLBACK_TEN_PROMPT.get(src_key, "")))


# cm.get_lstr 缺失（返 key 本身）→ fallback。key 用 StringName 避免 String 比较开销。
func _lstr_or(key: StringName, fallback: String) -> String:
	if _cm == null or not _cm.has_method("get_lstr"):
		return fallback
	var v: String = _cm.get_lstr(String(key))
	return v if v != String(key) else fallback


func _src_key(pool_key: String) -> String:
	match pool_key:
		"Bronze": return "bronze"
		"Gold": return "gold"
		"MagicSoul": return "magic"
		_: return "bronze"


func _read_cost_info(key: String) -> Dictionary:
	var once_row: Dictionary = TavernData.get_tavern_info(key, false, false, 0, _cm)
	var ten_row: Dictionary = TavernData.get_tavern_info(key, true, false, 0, _cm)
	var once_cost: int = int(once_row.get("Cost", 0)) if not once_row.is_empty() else 0
	var once_pay: String = String(once_row.get("Cost Type", "Diamond")) if not once_row.is_empty() else "Diamond"
	return {
		"once_cost": once_cost,
		"ten_cost": int(ten_row.get("Cost", 0)),
		"once_pay": once_pay,
		"ten_pay": String(ten_row.get("Cost Type", "Diamond")),
	}


# 切当前 pool + 刷新倒计时/Magic 预览（供 _on_check_pressed 与外部切池调用，不触滑动）。
func _select_pool(key: String) -> void:
	_current_pool = key
	_refresh_countdown_label()
	_refresh_magicsoul_preview(key)


func _on_check_pressed(key: String) -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	_select_pool(key)
	_expand_scroll((_boards[key] as Dictionary)["scroll_board"] as Control)


func _on_arrow_pressed(key: String) -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	_collapse_scroll((_boards[key] as Dictionary)["scroll_board"] as Control)


func _on_once_pressed(key: String) -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	_on_draw(_player, _rng, key, false)


func _on_ten_pressed(key: String) -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	_on_draw(_player, _rng, key, true)


# 源 doClickCheck:1576：scroll_board CCMoveTo(0.2,(0,320)) EaseSineIn（cocos y 向上 320
# = Godot y 向下 -320）→ Tween TRANS_SINE EASE_IN。
func _expand_scroll(scroll: Control) -> void:
	var tw: Tween = scroll.create_tween()
	tw.tween_property(scroll, "position:y", -SLIDE_OFFSET, SLIDE_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


# 源 doClickArrow:1584：CCMoveTo(0.2,(0,0)) EaseSineOut。
func _collapse_scroll(scroll: Control) -> void:
	var tw: Tween = scroll.create_tween()
	tw.tween_property(scroll, "position:y", 0.0, SLIDE_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


# 源 playLightAnim :577-590 gold/magic light CCRotateBy(5,360) RepeatForever。
# TextureRect rotation 绕 pivot_offset，照源 Sprite anchor(0.5,0.5) → pivot=size/2。
func _play_light_anim(board: Dictionary) -> void:
	var light: TextureRect = board.get("light", null)
	if light == null:
		return
	light.pivot_offset = light.size * 0.5
	var tw: Tween = light.create_tween().set_loops()
	tw.tween_property(light, "rotation", deg_to_rad(FULL_CIRCLE_DEG), LIGHT_ROTATE_SEC)


# 源 tavern.lua:566-574 getArrowudAnim：arrow MoveBy(1,(0,-5)) SineInOut ↔ reverse 循环。
func _play_arrow_float_anim(board: Dictionary) -> void:
	var arrow: TextureButton = board.get("arrow_btn", null)
	if arrow == null or not arrow.is_inside_tree():
		return
	var base_y: float = arrow.position.y
	var tw: Tween = arrow.create_tween().set_loops()
	tw.tween_property(arrow, "position:y", base_y + ARROW_FLOAT_OFFSET_Y, ARROW_FLOAT_SEC) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(arrow, "position:y", base_y, ARROW_FLOAT_SEC) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	arrow.set_meta(&"arrow_float_active", true)   # headless 测试查 meta（Tween 推进不可靠）


# magic scroll_board drop_bg heroIcons 4 组（照源 left3+right1+day3+month1）+
# 面板级 _preview_container 单行（兼容 test_tavern_magic，前 4 hero）。
func _refresh_magicsoul_preview(key: String) -> void:
	if _preview_label == null or _preview_container == null:
		return
	if key == "MagicSoul" and _rng != null:
		var ids: Array[int] = TavernData.ask_magicsoul(_rng)
		_preview_label.text = "今日魂匣预览："
		_preview_label.visible = true
		# 面板级预览（兼容 test_tavern_magic，单行横排前 4 hero：extra+3hero）
		for c in _preview_container.get_children(): c.queue_free()
		for i in range(mini(ids.size(), 4)):
			var icon := _make_hero_preview_icon(ids[i])
			if icon != null:
				_preview_container.add_child(icon)
		_preview_container.visible = true
		# magic scroll_board drop_bg heroIcons 4 组（照源 doRefrehMagicHeroIcon:1290）
		_fill_magic_heroicons(ids)
	else:
		_preview_label.visible = false
		_preview_container.visible = false


# ids[0]=extra(hids[1]→right/month) ids[1,2,3]=hero(hids[2,3,4]→left/day)，照源 hids[5,6] 未用。
func _fill_magic_heroicons(ids: Array[int]) -> void:
	var magic: Dictionary = _boards.get("MagicSoul", {})
	if magic.is_empty():
		return
	var scroll: Control = magic["scroll_board"]
	# 清旧 heroIcons（set_meta "magic_icon" 标记）
	for c in scroll.get_children():
		if c.has_meta("magic_icon"):
			c.queue_free()
	if ids.is_empty():
		return
	var extra_id: int = ids[0]
	var hero_ids: Array[int] = []
	for i in range(1, mini(ids.size(), 4)):
		hero_ids.append(ids[i])
	# left 3 hero（源 ccp(42,175)/(82,175)/(122,175)，ox=42 dx=40）
	for i in hero_ids.size():
		_add_magic_icon(scroll, hero_ids[i], 42.0 + 40.0 * float(i), 175.0)
	# right 1 extra（源 ccp(175,175)）
	_add_magic_icon(scroll, extra_id, 175.0, 175.0)
	# day 3 hero（源 ccp(66,-140)/(108,-140)/(150,-140)，ox=66 dx=42）
	for i in hero_ids.size():
		_add_magic_icon(scroll, hero_ids[i], 66.0 + 42.0 * float(i), -140.0)
	# month 1 extra（源 ccp(107,-63)）
	_add_magic_icon(scroll, extra_id, 107.0, -63.0)


func _add_magic_icon(scroll: Control, tid: int, cx: float, cy: float) -> void:
	var icon := _make_hero_preview_icon(tid)
	if icon == null:
		return
	icon.set_meta("magic_icon", true)
	icon.custom_minimum_size = Vector2(38.0, 38.0)
	icon.size = Vector2(38.0, 38.0)
	icon.position = Vector2(cx, CLIP_H - cy) - icon.size * 0.5
	scroll.add_child(icon)


func _make_hero_preview_icon(tid: int) -> Control:
	# 源 tavern.lua:1307/1318/1332/1344 readhero.createIcon({id=id, length=38}).icon：
	# 头像图标（品质框，info 无 rank → 源默认 1；length=38 → container 104 缩 38/104）。
	# 2026-08-22 巡检订正：旧 Label 文本降级（位置/布局照源唯独内容是文字）。包 38×38
	# Control wrapper 参与容器布局，ReadheroIcon 挂内部 scale 居中。
	var wrap := Control.new()
	wrap.custom_minimum_size = Vector2(38.0, 38.0)
	wrap.size = Vector2(38.0, 38.0)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := ReadheroIcon.new()
	icon.setup({"id": tid, "rank": 1}, _cm)
	var s: float = 38.0 / ReadheroIcon.CONTAINER_SIZE.x
	icon.scale = Vector2(s, s)
	icon.position = -ReadheroIcon.CONTAINER_SIZE * s * 0.5
	wrap.add_child(icon)
	return wrap


func _on_draw(p_player: PlayerData, rng: BattleRng, tavern_type: String, is_ten: bool) -> void:
	# 项目单机化用 Toast（源 toRecharge dialog 的 explaination 文案）。
	if tavern_type == "MagicSoul":
		var ulv: int = VipData.get_area_unlock_vip(MAGIC_VIP_KEY, _cm)
		if ulv > p_player.vip_level:
			var tpl: String = String(_cm.get_lstr("TAVERN.VIP_LEVEL_TO_D_LEVELS_TO_UNLOCK_THIS_FEATURE_NEED_CHARGE"))
			if tpl == "TAVERN.VIP_LEVEL_TO_D_LEVELS_TO_UNLOCK_THIS_FEATURE_NEED_CHARGE":
				tpl = "VIP等级达到%d级解锁该功能，是否充值？"
			_result_label.text = tpl % ulv
			return
	var now: int = int(Time.get_unix_time_from_system())
	var is_free: bool = TavernData.is_show_free(p_player, tavern_type, now) and (tavern_type == "MagicSoul" or not is_ten)
	var r: Dictionary = p_player.draw_tavern_full(tavern_type, is_ten, is_free, 0, rng)
	if not bool(r["ok"]):
		_result_label.text = "资源不足"
		return
	if is_free:
		TavernData.use_free_tavern(p_player, tavern_type, now)
	TavernData.refresh_first_tavern(p_player, tavern_type, is_ten)
	GameData.mark_save_dirty()
	_result_label.text = "产出已展示"
	var loot_popup := PopTavernLoot.new("poptavernloot", {})
	var popup_cost: Dictionary = {"pay": "Diamond", "number": 0}
	if not is_free:
		var row: Dictionary = TavernData.get_tavern_info(tavern_type, is_ten, false, 0, _cm)
		popup_cost = {"pay": String(row.get("Cost Type", "Diamond")), "number": int(row.get("Cost", 0))}
	loot_popup.setup_loot(r["loots"], p_player.cm, tavern_type.to_lower(), "ten" if is_ten else "one", popup_cost)
	loot_popup.show_window(get_parent())
	drawn.emit()
	_refresh_countdown_label()


# 免费状态刷新（源 getCountdownText：CD 倒计时 / bronze 剩余次数）。
func _refresh_countdown_label() -> void:
	if _player == null or _status_label == null:
		return
	var now: int = int(Time.get_unix_time_from_system())
	_status_label.text = String(TavernData.get_countdown_text(_player, _current_pool, now)["text"])


func _process(delta: float) -> void:
	_refresh_timer += delta
	if _refresh_timer >= REFRESH_INTERVAL_SEC:
		_refresh_timer = 0.0
		_refresh_countdown_label()
