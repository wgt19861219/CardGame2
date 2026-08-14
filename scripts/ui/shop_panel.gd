class_name ShopPanel
extends PopWindow

## 商店主面板（View 层）— 照源 ui/market/shop.lua create(764-917) + createCommon(325-510)。
## 重构（2026-07-17）：base 层（frame/title/head/refresh/time/talk/close/money + bg.jpg）静态化进
## shop_content.tscn（位置/size 编辑器可视化调）。ShopBuilder fill 动态数据 + 商品列表 procedural。
## 底框 + NPC 头像 + 标题 + 刷新按钮 + 商品列表（两行 getItemPos）+ 购买闭环。
## 单机化：源 net shop_* → ShopManager Logic；NPC 对话 + 自动刷新时刻照源。
## 坐标：源 cocos(800×480 左下)→Godot(960×640 左上) via (cx+80, 560-cy)；
## PanelLayer 作 frame sprite Godot 等价（左上原点 = to_godot(framePos) - frame_size/2），子元素坐标相对 PanelLayer。
## CS：源 hello.lua:311 setContentScaleFactor=1.28125，CCSprite 显示=纹理/CS。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/shop_content.tscn")
# 源 shop.lua:33-44 talkBg Scale9 frame（capInsets 30,15,110,26）+ talk Label。
# TalkLabel 在 .tscn 已建；本项目补 talk_bg Scale9 气泡背景（shop_talk_bg.png）。
const TALK_BG_RES: String = "res://assets/ui/alpha/HVGA/shop_talk_bg.png"
const TALK_BG_CAP: Rect2 = Rect2(30.0, 15.0, 110.0, 26.0)
# talkBg 源 anchor(0,0.5) ccp(190,360)（talk bg 左中），talk Label 同 anchor ccp(190+10,360)。
# .tscn TalkLabel 已固定位置，bg 衬其下：bg 左上对齐 TalkLabel 左边 + 一定 padding。
const TALK_BG_PADDING: Vector2 = Vector2(-10.0, -10.0)
const TALK_BG_SIZE_PAD: Vector2 = Vector2(20.0, 20.0)
const AUTO_REFRESH_CHECK_INTERVAL: float = 1.0   # _process 自动刷新轮询间隔（秒，源客户端 auto_refresh 轮询）

var shop_id: int = 1
var shop_mgr: ShopManager
var cm: Variant = null
var pd: PlayerData = null
var rng: BattleRng
var _config: Dictionary = {}
var _panel_layer: Control
var _item_layer: Control
var _money_label: Label
var _refresh_cost_label: Label
var _talk_label: Label             # NPC 对话气泡（照源 shop.lua:19 showTalk）
var _next_refresh_label: Label     # 下次自动刷新时刻（照源 getShopNextAutoRefreshPointDesc）
var _head_touch: Control           # NPC 头像触摸层（点头像→Touch，源 shop.lua:940 head_button）
var _talk_tween: Tween = null      # 对话淡出动画（源 showTalk CCFadeOut）
var _talk_bg: NinePatchRect = null  # P1 talkBg Scale9 气泡背景（源 shop.lua:33-44）
var _press_tween: Tween = null     # 商品按下 scale Tween（源 shop.lua:198 setScale 0.95）
var _auto_refresh_accum: float = 0.0   # _process 自动刷新轮询累加器


func setup_panel(p_shop_id: int, p_mgr: ShopManager, p_pd: PlayerData, p_rng: BattleRng) -> void:
	play_open_sfx = true   # T4：原 register_on_enter 音效样板上收基类
	hud_identity = "shop"   # T4：原 apply/remove override 样板上收基类
	transparent_shade = true   # T4：原 shade 透明 hack 上收基类
	shop_id = p_shop_id
	shop_mgr = p_mgr
	pd = p_pd
	rng = p_rng
	cm = pd.cm
	_config = MarketConfig.get_type_config(shop_id)
	setup()
	# shop 是 pushScene 独立场景（main.lua:1378），framework.lua:749 自动铺全屏 bg.jpg。
	# 单机化用 PopWindow 弹窗替代 pushScene → shade 透明 + .tscn %FrameworkBg 补 bg.jpg。
	shop_mgr.open_shop(shop_id, rng, cm)
	shop_mgr.init_auto_refresh(shop_id, pd, _now())
	shop_mgr.init_expire(shop_id, pd, _now())
	shop_mgr.check_auto_refresh(shop_id, pd, _now(), rng)
	_build_content()
	register_on_enter(func() -> void:
		_show_talk("Welcome"))


# 建 UI 内容。Phase base 层从 .tscn instantiate + fill 动态数据；商品列表 procedural 挂 %ItemLayer。
func _build_content() -> void:
	var content: Control = CONTENT_SCENE.instantiate() as Control
	container.add_child(content)
	_panel_layer = content.get_node("%PanelLayer") as Control
	ShopBuilder.setup_panel_layer(_panel_layer, _config)
	# 绑定 .tscn 静态按钮/区域
	(_panel_layer.get_node("%CloseBtn") as BaseButton).pressed.connect(func() -> void:
		AudioPlayer.play_sfx("common_close_popup_window")
		remove_window())
	(_panel_layer.get_node("%RefreshBtn") as BaseButton).pressed.connect(_on_refresh)
	_head_touch = _panel_layer.get_node("%HeadTouch") as Control
	_head_touch.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
			_show_talk("Touch"))
	# 动态数据节点引用
	_money_label = _panel_layer.get_node("%MoneyLabel") as Label
	_refresh_cost_label = _panel_layer.get_node("%RefreshCostLabel") as Label
	_talk_label = _panel_layer.get_node("%TalkLabel") as Label
	_talk_label.modulate.a = 0.0   # 初始隐藏（淡入时设 a=1）
	_add_talk_bubble()   # P1 talkBg Scale9 气泡背景（源 shop.lua:33-44）
	_next_refresh_label = _panel_layer.get_node("%TimeLabel") as Label
	_item_layer = _panel_layer.get_node("%ItemLayer") as Control
	_refresh_money()
	_build_goods()
	_update_refresh_label()
	_update_next_refresh_label()
	# HudOverlay 切 identity=shop。




func _build_goods() -> void:
	for c in _item_layer.get_children():
		c.free()
	var goods: Array = shop_mgr.get_goods(shop_id)
	var items: Array = ShopBuilder.build_goods(_item_layer, goods, _config, cm)
	# 商品 item gui_input → 购买（按 slot 索引）。源 doClickInProduct。
	for i in items.size():
		var item: Control = items[i]
		item.gui_input.connect(_make_buy_handler(i))


func _make_buy_handler(slot: int) -> Callable:
	# 源 shop.lua:198 product panel 按下 setScale(0.95)：press→缩到 0.95，release→回弹 1.0。
	# gui_input 在 press/release 都触发（不像 button.pressed 只在 release）；按状态切 Tween。
	var items: Array = _item_layer.get_children()
	return func(ev: InputEvent) -> void:
		if not (ev is InputEventMouseButton):
			return
		var mb: InputEventMouseButton = ev as InputEventMouseButton
		if slot < 0 or slot >= items.size():
			return
		var item: Control = items[slot]
		if not is_instance_valid(item):
			return
		if mb.pressed:
			_tween_item_scale(item, ShopBuilder.ITEM_PRESS_SCALE)
		else:
			_tween_item_scale(item, Vector2.ONE)
			if mb.button_index == MOUSE_BUTTON_LEFT:
				_on_buy(slot)


# 商品按下/松开 scale Tween（源 shop.lua:198 setScale 0.95 视觉反馈）。
# 不用 button.pressed 是因源 panel gui_input 拦截 press 即时反馈，松开才触发购买。
func _tween_item_scale(item: Control, target: Vector2) -> void:
	if not is_instance_valid(item):
		return
	if _press_tween != null and _press_tween.is_valid():
		_press_tween.kill()
	_press_tween = create_tween()
	_press_tween.tween_property(item, "scale", target, ShopBuilder.ITEM_PRESS_SEC) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


# C6（2026-07-23）：照源补 equipboard ofbuy 确认面板（源 openBuyPanel → equipboard.init("ofbuy", data)），
# 确认后触发 confirmed → _do_buy 实际 shop_mgr.buy（源 param.doBuy 闭包 → confirmed 信号）。
# 售罄商品照源 showTalk("Soldout") 不弹确认面板。
func _on_buy(slot: int) -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	var goods: Array = shop_mgr.get_goods(shop_id)
	if slot < 0 or slot >= goods.size():
		return
	var g: Dictionary = goods[slot]
	if int(g.get("amount", 0)) <= 0:
		_show_talk("Soldout")
		Toast.show_message("已售罄")
		return
	var amount: int = int(g.get("amount", 1))
	var price: int = int(g.get("price", 0))
	var cost: int = price * maxi(amount, 1)
	var popup := EquipboardOfbuyPanel.new("equipboardofbuy", {})
	popup.setup_panel({
		"id": int(g.get("id", 0)),
		"amount": amount,
		"pay": String(g.get("type", "gold")),
		"price": price,
		"cost": cost,
	}, cm)
	popup.confirmed.connect(_make_buy_confirm_handler(slot))
	container.add_child(popup)


# 实际购买执行（源 param.doBuy → doBuy:167-188 handler）。确认弹窗 confirmed 后触发。
func _make_buy_confirm_handler(slot: int) -> Callable:
	return func() -> void:
		var ok: bool = shop_mgr.buy(shop_id, slot, pd, cm)
		if ok:
			GameData.mark_save_dirty()
			Toast.show_message("购买成功")
			_show_talk("Purchase")
		else:
			var goods2: Array = shop_mgr.get_goods(shop_id)
			var sold_out: bool = true
			if slot >= 0 and slot < goods2.size():
				var g2: Dictionary = goods2[slot]
				sold_out = int(g2.get("amount", 0)) <= 0
			if sold_out:
				_show_talk("Soldout")
			Toast.show_message("已售罄" if sold_out else "货币不足")
		call_deferred("_rebuild")


func _on_refresh() -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	var cost: int = shop_mgr.get_refresh_cost(shop_id, cm)
	if pd.diamond < cost:
		Toast.show_message("钻石不足（需 %d）" % cost)
		return
	# coinname 源 config.getRefreshCoinName 返 i18n 货币名，本项目降级"钻石"字面量（无对应货币名 LSTR key）。
	# refreshshoptimes 源 getRefreshShopTimes 返剩余次数，本项目 get_refresh_times 返已用次数（无刷新上限，语义差异）。
	var coinname: String = "钻石"
	var times: int = shop_mgr.get_refresh_times(shop_id)
	var popup := ShopRefreshConfirm.new()
	popup.set_message(String(cm.get_lstr("SHOP.SPEND_XXX_TO_REFRESH")) % [cost, coinname, times], cm)
	popup.confirmed.connect(_on_refresh_confirmed)
	container.add_child(popup)


func _on_refresh_confirmed() -> void:
	if shop_mgr.refresh(shop_id, pd, rng, cm):
		Toast.show_message("刷新成功")
		_show_talk("Refresh")
	else:
		Toast.show_message("钻石不足")
	call_deferred("_rebuild")


func _rebuild() -> void:
	_build_goods()
	_update_refresh_label()
	_update_next_refresh_label()
	_refresh_money()


func _refresh_money() -> void:
	ShopBuilder.fill_money(_money_label, pd)


func _update_refresh_label() -> void:
	var cost: int = shop_mgr.get_refresh_cost(shop_id, cm)
	# cost 显示在按钮上方 Label（源按钮本身只显"刷新"，cost 在 confirm dialog SPEND_XXX_TO_REFRESH 内）。
	ShopBuilder.fill_refresh_cost(_refresh_cost_label, cost)


func _update_next_refresh_label() -> void:
	ShopBuilder.fill_time_label(_next_refresh_label, shop_id, shop_mgr, pd, _now(), cm)


func _now() -> int:
	return int(Time.get_unix_time_from_system())


func _show_talk(key: String) -> void:
	var ttype: String = shop_mgr.get_time_type(shop_id, pd, _now())
	var text: String = MerchantTalkData.get_talk_content(shop_id, key, ttype, rng, cm)
	if text == "":
		return
	if _talk_tween and _talk_tween.is_valid():
		_talk_tween.kill()
	_talk_label.text = text
	_talk_label.modulate.a = 1.0
	if _talk_bg != null:
		_talk_bg.modulate.a = 1.0   # 气泡背景与文字同步显隐
	if is_inside_tree():   # 未入树（setup 早期）只显示不动画，避 create_tween 失效
		_talk_tween = create_tween()
		_talk_tween.tween_interval(2.5)
		_talk_tween.set_parallel(true)
		_talk_tween.tween_property(_talk_label, "modulate:a", 0.0, 0.8)
		if _talk_bg != null:
			_talk_tween.tween_property(_talk_bg, "modulate:a", 0.0, 0.8)


# P1 源 shop.lua:33-44 talkBg Scale9 frame（shop_talk_bg.png cap 30,15,110,26）。
# 衬在 TalkLabel 下（z 低），随 talk 文字同步淡入淡出。.tscn TalkLabel 位置已固定，bg 跟随其 rect。
func _add_talk_bubble() -> void:
	if not ResourceLoader.exists(TALK_BG_RES):
		return
	_talk_bg = NinePatchRect.new()
	_talk_bg.texture = load(TALK_BG_RES) as Texture2D
	_talk_bg.patch_margin_left = int(TALK_BG_CAP.position.x)
	_talk_bg.patch_margin_top = int(TALK_BG_CAP.position.y)
	if _talk_bg.texture != null:
		_talk_bg.patch_margin_right = int(_talk_bg.texture.get_width()) - int(TALK_BG_CAP.position.x) - int(TALK_BG_CAP.size.x)
		_talk_bg.patch_margin_bottom = int(_talk_bg.texture.get_height()) - int(TALK_BG_CAP.position.y) - int(TALK_BG_CAP.size.y)
	# bg 跟随 TalkLabel rect + padding（衬其下）。
	_talk_bg.position = _talk_label.position + TALK_BG_PADDING
	_talk_bg.size = _talk_label.size + TALK_BG_SIZE_PAD
	_talk_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_talk_bg.modulate.a = 0.0   # 初始隐藏（_show_talk 时淡入）
	var label_idx: int = _talk_label.get_index()
	_panel_layer.add_child(_talk_bg)
	_panel_layer.move_child(_talk_bg, label_idx)   # bg 移到 label 前（z 低，label 绘其上）


# 运行中轮询（源 shop.lua timeRefresh:648-698 每秒）：① 到期检查（地精/黑市停留 3600s）② 自动刷新（Refresh Times 点）③ 时刻 Label 刷新。
func _process(delta: float) -> void:
	_auto_refresh_accum += delta
	if _auto_refresh_accum < AUTO_REFRESH_CHECK_INTERVAL:
		return
	_auto_refresh_accum = 0.0
	if shop_mgr.check_expire(shop_id, pd, _now()):
		_on_expire()
		return
	if shop_mgr.check_auto_refresh(shop_id, pd, _now(), rng):
		_rebuild()
		_show_talk("Refresh")
	_update_next_refresh_label()


# 单机化：Toast 替 alertDialog + remove_window + clear_expire（常驻按钮再点重计，源 NPC 消失等价）。
func _on_expire() -> void:
	_show_talk("Expire")
	Toast.show_message(String(cm.get_lstr("SHOP.THE_MYSTERIOUS_BUSINESSMAN_HAS_DRIFTED_AWAY_PLEASE_BE_QUICK_NEXT_TIME")))
	shop_mgr.clear_expire(shop_id, pd)
	call_deferred("remove_window")
