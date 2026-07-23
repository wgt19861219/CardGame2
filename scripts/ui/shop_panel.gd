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
var _refresh_cost_label: Label       # 源 shop_refresh_cost_bg + 价格（按钮上方）
var _talk_label: Label             # NPC 对话气泡（照源 shop.lua:19 showTalk）
var _next_refresh_label: Label     # 下次自动刷新时刻（照源 getShopNextAutoRefreshPointDesc）
var _head_touch: Control           # NPC 头像触摸层（点头像→Touch，源 shop.lua:940 head_button）
var _talk_tween: Tween = null      # 对话淡出动画（源 showTalk CCFadeOut）
var _auto_refresh_accum: float = 0.0   # _process 自动刷新轮询累加器


func setup_panel(p_shop_id: int, p_mgr: ShopManager, p_pd: PlayerData, p_rng: BattleRng) -> void:
	shop_id = p_shop_id
	shop_mgr = p_mgr
	pd = p_pd
	rng = p_rng
	cm = pd.cm
	_config = MarketConfig.get_type_config(shop_id)
	setup()
	# shop 是 pushScene 独立场景（main.lua:1378），framework.lua:749 自动铺全屏 bg.jpg。
	# 单机化用 PopWindow 弹窗替代 pushScene → shade 透明 + .tscn %FrameworkBg 补 bg.jpg。
	if shade_layer != null:
		shade_layer.color.a = 0
		shade_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shop_mgr.open_shop(shop_id, rng, cm)
	shop_mgr.init_auto_refresh(shop_id, pd, _now())         # 源 local_server:1219 open_shop 设 _last_auto_refresh_time
	shop_mgr.init_expire(shop_id, pd, _now())               # 源 local_server:1316 open_shop 设 _expire_time
	shop_mgr.check_auto_refresh(shop_id, pd, _now(), rng)   # 源 up.proto:260 到点 auto_refresh 触发
	_build_content()
	register_on_enter(func() -> void:
		AudioPlayer.play_sfx("common_popup_window")
		_show_talk("Welcome"))   # 源 shop.lua:920 进店 Welcome（进场后触发，已入树）


# 建 UI 内容。Phase base 层从 .tscn instantiate + fill 动态数据；商品列表 procedural 挂 %ItemLayer。
func _build_content() -> void:
	var content: Control = CONTENT_SCENE.instantiate() as Control
	container.add_child(content)
	_panel_layer = content.get_node("%PanelLayer") as Control
	ShopBuilder.setup_panel_layer(_panel_layer, _config)
	# 绑定 .tscn 静态按钮/区域
	(_panel_layer.get_node("%CloseBtn") as BaseButton).pressed.connect(func() -> void:
		AudioPlayer.play_sfx("common_close_popup_window")   # 源 closeWindow
		remove_window())
	(_panel_layer.get_node("%RefreshBtn") as BaseButton).pressed.connect(_on_refresh)
	# 源 shop.lua:940 head_button（点头像→Touch）。
	_head_touch = _panel_layer.get_node("%HeadTouch") as Control
	_head_touch.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
			_show_talk("Touch"))
	# 动态数据节点引用
	_money_label = _panel_layer.get_node("%MoneyLabel") as Label
	_refresh_cost_label = _panel_layer.get_node("%RefreshCostLabel") as Label
	_talk_label = _panel_layer.get_node("%TalkLabel") as Label
	_talk_label.modulate.a = 0.0   # 初始隐藏（淡入时设 a=1）
	_next_refresh_label = _panel_layer.get_node("%TimeLabel") as Label
	_item_layer = _panel_layer.get_node("%ItemLayer") as Control
	_refresh_money()
	_build_goods()
	_update_refresh_label()
	_update_next_refresh_label()


# 源 createCommon：两行商品列表（getItemPos :371-382）。先 free 老 item 再建（_rebuild 用）。
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
	return func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
			_on_buy(slot)


# 源 doClickInProduct:239-279 + openBuyPanel:314-322 + doBuy:167-188。
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
		_show_talk("Soldout")   # 源 shop.lua:246 点售罄商品
		Toast.show_message("已售罄")
		return
	# 源 openBuyPanel:314-322 equipboard.init("ofbuy", data)。data 字段照源 createCommon:343-358。
	var amount: int = int(g.get("amount", 1))
	var price: int = int(g.get("price", 0))
	var cost: int = price * maxi(amount, 1)   # 源 createCommon:351 cost = price * max(amount,1)
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
			Toast.show_message("购买成功")   # 源 shop.lua:122 硬编码字面量（非 LSTR）
			_show_talk("Purchase")   # 源 shop.lua:130 购买后对话
		else:
			# 照源 buy 失败区分：slot 越界 / amount<=0 → 售罄；否则货币不足。
			var goods2: Array = shop_mgr.get_goods(shop_id)
			var sold_out: bool = true
			if slot >= 0 and slot < goods2.size():
				var g2: Dictionary = goods2[slot]
				sold_out = int(g2.get("amount", 0)) <= 0
			if sold_out:
				_show_talk("Soldout")
			# 源 shop.lua:173/175 "金币不足"/"钻石不足" 硬编码字面量；interfax/gladiator 才走 LSTR（本项目统一降级字面量）。
			Toast.show_message("已售罄" if sold_out else "货币不足")
		call_deferred("_rebuild")


# 源 doClickRefresh + shop_refresh（:302-313）。P1-8 照源 showConfirmDialog → 独立 ShopRefreshConfirm。
func _on_refresh() -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	var cost: int = shop_mgr.get_refresh_cost(shop_id, cm)
	if pd.diamond < cost:
		Toast.show_message("钻石不足（需 %d）" % cost)
		return
	# 源 :307-308 SHOP.SPEND_XXX_TO_REFRESH（3 参：cost/coinname/refreshshoptimes）。
	# coinname 源 config.getRefreshCoinName 返 i18n 货币名，本项目降级"钻石"字面量（无对应货币名 LSTR key）。
	# refreshshoptimes 源 getRefreshShopTimes 返剩余次数，本项目 get_refresh_times 返已用次数（无刷新上限，语义差异）。
	var coinname: String = "钻石"
	var times: int = shop_mgr.get_refresh_times(shop_id)
	var popup := ShopRefreshConfirm.new()
	popup.set_message(String(cm.get_lstr("SHOP.SPEND_XXX_TO_REFRESH")) % [cost, coinname, times], cm)
	popup.confirmed.connect(_on_refresh_confirmed)
	container.add_child(popup)


# 源 :309 rightHandler（确认框确认）→ doSendRefresh。
func _on_refresh_confirmed() -> void:
	if shop_mgr.refresh(shop_id, pd, rng, cm):
		Toast.show_message("刷新成功")
		_show_talk("Refresh")   # 源 shop.lua:281 手动刷新对话
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


# 源 shop.lua:19-73 showTalk：getTalkContent 选词 + 显示气泡 + 淡出（CCFadeOut）。无台词静默。
func _show_talk(key: String) -> void:
	var ttype: String = shop_mgr.get_time_type(shop_id, pd, _now())
	var text: String = MerchantTalkData.get_talk_content(shop_id, key, ttype, rng, cm)
	if text == "":
		return
	if _talk_tween and _talk_tween.is_valid():
		_talk_tween.kill()
	_talk_label.text = text
	_talk_label.modulate.a = 1.0
	if is_inside_tree():   # 未入树（setup 早期）只显示不动画，避 create_tween 失效
		_talk_tween = create_tween()
		_talk_tween.tween_interval(2.5)
		_talk_tween.tween_property(_talk_label, "modulate:a", 0.0, 0.8)


# 运行中轮询（源 shop.lua timeRefresh:648-698 每秒）：① 到期检查（地精/黑市停留 3600s）② 自动刷新（Refresh Times 点）③ 时刻 Label 刷新。
func _process(delta: float) -> void:
	_auto_refresh_accum += delta
	if _auto_refresh_accum < AUTO_REFRESH_CHECK_INTERVAL:
		return
	_auto_refresh_accum = 0.0
	# 源 shop.lua:686-694 tc<0 and state=="expire" → showTalk(Expire)+alertDialog+popScene+停 update
	if shop_mgr.check_expire(shop_id, pd, _now()):
		_on_expire()
		return
	if shop_mgr.check_auto_refresh(shop_id, pd, _now(), rng):
		_rebuild()
		_show_talk("Refresh")
	_update_next_refresh_label()   # 源 :662 每秒 setString（expire 倒计时 / refresh 描述）


# 源 shop.lua:686-694 到期：showTalk(Expire) + alertDialog("神秘商人已漂走") + popScene。
# 单机化：Toast 替 alertDialog + remove_window + clear_expire（常驻按钮再点重计，源 NPC 消失等价）。
func _on_expire() -> void:
	_show_talk("Expire")
	Toast.show_message(String(cm.get_lstr("SHOP.THE_MYSTERIOUS_BUSINESSMAN_HAS_DRIFTED_AWAY_PLEASE_BE_QUICK_NEXT_TIME")))
	shop_mgr.clear_expire(shop_id, pd)
	call_deferred("remove_window")
