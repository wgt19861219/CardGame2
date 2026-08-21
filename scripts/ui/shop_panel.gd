class_name ShopPanel
extends PopWindow

## 商店主面板（View 层）— 照源 ui/market/shop.lua create(764-917) + createCommon(325-510)。
## 重构（2026-07-17）：base 层（frame/title/head/refresh/time/talk/close + bg.jpg）静态化进
## shop_content.tscn（位置/size 编辑器可视化调）。
## 两件套范式（2026-08-14）：静态结构在 shop_content.tscn + shop_item.tscn 模板；
## 本文件只做业务 + 信号 + fill（fill 归 panel，旧 builder 退役；商品行 ShopRowBuilder）。
## 底框 + NPC 头像 + 标题底图/标题 + 刷新按钮 + 商品列表（两行 getItemPos）+ 购买闭环。
## 单机化：源 net shop_* → ShopManager Logic；NPC 对话 + 自动刷新时刻照源。
## 坐标：源 cocos(800×480 左下)→Godot(800×480 左上) via (cx, 480-cy)；
## PanelLayer 作 frame sprite Godot 等价（左上原点 = to_godot(framePos) - frame_size/2），子元素坐标相对 PanelLayer。
## CS：源 hello.lua:311 setContentScaleFactor=1.28125，CCSprite 显示=纹理/CS。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/shop_content.tscn")
const AUTO_REFRESH_CHECK_INTERVAL: float = 1.0   # _process 自动刷新轮询间隔（秒，源客户端 auto_refresh 轮询）
# 两件套范式（2026-08-14）：fill 归 panel，builder 退役。坐标换算照源 cocos(800×480 左下)→Godot(800×480 左上)。
const UI_DIR: String = "res://assets/ui/alpha/HVGA/"
# 源 shop.lua:198 商品按下 setScale(0.95)。
const ITEM_PRESS_SCALE: Vector2 = Vector2(0.95, 0.95)
const ITEM_PRESS_SEC: float = 0.1

var shop_id: int = 1
var shop_mgr: ShopManager
var cm: Variant = null
var pd: PlayerData = null
var rng: BattleRng
var _config: Dictionary = {}
var _panel_layer: Control
var _item_layer: Control
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
	_setup_panel_layer()
	# 绑定 .tscn 静态按钮/区域
	# CloseBtn 挂场景根（屏幕左上 20,15，项目惯例 crusade/dungeon 同款；挂 PanelLayer 内会压 NPC 头像）。
	(content.get_node("%CloseBtn") as BaseButton).pressed.connect(func() -> void:
		AudioPlayer.play_sfx("common_close_popup_window")
		remove_window())
	(_panel_layer.get_node("%RefreshBtn") as BaseButton).pressed.connect(_on_refresh)
	_head_touch = _panel_layer.get_node("%HeadTouch") as Control
	_head_touch.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
			_show_talk("Touch"))
	# 动态数据节点引用（Task 5 三轮：源无 MoneyLabel/RefreshCostLabel——货币走 HUD、
	# 刷新花费走确认弹窗，迁移期发明元素已删）
	_talk_label = _panel_layer.get_node("%TalkLabel") as Label
	_talk_label.modulate.a = 0.0   # 初始隐藏（淡入时设 a=1）
	_talk_bg = _panel_layer.get_node("%TalkBg") as NinePatchRect   # TalkBg 已静态化进 .tscn
	_next_refresh_label = _panel_layer.get_node("%TimeLabel") as Label
	_item_layer = _panel_layer.get_node("%ItemLayer") as Control
	_build_goods()
	_update_next_refresh_label()
	# HudOverlay 切 identity=shop。




func _build_goods() -> void:
	for c in _item_layer.get_children():
		c.free()
	var goods: Array = shop_mgr.get_goods(shop_id)
	var items: Array = ShopRowBuilder.build_goods(_item_layer, goods, _config, cm)
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
			_tween_item_scale(item, ITEM_PRESS_SCALE)
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
	_press_tween.tween_property(item, "scale", target, ITEM_PRESS_SEC) \
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
	# pd 传弹窗（源 board.lua initAmount equip_qunty 拥有行 + initAtt 碎片 X/Y 用）
	popup.setup_panel({
		"id": int(g.get("id", 0)),
		"amount": amount,
		"pay": String(g.get("type", "gold")),
		"price": price,
		"cost": cost,
	}, cm, pd)
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
	_update_next_refresh_label()


func _update_next_refresh_label() -> void:
	var tt: String = shop_mgr.get_time_type(shop_id, pd, _now())
	if tt == "expire":
		var exp: String = shop_mgr.get_expire_desc(shop_id, pd, _now())
		_next_refresh_label.text = (String(cm.get_lstr("SHOP.MERCHANT_LEAVES_AFTER")) + " " + exp + " " + String(cm.get_lstr("SHOP.TIMES"))) if exp != "" else ""
		return
	var desc: String = shop_mgr.get_next_refresh_desc(shop_id, pd, _now())
	_next_refresh_label.text = (String(cm.get_lstr("SHOP.NEXT_AUTOMATICALLY_REFRESH_TIME")) + desc) if desc != "" else ""


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
		# 源 talkBg 宽 = label 宽 + 30（Scale9 动态拉宽）；label 左距 20 → bg 宽 = label + 20 + 右余量
		_talk_bg.size.x = _talk_label.get_combined_minimum_size().x + 20.0
	if is_inside_tree():   # 未入树（setup 早期）只显示不动画，避 create_tween 失效
		_talk_tween = create_tween()
		_talk_tween.tween_interval(2.5)
		_talk_tween.set_parallel(true)
		_talk_tween.tween_property(_talk_label, "modulate:a", 0.0, 0.8)
		if _talk_bg != null:
			_talk_tween.tween_property(_talk_bg, "modulate:a", 0.0, 0.8)


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


# 两件套：PanelLayer rect 纯 tscn 静态（三型商店 frameRes 均为 shop_bg.png，源无逐型定位）；
# 运行时只按 shop 类型填贴图/文字。
func _setup_panel_layer() -> void:
	_fill_texture(_panel_layer.get_node("%Bg") as TextureRect, UI_DIR + String(_config["frameRes"]))
	_fill_texture(_panel_layer.get_node("%Head") as TextureRect, UI_DIR + String(_config.get("headRes", "")))
	(_panel_layer.get_node("%Title") as Label).text = String(_config.get("titleText", ""))


func _fill_texture(rect: TextureRect, path: String) -> void:
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	rect.texture = load(path) as Texture2D
