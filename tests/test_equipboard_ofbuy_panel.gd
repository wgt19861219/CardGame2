extends GutTest

## EquipboardOfbuyPanel 测试（C6 2026-07-23）— 照源 ui/equipboard/ofbuy.lua（202 行）。
## shop 商品点击购买时弹出的确认浮层：icon + name + 购买数量 + 货币图标 + 总价 + 确认按钮。
## 源 equipboard.init("ofbuy", data)：data={id, amount, pay, price, cost, doBuy}。
## 单机化：doBuy 闭包 → confirmed 信号（ShopPanel 连接执行 shop_mgr.buy）。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


# 源 ofbuy.lua create + initFrame + initWindow：frame + close + icon + name + amount + cost + 确认按钮
func test_setup_panel_assembles_nodes() -> void:
	var panel := EquipboardOfbuyPanel.new("equipboardofbuy", {})
	add_child(panel)
	panel.setup_panel({"id": 371, "amount": 1, "pay": "gold", "price": 100, "cost": 100}, cm)
	# frame 装配（源 board.lua:420 initFrame）
	assert_ne(panel.get("_frame"), null, "_frame 装配（源 initFrame）")
	var frame: Control = panel.get("_frame") as Control
	# icon + name + 购买标题 + 数量 + 后缀 + money_bg + money_icon + cost + 确认按钮 + close
	# 子节点数 ≥ 9（icon/name/title/amount/suffix/money_bg/money_icon/money_label/btn + close）
	assert_gte(frame.get_child_count(), 9, "frame 含 9+ 子节点（源 initFrame + initWindow）")
	panel.free()


# 源 ofbuy.lua:60-61 amount>1 → name="NamexN"；amount=1 → 原名
func test_equip_name_with_amount_suffix() -> void:
	var panel1 := EquipboardOfbuyPanel.new("equipboardofbuy", {})
	add_child(panel1)
	panel1.setup_panel({"id": 371, "amount": 1, "pay": "gold", "price": 100, "cost": 100}, cm)
	var name1: String = panel1._equip_name()
	assert_false(name1.ends_with("x1"), "amount=1 name 无 x1 后缀（源 :61 if amount>1）")
	panel1.free()
	var panel3 := EquipboardOfbuyPanel.new("equipboardofbuy", {})
	add_child(panel3)
	panel3.setup_panel({"id": 371, "amount": 3, "pay": "gold", "price": 100, "cost": 300}, cm)
	var name3: String = panel3._equip_name()
	assert_true(name3.ends_with("x3"), "amount=3 name 含 x3 后缀（源 :60 T(\"%sx%d\",name,amount)）")
	panel3.free()


# 源 ofbuy.lua:34-38 sell_button clickHandler → param.doBuy()；本项目 emit confirmed（ShopPanel 连接执行 buy）
func test_confirm_button_emits_signal() -> void:
	var panel := EquipboardOfbuyPanel.new("equipboardofbuy", {})
	add_child(panel)
	panel.setup_panel({"id": 371, "amount": 1, "pay": "gold", "price": 100, "cost": 100}, cm)
	var emitted := [false]
	panel.confirmed.connect(func() -> void: emitted[0] = true)
	panel._on_confirm()
	assert_true(emitted[0], "确认按钮 emit confirmed 信号（源 param.doBuy → confirmed）")
	# queue_free 延迟下帧，改测 is_inside_tree 标志（queue_free 当帧仍 true，用 frame 等待不可行）
	# 主要验证 confirmed 信号已触发（核心行为），remove_window 由 PopWindow 基类保证
	panel.free()


# 源 :34-38 close 按钮 clickHandler → destroy（不触发 doBuy）
func test_close_button_does_not_emit_confirmed() -> void:
	var panel := EquipboardOfbuyPanel.new("equipboardofbuy", {})
	add_child(panel)
	panel.setup_panel({"id": 371, "amount": 1, "pay": "gold", "price": 100, "cost": 100}, cm)
	var emitted := [false]
	panel.confirmed.connect(func() -> void: emitted[0] = true)
	panel._on_close()
	assert_false(emitted[0], "close 不触发 confirmed（源 :25-28 close_button 仅 destroy）")
	panel.free()


# 源 marketconfig.getCoinRes：gold→shop_gold_icon，其他→shop_token_icon
func test_pay_icon_path_gold_vs_diamond() -> void:
	var panel := EquipboardOfbuyPanel.new("equipboardofbuy", {})
	add_child(panel)
	panel.setup_panel({"id": 371, "amount": 1, "pay": "gold", "price": 100, "cost": 100}, cm)
	assert_eq(panel._pay_icon_path("gold"), "res://assets/ui/alpha/HVGA/shop_gold_icon.png", "gold→shop_gold_icon")
	assert_eq(panel._pay_icon_path("diamond"), "res://assets/ui/alpha/HVGA/shop_token_icon.png", "diamond→shop_token_icon")
	panel.free()
